#if canImport(SwiftUI)
import EchoHub
import SwiftUI
import Vigie

/// Le pupitre : les deux mondes montés en permanence, un sélecteur en tête.
///
/// `☠` Les deux coquilles VIVENT en même temps — changer de monde ne démonte
/// rien. C'est ce qui permet à une génération EchoHub de continuer pendant
/// qu'on tranche une décision au Quart, et au Quart de sonder le Pi pendant
/// qu'on lit une réponse. Le prix : les deux démarrent au lancement, et le
/// monde caché reçoit les `onAppear`. Vigie règle déjà ce cas pour ses propres
/// piles avec `\.ecranVisible` ; EchoHub n'a qu'un onglet actif à la fois et
/// sonde peu.
///
/// Le sélecteur est peint avec la charte de Vigie : le centre de contrôle EST
/// le Quart, et la Machine y est un monde invité. Chaque monde garde sa propre
/// barre en bas — les deux directions artistiques ne se mélangent pas.
struct Pupitre: View {
    @State private var monde: Monde = .quart

    var body: some View {
        VStack(spacing: 0) {
            SelecteurMonde(monde: $monde)
            mondes
        }
        .background(Vigie.Teinte.fond.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var mondes: some View {
        ZStack {
            Vigie.Coquille()
                .opacity(monde == .quart ? 1 : 0)
                .allowsHitTesting(monde == .quart)
            // La suspension à l'arrière-plan est celle d'EchoHub seul ; ici
            // le système de veille de Vigie tient le processus, donc une
            // génération n'a plus à être coupée quand l'écran s'éteint.
            EchoHub.Coquille(suspendreEnArrierePlan: { !MaintienVie.partage.actif })
                .opacity(monde == .machine ? 1 : 0)
                .allowsHitTesting(monde == .machine)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
