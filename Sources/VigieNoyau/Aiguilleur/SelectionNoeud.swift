import Foundation

// Responsabilité : le choix du nœud auquel l'appareil se relie, parmi les nœuds en ligne du réseau. Ordre : le
// nœud préféré (réglage de Chris) s'il est en ligne ; sinon un nœud appairé (identité connue) en ligne, le sans
// écran d'abord (la tour, toujours allumée) ; sinon, sans aucun appairage, le premier nœud avec écran en ligne
// (il faut un accord humain pour un premier appairage). Jamais soi, jamais un appareil, jamais un nœud refusé.

enum SelectionNoeud {
    static func choisir(
        _ membres: [ProtocoleAiguilleur.Membre], moi: String, appaires: Set<String>,
        prefere: String?, refuses: Set<String> = []
    ) -> String? {
        let vus = membres.filter { $0.enLigne && $0.id != moi && $0.genre == "noeud" && !refuses.contains($0.id) }
        if let prefere, let choisi = vus.first(where: { $0.id == prefere }) { return choisi.id }
        let appaiesEnLigne = vus.filter { appaires.contains($0.id) }
        if !appaiesEnLigne.isEmpty {
            return (appaiesEnLigne.first { $0.sansEcran == true } ?? appaiesEnLigne[0]).id
        }
        if appaires.isEmpty {
            return vus.first { $0.sansEcran != true }?.id
        }
        return nil
    }
}
