#if canImport(SwiftUI)
import Foundation
import PhotosUI
import SwiftUI
import VigieNoyau

/// Un fil de l'orchestrateur : les tours segmentés, le bloc en cours de
/// frappe, le composeur, et la feuille de tenue du fil (⋯).
///
/// `☠` Seul écran autorisé à battre à 400 ms, et seulement pendant une
/// génération. Le curseur `depuis` n'est jamais remis à zéro tant que le fil
/// est ouvert : re-demander l'historique entier à chaque battement le ferait
/// clignoter et rejetterait le défilement.
struct ConversationEcran: View {
    @Environment(\.clientPi) private var client
    @Environment(\.miroir) private var miroir
    @Environment(Cadence.self) private var cadence
    @Environment(\.dismiss) private var congedier
    @Environment(\.scenePhase) private var phaseScene

    let identifiant: String
    /// Peut arriver vide (ouverture par notification) : le miroir le retrouve.
    let titre: String

    @State private var evenements: [EvenementApi] = []
    @State private var propositions: [String: PropositionApi] = [:]
    @State private var detail: DetailFilApi?
    @State private var filConnu: FilApi?
    @State private var partiel: PartielApi?
    @State private var curseur = 0
    @State private var generation = false
    @State private var brouillon = ""
    @State private var pieces: [PieceEnAttente] = []
    @State private var envoiEnCours = false
    @State private var refus: ErreurApi?
    @State private var releveA: Date?
    @State private var choixMoteur = ChoixMoteur()
    @State private var catalogue: [ModeleApi] = []
    @State private var feuilleMoteur = false
    @State private var feuilleReglages = false
    @State private var colleBas = true
    @State private var loinDuBas = false
    @State private var avis: String?

    private var cle: String { "fil.\(identifiant)" }
    private static let ancreBas = "fil.bas"

    var body: some View {
        VStack(spacing: 0) {
            entete
            if let detail { EnTeteFilMeta(detail: detail, machine: filConnu?.machine) }
            fil
            composeur
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Teinte.fond)
        .task { await ouvrir() }
        .cadencePar(cle) { await battre() }
        .onChange(of: generation) { _, enCours in
            cadence.changerRegime(cle, enCours ? .generation : .repos)
            // La réponse est arrivée sous les yeux : plus rien à annoncer.
            if !enCours { CentreAlerte.partage.cesserDAttendre(fil: identifiant) }
        }
        .onChange(of: phaseScene) { _, phase in
            if phase != .active { noterLAttenteSiBesoin() }
        }
        .onDisappear { noterLAttenteSiBesoin() }
        .avisFugace($avis)
        .feuilleQuart(presentee: $feuilleMoteur, hauteurs: [.medium, .large]) {
            ChoixMoteurFeuille(catalogue: catalogue, modeleDuFil: detail?.model, choix: $choixMoteur)
        }
        .feuilleQuart(presentee: $feuilleReglages) {
            ReglagesFilFeuille(
                identifiant: identifiant,
                detail: detail,
                filConnu: filConnu,
                apres: { await battre(); await rafraichirFilConnu() },
                apresArchivage: { congedier() }
            )
        }
    }

    // MARK: - Composition

