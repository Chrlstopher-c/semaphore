// Une pièce jointe choisie mais pas encore envoyée.
//
// `☠` Ce module N'EST PAS l'autorité sur ce qui est accepté — le plafond réel
// vit côté serveur (`control-plane/pieces-jointes/`) et son refus est montré
// mot pour mot en cas de dépassement (voir `Composeur.envoyer`). On ne
// duplique ici qu'un plafond de COMPTE, pour un retour immédiat sans aller-
// retour réseau ; la taille, elle, n'est jamais devinée côté client.
#if canImport(SwiftUI)
import Foundation
// `PhotosPickerItem` n'est visible qu'avec SwiftUI dans la portée : la partie
// utile de PhotosUI est une surcouche SwiftUI, pas le framework historique.
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct PieceEnAttente: Identifiable, Equatable, Sendable {
    let id = UUID()
    let nom: String
    /// Type MIME — c'est ce que le contrat attend dans `pieces[].type`.
    let type: String
    let donnees: Data

    /// Même plafond que la maquette web (`HP_MAX_FICHIERS`).
    static let plafondParMessage = 6

    /// La forme attendue par `POST …/message` : `{ nom, type, donneesBase64 }`.
    /// `☠` Le serveur ne valide RIEN dans la route — types, tailles et plafonds
    /// sont refusés par le domaine `pieces-jointes`, en 400 avec un message qui
    /// nomme ce qui est accepté. On l'affiche tel quel plutôt que de dupliquer
    /// ici une seconde vérité sur ce qui passe.
    var charge: ValeurJSON {
        .objet([
            "nom": .texte(nom),
            "type": .texte(type),
            "donneesBase64": .texte(donnees.base64EncodedString()),
        ])
    }

    var tailleLisible: String {
        let octets = donnees.count
        if octets >= 1_048_576 { return String(format: "%.1f Mo", Double(octets) / 1_048_576) }
        return "\(max(1, octets / 1024)) Ko"
    }
}

extension PieceEnAttente {
    /// Lit un `PhotosPickerItem` en pièce prête à joindre. `nil` = fichier
    /// illisible (purge de la photothèque, format que `Transferable` refuse).
    static func depuis(_ item: PhotosPickerItem) async -> PieceEnAttente? {
        guard let donnees = try? await item.loadTransferable(type: Data.self) else { return nil }
        let genre = item.supportedContentTypes.first
        let mime = genre?.preferredMIMEType ?? "image/jpeg"
        let extensionFichier = genre?.preferredFilenameExtension ?? "jpg"
        // Le presse-papier et la photothèque ne nomment pas toujours ce qu'ils
        // donnent : sans repli, toutes les captures d'un fil s'appelleraient pareil.
        let nom = "capture-\(Int(Date().timeIntervalSince1970)).\(extensionFichier)"
        return PieceEnAttente(nom: nom, type: mime, donnees: donnees)
    }
}
#endif
