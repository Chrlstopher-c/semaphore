// La découverte des PC sur le réseau local, par Bonjour natif, et la résolution
// d'un service en adresse joignable.
#if canImport(SwiftUI)
import DuplexNoyau
import Foundation
import Network

/// Parcourt `_duplex._tcp` et rend la liste des PC qui s'y publient.
///
/// `☠` On ne devine JAMAIS une adresse et on ne balaie jamais le réseau : le
/// protocole l'interdit, et iOS punirait un balayage en refusant l'autorisation
/// « réseau local ». Le point de contact est le service Bonjour, rien d'autre.
///
/// `☠` Sur iOS 18, sans `NSBonjourServices` listant `_duplex._tcp` dans
/// l'`Info.plist`, le navigateur ne rend AUCUN résultat — sans erreur, sans
/// invite, sans trace. Une liste vide n'est donc pas forcément un PC éteint.
public actor Decouverte {
    private var navigateur: NWBrowser?
    private var continuation: AsyncStream<[PosteTrouve]>.Continuation?
    /// L'extrémité Bonjour de chaque poste, par identifiant. Elle ne peut pas
    /// vivre dans `PosteTrouve` : le noyau est pur et ne connaît pas `Network`.
    private var extremites: [String: NWEndpoint] = [:]

    public init() {}

    /// Le flux des relevés. À consommer une seule fois, par le duplexeur.
    public func flux() -> AsyncStream<[PosteTrouve]> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    /// Démarre le parcours. Idempotent : un appel de plus ne crée pas un second
    /// navigateur.
    public func demarrer() {
        guard navigateur == nil else { return }
        let parametres = NWParameters()
        parametres.includePeerToPeer = false
        let navigateur = NWBrowser(
            for: .bonjourWithTXTRecord(type: Cadence.service, domain: nil), using: parametres
        )
        navigateur.browseResultsChangedHandler = { [weak self] resultats, _ in
            let releve = Self.lire(resultats)
            Task { await self?.publier(releve) }
        }
        navigateur.stateUpdateHandler = { [weak self] etat in
            guard case let .failed(erreur) = etat else { return }
            Journal.echec("découverte interrompue : \(erreur.localizedDescription)")
            Task { await self?.publier([]) }
        }
        self.navigateur = navigateur
        navigateur.start(queue: .global(qos: .userInitiated))
    }

    public func arreter() {
        navigateur?.cancel()
        navigateur = nil
        extremites.removeAll()
        continuation?.yield([])
    }

    /// Résout un poste en URL de canal de contrôle.
    ///
    /// `☠` Un nom d'instance Bonjour (`Tour._duplex._tcp.local`) n'est PAS un
    /// nom d'hôte : il se résout par un enregistrement SRV, que `URLSession` ne
    /// sait pas interroger. On ouvre donc une connexion `Network` — qui, elle,
    /// résout Bonjour nativement — juste le temps de lire l'hôte et le port
    /// réels, puis on la referme et on passe le relais au WebSocket.
    public func resoudre(poste: String) async throws -> URL {
        guard let extremite = extremites[poste] else {
            throw ErreurDuplex.decouverteImpossible("PC disparu de la liste")
        }
        let (hote, port) = try await ResolutionBonjour.resoudre(extremite)
        guard let url = AdresseUrl.canal(hote: hote, port: port) else {
            throw ErreurDuplex.decouverteImpossible("adresse résolue illisible : \(hote)")
        }
        return url
    }

    private func publier(_ releve: [(poste: PosteTrouve, extremite: NWEndpoint)]) {
        for entree in releve { extremites[entree.poste.id] = entree.extremite }
        continuation?.yield(releve.map(\.poste))
    }

    /// Traduit les résultats Bonjour en postes. Un service dont le TXT est
    /// inexploitable est ignoré, jamais affiché à moitié.
    private static func lire(
        _ resultats: Set<NWBrowser.Result>
    ) -> [(poste: PosteTrouve, extremite: NWEndpoint)] {
        resultats.compactMap { resultat in
            guard case let .service(nom, _, _, _) = resultat.endpoint,
                  case let .bonjour(txt) = resultat.metadata else { return nil }
            var champs: [String: String] = [:]
            for cle in ["v", "nom", "id"] where txt[cle] != nil {
                champs[cle] = txt[cle]
            }
            guard let poste = EnregistrementTXT.lire(champs, service: nom) else { return nil }
            return (poste, resultat.endpoint)
        }
        .sorted { $0.poste.nom.localizedCaseInsensitiveCompare($1.poste.nom) == .orderedAscending }
    }
}

