// Le prompt système et l'échantillonnage de la conversation ouverte.
//
// `☠` Le manque le plus sournois de l'app avant cet écran n'était pas de ne
// pas pouvoir RÉGLER, c'était de ne pas pouvoir VOIR : une conversation dont le
// prompt système avait été posé au navigateur se comportait « bizarrement » sur
// le téléphone, et rien n'expliquait pourquoi.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct ReglagesConversationFeuille: View {
    @Environment(Salon.self) private var salon
    @Environment(\.dismiss) private var fermer
    @State private var brouillon = ReglagesConversation()
    @State private var etat: EtatChargement<ReglagesConversation> = .chargement
    @State private var erreur: String?
    @State private var enregistre = false
    /// Le texte des limites du bac à sable, rendu par le serveur. Vide quand il
    /// n'a rien à dire — la section se tait alors plutôt que d'annoncer une
    /// garantie qu'elle ne connaît pas.
    @State private var limites = ""
    @State private var limitesOuvertes = false

    var body: some View {
        NavigationStack {
            ZStack {
                Teinte.fond.ignoresSafeArea()
                ScrollView { contenu }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { barre }
            .task {
                await charger()
                limites = (try? await salon.outils.limitesBac()) ?? ""
            }
        }
    }

    @ToolbarContentBuilder private var barre: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Fermer") { fermer() }
                .buttonStyle(.appui).foregroundStyle(Teinte.encreDouce)
        }
        ToolbarItem(placement: .topBarTrailing) {
            if enregistre {
                ProgressView().tint(Teinte.encreDouce).controlSize(.small)
            } else {
                Button("Enregistrer") { Task { await enregistrer() } }
                    .buttonStyle(.appui)
                    .foregroundStyle(modifie ? Teinte.accent : Teinte.encreEteinte)
                    .disabled(!modifie)
            }
        }
    }

    @ViewBuilder private var contenu: some View {
        VStack(alignment: .leading, spacing: Trame.section) {
            if let erreur { EchecAction(raison: erreur) }
            switch etat {
            case .chargement, .vide:
                ChargementVue().transition(.scene)
            case .echec(let raison):
                EtatCalme(
                    symbole: "slider.horizontal.3", titre: "Réglages injoignables",
                    detail: raison, actionTitre: "Réessayer",
                    action: { Task { await charger() } }
                )
            case .pret:
                sectionPrompt
                sectionEchantillonnage
                sectionBornes
            }
        }
        .padding(.vertical, Trame.groupe)
    }

    /// `☠` Ce que Chris écrit ici est une SURCOUCHE, jamais une substitution.
    /// La génération compose `prompt_socle(...)` PUIS ce texte
    /// (`backend/chat/generation.py`) : le socle du harnais est posé avant, il
    /// annonce au modèle les outils réellement disponibles, et rien de ce qui
    /// est saisi ici ne peut le supprimer. Sans ce socle, les modèles chargés
    /// annoncent savoir chercher sur le web puis fabriquent des résultats —
    /// constaté côté serveur le 2026-08-14.
    ///
    /// `☠` Le socle n'est exposé par AUCUNE route : on ne peut donc pas
    /// l'afficher, seulement signaler qu'il existe. Prétendre le montrer serait
    /// pire que se taire. Ce que le serveur rend et qu'on peut montrer, c'est
    /// le texte des limites du bac à sable.
    private var socle: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            HStack(spacing: Trame.serre) {
                Image(systemName: "lock.fill").imageScale(.small)
                    .foregroundStyle(Teinte.encreEteinte)
                Text("Un socle du harnais est posé AVANT ce texte")
                    .legende().foregroundStyle(Teinte.encreDouce)
            }
            Text("Il annonce au modèle les outils réellement disponibles, et il n'est pas "
                + "modifiable depuis l'app. Ce que tu écris s'ajoute après : tu peux le "
                + "contredire, jamais l'effacer.")
                .legende().foregroundStyle(Teinte.encreEteinte)
                .fixedSize(horizontal: false, vertical: true)
            if !limites.isEmpty {
                DisclosureGroup(isExpanded: $limitesOuvertes) {
                    Text(limites).brut().foregroundStyle(Teinte.encreDouce)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Trame.serre)
                } label: {
                    Text("Ce que le bac à sable garantit")
                        .legende().foregroundStyle(Teinte.accent)
                }
                .tint(Teinte.accent)
            }
        }
    }

    private var sectionPrompt: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            Text("Prompt système").rubrique()
            socle
            Panneau {
                TextField(
                    "Aucun — le modèle part de ses propres consignes.",
                    text: Binding(
                        get: { brouillon.promptSysteme },
                        set: { brouillon.promptSysteme = $0 }
                    ),
                    axis: .vertical
                )
                .lineLimit(3...12)
                .corps()
                .foregroundStyle(Teinte.encre)
                .tint(Teinte.accent)
                .textFieldStyle(.plain)
            }
        }
        .padding(.horizontal, Trame.ecran)
    }

    private var sectionEchantillonnage: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            Text("Échantillonnage").rubrique()
            CurseurReglage(
                "Température", valeur: liaison(\.temperature), plage: 0...2, pas: 0.05,
                detail: "Plus haut, plus imprévisible."
            )
            CurseurReglage(
                "Top-p", valeur: liaison(\.topP), plage: 0.05...1, pas: 0.05,
                detail: "La masse de probabilité retenue."
            )
            CurseurReglage(
                "Top-k", valeur: liaisonEntiere(\.topK), plage: 0...200, pas: 1,
                detail: "0 = aucune coupe."
            )
            CurseurReglage(
                "Pénalité de répétition", valeur: liaison(\.penaliteRepetition),
                plage: 0...2, pas: 0.05, detail: "1 = neutre."
            )
        }
        .padding(.horizontal, Trame.ecran)
    }

    private var sectionBornes: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            Text("Bornes").rubrique()
            ChampFacultatif(
                "Plafond de tokens", absent: "Aucun plafond",
                valeur: Binding(
                    get: { brouillon.parametres.maxTokens },
                    set: { brouillon.parametres.maxTokens = $0 }
                ),
                defaut: 2048,
                detail: "Sans plafond, le moteur va jusqu'à sa fenêtre de contexte."
            )
            ChampFacultatif(
                "Graine", absent: "Aléatoire",
                valeur: Binding(
                    get: { brouillon.parametres.graine },
                    set: { brouillon.parametres.graine = $0 }
                ),
                defaut: 42,
                detail: "Une graine fixe rend une génération reproductible."
            )
            ChampFacultatif(
                "Historique envoyé", absent: "Complet",
                valeur: Binding(
                    get: { brouillon.historiqueMaxMessages },
                    set: { brouillon.historiqueMaxMessages = $0 }
                ),
                defaut: 20,
                detail: "Un compte de MESSAGES, jamais de tokens."
            )
        }
        .padding(.horizontal, Trame.ecran)
    }

    // MARK: - Liaisons

    private var modifie: Bool { etat.contenu != brouillon }

    private func liaison(_ chemin: WritableKeyPath<ParametresEchantillonnage, Double>)
    -> Binding<Double> {
        Binding(
            get: { brouillon.parametres[keyPath: chemin] },
            set: { brouillon.parametres[keyPath: chemin] = $0 }
        )
    }

    /// Le curseur travaille en `Double` ; le contrat, lui, veut un entier.
    private func liaisonEntiere(_ chemin: WritableKeyPath<ParametresEchantillonnage, Int>)
    -> Binding<Double> {
        Binding(
            get: { Double(brouillon.parametres[keyPath: chemin]) },
            set: { brouillon.parametres[keyPath: chemin] = Int($0.rounded()) }
        )
    }

    // MARK: - Actions

    private func charger() async {
        guard let conversation = salon.conversation else { return }
        // Amorçage sur ce que le fil a déjà lu : sans lui, l'écran montre une
        // seconde les DÉFAUTS recopiés du serveur, qui ne sont pas les réglages
        // de cette conversation.
        if let connus = salon.reglagesConversation {
            brouillon = connus
            etat = .pret(connus)
        }
        do {
            let lus = try await salon.conversations.reglages(conversation.id)
            brouillon = lus
            salon.poser(reglages: lus)
            withAnimation(Elan.normal) { etat = .pret(lus) }
        } catch {
            Journal.echec("réglages de conversation illisibles : \(error)")
            // Un échec ne doit pas effacer ce que le fil avait déjà lu : on le
            // dit sous le fronton, l'écran reste utilisable.
            withAnimation(Elan.normal) {
                if etat.contenu == nil { etat = .echec(Salon.libelle(error)) }
                erreur = Salon.libelle(error)
            }
        }
    }

    /// On renvoie TOUT le brouillon, `null` compris — c'est ce que `MajReglages`
    /// sait exprimer et qu'un `Optional` nu ne saurait pas.
    private func enregistrer() async {
        guard let conversation = salon.conversation else { return }
        enregistre = true
        defer { enregistre = false }
        do {
            let ecrits = try await salon.conversations.definirReglages(
                conversation.id,
                MajReglages(
                    promptSysteme: brouillon.promptSysteme,
                    parametres: MajParametres(ecrivant: brouillon.parametres),
                    historiqueMaxMessages: ChampPatch(ecrivant: brouillon.historiqueMaxMessages)
                )
            )
            brouillon = ecrits
            salon.poser(reglages: ecrits)
            withAnimation(Elan.normal) {
                etat = .pret(ecrits)
                erreur = nil
            }
        } catch {
            Journal.echec("réglages non enregistrés : \(error)")
            withAnimation(Elan.normal) { erreur = Salon.libelle(error) }
        }
    }
}
#endif
