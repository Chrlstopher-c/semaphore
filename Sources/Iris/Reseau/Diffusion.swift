// La diffusion : une liaison TCP directe par PC qui veut le flux, sur le réseau local.
// La même unité compressée part vers chacun — l'iPhone n'encode qu'une fois.
#if canImport(Network)
import Foundation
import IrisNoyau
import Network
import os

public enum EtatLiaison: Sendable, Equatable {
    case connexion, etablie, injoignable
}

/// `@unchecked Sendable` : tout l'état vit sur `file` (série), y compris les
/// rappels de `NWConnection`, démarrées sur cette même file.
final class Diffusion: @unchecked Sendable {
    private struct Liaison {
        let session: Int
        let connexion: NWConnection
        var restantes: [AdressePoste]
        var regulateur = Regulateur()
        var prete = false
    }

    private static let pause: TimeInterval = 5

    private let file = DispatchQueue(label: "iris.diffusion")
    private var liaisons: [String: Liaison] = [:]
    private var enPause: [String: Date] = [:]
    private let cle: String
    private let demanderCle: @Sendable () -> Void
    private let signaler: @Sendable (String, EtatLiaison?) -> Void
    private let journal = Logger(subsystem: "com.echo.labs", category: "iris.diffusion")

    /// `signaler(nom, nil)` : la liaison n'existe plus.
    init(cle: String, demanderCle: @escaping @Sendable () -> Void,
         signaler: @escaping @Sendable (String, EtatLiaison?) -> Void) {
        self.cle = cle
        self.demanderCle = demanderCle
        self.signaler = signaler
    }

    /// Aligne les liaisons sur les PC qui veulent le flux.
    func accorder(_ voulus: [Recepteur]) {
        file.async { self.accorderSurFile(voulus) }
    }

    func envoyer(_ unite: Data, cle: Bool) {
        let trame = AnnexeB.encadrer(unite)
        file.async { self.envoyerSurFile(trame, cle: cle) }
    }

    private func accorderSurFile(_ voulus: [Recepteur]) {
        let sessions = Dictionary(voulus.map { ($0.nom, $0.session) }, uniquingKeysWith: { a, _ in a })
        for (nom, liaison) in liaisons where sessions[nom] != liaison.session { fermer(nom) }
        let maintenant = Date()
        for recepteur in voulus where liaisons[recepteur.nom] == nil {
            if let reprise = enPause[recepteur.nom], reprise > maintenant { continue }
            let adresses = recepteur.adresses.compactMap(AdressePoste.init)
            ouvrir(recepteur.nom, session: recepteur.session, adresses: adresses)
        }
    }

    private func ouvrir(_ nom: String, session: Int, adresses: [AdressePoste]) {
        guard let adresse = adresses.first else {
            echouer(nom)
            return
        }
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        tcp.connectionTimeout = 3
        let connexion = NWConnection(
            host: NWEndpoint.Host(adresse.hote), port: NWEndpoint.Port(rawValue: adresse.port) ?? .any,
            using: NWParameters(tls: nil, tcp: tcp)
        )
        liaisons[nom] = Liaison(session: session, connexion: connexion, restantes: Array(adresses.dropFirst()))
        connexion.stateUpdateHandler = { [weak self] etat in self?.suivre(nom, session: session, etat) }
        connexion.start(queue: file)
        signaler(nom, .connexion)
    }

    private func suivre(_ nom: String, session: Int, _ etat: NWConnection.State) {
        guard var liaison = liaisons[nom], liaison.session == session else { return }
        switch etat {
        case .ready:
            liaison.connexion.send(content: MessageSortant.poigneeDeMain(cle: cle), completion: .idempotent)
            liaison.prete = true
            liaisons[nom] = liaison
            demanderCle()
            signaler(nom, .etablie)
            journal.info("liaison établie avec \(nom, privacy: .public)")
        case .waiting(let erreur), .failed(let erreur):
            journal.info("liaison \(nom, privacy: .public) : \(erreur.localizedDescription, privacy: .public)")
            liaison.connexion.cancel()
            liaisons[nom] = nil
            if liaison.restantes.isEmpty {
                echouer(nom)
            } else {
                ouvrir(nom, session: session, adresses: liaison.restantes)
            }
        case .cancelled:
            if liaisons[nom]?.connexion === liaison.connexion { liaisons[nom] = nil }
        default:
            break
        }
    }

    private func envoyerSurFile(_ trame: Data, cle: Bool) {
        for (nom, var liaison) in liaisons where liaison.prete {
            guard liaison.regulateur.decider(taille: trame.count, cle: cle) else {
                liaisons[nom] = liaison
                continue
            }
            liaisons[nom] = liaison
            let session = liaison.session, taille = trame.count
            liaison.connexion.send(content: trame, completion: .contentProcessed { [weak self] erreur in
                self?.acquitter(nom, session: session, taille: taille, erreur: erreur)
            })
        }
    }

    private func acquitter(_ nom: String, session: Int, taille: Int, erreur: NWError?) {
        guard var liaison = liaisons[nom], liaison.session == session else { return }
        if erreur != nil {
            fermer(nom)
            echouer(nom)
            return
        }
        liaison.regulateur.acquitter(taille)
        liaisons[nom] = liaison
    }

    private func fermer(_ nom: String) {
        liaisons.removeValue(forKey: nom)?.connexion.cancel()
        signaler(nom, nil)
    }

    private func echouer(_ nom: String) {
        enPause[nom] = Date().addingTimeInterval(Self.pause)
        signaler(nom, .injoignable)
    }
}
#endif
