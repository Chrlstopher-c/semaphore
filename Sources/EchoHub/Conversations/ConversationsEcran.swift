// Le tiroir des conversations, comme la colonne du web : nouvelle session, filtre, projets puis périodes,
// archivées repliées en bas. La liste vit sur le PC : rien n'est gardé ici.
//
// Le titre est un `Fronton` maison, pas la barre système : voir `Allures.swift`
// — le mode `.large` compose à 34 pt, au-dessus du plafond de la charte.
#if canImport(SwiftUI)
import SwiftUI
import UIKit
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
    @State private var archivesOuvertes = false
    @State private var archivees: [ResumeConversation] = []
    @State private var filtre = ""
    @Environment(\.scenePhase) private var phase
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
                        entete
                        if let erreurAction { EchecAction(raison: erreurAction) }
                        contenu
                        sectionArchivees
                    }
                    .padding(.top, Trame.groupe)
                }
                .refreshable { await charger() }
            }
            .toolbar(.hidden, for: .navigationBar)
            // Resynchro toutes les 15 s, et au retour au premier plan, comme le web.
            .task(id: phase == .active) {
                guard phase == .active else { return }
                while !Task.isCancelled {
                    await charger()
                    try? await Task.sleep(for: .seconds(15))
                }
            }
            // La liste vit dans cet écran, pas dans le salon, et son `.task` est
            // lié à la durée de vie de la vue — pas à l'apparition de l'onglet.
            // Une conversation créée depuis le Fil n'y apparaissait jamais.
            .onChange(of: salon.versionListe) { _, _ in Task { await charger() } }
            .onChange(of: archivesOuvertes) { _, _ in Task { await charger() } }
            .alert("Renommer la conversation", isPresented: renommagePresente) { champRenommage }
            .confirmationDialog(
                "Supprimer « \(aSupprimer?.titre ?? "") » ?",
                isPresented: suppressionPresente, titleVisibility: .visible
            ) { boutonsSuppression } message: {
                Text("Elle disparaîtra aussi du navigateur : c'est le même historique.")
            }
        }
    }

    /// « Nouvelle session » et le filtre, en tête de colonne comme au web.
    private var entete: some View {
        VStack(spacing: Trame.element) {
            Button(action: creer) {
                Label("Nouvelle session", systemImage: "square.and.pencil")
                    .mention()
                    .frame(maxWidth: .infinity, minHeight: Trame.cible)
            }
            .buttonStyle(.appui)
            .foregroundStyle(Teinte.encre)
            .background(Teinte.surface, in: .rect(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Teinte.trait))
            HStack(spacing: Trame.serre) {
                Image(systemName: "magnifyingglass").imageScale(.small).foregroundStyle(Teinte.encreEteinte)
                TextField("Filtrer", text: $filtre)
                    .mention()
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !filtre.isEmpty {
                    Button { filtre = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.appui)
                        .foregroundStyle(Teinte.encreEteinte)
                        .accessibilityLabel("Effacer le filtre")
                }
            }
            .padding(.horizontal, Trame.element)
            .frame(height: 36)
            .background(Teinte.surface, in: .rect(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Teinte.trait))
        }
        .padding(.horizontal, Trame.ecran)
    }

    @ViewBuilder private var contenu: some View {
        switch etat {
        case .chargement:
            ChargementVue().transition(.scene)
        case .vide:
            EtatCalme(
                symbole: "bubble.left.and.bubble.right",
                titre: "Aucune conversation",
                detail: "Celles ouvertes au navigateur apparaîtront ici : c'est le même historique."
            )
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
            groupes(RangementConversations(RangementConversations.filtrer(liste, filtre)))
        }
    }

    @ViewBuilder private func groupes(_ rangement: RangementConversations) -> some View {
        if rangement.estVide {
            Text("Aucune conversation ne correspond.").note().foregroundStyle(Teinte.encreEteinte)
                .padding(.horizontal, Trame.ecran)
        }
        if !rangement.projets.isEmpty {
            Text("Projets").rubrique().foregroundStyle(Teinte.encreEteinte).padding(.horizontal, Trame.ecran)
            ForEach(rangement.projets) { groupe in
                VStack(alignment: .leading, spacing: 0) {
                    Label(groupe.libelle, systemImage: "folder")
                        .mention().foregroundStyle(Teinte.encreDouce)
                        .padding(.horizontal, Trame.ecran)
                    rangees(groupe.conversations)
                }
            }
        }
        ForEach(rangement.periodes) { groupe in
            VStack(alignment: .leading, spacing: 0) {
                Text(groupe.libelle).rubrique().foregroundStyle(Teinte.encreEteinte)
                    .padding(.horizontal, Trame.ecran)
                rangees(groupe.conversations)
            }
        }
    }

    /// Les archivées, repliées en bas comme au web ; relues à l'ouverture.
    private var sectionArchivees: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(Elan.normal) { archivesOuvertes.toggle() }
            } label: {
                HStack(spacing: Trame.serre) {
                    Image(systemName: "chevron.right").imageScale(.small)
                        .rotationEffect(.degrees(archivesOuvertes ? 90 : 0))
                    Text("Archivées").rubrique()
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Teinte.encreEteinte)
                .padding(.horizontal, Trame.ecran)
                .frame(minHeight: Trame.cible)
                .contentShape(.rect)
            }
            .buttonStyle(.appui)
            if archivesOuvertes {
                if archivees.isEmpty {
                    Text("Aucune archive.").note().foregroundStyle(Teinte.encreEteinte)
                        .padding(.horizontal, Trame.ecran)
                } else {
                    rangees(archivees)
                }
            }
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
        Button { ouvrir(resume) } label: {
            Label("Ouvrir", systemImage: "arrow.up.right")
        }
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
        Button { UIPasteboard.general.string = resume.titre } label: {
            Label("Copier le titre", systemImage: "doc.on.doc")
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
            let liste = try await salon.conversations.lister()
            let archives = archivesOuvertes ? try await salon.conversations.lister(archivees: true) : archivees
            withAnimation(Elan.normal) {
                etat = liste.isEmpty ? .vide : .pret(liste)
                archivees = archives
            }
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
