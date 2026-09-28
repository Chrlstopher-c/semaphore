// L'écran unique de Lueur. Focal : la roue, interrupteur au cœur. Sous elle, l'intensité, les couleurs, les effets.
// Budget : en-tête 34 + 24 + roue 280 + 32 + intensité 68 = 438 pt au-dessus de la ligne de flottaison (641 utiles) ;
// couleurs et effets se gagnent au défilement, par décision.
#if canImport(SwiftUI) && canImport(UIKit)
import LueurNoyau
import SwiftUI
import Systeme

struct LueurEcran: View {
    @Environment(Lampe.self) private var lampe

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Grille.section) {
                VStack(alignment: .leading, spacing: Grille.groupe) {
                    enTete
                    RoueChromatique().frame(maxWidth: .infinity)
                }
                Intensite()
                Nuancier()
                Effets()
            }
            .padding(.horizontal, Grille.ecran)
            .padding(.vertical, Grille.groupe)
        }
        .background(Neutre.fond.ignoresSafeArea())
        .sensoryFeedback(Toucher.butee, trigger: lampe.echecs)
    }

    private var enTete: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Lueur").font(Voix.titreEcran).foregroundStyle(Neutre.encre)
            Spacer()
            Text(libelle).font(Voix.legende).foregroundStyle(couleurEtat)
                .animation(Mouvement.normal, value: libelle)
        }
    }

    private var libelle: String {
        switch lampe.joignabilite {
        case .inconnue: return "…"
        case .sansAdresse: return "Adresse absente"
        case .injoignable: return "Pi injoignable"
        case .jointe: return lampe.etat?.relie == true ? "Ruban relié" : "Ruban injoignable"
        }
    }

    private var couleurEtat: Color {
        switch lampe.joignabilite {
        case .jointe: return lampe.etat?.relie == true ? Semantique.ok : Semantique.alerte
        case .injoignable, .sansAdresse: return Semantique.panne
        case .inconnue: return Neutre.encreEteinte
        }
    }
}

/// L'intensité du ruban, de 1 à 100 %. Valeur locale pendant le glissé, envoyée par la file (la dernière gagne).
private struct Intensite: View {
    @Environment(Lampe.self) private var lampe
    @State private var valeur: Double = 100
    @State private var enCours = false

    var body: some View {
        VStack(alignment: .leading, spacing: Grille.serre) {
            HStack {
                Text("Intensité").rubrique()
                Spacer()
                Text("\(Int(valeur)) %").font(Voix.mesure).foregroundStyle(Neutre.encreDouce)
            }
            Slider(value: $valeur, in: 1...100, step: 1) { enCours = $0 }
                .frame(minHeight: Grille.cible)
                .onChange(of: valeur) { _, v in if enCours { lampe.envoyer(.intensite(Int(v))) } }
        }
        .onChange(of: lampe.etat?.intensite, initial: true) { _, v in
            if let v, !enCours { valeur = Double(v) }
        }
    }
}
#endif
