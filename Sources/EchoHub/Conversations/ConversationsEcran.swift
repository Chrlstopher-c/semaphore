// L'onglet d'historique. La liste vit sur le PC : rien n'est gardé ici.
//
// Le titre est un `Fronton` maison, pas la barre système : voir `Allures.swift`
// — le mode `.large` compose à 34 pt, au-dessus du plafond de la charte.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

public struct ConversationsEcran: View {
    @Environment(Salon.self) private var salon
    @State private var etat: EtatChargement<[ResumeConversation]> = .chargement
    @State private var aRenommer: ResumeConversation?
    @State private var nouveauTitre = ""
    @State private var aSupprimer: ResumeConversation?
    /// L'échec d'un renommage ou d'une suppression. Distinct de l'état de la
    /// liste : une action ratée ne doit pas effacer l'historique déjà affiché.
    @State private var erreurAction: String?
    /// Actives ou archivées. Sans cette bascule, une conversation archivée
    /// depuis le navigateur disparaissait du téléphone sans explication et
    /// devenait irrécupérable depuis l'app.
    @State private var archives = false
    /// Appelé quand une conversation est ouverte : la coquille bascule sur le
    /// fil. C'est un rappel et pas une navigation interne — l'écran de
    /// conversation EST un onglet, pas une destination poussée.
    let surOuverture: () -> Void

    public init(surOuverture: @escaping () -> Void) {
        self.surOuverture = surOuverture
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Teinte.fond.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Trame.groupe) {
                        Fronton("Conversations")
                        bascule
                        if let erreurAction { EchecAction(raison: erreurAction) }
                        contenu
                    }
                    .padding(.top, Trame.groupe)
                }
                .refreshable { await charger() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await charger() }
            // La liste vit dans cet écran, pas dans le salon, et son `.task` est
            // lié à la durée de vie de la vue — pas à l'apparition de l'onglet.
            // Une conversation créée depuis le Fil n'y apparaissait jamais.
            .onChange(of: salon.versionListe) { _, _ in Task { await charger() } }
            .onChange(of: archives) { _, _ in Task { await charger() } }
            .alert("Renommer la conversation", isPresented: renommagePresente) { champRenommage }
            .confirmationDialog(
                "Supprimer « \(aSupprimer?.titre ?? "") » ?",
                isPresented: suppressionPresente, titleVisibility: .visible
            ) { boutonsSuppression } message: {
                Text("Elle disparaîtra aussi du navigateur : c'est le même historique.")
            }
        }
    }

    /// Les archives n'ont pas de bouton « Nouvelle conversation » : une neuve
    /// naît active, elle n'apparaîtrait pas dans la liste qu'on regarde.
    @ViewBuilder private var listeVide: some View {
        if archives {
            EtatCalme(
                symbole: "archivebox",
                titre: "Aucune archive",
                detail: "Les conversations archivées, ici ou au navigateur, se rangent ici."
            )
        } else {
            EtatCalme(
                symbole: "bubble.left.and.bubble.right",
                titre: "Aucune conversation",
                detail: "Celles ouvertes au navigateur apparaîtront ici : c'est le même historique.",
                actionTitre: "Nouvelle conversation",
                action: creer
            )
        }
    }

    /// Deux libellés, pas un `Picker` système : la charte compose ses propres
    /// contrôles, et un segmenté iOS impose sa police et son galbe.
    private var bascule: some View {
        HStack(spacing: Trame.element) {
            onglet("Actives", actif: !archives) { archives = false }
            onglet("Archivées", actif: archives) { archives = true }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Trame.ecran)
    }

    private func onglet(_ titre: String, actif: Bool, action: @escaping () -> Void) -> some View {
        Button(titre) { withAnimation(Elan.normal) { action() } }
            .buttonStyle(.appui)
            .mention()
            .foregroundStyle(actif ? Teinte.accent : Teinte.encreEteinte)
    }

    @ViewBuilder private var contenu: some View {
        switch etat {
        case .chargement:
            ChargementVue().transition(.scene)
        case .vide:
            listeVide
                .padding(.top, Trame.souffle)
                .transition(.scene)
        case .echec(let raison):
            EtatCalme(
                symbole: "antenna.radiowaves.left.and.right.slash",
                titre: "Historique injoignable",
                detail: raison,
                actionTitre: "Réessayer",
                action: { Task { await charger() } }
            )
            .padding(.top, Trame.souffle)
            .transition(.scene)
        case .pret(let liste):
            rangees(liste)
        }
    }

    private func rangees(_ liste: [ResumeConversation]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(liste.enumerated()), id: \.element.id) { rang, resume in
                Button { ouvrir(resume) } label: {
                    LigneConversation(
                        resume: resume,
                        courante: resume.id == salon.conversation?.id
                    )
                }
                .buttonStyle(.appui)
                .contextMenu { menu(resume) }
                .entreeEnScene(rang: rang)
                if resume.id != liste.last?.id {
                    Rectangle().fill(Teinte.trait).frame(height: Trame.trait)
                        .padding(.leading, Trame.ecran)
                }
            }
        }
        .transition(.scene)
    }

    /// `☠` « Supprimer » était MASQUÉ sur la conversation ouverte, faute d'un
    /// `Salon.fermer()` : la seule qu'on lit était la seule qu'on ne pouvait pas
    /// supprimer, et le menu ne disait pas pourquoi — l'entrée disparaissait,
    /// exactement le défaut que le web s'interdit. `fermer()` existe désormais.
    @ViewBuilder private func menu(_ resume: ResumeConversation) -> some View {
        Button {
            nouveauTitre = resume.titre
            aRenommer = resume
        } label: {
            Label("Renommer", systemImage: "pencil")
        }
        Button {
            Task { await basculerArchive(resume) }
        } label: {
            Label(
                resume.archivee ? "Désarchiver" : "Archiver",
                systemImage: resume.archivee ? "tray.and.arrow.up" : "archivebox"
            )
        }
        Button(role: .destructive) { aSupprimer = resume } label: {
            Label("Supprimer", systemImage: "trash")
        }
    }

    @ViewBuilder private var champRenommage: some View {
        TextField("Titre", text: $nouveauTitre)
        Button("Renommer") { Task { await renommer() } }
        Button("Annuler", role: .cancel) {}
    }

    @ViewBuilder private var boutonsSuppression: some View {
        Button("Supprimer", role: .destructive) { Task { await supprimer() } }
        Button("Annuler", role: .cancel) {}
    }

    // MARK: - Liaisons de présentation

    private var renommagePresente: Binding<Bool> {
        Binding(get: { aRenommer != nil }, set: { if !$0 { aRenommer = nil } })
    }

    private var suppressionPresente: Binding<Bool> {
        Binding(get: { aSupprimer != nil }, set: { if !$0 { aSupprimer = nil } })
    }

    // MARK: - Actions

    private func ouvrir(_ resume: ResumeConversation) {
        Task {
            await salon.ouvrir(resume)
            surOuverture()
        }
    }

    private func creer() {
        Task {
            await salon.nouvelleConversation()
            surOuverture()
        }
    }

    private func renommer() async {
        guard let cible = aRenommer else { return }
        let titre = nouveauTitre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !titre.isEmpty, titre != cible.titre else { return }
        do {
            // Résumé rendu ignoré : `charger()` juste après relit la liste entière.
            _ = try await salon.conversations.modifier(cible.id, MajConversation(titre: titre))
            withAnimation(Elan.normal) { erreurAction = nil }
        } catch {
            Journal.echec("renommage impossible : \(error)")
            withAnimation(Elan.normal) { erreurAction = Salon.libelle(error) }
        }
        salon.noterChangementDeListe()
        await charger()
    }

    private func supprimer() async {
        guard let cible = aSupprimer else { return }
        // L'ordre compte : fermer d'abord annule la génération en cours, sinon
        // le flux continuerait d'écrire dans une conversation que le serveur
        // vient de détruire.
        if cible.id == salon.conversation?.id { salon.fermer() }
        do {
            try await salon.conversations.supprimer(cible.id)
            withAnimation(Elan.normal) { erreurAction = nil }
        } catch {
            Journal.echec("suppression impossible : \(error)")
            withAnimation(Elan.normal) { erreurAction = Salon.libelle(error) }
        }
        salon.noterChangementDeListe()
        await charger()
    }

    private func basculerArchive(_ resume: ResumeConversation) async {
        do {
            _ = try await salon.conversations.modifier(
                resume.id, MajConversation(archivee: !resume.archivee)
            )
            withAnimation(Elan.normal) { erreurAction = nil }
        } catch {
            Journal.echec("archivage impossible : \(error)")
            withAnimation(Elan.normal) { erreurAction = Salon.libelle(error) }
        }
        salon.noterChangementDeListe()
        await charger()
    }

    private func charger() async {
        do {
            let liste = try await salon.conversations.lister(archivees: archives)
            withAnimation(Elan.normal) { etat = liste.isEmpty ? .vide : .pret(liste) }
        } catch {
            Journal.echec("liste des conversations illisible : \(error)")
            withAnimation(Elan.normal) { etat = .echec(Salon.libelle(error)) }
        }
    }
}