    private var entete: some View {
        EnTeteEcran(titreAffiche, releveA: releveA, retour: true) {
            Button {
                feuilleReglages = true
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .buttonStyle(.allureIcone)
            .foregroundStyle(Teinte.encreDouce)
            .accessibilityLabel("Tenue du fil")
        }
    }

    private var titreAffiche: String {
        if !titre.isEmpty { return titre }
        return filConnu?.titre ?? detail?.titre ?? "Fil"
    }

    private var fil: some View {
        ScrollViewReader { defilement in
            ScrollView {
                VStack(alignment: .leading, spacing: Trame.bloc) {
                    if let refus, refus.genre != .transport {
                        BandeauNote(refus.message, ton: .vigilance)
                    }
                    ForEach(segments) { segment in
                        VueSegmentFil(segment: segment, propositionsConnues: propositions)
                    }
                    if let partiel { BlocPartielVue(partiel: partiel) }
                    // Ancre : le bas du fil, jamais un index de ligne — les
                    // lignes changent, le bas ne bouge pas.
                    Color.clear.frame(height: 1).id(Self.ancreBas)
                }
                .padding(.horizontal, Trame.ecran)
                .padding(.vertical, Trame.element)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onScrollGeometryChange(for: EtatDefilement.self) { geometrie in
                EtatDefilement(
                    distanceAuBas: geometrie.contentSize.height
                        - geometrie.contentOffset.y - geometrie.containerSize.height,
                    hauteurVisible: geometrie.containerSize.height,
                    hauteurTotale: geometrie.contentSize.height,
                    messages: nombreDeTours
                )
            } action: { _, etat in
                colleBas = etat.colleAuBas
                withAnimation(Elan.vif) { loinDuBas = etat.loinDuBas }
            }
            .onChange(of: curseur) { _, _ in recoller(defilement) }
            .onChange(of: partiel) { _, _ in recoller(defilement) }
            .overlay(alignment: .bottom) {
                if loinDuBas {
                    RetourAuBas { sauterAuBas(defilement) }
                        .padding(.bottom, Trame.element)
                }
            }
        }
    }

    /// Ce que Chris compte quand il dit « cinq messages » : les tours, pas les
    /// événements bruts du harness — un seul tour d'agent en contient parfois
    /// vingt.
    private var nombreDeTours: Int {
        segments.count
    }

    /// Le saut est immédiat, sans ressort : on demande le bas parce qu'on veut
    /// y être, pas le regarder arriver.
    private func sauterAuBas(_ defilement: ScrollViewProxy) {
        withAnimation(Elan.vif) {
            defilement.scrollTo(Self.ancreBas, anchor: .bottom)
        }
        colleBas = true
        loinDuBas = false
    }

    /// On ne recolle au bas que si Chris y était déjà : relire un vieux tour
    /// pendant qu'un nouveau arrive ne doit jamais rejeter la lecture.
    private func recoller(_ defilement: ScrollViewProxy) {
        guard colleBas else { return }
        withAnimation(Elan.pose) {
            defilement.scrollTo(Self.ancreBas, anchor: .bottom)
        }
    }

    private var segments: [SegmentFil] {
        SegmentationFil.segmenter(evenements)
    }

    private var composeur: some View {
        ComposeurFil(
            texte: $brouillon,
            choixMoteur: $choixMoteur,
            pieces: pieces,
            generation: generation,
            envoiEnCours: envoiEnCours,
            ouvrirMoteur: { feuilleMoteur = true },
            ajouterPieces: ajouter(_:),
            retirerPiece: { identifiant in pieces.removeAll { $0.id == identifiant } },
            envoyer: { Task { await envoyer() } },
            interrompre: { Task { await interrompre() } }
        )
    }

    // MARK: - Relevés

    private func ouvrir() async {
        // On est dedans : ce qui arrive s'affiche, il n'y a plus à l'annoncer.
        CentreAlerte.partage.cesserDAttendre(fil: identifiant)
        if let cache = await miroir.lire(DetailFilApi.self, .fil(identifiant)) {
            appliquer(cache.valeur)
            releveA = cache.releveA
        }
        if let cache = await miroir.lire([FilApi].self, .fils) {
            filConnu = cache.valeur.first { $0.id == identifiant }
        }
        if filConnu == nil { await rafraichirFilConnu() }
        if let cache = await miroir.lire([ModeleApi].self, .modeles) {
            catalogue = cache.valeur
        }
        await lireLesPropositions()
        if catalogue.isEmpty {
            let lecture = await client.lire([ModeleApi].self, Route.modeles, memoriser: .modeles)
            if let charge = lecture.charge { catalogue = charge }
        }
    }

    /// `☠` Le premier appel prend le fil entier ; les suivants n'en prennent
    /// que la suite, par le curseur rendu par le serveur.
    @MainActor private func battre() async {
        if evenements.isEmpty {
            let lecture = await client.lire(
                DetailFilApi.self, Route.fil(identifiant), memoriser: .fil(identifiant)
            )
            if let charge = lecture.charge { appliquer(charge) }
            refus = lecture.erreur
        } else {
            let lecture = await client.lire(
                EvenementsFilApi.self, Route.evenementsFil(identifiant, depuis: curseur)
            )
            if let charge = lecture.charge { appliquerSuite(charge) }
            refus = lecture.erreur
        }
        if refus == nil { releveA = Date() }
    }

    private func appliquer(_ charge: DetailFilApi) {
        detail = charge
        evenements = charge.events
        curseur = charge.cursor
        generation = charge.generating
        partiel = charge.partial
    }

    private func appliquerSuite(_ charge: EvenementsFilApi) {
        // `☠` Un appel d'outil revient avec le MÊME `seq` une fois son
        // résultat arrivé : il se met à jour EN PLACE, il ne se reposte pas.
        var parSeq = Dictionary(evenements.map { ($0.seq, $0) }, uniquingKeysWith: { _, d in d })
        for evenement in charge.events { parSeq[evenement.seq] = evenement }
        evenements = parSeq.values.sorted { $0.seq < $1.seq }
        curseur = charge.cursor
        generation = charge.generating
        partiel = charge.partial
    }

    /// On s'en va pendant que le fil travaille : le bus prendra le relais et
    /// annoncera la réponse.
    ///
    /// `☠` DEUX sorties, pas une. Le retour arrière (`onDisappear`) est la plus
    /// évidente, mais la plus fréquente est le verrouillage du téléphone en
    /// restant dans le fil — qui ne déclenche AUCUN `onDisappear`. N'écouter que
    /// la première laisserait sans alerte le cas le plus courant du produit :
    /// poser une question, ranger le téléphone, attendre.
    @MainActor private func noterLAttenteSiBesoin() {
        guard generation else { return }
        CentreAlerte.partage.attendreLaReponse(
            fil: identifiant,
            titre: titreAffiche,
            majA: filConnu?.majA ?? 0
        )
    }

    /// Relit la fiche du fil dans la LISTE.
    ///
    /// `☠` La machine d'un fil ne vit que là : `GET /conversations/:id` la sert
    /// toujours à `null` (le port `detail()` du control plane ne la porte pas,
    /// vérifié dans les sources). Sans ce rappel après chaque geste, l'écran
    /// gardait l'instantané pris à l'ouverture — on rattachait un fil au VPS et
    /// l'en-tête continuait d'afficher l'ancienne machine. La webapp n'a jamais
    /// eu le défaut parce qu'elle relit sa liste en continu.
    ///
    /// Hors des gestes, on ne la rappelle PAS : ce serait une requête de plus à
    /// chaque battement, jusqu'à 400 ms pendant une génération.
    @MainActor private func rafraichirFilConnu() async {
        let lecture = await client.lire([FilApi].self, Route.fils, memoriser: .fils)
        guard let charge = lecture.charge else { return }
        filConnu = charge.first { $0.id == identifiant }
    }

    /// Un évènement `mandat` ne porte que l'IDENTIFIANT de la proposition :
    /// la carte se remplit en croisant avec la liste des propositions.
    private func lireLesPropositions() async {
        let lecture = await client.lire(
            [PropositionApi].self, Route.propositions, memoriser: .propositions
        )
        guard let charge = lecture.charge else { return }
        propositions = Dictionary(charge.map { ($0.id, $0) }, uniquingKeysWith: { premier, _ in premier })
    }

    // MARK: - Écritures

    private func ajouter(_ choisies: [PhotosPickerItem]) async {
        for element in choisies {
            guard let piece = await PieceEnAttente.depuis(element) else { continue }
            pieces.append(piece)
        }
    }

    private func envoyer() async {
        let texte = brouillon.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !texte.isEmpty || !pieces.isEmpty, !envoiEnCours else { return }
        envoiEnCours = true
        defer { envoiEnCours = false }
        // `☠` Le champ est `text`, et un texte VIDE est valide dès qu'il y a
        // une pièce : coller une capture sans un mot est le geste normal.
        var champs: [String: ValeurJSON] = ["text": .texte(texte)]
        if !pieces.isEmpty { champs["pieces"] = .liste(pieces.map(\.charge)) }
        choixMoteur.verser(dans: &champs)
        switch await client.ecrire(Route.messageFil(identifiant), CorpsJSON(champs)) {
        case .success:
            brouillon = ""
            pieces = []
            colleBas = true
            await battre()
        case .failure(let erreur):
            // Le refus des pièces jointes nomme les types et plafonds acceptés
            // — mot pour mot, en place.
            refus = erreur
        }
    }

    /// `☠` `interrupted: false` n'est PAS une erreur : le fil ne générait
    /// rien. L'effet du serveur le dit — on l'affiche tel quel.
    private func interrompre() async {
        switch await client.ecrire(Route.interrompreFil(identifiant)) {
        case .success(let accuse):
            avis = accuse.effet
            await battre()
        case .failure(let erreur):
            refus = erreur
        }
    }
}
#endif
