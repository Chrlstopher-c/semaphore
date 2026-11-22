import Foundation

// Responsabilité : le choix du nœud auquel un appareil se relie — le premier nœud en ligne, jamais soi, jamais
// un autre appareil. Un membre sans genre n'est pas un nœud : on ne relie pas un appareil à l'inconnu.

enum SelectionNoeud {
    /// Identifiant du premier nœud en ligne (genre « noeud » explicite, différent de soi), ou nil sinon.
    static func choisir(_ membres: [ProtocoleAiguilleur.Membre], moi: String) -> String? {
        membres.first { $0.enLigne && $0.id != moi && $0.genre == "noeud" }?.id
    }
}
