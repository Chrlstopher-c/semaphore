#if canImport(SwiftUI)
import Duplex
import EchoHub
import Saily
import SwiftUI
import Systeme
import Vigie

/// Le pupitre : les mondes montés en permanence, un sélecteur en tête.
///
/// `☠` Les coquilles VIVENT en même temps — changer de monde ne démonte
/// rien. C'est ce qui permet à une génération EchoHub de continuer pendant
/// qu'on tranche une décision au Quart, et au Quart de sonder le Pi pendant
/// qu'on lit une réponse. Le prix : tout démarre au lancement, et le
/// monde caché reçoit les `onAppear`. Vigie règle déjà ce cas pour ses propres
/// piles avec `\.ecranVisible` ; EchoHub n'a qu'un onglet actif à la fois et
/// sonde peu.
///
/// Le chrome est peint avec le socle `Systeme`, en pierre neutre : le centre
/// de contrôle n'appartient à aucun monde. Chaque monde garde sa propre barre
/// en bas et sa couleur — les directions artistiques ne se mélangent pas.
///
/// La bascule de monde reproduit `AnyTransition.monde` (zoom profond + fondu)
/// SANS `.id` ni transition d'insertion : une identité changeante démonterait
/// les coquilles et tuerait la génération en cours. On anime donc `scale` et
/// `opacity` sur les vues persistantes — même geste, zéro démontage.
struct Pupitre: View {
    @State private var monde: Monde = .quart
    @Environment(\.accessibilityReduceMotion) private var reduireMouvement

    var body: some View {
        VStack(spacing: 0) {
            SelecteurMonde(monde: $monde, bascule: basculer(vers:))
            mondes
        }
        .background(Neutre.fond.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sensoryFeedback(Toucher.selection, trigger: monde)
    }

    private var mondes: some View {
        ZStack {
            scene(.quart) { Vigie.Coquille() }
            // La suspension à l'arrière-plan est celle d'EchoHub seul ; ici
            // le système de veille de Vigie tient le processus, donc une
            // génération n'a plus à être coupée quand l'écran s'éteint.
            scene(.machine) {
                EchoHub.Coquille(suspendreEnArrierePlan: { !MaintienVie.partage.actif })
            }
            scene(.saily) { Saily.Coquille() }
            scene(.duplex) { Duplex.Coquille() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Habille une coquille persistante pour la bascule : le monde actif est
    /// à l'échelle 1, le monde caché recule à 0,98 dans le fondu. À l'entrée
    /// il avance donc vers soi, à la sortie il plonge — le geste de
    /// `AnyTransition.monde`, sans insertion ni retrait.
    private func scene(_ cible: Monde, @ViewBuilder _ contenu: () -> some View) -> some View {
        let actif = monde == cible
        return contenu()
            .opacity(actif ? 1 : 0)
            .scaleEffect(reduireMouvement ? 1 : (actif ? 1 : 0.98))
            .allowsHitTesting(actif)
            .accessibilityHidden(!actif)
    }

    /// Le seul point d'écriture de `monde` : la bascule est toujours jouée
    /// avec le même mouvement, réduit à un fondu court quand « Réduire les
    /// animations » est actif.
    private func basculer(vers cible: Monde) {
        guard cible != monde else { return }
        withAnimation(reduireMouvement ? Mouvement.fonduReduit : Mouvement.surface) {
            monde = cible
        }
    }
}
#endif
