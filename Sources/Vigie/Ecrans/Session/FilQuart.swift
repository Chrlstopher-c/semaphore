// Le fil d'une session (étalon 001/022/023) : réponses pleine largeur, bulles de Chris à droite, suites d'actions
// résumées en une ligne qui ouvre leur feuille, texte en cours d'écriture en direct (Direct.swift). Ancré en bas.
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
                    BlocVue(bloc: bloc, ouvrirActions: ouvrirActions).equatable().transition(arrivee(bloc))
                }
                ForEach(Array(envois.enumerated()), id: \.offset) { _, texte in
                    BulleChris(texte: texte).transition(Self.arrivee)
                }
                DirectVue(id: lu, statut: session.statut, attente: !envois.isEmpty,
                          taches: TachesDuFil.enCours(blocs), ouvrirTaches: ouvrirTaches)
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
        .overlay(alignment: .bottom) {
            if !auBas { FlecheVersLeBas(action: allerEnBas).transition(.opacity.combined(with: .scale(scale: 0.85))) }
        }
        .animation(.smooth(duration: 0.2), value: auBas)
    }

    /// Flèche « ↓ » : retour au bas du fil (là où Claude écrit), comme sur l'appli de bureau.
    private func allerEnBas() {
        withAnimation(.smooth(duration: 0.35)) { position.scrollTo(edge: .bottom) }
    }

    /// Un message ou un bloc arrive : si Chris lisait le bas du fil, on l'y garde (sinon on ne bouge pas sa lecture).
    private func suivreLeBas() {
        guard auBas else { return }
        withAnimation(.smooth(duration: 0.3)) { position.scrollTo(edge: .bottom) }
    }

    private static let arrivee = AnyTransition.opacity.combined(with: .offset(y: 12))

    /// Une réponse qui remplace le texte écrit en direct prend sa place telle quelle (aucun fondu ni glissement : le
    /// même texte ne doit pas clignoter) ; tout autre bloc entre en fondu montant.
    private func arrivee(_ bloc: BlocFil) -> AnyTransition {
        guard case .assistant(_, let texte) = bloc, let direct = modele.texteDirectFini[lu],
              texte.hasPrefix(direct.prefix(40)) else { return Self.arrivee }
        return .identity
    }

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
/// Bouton rond flottant au-dessus du champ de saisie, visible seulement quand Chris est remonté dans le fil.
private struct FlecheVersLeBas: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.down")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(.regularMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.08)))
                .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 12)
        .accessibilityLabel("Revenir en bas du fil")
    }
}

#endif
