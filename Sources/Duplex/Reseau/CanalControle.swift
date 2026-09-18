// Le canal de contrôle : un WebSocket sur TCP 7651. Tout ce qui n'est pas de
// l'audio passe par ici.
#if canImport(SwiftUI)
import DuplexNoyau
import Foundation

/// Ce que le canal rapporte au duplexeur.
public enum EvenementCanal: Sendable {
    case ouvert
    case recu(MessagePoste)
    /// Fermé, avec la raison quand il y en a une. Le canal ne se rouvre PAS tout
    /// seul : c'est une action de Chris, pas une reconnexion de fond. Rouvrir
    /// sans lui relancerait une écoute qu'il vient peut-être d'arrêter.
    case ferme(ErreurDuplex?)
}

/// Le WebSocket de contrôle, et son battement.
///
/// `actor` : le socket, la minuterie et l'horodatage du dernier signe de vie ne
/// sont touchés que d'ici.
public actor CanalControle {
    private let session = URLSession(configuration: .ephemeral)
    private var socket: URLSessionWebSocketTask?
    private var reception: Task<Void, Never>?
    private var battement: Task<Void, Never>?
    private var continuation: AsyncStream<EvenementCanal>.Continuation?
    private var dernierSigneDeVie = Date()

    public init() {}

    public func flux() -> AsyncStream<EvenementCanal> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    /// Ouvre le canal. Un canal déjà ouvert est d'abord fermé : deux sockets sur
    /// le même PC feraient émettre deux flux vers deux ports.
    public func ouvrir(_ url: URL) {
        fermer()
        let tache = session.webSocketTask(with: url)
        socket = tache
        dernierSigneDeVie = Date()
        tache.resume()
        continuation?.yield(.ouvert)
        Journal.note("canal de contrôle ouvert vers \(url.absoluteString)")
        reception = Task { await boucleReception(tache) }
        battement = Task { await boucleBattement() }
    }

    public func fermer() {
        reception?.cancel()
        battement?.cancel()
        reception = nil
        battement = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }

    /// Émet un message. Lève si le canal n'est pas ouvert — c'est le signal, pour
    /// le duplexeur, que le geste n'a pas eu lieu.
    public func emettre(_ message: MessageTelephone) async throws {
        guard let socket else { throw ErreurDuplex.injoignable("canal fermé") }
        do {
            try await socket.send(.string(try message.texte()))
        } catch {
            if ErreurDuplex.vientDUneAnnulation(error) { throw ErreurDuplex.annule }
            Journal.echec("émission refusée : \(error.localizedDescription)")
            throw ErreurDuplex.injoignable(error.localizedDescription)
        }
    }

    // MARK: - Les deux boucles

    /// Reçoit message après message. Chaque `receive` SUSPEND : la boucle n'est
    /// jamais chaude. Une erreur la termine et ferme le canal.
    private func boucleReception(_ tache: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let recu = try await tache.receive()
                dernierSigneDeVie = Date()
                traiter(recu)
            } catch {
                guard !Task.isCancelled, !ErreurDuplex.vientDUneAnnulation(error) else { return }
                Journal.echec("canal interrompu : \(error.localizedDescription)")
                continuation?.yield(.ferme(.injoignable(error.localizedDescription)))
                return
            }
        }
    }

    /// Un battement toutes les 5 s, et la surveillance du silence d'en face.
    ///
    /// `☠` Sans battement pendant 15 s, le PC cesse d'émettre. Le téléphone
    /// applique le MÊME seuil dans l'autre sens : sans ça, Chris resterait devant
    /// un bouton « en écoute » alors que plus rien n'arrive depuis une minute.
    private func boucleBattement() async {
        while !Task.isCancelled {
            try? await Task.sleep(
                nanoseconds: UInt64(Cadence.battementSecondes * 1_000_000_000)
            )
            guard !Task.isCancelled else { return }
            if Date().timeIntervalSince(dernierSigneDeVie) > Cadence.silenceToleredSecondes {
                Journal.echec("aucun signe du PC depuis \(Cadence.silenceToleredSecondes) s")
                continuation?.yield(.ferme(.injoignable("le PC ne répond plus")))
                fermer()
                return
            }
            try? await emettre(.battement)
        }
    }

    private func traiter(_ recu: URLSessionWebSocketTask.Message) {
        let donnees: Data?
        switch recu {
        case let .string(texte): donnees = Data(texte.utf8)
        case let .data(brut): donnees = brut
        @unknown default: donnees = nil
        }
        guard let donnees, let message = MessagePoste.decoder(donnees) else {
            Journal.note("message du PC ignoré (illisible ou type inconnu)")
            return
        }
        continuation?.yield(.recu(message))
    }
}
#endif
