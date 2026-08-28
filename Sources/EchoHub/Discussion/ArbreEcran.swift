// L'arbre complet d'une conversation — branches abandonnées comprises.
//
// `☠` C'est la preuve VÉRIFIABLE qu'un rejeu ou une édition n'efface rien. Le
// fil ne montre que le chemin actif, et « l'ancienne réponse reste accessible
// en variante » n'était jusqu'ici qu'une affirmation de la documentation :
// rien, depuis le téléphone, ne permettait de la constater. Les flèches
// « ‹ 2 / 3 › » du fil ne montrent que les variantes du tour COURANT ; l'arbre
// montre tout, y compris ce qui a été abandonné trois tours plus haut.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct ArbreEcran: View {
    @Environment(Salon.self) private var salon
    @Environment(\.dismiss) private var fermer
    @State private var etat: EtatChargement<ArbreConversation> = .chargement
    @State private var videDemande = false
    @State private var echecAction: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Teinte.fond.ignoresSafeArea()
                ScrollView { contenu }
            }
            .navigationTitle("Arbre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { barre }
            .task { await charger() }
            .confirmationDialog(
                "Vider l'historique ?", isPresented: $videDemande, titleVisibility: .visible
            ) {
                Button("Tout supprimer", role: .destructive) { Task { await vider() } }
                Button("Annuler", role: .cancel) {}
            } message: {
                // La portée RÉELLE : c'est tout l'arbre, pas seulement ce que
                // le fil montre. Sans cette phrase, « vider » se lirait comme
                // « replier ».
                Text("Tous les messages partent, y compris les branches abandonnées que le fil "
                    + "ne montre pas. La conversation, son titre et ses réglages restent.")
            }
        }
    }

    @ToolbarContentBuilder private var barre: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Fermer") { fermer() }
                .buttonStyle(.appui).foregroundStyle(Teinte.encreDouce)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Vider") { videDemande = true }
                .buttonStyle(.appui).foregroundStyle(Teinte.panne)
                .disabled(salon.conversation == nil || salon.enGeneration)
        }
    }

    @ViewBuilder private var contenu: some View {
        VStack(alignment: .leading, spacing: Trame.groupe) {
            if let echecAction { EchecAction(raison: echecAction) }
            switch etat {
            case .chargement, .vide:
                ChargementVue().transition(.scene)
            case .echec(let raison):
                EtatCalme(
                    symbole: "point.3.connected.trianglepath.dotted", titre: "Arbre illisible",
                    detail: raison, actionTitre: "Réessayer", action: { Task { await charger() } }
                )
                .transition(.scene)
            case .pret(let arbre):
                bandeau(arbre)
                branches(arbre)
            }
        }
        .padding(.vertical, Trame.groupe)
    }

    private func bandeau(_ arbre: ArbreConversation) -> some View {
        VStack(alignment: .leading, spacing: Trame.fin) {
            Text("\(arbre.messages.count) messages")
                .titreSection().foregroundStyle(Teinte.encre)
            Text(arbre.comporteDesVariantes
                ? "Des tours ont plusieurs variantes. Touche une branche éteinte pour y basculer."
                : "Aucune variante : ce fil est resté linéaire.")
                .note().foregroundStyle(Teinte.encreDouce)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Trame.ecran)
    }

    /// L'arbre est parcouru en profondeur : c'est l'ordre de lecture d'une
    /// conversation, et il place chaque variante juste sous le tour qu'elle
    /// rejoue.
    private func branches(_ arbre: ArbreConversation) -> some View {
        let enfants = arbre.enfantsParParent
        let actifs = cheminActif(arbre, enfants)
        return VStack(alignment: .leading, spacing: Trame.serre) {
            ForEach(parcourir(arbre.racines, enfants, profondeur: 0), id: \.message.id) { noeud in
                LigneArbre(
                    message: noeud.message, profondeur: noeud.profondeur,
                    surLeChemin: actifs.contains(noeud.message.id)
                ) {
                    Task { await basculer(noeud.message) }
                }
            }
        }
        .padding(.horizontal, Trame.ecran)
    }

    private struct Noeud {
        let message: MessageChat
        let profondeur: Int
    }

    /// Récursion bornée par le nombre de messages : chaque message n'est visité
    /// qu'une fois, et un `parentId` ne peut pas désigner un descendant — le
    /// serveur construit l'arbre, pas l'app.
    private func parcourir(
        _ niveau: [MessageChat], _ enfants: [String: [MessageChat]], profondeur: Int
    ) -> [Noeud] {
        niveau.flatMap { message in
            [Noeud(message: message, profondeur: profondeur)]
                + parcourir(enfants[message.id] ?? [], enfants, profondeur: profondeur + 1)
        }
    }

    /// Le chemin actif remonte de la feuille vers la racine — c'est la seule
    /// façon de le retrouver sans le redemander au serveur, qui ne rend que la
    /// feuille.
    private func cheminActif(
        _ arbre: ArbreConversation, _ enfants: [String: [MessageChat]]
    ) -> Set<String> {
        var parents: [String: String] = [:]
        for message in arbre.messages where message.parentId != nil {
            parents[message.id] = message.parentId
        }
        var chemin: Set<String> = []
        var courant = arbre.feuilleActive
        // Bornée par le nombre de messages : chaque tour remonte d'un cran, et
        // un identifiant déjà vu arrête la boucle.
        while let identifiant = courant, !chemin.contains(identifiant) {
            chemin.insert(identifiant)
            courant = parents[identifiant]
        }
        return chemin
    }

    // MARK: - Actions

    private func charger() async {
        guard let conversation = salon.conversation else { return }
        do {
            let arbre = try await salon.conversations.arbre(conversation.id)
            withAnimation(Elan.normal) { etat = .pret(arbre) }
        } catch {
            Journal.echec("arbre illisible : \(error)")
            withAnimation(Elan.normal) { etat = .echec(Salon.libelle(error)) }
        }
    }

    /// Bascule le fil vers la branche qui contient ce message. Le serveur rend
    /// le chemin complet à afficher : l'app n'a aucun arbre à reconstruire.
    private func basculer(_ message: MessageChat) async {
        guard let conversation = salon.conversation, !Salon.estLocal(message.id) else { return }
        do {
            salon.appliquer(try await salon.conversations.activerBranche(
                conversation.id, message: message.id
            ))
            fermer()
        } catch {
            Journal.echec("bascule de branche refusée : \(error)")
            echecAction = Salon.libelle(error)
        }
    }

    private func vider() async {
        guard let conversation = salon.conversation else { return }
        do {
            try await salon.conversations.viderMessages(conversation.id)
            await salon.recharger()
            fermer()
        } catch {
            Journal.echec("vidage de l'historique refusé : \(error)")
            echecAction = Salon.libelle(error)
        }
    }
}

