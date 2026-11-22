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
    @State private var position = ScrollPosition(edge: .bottom)
    @State private var auBas = true

    // `☠` Fluidité : ce corps ne lit que le fil (blocs mis en cache par le modèle) ; le texte en flux vit dans
    // `DirectVue`, seule vue invalidée à chaque paquet de deltas. Les blocs sont `Equatable` : un bloc inchangé
    // n'est jamais réévalué, même quand la session (statut, contexte) bouge.
    var body: some View {
        let blocs = modele.blocs(lu) ?? []
        let envois = modele.envois[lu] ?? []
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                debut(vide: blocs.isEmpty && envois.isEmpty)
                ForEach(blocs) { bloc in
                    BlocVue(bloc: bloc, ouvrirActions: ouvrirActions).equatable().transition(Self.arrivee)
                }
                ForEach(Array(envois.enumerated()), id: \.offset) { _, texte in
                    BulleChris(texte: texte).transition(Self.arrivee)
                }
                DirectVue(id: lu, statut: session.statut, taches: TachesDuFil.enCours(blocs),
                          ouvrirTaches: ouvrirTaches)
            }
            .padding(.horizontal, Q.margeTexte).padding(.top, 12).padding(.bottom, 24)
            .animation(.smooth(duration: 0.3), value: blocs.last?.id)
            .animation(.smooth(duration: 0.3), value: envois.count)
        }
        .environment(\.sessionFil, lu)
        // `☠` iOS 18 : sans le rôle `sizeChanges`, un fil qui grandit sous un défilement ancré en bas laissait la vue
        // vide jusqu'au geste suivant (constaté après un envoi). Ancré en bas au départ ET quand la taille change.
        .defaultScrollAnchor(.bottom, for: .initialOffset)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .scrollPosition($position)
        .onScrollGeometryChange(for: Bool.self) { g in
            g.contentOffset.y + g.containerSize.height >= g.contentSize.height - 160
        } action: { _, enBas in auBas = enBas }
        .onChange(of: blocs.count + envois.count) { _, _ in suivreLeBas() }
        .scrollDismissesKeyboard(.interactively)
        .background(Q.fondFil)
    }

    /// Un message ou un bloc arrive : si Chris lisait le bas du fil, on l'y garde (sinon on ne bouge pas sa lecture).
    private func suivreLeBas() {
        guard auBas else { return }
        withAnimation(.smooth(duration: 0.3)) { position.scrollTo(edge: .bottom) }
    }

    private static let arrivee = AnyTransition.opacity.combined(with: .offset(y: 12))

    /// La fiche dont on lit le fil : celle du poste quand la session montrée est sa jumelle Remote Control.
    private var lu: String { modele.sourceLecture(session.id) }

    /// En tête du fil : charger plus ancien à l'apparition, ou l'état vide / chargement.
    @ViewBuilder private func debut(vide: Bool) -> some View {
        if modele.fils[lu] == nil {
            ChargementFil()
        } else if vide && !session.statut.enActivite {
            Text("Rien pour l’instant.\nLe fil s’affiche dès que Claude travaille.").font(Q.detail)
                .foregroundStyle(Q.tertiaire)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
        } else if !modele.debutAtteint.contains(lu) {
            IndicateurTravail().frame(width: 18, height: 18).frame(maxWidth: .infinity)
                .task { await modele.chargerPlusAncien(lu) }
        }
    }
}

/// Ce qui s'écrit maintenant : réflexion, texte en flux, roue de travail, tâches de fond.
private struct DirectVue: View {
    @Environment(ModeleRelais.self) private var modele
    let id: String
    let statut: StatutSession
    let taches: Int
    let ouvrirTaches: () -> Void

    var body: some View {
        if let r = modele.reflexionEnCours[id], !r.isEmpty {
            Text(r.suffix(280)).font(Q.detail).italic().foregroundStyle(Q.tertiaire).lineLimit(4)
        }
        if let t = modele.enEcriture[id], !t.isEmpty {
            MarkdownVue(source: t)
        } else if statut.enActivite {
            HStack(spacing: 10) {
                IndicateurTravail().frame(width: 16, height: 16)
                Text(statut == .compaction ? "Compaction du contexte…" : "Claude travaille…")
                    .font(Q.detail).foregroundStyle(Q.tertiaire)
            }
        }
        if taches > 0 {
            Button(action: ouvrirTaches) {
                Text(taches > 1 ? "\(taches) tâches en cours" : "1 tâche en cours")
                    .font(Q.rangee).foregroundStyle(Q.lien)
            }
        }
    }
}

/// Les sous-agents encore au travail dans le fil (le compteur « N tâches en cours » de l'étalon).
enum TachesDuFil {
    static func enCours(_ blocs: [BlocFil]) -> Int {
        blocs.reduce(0) { total, bloc in
            guard case .actions(let g) = bloc else { return total }
            let agents = g.elements.filter {
                if case .sousAgent(let a) = $0 { return a.fin == nil } else { return false }
            }
            return total + agents.count
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
