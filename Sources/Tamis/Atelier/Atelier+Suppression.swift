// La suppression du panier. iOS affiche sa propre confirmation ; un refus n'est
// pas une panne, le panier reste tel quel.
#if canImport(SwiftUI) && canImport(Photos)
import Foundation
import Photos
import TamisNoyau

extension Atelier {
    func viderPanier() async {
        let ids = Array(decisions.panier)
        guard !ids.isEmpty else { return }
        let poids = poidsPanier
        do {
            try await Inventaire.supprimer(ids)
            retirer(Set(ids))
            bilan = Bilan(nombre: ids.count, poids: poids, echec: nil)
            Journal.note("supprimés : \(ids.count)")
        } catch {
            let annule = (error as? PHPhotosError)?.code == .userCancelled
                || (error as NSError).code == 3072
            Journal.echec("suppression : \(error.localizedDescription)")
            bilan = annule ? nil : Bilan(nombre: 0, poids: 0, echec: error.localizedDescription)
        }
    }
}
#endif
