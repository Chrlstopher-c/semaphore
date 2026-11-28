#if canImport(SwiftUI)
import Duplex
import EchoHub
import Iris
import Lueur
import Saily
import SwiftUI
import Systeme
import Tamis
import Vigie

/// Le pupitre : un sélecteur en tête, et SEUL le monde affiché est monté.
///
/// `☠` Les mondes vivaient tous en même temps (sondes, flux, rendus cachés) : l'iPhone chauffait pour des écrans
/// que Chris ne regardait pas (28/11/2026). Quitter un monde le démonte, ses tâches s'arrêtent. Une génération
/// EchoHub n'est pas perdue : le PC la poursuit et la persiste, l'app la relit au retour. Ce qui doit survivre au
/// changement de monde (veille, alertes de Quart) vit dans le câblage de l'app, pas dans une coquille.
///
/// Le chrome est peint avec le socle `Systeme`, en pierre neutre : le centre
/// de contrôle n'appartient à aucun monde. Chaque monde garde sa propre barre
/// en bas et sa couleur — les directions artistiques ne se mélangent pas.
struct Pupitre: View {
    @State private var monde: Monde = .quart
    @State private var grilleOuverte = false
    @Environment(\.accessibilityReduceMotion) private var reduireMouvement

    var body: some View {
        VStack(spacing: 0) {
            SelecteurMonde(monde: monde, ouverte: $grilleOuverte)
            mondes.overlay(alignment: .top) {
                if grilleOuverte {
                    GrilleMondes(monde: monde, fermer: fermerGrille, bascule: basculer(vers:))
                }
            }
        }
        .background(Neutre.fond.ignoresSafeArea())
        // Tous les mondes sont sombres ; Quart aussi depuis sa v1 (étalon capturé en sombre).
        .preferredColorScheme(.dark)
        .sensoryFeedback(Toucher.selection, trigger: monde)
    }

    private var mondes: some View {
        ZStack {
            scene
                .id(monde)
                .transition(reduireMouvement ? .opacity : .monde)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Une notification ou un lien de session de Quart ramène à Quart, d'où qu'on soit.
        .onChange(of: Vigie.LienProfond.sessionEnAttente) { _, id in
            if id != nil { basculer(vers: .quart) }
        }
    }

    @ViewBuilder private var scene: some View {
        switch monde {
        case .quart: Vigie.Coquille()
        // La suspension à l'arrière-plan est celle d'EchoHub seul ; ici
        // le système de veille de Vigie tient le processus, donc une
        // génération n'a plus à être coupée quand l'écran s'éteint.
        case .machine: EchoHub.Coquille(suspendreEnArrierePlan: { !MaintienVie.partage.actif })
        case .saily: Saily.Coquille()
        case .duplex: Duplex.Coquille()
        case .tamis: Tamis.Coquille(visible: true)
        case .iris: Iris.Coquille(visible: true)
        case .lueur: Lueur.Coquille(visible: true)
        }
    }

    /// Le seul point d'écriture de `monde` : la bascule est toujours jouée
    /// avec le même mouvement, réduit à un fondu court quand « Réduire les
    /// animations » est actif.
    private func basculer(vers cible: Monde) {
        fermerGrille()
        guard cible != monde else { return }
        withAnimation(reduireMouvement ? Mouvement.fonduReduit : Mouvement.surface) {
            monde = cible
        }
    }

    private func fermerGrille() {
        withAnimation(reduireMouvement ? Mouvement.fonduReduit : Mouvement.normal) {
            grilleOuverte = false
        }
    }
}
#endif
