// L'onglet où l'on vit : le fil de la conversation en cours, et le composeur.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

public struct DiscussionEcran: View {
    @Environment(Salon.self) private var salon
    @State private var outilsOuverts = false
    @State private var reglagesOuverts = false
    @State private var arbreOuvert = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Teinte.fond.ignoresSafeArea()
                contenu
            }
            .navigationTitle("Fil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { barre }
            .sheet(isPresented: $outilsOuverts) { OutilsFeuille() }
            .task(id: salon.conversation?.id) { await salon.releverLesOutils() }
            .sheet(isPresented: $reglagesOuverts) { ReglagesConversationFeuille() }
            .sheet(isPresented: $arbreOuvert) { ArbreEcran() }
        }
    }

    @ViewBuilder private var contenu: some View {
        switch salon.etatFil {
        case .vide:
            EtatCalme(
                symbole: "text.alignleft",
                titre: "Aucune conversation",
                detail: "Ouvres-en une depuis l'onglet Conversations, ou commences-en une neuve.",
                actionTitre: "Nouvelle conversation",
                action: { Task { await salon.nouvelleConversation() } }
            )
            .transition(.scene)
        case .chargement:
            ChargementVue().transition(.scene)
        case .echec(let raison):
            EtatCalme(
                symbole: "antenna.radiowaves.left.and.right.slash",
                titre: "Fil indisponible",
                detail: raison,
                actionTitre: "Réessayer",
                action: reessayer
            )
            .transition(.scene)
        case .pret:
            pile
        }
    }

    /// L'empilement du fil : ce qui se lit, ce qui est coupé, ce qui empêche, et
    /// ce qui écrit. L'ordre est celui de la lecture, du haut vers le pouce.
    private var pile: some View {
        VStack(spacing: 0) {
            if filVierge { FilVierge() } else { FilConversation() }
            RappelOutils(
                selection: salon.outilsConversation, total: salon.nombreOutils,
                ouvrir: { outilsOuverts = true }
            )
            BandeauMachine()
            Composeur()
        }
        .animation(Elan.normal, value: salon.statutPret?.etat)
        .transition(.scene)
    }

    /// Une conversation ouverte où rien ne s'est encore dit. Un fil nu avec un
    /// composeur en bas ressemblerait à un écran cassé — c'est un état dessiné.
    private var filVierge: Bool {
        salon.messages.isEmpty && salon.enCours == nil && salon.erreurGeneration == nil
    }

    @ToolbarContentBuilder private var barre: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if let modele = salon.statutPret?.modele, salon.statutPret?.estPret == true {
                Text(modele).mesureFine().foregroundStyle(Teinte.encreDouce).lineLimit(1)
            }
        }
        ToolbarItem(placement: .topBarTrailing) { menuConversation }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task { await salon.nouvelleConversation() }
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .buttonStyle(.appui)
            .foregroundStyle(Teinte.accent)
            .disabled(salon.enGeneration)
            .accessibilityLabel("Nouvelle conversation")
        }
    }

    /// Deux feuilles derrière un seul point d'entrée : elles ne s'ouvrent que
    /// sur une conversation, et deux icônes de plus dans la barre voleraient la
    /// place du nom du modèle.
    private var menuConversation: some View {
        Menu {
            Button { reglagesOuverts = true } label: {
                Label("Réglages", systemImage: "slider.horizontal.3")
            }
            Button { outilsOuverts = true } label: {
                // L'état dans le libellé : le menu dit ce qu'on trouvera
                // derrière, plutôt que de le faire ouvrir pour le savoir.
                Label(
                    "Outils — \(salon.outilsConversation.resume(surTotal: salon.nombreOutils))",
                    systemImage: "wrench.and.screwdriver"
                )
            }
            Button { arbreOuvert = true } label: {
                Label("Arbre des branches", systemImage: "point.3.connected.trianglepath.dotted")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .foregroundStyle(Teinte.accent)
        .disabled(salon.conversation == nil)
        .accessibilityLabel("Réglages de la conversation")
    }

    private func reessayer() {
        guard let conversation = salon.conversation else { return }
        Task { await salon.ouvrir(conversation) }
    }
}

/// Le quatrième état du fil : ouvert, et vierge. Le calme est un état conçu —
/// il dit que tout est prêt, pas que quelque chose manque.
struct FilVierge: View {
    var body: some View {
        VStack {
            Spacer(minLength: 0)
            EtatCalme(
                symbole: "ellipsis.bubble",
                titre: "Conversation neuve",
                detail: "Écris — elle se retrouvera aussi au navigateur, c'est le même historique."
            )
            Spacer(minLength: 0)
        }
        .transition(.scene)
    }
}
#endif