/// L'échec d'une action de liste, sous le fronton. La liste reste affichée :
/// c'est l'action qui a raté, pas l'historique.
struct EchecAction: View {
    let raison: String

    var body: some View {
        HStack(alignment: .top, spacing: Trame.serre) {
            Image(systemName: "exclamationmark.triangle.fill")
                .imageScale(.small)
                .foregroundStyle(Teinte.panne)
            Text(raison).note().foregroundStyle(Teinte.encreDouce)
        }
        .padding(.horizontal, Trame.ecran)
        .transition(.scene)
    }
}

struct LigneConversation: View {
    let resume: ResumeConversation
    let courante: Bool

    var body: some View {
        HStack(spacing: Trame.element) {
            VStack(alignment: .leading, spacing: Trame.fin) {
                Text(resume.titre)
                    .mention()
                    .foregroundStyle(courante ? Teinte.accent : Teinte.encre)
                    .lineLimit(1)
                HStack(spacing: Trame.serre) {
                    Text(resume.majLe, format: .relative(presentation: .named))
                        .mesureFine()
                        .foregroundStyle(Teinte.encreEteinte)
                    Text("·").mesureFine().foregroundStyle(Teinte.encreEteinte)
                    Text("\(resume.nbMessages) messages")
                        .mesureFine()
                        .foregroundStyle(Teinte.encreEteinte)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").imageScale(.small)
                .foregroundStyle(Teinte.encreEteinte)
        }
        .padding(.horizontal, Trame.ecran)
        .frame(minHeight: Trame.rangee)
        .contentShape(.rect)
    }
}
#endif
