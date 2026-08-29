#if canImport(SwiftUI)
import EchoHub
import Movix
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
    /// Plein écran du monde Movix : quand il est actif, le sélecteur de mondes
    /// s'efface pour rendre tout le haut de l'écran au player web. Piloté par le
    /// bouton HUD de la coquille Movix.
    @State private var movixImmersif = false
    @Environment(\.accessibilityReduceMotion) private var reduireMouvement

    /// Le chrome ne s'efface que pour Movix : les autres mondes ne touchent
    /// jamais ce drapeau, ils gardent leur sélecteur en toutes circonstances.
    private var immersion: Bool { movixImmersif && monde == .movix }

    var body: some View {
        VStack(spacing: 0) {
            if !immersion {
                SelecteurMonde(monde: $monde, bascule: basculer(vers:))
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
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
            scene(.movix) { Movix.Coquille(immersif: $movixImmersif) }
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
        // Quitter Movix éteint son plein écran : le prochain retour repart avec
        // le chrome visible, jamais coincé sans sélecteur.
        movixImmersif = false
        withAnimation(reduireMouvement ? Mouvement.fonduReduit : Mouvement.surface) {
            monde = cible
        }
    }
}
#endif
