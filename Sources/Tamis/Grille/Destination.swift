// Les écrans qu'on peut pousser depuis n'importe quel onglet. Une seule table de
// routage : chaque pile y branche la même.
#if canImport(SwiftUI) && canImport(Photos)
import SwiftUI
import Systeme
import TamisNoyau

enum Destination: Hashable {
    /// Une sélection à revoir vignette par vignette.
    case grille(titre: String, ids: [String])
    /// Le tamisage par période.
    case plage
    /// Une piste qui se revoit groupe par groupe.
    case groupes(Piste)
}

extension View {
    func destinationsTamis() -> some View {
        navigationDestination(for: Destination.self) { destination in
            switch destination {
            case let .grille(titre, ids): GrilleEcran(titre: titre, ids: ids)
            case .plage: PlageEcran()
            case let .groupes(piste): GroupesEcran(piste: piste)
            }
        }
    }

    /// Le fond et la barre de navigation communs aux écrans poussés.
    func pageTamis(_ titre: String) -> some View {
        background(Neutre.fond.ignoresSafeArea())
            .navigationTitle(titre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Neutre.fond, for: .navigationBar)
    }
}
#endif
