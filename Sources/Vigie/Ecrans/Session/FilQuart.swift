// Le fil d'une session (étalon 001/022/023) : réponses pleine largeur, bulles de Chris à droite, suites d'actions
// résumées en une ligne qui ouvre leur feuille, texte en cours d'écriture en direct. Ancré en bas.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct FilQuart: View {
    @Environment(ModeleRelais.self) private var modele
    let session: Session
    let ouvrirActions: (GroupeActions) -> Void
    let ouvrirTaches: () -> Void

    var body: some View {
        let blocs = BlocsFil.depuis(StructureFil.structurer(modele.fils[session.id] ?? []))
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                debut(vide: blocs.isEmpty)
                ForEach(blocs) { bloc in BlocVue(bloc: bloc, ouvrirActions: ouvrirActions) }
                direct(blocs)
            }
            .padding(.horizontal, Q.margeTexte).padding(.top, 12).padding(.bottom, 24)
        }
        .defaultScrollAnchor(.bottom)
        .scrollDismissesKeyboard(.interactively)
        .background(Q.fondFil)
    }

    /// En tête du fil : charger plus ancien à l'apparition, ou l'état vide / chargement.
    @ViewBuilder private func debut(vide: Bool) -> some View {
        if modele.fils[session.id] == nil {
            ChargementFil()
        } else if vide && !session.statut.enActivite {
            Text("Rien pour l’instant.\nLe fil s’affiche dès que Claude travaille.").font(Q.detail)
                .foregroundStyle(Q.tertiaire).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.top, 80)
        } else if !modele.debutAtteint.contains(session.id) {
            IndicateurTravail().frame(width: 18, height: 18).frame(maxWidth: .infinity)
                .task { await modele.chargerPlusAncien(session.id) }
        }
    }

    /// Ce qui s'écrit maintenant : réflexion, texte en flux, roue de travail, tâches de fond.
    @ViewBuilder private func direct(_ blocs: [BlocFil]) -> some View {
        if let r = modele.reflexionEnCours[session.id], !r.isEmpty {
            Text(r.suffix(280)).font(Q.detail).italic().foregroundStyle(Q.tertiaire).lineLimit(4)
        }
        if let t = modele.enEcriture[session.id], !t.isEmpty {
            MarkdownVue(source: t)
        } else if session.statut.enActivite {
            HStack(spacing: 10) {
                IndicateurTravail().frame(width: 16, height: 16)
                Text(session.statut == .compaction ? "Compaction du contexte…" : "Claude travaille…")
                    .font(Q.detail).foregroundStyle(Q.tertiaire)
            }
        }
        let n = TachesFond.enCours(blocs)
        if n > 0 {
            Button(action: ouvrirTaches) {
                Text(n > 1 ? "\(n) tâches en cours" : "1 tâche en cours").font(Q.rangee).foregroundStyle(Q.lien)
            }
        }
    }
}

/// Les sous-agents encore au travail dans le fil (le compteur « N tâches en cours » de l'étalon).
enum TachesFond {
    static func enCours(_ blocs: [BlocFil]) -> Int {
        blocs.reduce(0) { total, bloc in
            guard case .actions(let g) = bloc else { return total }
            return total + g.elements.filter { if case .sousAgent(let a) = $0 { return a.fin == nil } else { return false } }.count
        }
    }
}

/// Gabarit pendant le premier chargement : trois lignes estompées, jamais une roue nue au milieu.
private struct ChargementFil: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach([0.9, 0.75, 0.5], id: \.self) { part in
                Capsule().fill(Q.carte).frame(height: 14).frame(maxWidth: .infinity, alignment: .leading)
                    .containerRelativeFrame(.horizontal) { l, _ in l * part }
            }
        }
        .padding(.top, 24)
    }
}
#endif
