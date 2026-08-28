// Le mouvement de la charte, adossé au moteur du socle `Systeme`. Les noms
// historiques restent : les composants écrivent `Elan.vif` sans changement.
// Bouge : l'arrivée d'un élément NOUVEAU, un changement d'état, le retour
// d'appui. Ne bouge jamais : un rafraîchissement périodique, le texte lu, la
// position de défilement.
//
// `entreeEnScene` et les transitions viennent du socle `Systeme`, hérités par
// visibilité transitive du module. Les redéfinir ici créerait une ambiguïté à
// l'appel (deux candidats visibles) — c'est ce que le compilateur a tranché.
#if canImport(SwiftUI)
import SwiftUI
import Systeme

public enum Elan {
    /// Retour d'appui, bascules, sélection.
    public static let vif = Mouvement.micro
    /// Changements d'état, plis et déplis.
    public static let pose = Mouvement.normal
    /// Arrivée d'un élément nouveau.
    public static let entree = Mouvement.surface

    /// Cascade du socle : 40 ms par rang, plafonnée — le douzième élément
    /// d'une longue liste n'attend pas une seconde pour exister.
    public static func cascade(_ rang: Int) -> Animation {
        Mouvement.cascade(rang)
    }
}

/// Trois points qui respirent — « quelque chose est en train de se produire ».
/// Réservé à un travail réellement en vol (génération, résultat attendu).
public struct SouffleActivite: View {
    let teinte: Color
    @State private var phase = false

    public init(teinte: Color = Teinte.encreTernie) {
        self.teinte = teinte
    }

    public var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { rang in
                Circle()
                    .fill(teinte)
                    .frame(width: 4, height: 4)
                    .opacity(phase ? 1 : 0.25)
                    .animation(
                        .easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(Double(rang) * 0.16),
                        value: phase
                    )
            }
        }
        .onAppear { phase = true }
    }
}
#endif
