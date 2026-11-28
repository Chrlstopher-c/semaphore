// Le coffre echo-vault de la tour, vu de Saily : la liste, le verrou Face ID et les écritures.
// Le chemin est celui d'EchoHub (relais du Pi → tour) : même adresse, même jeton, lus à chaque ouverture.
#if canImport(SwiftUI) && canImport(LocalAuthentication)
import EchoHubNoyau
import LocalAuthentication
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@MainActor @Observable
final class Coffre {
    enum Etat: Equatable {
        case verrouille, chargement, pret, echec(String)
    }

    private(set) var etat = Etat.verrouille
    private(set) var secrets: [SecretCoffre] = []
    /// Le coffre de l'app, gardé quand le pupitre démonte le monde Saily (il se reverrouille quand même).
    static let memoire = Coffre()

    private var client: ClientEchoHub {
        ClientEchoHub(reglages: MagasinReglagesRelaisDisque(dossier: FileManager.dossierReglagesParDefaut()).charger())
    }

    /// Face ID, ou le code de l'iPhone en repli.
    func deverrouiller() async {
        let contexte = LAContext()
        do {
            guard try await contexte.evaluatePolicy(
                .deviceOwnerAuthentication, localizedReason: "Ouvrir le coffre de la tour"
            ) else { return }
        } catch {
            return
        }
        await charger()
    }

    func verrouiller() {
        etat = .verrouille
        secrets = []
    }

    func charger() async {
        if secrets.isEmpty { etat = .chargement }
        do {
            secrets = try await client.secretsCoffre().sorted { $0.nom.localizedStandardCompare($1.nom) == .orderedAscending }
            etat = .pret
        } catch {
            etat = .echec(Self.libelle(error))
        }
    }

    func valeur(_ nom: String) async throws -> String {
        try await client.valeurSecret(nom)
    }

    func creer(_ edition: EditionSecret) async throws {
        try await client.creerSecret(edition)
        await charger()
    }

    func modifier(_ nom: String, _ edition: EditionSecret) async throws {
        try await client.modifierSecret(nom, edition)
        await charger()
    }

    func supprimer(_ nom: String) async throws {
        try await client.supprimerSecret(nom)
        secrets.removeAll { $0.nom == nom }
    }

    func allumerLaTour() async {
        try? await client.reveillerTour()
    }

    /// Copie qui s'efface d'elle-même au bout d'une minute, et ne part pas vers les autres appareils.
    static func copier(_ texte: String) {
        UIPasteboard.general.setItems(
            [[UTType.plainText.identifier: texte]],
            options: [.expirationDate: Date().addingTimeInterval(60), .localOnly: true]
        )
    }

    static func libelle(_ erreur: Error) -> String {
        (erreur as? ErreurRelais)?.libelle ?? erreur.localizedDescription
    }
}
#endif
