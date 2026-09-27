// L'analyse Vision : où elle en est, le geste pour la lancer ou la suspendre, et
// la sévérité des similaires. Elle se reprend là où on l'a laissée.
#if canImport(SwiftUI) && canImport(Photos)
import SwiftUI
import Systeme
import TamisNoyau

struct PanneauAnalyse: View {
    @Environment(Atelier.self) private var atelier

    var body: some View {
        Panneau {
            VStack(alignment: .leading, spacing: Grille.element) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Analyse").font(Voix.entete).foregroundStyle(Neutre.encre)
                    Spacer(minLength: 0)
                    Text(etat).font(Voix.mesure).foregroundStyle(Neutre.encreDouce)
                        .contentTransition(.numericText())
                }
                progression
                Text("Sur l'iPhone, par Vision. Rien ne sort. Compte une demi-heure pour 30 000 photos ; "
                     + "l'écran peut rester dans un autre monde.")
                    .font(Voix.note).foregroundStyle(Neutre.encreEteinte)
                geste
                severite
            }
        }
    }

    private var fait: (Int, Int) {
        let total = atelier.cliches.lazy.filter { $0.media == .photo && $0.date != nil }.count
        if case let .enCours(f, t) = atelier.analyse { return (total - t + f, total) }
        return (total - atelier.restantes.count, total)
    }

    private var etat: String {
        let (f, t) = fait
        return "\(f.formatted()) / \(t.formatted())"
    }

    private var progression: some View {
        let (f, t) = fait
        return ProgressView(value: Double(f), total: Double(max(t, 1)))
            .tint(Teinte.accent)
            .animation(Mouvement.normal, value: f)
    }

    @ViewBuilder private var geste: some View {
        if case .enCours = atelier.analyse {
            Button("Suspendre") { atelier.suspendreAnalyse() }
                .buttonStyle(.appui)
                .font(Voix.entete).foregroundStyle(Neutre.encreDouce)
                .frame(maxWidth: .infinity, minHeight: Grille.cible)
                .background(Neutre.surfaceHaute, in: .rect(cornerRadius: Rayon.controle, style: .continuous))
        } else if !atelier.restantes.isEmpty {
            Button(fait.0 == 0 ? "Lancer l'analyse" : "Reprendre l'analyse") { atelier.lancerAnalyse() }
                .buttonStyle(.engage)
        }
    }

    private var severite: some View {
        @Bindable var atelier = atelier
        return VStack(alignment: .leading, spacing: Grille.serre) {
            Text("Similaires").rubrique()
            Picker("Similaires", selection: $atelier.reglage.seuilSimilarite) {
                Text("Quasi identiques").tag(Float(0.95))
                Text("Proches").tag(Float(0.92))
                Text("Ressemblantes").tag(Float(0.88))
            }
            .pickerStyle(.segmented)
        }
    }
}
#endif
