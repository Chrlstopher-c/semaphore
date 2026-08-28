// Le dépôt des pièces jointes : sélection, montée, retrait.
//
// Séparé du salon par domaine — l'état d'un côté, le transfert de l'autre, comme
// pour la génération.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

extension Salon {
    /// Dépose des octets sur le PC et garde l'identifiant rendu.
    ///
    /// La vignette apparaît AVANT la montée : sur une photo de 4 Mo en 4G, ne
    /// rien afficher pendant trois secondes donne l'impression que le geste
    /// n'a pas été senti, et fait rappuyer.
    public func joindre(nom: String, typeMime: String, octets: Data) async {
        guard let conversation else { return }
        let piece = PieceJointe(nom: nom, etat: .depot)
        ajouter(piece: piece)
        do {
            let pose = try await fichiers.deposer(
                conversation: conversation.id, nom: nom, typeMime: typeMime, octets: octets
            )
            majPiece(piece.id, .posee(pose.id))
        } catch {
            Journal.echec("dépôt de « \(nom) » échoué : \(error)")
            majPiece(piece.id, .echec(Self.libelle(error)))
        }
    }

    /// Le type MIME vient de l'EXTENSION, jamais du contenu : c'est ce que le
    /// serveur valide (`backend/fichiers/politique.py`), et il refuse tout ce
    /// qui n'est pas dans sa liste blanche.
    public func joindre(fichierA url: URL) async {
        let accessible = url.startAccessingSecurityScopedResource()
        defer { if accessible { url.stopAccessingSecurityScopedResource() } }
        do {
            let octets = try Data(contentsOf: url)
            await joindre(
                nom: url.lastPathComponent, typeMime: Self.typeMime(de: url), octets: octets
            )
        } catch {
            Journal.echec("lecture de « \(url.lastPathComponent) » impossible : \(error)")
            ajouter(piece: PieceJointe(
                nom: url.lastPathComponent, etat: .echec("Fichier illisible.")
            ))
        }
    }

    static func typeMime(de url: URL) -> String {
        #if canImport(UniformTypeIdentifiers)
        if let type = UTType(filenameExtension: url.pathExtension),
           let mime = type.preferredMIMEType {
            return mime
        }
        #endif
        // Le serveur accepte `application/octet-stream` : mieux vaut lui laisser
        // trancher que refuser ici sur une extension inconnue.
        return "application/octet-stream"
    }
}
#endif
