// Le lien avec le relais Iris du Pi : présence des PC, états, réglages. Aucune image n'y passe.
#if canImport(UIKit)
import Foundation
import IrisNoyau
import os

public enum EtatRelais: Sendable, Equatable {
    case repos, connexion, connecte, coupe
    /// Une autre caméra (la page web) a pris la place : on ne revient pas de soi-même.
    case remplace
}

actor Signalisation {
    private static let delaiMax: Double = 15
    private static let codeRemplace = 4001

    private let url: URL
    private let recevoir: @Sendable (MessageRelais) async -> Void
    private let changerEtat: @Sendable (EtatRelais) async -> Void
    private var tache: URLSessionWebSocketTask?
    private let journal = Logger(subsystem: "com.echo.labs", category: "iris.relais")

    init(url: URL, recevoir: @escaping @Sendable (MessageRelais) async -> Void,
         changerEtat: @escaping @Sendable (EtatRelais) async -> Void) {
        self.url = url
        self.recevoir = recevoir
        self.changerEtat = changerEtat
    }

    /// Tourne jusqu'à l'annulation de la tâche appelante, en se reconnectant.
    func tourner() async {
        var delai: Double = 1
        while !Task.isCancelled {
            await changerEtat(.connexion)
            let tache = URLSession.shared.webSocketTask(with: url)
            self.tache = tache
            tache.resume()
            do {
                try await boucler(tache)
            } catch {
                journal.info("relais : \(error.localizedDescription, privacy: .public)")
            }
            tache.cancel(with: .goingAway, reason: nil)
            self.tache = nil
            if tache.closeCode.rawValue == Self.codeRemplace {
                await changerEtat(.remplace)
                return
            }
            guard !Task.isCancelled else { break }
            await changerEtat(.coupe)
            try? await Task.sleep(for: .seconds(delai))
            delai = min(delai * 2, Self.delaiMax)
        }
        await changerEtat(.repos)
    }

    func envoyer(_ texte: String) async {
        do {
            try await tache?.send(.string(texte))
        } catch {
            journal.info("envoi au relais impossible : \(error.localizedDescription, privacy: .public)")
        }
    }

    private func boucler(_ tache: URLSessionWebSocketTask) async throws {
        try await tache.send(.string(MessageSortant.maintien))
        await changerEtat(.connecte)
        let recevoir = self.recevoir
        try await withThrowingTaskGroup(of: Void.self) { groupe in
            groupe.addTask {
                while true {
                    try await Task.sleep(for: .seconds(25))
                    try await tache.send(.string(MessageSortant.maintien))
                }
            }
            groupe.addTask {
                while true {
                    switch try await tache.receive() {
                    case .string(let texte): await recevoir(MessageRelais.lire(Data(texte.utf8)))
                    case .data(let donnees): await recevoir(MessageRelais.lire(donnees))
                    @unknown default: break
                    }
                }
            }
            try await groupe.next()
            groupe.cancelAll()
        }
    }
}
#endif
