import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Ce que la connexion de synchro rapporte au store.
public enum EvenementSync: Sendable {
    /// Socket ouvert : le store envoie `hello{since}` et rejoue sa file offline.
    case connecte
    /// Un message décodé du serveur.
    case message(MessageServeur)
    /// Socket fermé (le store bascule l'inbox en « hors ligne »). La reconnexion
    /// est déjà relancée en interne.
    case deconnecte
}

/// La connexion WebSocket `/sync`, avec reconnexion à backoff BORNÉ.
///
/// `actor` : le socket et l'état de reconnexion ne sont touchés que d'ici. Le
/// store consomme `flux` (un `AsyncStream`) et pousse ses écritures par
/// `envoyer`.
///
/// `☠` La boucle de reconnexion est VOLONTAIREMENT longue à vivre — un client
/// de synchro doit re-tenter tant que l'app tourne — mais elle n'est JAMAIS
/// chaude : chaque tour suspend soit sur une réception réseau, soit sur un délai
/// de backoff PLAFONNÉ (`plafondReconnexionSecondes`). Pas de `while(true)` qui
/// brûle le CPU sur un état inattendu ; l'annulation de la tâche la ferme.
public actor ConnexionSync {
    /// Le backoff démarre ici et double à chaque échec consécutif…
    public static let backoffInitialSecondes: Double = 1
    /// …jusqu'à ce plafond, jamais au-delà. Sans plafond, un serveur éteint
    /// longtemps repousserait la reconnexion à des heures.
    public static let plafondReconnexionSecondes: Double = 30

    private let client: ClientSaily
    private var socket: URLSessionWebSocketTask?
    private let session: URLSession
    private var boucle: Task<Void, Never>?
    private var continuation: AsyncStream<EvenementSync>.Continuation?
    private var echecsConsecutifs = 0

    public init(client: ClientSaily) {
        self.client = client
        self.session = URLSession(configuration: .ephemeral)
    }

    /// Le flux d'événements. À consommer une seule fois, par le store.
    public func flux() -> AsyncStream<EvenementSync> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    /// (Re)démarre la boucle de connexion. Idempotent : un appel de plus ne
    /// crée pas une seconde boucle.
    public func demarrer() {
        guard boucle == nil else { return }
        boucle = Task { await boucleConnexion() }
    }

    /// Ferme tout : socket et boucle. La reconnexion ne repartira qu'à un
    /// `demarrer()` explicite.
    public func arreter() {
        boucle?.cancel()
        boucle = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }

    /// Émet un message client sur le socket courant. Lève si le socket n'est pas
    /// ouvert — c'est le signal, pour le store, d'enfiler l'écriture hors ligne.
    public func envoyer(_ message: MessageClient) async throws {
        guard let socket else { throw ErreurSaily.injoignable("socket fermé") }
        let donnees = try CodageJSON.encodeur().encode(message)
        guard let texte = String(data: donnees, encoding: .utf8) else {
            throw ErreurSaily.reponseIllisible("message client non encodable")
        }
        do {
            try await socket.send(.string(texte))
        } catch {
            if ErreurSaily.vientDUneAnnulation(error) { throw ErreurSaily.annule }
            Journal.echec("envoi WS échoué : \(error.localizedDescription)")
            throw ErreurSaily.injoignable(error.localizedDescription)
        }
    }

    // MARK: - Boucle interne

    private func boucleConnexion() async {
        while !Task.isCancelled {
            guard let url = await client.urlSync() else {
                Journal.echec("URL de synchro invalide, reconnexion suspendue")
                await patienter()
                continue
            }
            await ouvrirEtRecevoir(url)
            continuation?.yield(.deconnecte)
            if Task.isCancelled { break }
            await patienter()
        }
    }

    /// Ouvre le socket, signale `.connecte`, puis reçoit jusqu'à la première
    /// erreur — moment où la fonction rend la main à la boucle de reconnexion.
    private func ouvrirEtRecevoir(_ url: URL) async {
        let tache = session.webSocketTask(with: url)
        socket = tache
        tache.resume()
        echecsConsecutifs = 0
        continuation?.yield(.connecte)
        Journal.note("socket de synchro ouvert")
        await boucleReception(tache)
        tache.cancel(with: .goingAway, reason: nil)
        if socket === tache { socket = nil }
    }

    /// Reçoit message après message. Chaque `receive` suspend : la boucle n'est
    /// jamais chaude. Une erreur (socket fermé) la termine.
    private func boucleReception(_ tache: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await tache.receive()
                traiter(message)
            } catch {
                if !ErreurSaily.vientDUneAnnulation(error) {
                    Journal.echec("réception WS interrompue : \(error.localizedDescription)")
                }
                return
            }
        }
    }

    private func traiter(_ message: URLSessionWebSocketTask.Message) {
        let donnees: Data?
        switch message {
        case let .string(texte): donnees = Data(texte.utf8)
        case let .data(brut): donnees = brut
        @unknown default: donnees = nil
        }
        guard let donnees, let decode = MessageServeur.decoder(donnees) else {
            Journal.note("message serveur ignoré (illisible ou type inconnu)")
            return
        }
        continuation?.yield(.message(decode))
    }

    /// Le délai de backoff, plafonné. Compte les échecs consécutifs pour doubler,
    /// sans jamais dépasser le plafond.
    private func patienter() async {
        echecsConsecutifs += 1
        let brut = Self.backoffInitialSecondes * pow(2, Double(echecsConsecutifs - 1))
        let delai = min(brut, Self.plafondReconnexionSecondes)
        try? await Task.sleep(nanoseconds: UInt64(delai * 1_000_000_000))
    }
}