/// Résout une extrémité Bonjour en hôte et port concrets.
enum ResolutionBonjour {
    /// Au-delà, on abandonne : une résolution qui traîne est un PC parti, et
    /// laisser l'utilisateur devant un rouet muet est le pire des deux maux.
    static let delaiSecondes: Double = 5

    static func resoudre(_ extremite: NWEndpoint) async throws -> (hote: String, port: UInt16) {
        let connexion = NWConnection(to: extremite, using: .tcp)
        defer { connexion.cancel() }
        return try await withThrowingTaskGroup(of: (String, UInt16).self) { groupe in
            groupe.addTask { try await attendreAdresse(connexion) }
            groupe.addTask {
                try await Task.sleep(nanoseconds: UInt64(delaiSecondes * 1_000_000_000))
                throw ErreurDuplex.injoignable("résolution trop longue")
            }
            guard let premier = try await groupe.next() else {
                throw ErreurDuplex.injoignable("résolution sans réponse")
            }
            groupe.cancelAll()
            return premier
        }
    }

    /// `☠` Le continuation ne doit être repris qu'UNE fois : `stateUpdateHandler`
    /// peut passer `.ready` puis `.cancelled` — et reprendre deux fois ne rate
    /// pas silencieusement, ça tue le processus. D'où la sentinelle.
    private static func attendreAdresse(
        _ connexion: NWConnection
    ) async throws -> (String, UInt16) {
        let porte = PorteUnique()
        return try await withCheckedThrowingContinuation { suite in
            connexion.stateUpdateHandler = { etat in
                switch etat {
                case .ready:
                    guard let adresse = adresse(de: connexion) else {
                        porte.franchir { suite.resume(throwing: ErreurDuplex
                            .injoignable("extrémité résolue sans adresse")) }
                        return
                    }
                    porte.franchir { suite.resume(returning: adresse) }
                case let .failed(erreur):
                    porte.franchir {
                        suite.resume(throwing: ErreurDuplex
                            .injoignable(erreur.localizedDescription))
                    }
                case .cancelled:
                    porte.franchir {
                        suite.resume(throwing: ErreurDuplex.annule)
                    }
                default:
                    break
                }
            }
            connexion.start(queue: .global(qos: .userInitiated))
        }
    }

    private static func adresse(de connexion: NWConnection) -> (String, UInt16)? {
        guard case let .hostPort(hote, port) = connexion.currentPath?.remoteEndpoint else {
            return nil
        }
        return (texte(hote), port.rawValue)
    }

    /// Un IPv6 doit être mis entre crochets dans une URL, et son identifiant de
    /// zone (`%en0`) réencodé — sinon `URL(string:)` rend `nil` sans rien dire.
    private static func texte(_ hote: NWEndpoint.Host) -> String {
        switch hote {
        case let .name(nom, _):
            return nom
        case let .ipv4(adresse):
            return "\(adresse)"
        case let .ipv6(adresse):
            return "[\("\(adresse)".replacingOccurrences(of: "%", with: "%25"))]"
        @unknown default:
            return "\(hote)"
        }
    }
}

/// Une porte qui ne s'ouvre qu'une fois, sous verrou.
///
/// `☠` Les rappels de `Network` et d'`URLSession` peuvent se déclencher DEUX
/// fois — une fois pour le succès, une fois pour l'annulation qui suit. Un
/// `CheckedContinuation` repris deux fois fait tomber le processus, il n'ignore
/// pas le second appel. Toute reprise depuis un rappel plateforme passe par ici.
final class PorteUnique: @unchecked Sendable {
    private var franchie = false
    private let verrou = NSLock()

    func franchir(_ geste: () -> Void) {
        verrou.lock()
        let dejaFait = franchie
        franchie = true
        verrou.unlock()
        guard !dejaFait else { return }
        geste()
    }
}
#endif