/// Un message de l'arbre. Ce qui est HORS du chemin actif s'éteint sans
/// disparaître — c'est exactement ce qu'on vient vérifier.
struct LigneArbre: View {
    let message: MessageChat
    let profondeur: Int
    let surLeChemin: Bool
    let basculer: () -> Void

    /// Le décalage par niveau. Borné à quatre crans : au-delà, la colonne de
    /// texte deviendrait plus étroite que lisible sur 335 pt.
    private var retrait: CGFloat { CGFloat(min(profondeur, 4)) * Trame.element }

    var body: some View {
        Button(action: basculer) {
            HStack(alignment: .top, spacing: Trame.serre) {
                Rectangle()
                    .fill(surLeChemin ? Teinte.accent : Teinte.trait)
                    .frame(width: Trame.trait * 2)
                VStack(alignment: .leading, spacing: Trame.fin) {
                    HStack(spacing: Trame.serre) {
                        Text(message.role.rawValue).legende()
                            .foregroundStyle(Teinte.encreEteinte)
                        if !surLeChemin {
                            Text("branche éteinte").legende().foregroundStyle(Teinte.encreEteinte)
                        }
                    }
                    Text(apercu)
                        .note()
                        .foregroundStyle(surLeChemin ? Teinte.encre : Teinte.encreEteinte)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, retrait)
            .contentShape(.rect)
        }
        .buttonStyle(.appui)
        .disabled(surLeChemin)
    }

    /// Trois lignes suffisent à reconnaître un tour. L'arbre sert à retrouver
    /// une branche, pas à la relire — pour ça, on y bascule.
    private var apercu: String {
        message.contenu.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
#endif
