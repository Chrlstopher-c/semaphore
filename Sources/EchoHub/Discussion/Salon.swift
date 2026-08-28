// L'état de la conversation en cours, en un seul objet, partagé par
// l'environnement. Le pendant de la `Platine` de Sillon.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

/// La réponse en train de s'écrire. Un type à part, et c'est la décision de
/// performance la plus importante de l'app.
///
/// `☠` Le grain d'observation de `@Observable` est la PROPRIÉTÉ ENTIÈRE. Écrire
/// chaque fragment dans `messages[i].contenu` invaliderait tout ce qui lit
/// `messages` — c'est-à-dire le fil entier, chaque message déjà rendu, ses blocs
/// repliés et ses cartes d'outil — plusieurs fois par seconde pendant toute une
/// génération. Sillon a mesuré exactement ce défaut sur `file.position` écrite à
/// 1 Hz : un à-coup périodique, pas une lenteur uniforme. Ici le débit est vingt
/// fois plus élevé. La réponse en cours est donc tenue HORS de `messages` :
/// seules les vues qui la lisent réellement se réinvalident.
public struct MessageEnCours: Equatable, Sendable {
    public var id: String
    public var parentId: String?
    public var modeleId: String?
    /// Le texte BRUT, balises comprises. La séparation appartient à
    /// `SegmenteurReponse`, jamais à cette structure.
    public var texte: String
}

/// Les états du fil. Un écran qui ne sait pas dire « je charge », « c'est
/// vide » et « ça a raté » finit par afficher un tourniquet dans les trois cas.
public enum EtatFil: Equatable, Sendable {
    case vide
    case chargement
    case pret
    case echec(String)
}

@Observable
@MainActor
public final class Salon {
    // MARK: - Ce que les écrans lisent

    public private(set) var reglages: ReglagesRelais = .parDefaut
    public private(set) var conversation: ResumeConversation?
    /// Les messages ÉTABLIS. Cette propriété ne change qu'à l'ouverture d'une
    /// conversation, à un rechargement, et à la fin d'un tour — jamais à chaque
    /// fragment.
    public private(set) var messages: [MessageChat] = []
    public private(set) var enCours: MessageEnCours?
    public private(set) var etatFil: EtatFil = .vide
    /// L'échec du dernier tour ou de la dernière relecture, affiché sous le fil.
    /// Distinct de `etatFil` : une génération ratée ne doit pas effacer la
    /// conversation déjà lue.
    public private(set) var erreurGeneration: String?
    /// `☠` Un `EtatChargement` et non un optionnel : `nil` couvrait DEUX
    /// réalités que le bandeau ne pouvait pas distinguer — « jamais relevé »
    /// (premier lancement) et « relevé en échec » (relais ou PC injoignable).
    /// Il affichait donc un neutre « Sans nouvelles de la machine » dans les
    /// deux cas, c'est-à-dire le sens rassurant, qui est le mauvais.
    public internal(set) var statut: EtatChargement<StatutInference> = .chargement
    /// Échecs de relevé de statut d'affilée, remis à zéro au premier succès.
    /// Sert la tolérance aux à-coups du tunnel (voir `rafraichirStatut`).
    @ObservationIgnored private var echecsStatut = 0
    /// Pour chaque message du chemin actif, les identifiants qui partagent son
    /// parent, lui compris. C'est ce qui donne le « ‹ 2 / 3 › » sans rien
    /// recalculer.
    public private(set) var variantes: [String: [String]] = [:]
    /// Prompt système et échantillonnage de la conversation ouverte, tels que le
    /// serveur les rend. Lus, jamais devinés.
    public private(set) var reglagesConversation: ReglagesConversation?
    /// Les réponses dont l'app ne sait PAS si elles sont complètes : son flux
    /// s'est fermé sans `fin`. Distinct d'`interrompu`, que seul le serveur
    /// affirme. Vidé dès qu'un rechargement rapporte la vérité du PC.
    public private(set) var aRelire: Set<String> = []
    /// Les pièces jointes du PROCHAIN message. Vidées à l'envoi ; ce qui a raté
    /// reste visible avec sa cause jusqu'à ce que Chris le retire lui-même.
    public private(set) var piecesJointes: [PieceJointe] = []
    /// Un chargement ou un déchargement de modèle est en route. Le GPU est
    /// exclusif : deux gestes concurrents n'ont aucun sens.
    public private(set) var chargementEnCours = false
    /// Ce que la dernière action machine a raté, en toutes lettres. Distinct du
    /// statut : un chargement raté ne doit pas effacer ce qu'on sait du PC.
    public private(set) var echecMachine: String?
    /// L'occupation de la fenêtre de contexte, relevée à la FIN d'un tour.
    /// `nil` tant que rien n'a été mesuré : un zéro se lirait « contexte vide ».
    public private(set) var occupation: OccupationContexte?
    /// Le message tapé PENDANT une génération, en attente de son tour.
    ///
    /// `☠` Sans lui, le bouton unique du composeur changeait de rôle pendant
    /// une génération : taper la question suivante puis appuyer TUAIT la
    /// réponse en cours, et le texte restait dans le champ. Un geste
    /// destructeur atteint par le geste le plus naturel.
    public private(set) var enAttente: String?
    /// La sélection d'outils appliquée aux conversations NEUVES.
    ///
    /// `☠` Ce défaut n'existe pas côté serveur — `outils_actifs` est une
    /// colonne par conversation. L'app le garde sur son disque et le pose à la
    /// création, dans le champ `reglages` que `POST /chat/conversations`
    /// accepte déjà. Les trois états du contrat sont préservés : voir
    /// `OutilsParDefaut`.
    public private(set) var outilsParDefaut = SelectionOutils()
    /// Le catalogue du PC, relevé pour savoir sur combien d'outils porte le
    /// défaut. `nil` tant qu'il n'a jamais été lu — jamais 0, qui se lirait
    /// « le PC n'enregistre aucun outil ».
    public private(set) var nombreOutils: Int?

    /// `demarrer()` a fini. Le retour au premier plan peut arriver AVANT sur un
    /// lancement à froid : sonder alors partirait sur l'adresse compilée, pas
    /// sur celle que Chris a saisie, et peindrait un échec pour rien.
    public private(set) var demarre = false

    /// Compteur de changements de la liste des conversations : création,
    /// suppression, renommage, archivage, fin de tour.
    ///
    /// `☠` La liste vit dans son écran, pas ici, et son `.task` est lié à la
    /// durée de vie de la vue — pas à l'apparition de l'onglet. Chris créait
    /// une conversation depuis le Fil, passait à Conversations : elle n'y était
    /// pas. Ce compteur est ce que l'écran observe pour se relire.
    public private(set) var versionListe = 0

    func noterChangementDeListe() { versionListe += 1 }

    /// Les outils de la conversation OUVERTE, lus avec ses réglages. C'est ce
    /// que le rappel au-dessus du composeur affiche — sans requête de plus.
    public var outilsConversation: SelectionOutils {
        reglagesConversation?.selectionOutils ?? SelectionOutils()
    }

    /// Le statut quand il a été relevé. La très grande majorité des écrans ne
    /// veut que ça — l'état de chargement n'intéresse que le bandeau et la
    /// carte de l'onglet Machine.
    public var statutPret: StatutInference? { statut.contenu }

    public var enGeneration: Bool { tacheGeneration != nil }

    // MARK: - Ce qui n'appartient qu'au salon

    let client: ClientEchoHub
    private let gestionnaire: GestionnaireReglagesRelais
    private let outilsDefaut: GestionnaireOutilsParDefaut
    private let dernierFil: MemoireDernierFil
    private var tacheGeneration: Task<Void, Never>?

    var conversations: DepotConversations { DepotConversations(client: client) }
    var modeles: DepotModeles { DepotModeles(client: client) }
    var outils: DepotOutils { DepotOutils(client: client) }
    var rechercheWeb: DepotRecherche { DepotRecherche(client: client) }
    var fichiers: DepotFichiers { DepotFichiers(client: client) }

    public init() {
        let dossier = FileManager.dossierReglagesParDefaut()
        gestionnaire = GestionnaireReglagesRelais(
            magasin: MagasinReglagesRelaisDisque(dossier: dossier)
        )
        outilsDefaut = GestionnaireOutilsParDefaut(
            magasin: MagasinOutilsParDefautDisque(dossier: dossier)
        )
        dernierFil = MemoireDernierFil(dossier: dossier)
        client = ClientEchoHub()
    }

    // MARK: - Réglages

    /// Premier geste de l'app : relire le réglage du disque et l'appliquer au
    /// client, AVANT toute requête. Sans ça, la première requête part sur
    /// l'adresse par défaut compilée, pas sur celle que Chris a saisie.
    public func demarrer() async {
        reglages = await gestionnaire.actuels()
        outilsParDefaut = await outilsDefaut.actuels()
        await client.configurer(reglages)
        await rafraichirStatut()
        await rouvrirLeDernierFil()
        demarre = true
    }

    /// Rouvre la dernière conversation lue. Un échec — elle a été supprimée
    /// depuis, le PC est éteint — retombe sur l'état vide SANS message d'erreur :
    /// c'est une commodité, pas une opération que Chris a demandée.
    private func rouvrirLeDernierFil() async {
        guard let identifiant = dernierFil.lire() else { return }
        etatFil = .chargement
        do {
            let detail = try await conversations.detail(identifiant)
            conversation = detail.conversation
            appliquer(detail)
            etatFil = .pret
        } catch {
            Journal.note("dernier fil non rouvert (\(identifiant)) : \(error)")
            conversation = nil
            etatFil = .vide
        }
    }

    /// Pose le défaut d'outils. Une conversation DÉJÀ créée n'est jamais
    /// touchée : changer le défaut ne réécrit pas l'histoire, il ne vaut que
    /// pour la suivante.
    public func mettreAJourOutilsParDefaut(_ selection: SelectionOutils) async {
        outilsParDefaut = selection
        await outilsDefaut.mettreAJour(selection)
    }

    /// Relève le catalogue du PC pour savoir sur combien d'outils porte le
    /// défaut. Toléré à l'échec : le réglage reste utilisable sans le total,
    /// seul le libellé perd sa précision.
    public func releverLesOutils() async {
        do {
            nombreOutils = try await outils.catalogue().count
        } catch {
            Journal.note("catalogue d'outils non relevé : \(error)")
        }
    }

    public func mettreAJourReglages(_ nouveaux: ReglagesRelais) async {
        reglages = nouveaux
        await gestionnaire.mettreAJour(nouveaux)
        await client.configurer(nouveaux)
        await rafraichirStatut()
    }

    /// Sonde le relais. Rend ce que le relais dit de LUI et du PC — c'est la
    /// seule machine bien placée pour savoir si EchoHub répond ; l'iPhone, lui,
    /// ne voit que le relais.
    public func sonderRelais() async -> Result<SanteRelais, ErreurRelais> {
        await client.sonder()
    }

    /// `☠` Le `try?` d'avant DÉTRUISAIT une `ErreurRelais` typée — libellé et
    /// remède compris — une ligne avant que l'écran en ait besoin, et sans même
    /// journaliser, contrairement à la règle écrite en tête de `Journal`.
    public func rafraichirStatut() async {
        if statut.contenu == nil { statut = .chargement }
        do {
            statut = .pret(try await modeles.statut())
            echecsStatut = 0
        } catch {
            // Une annulation locale n'est ni un échec ni un événement à compter :
            // on garde l'état connu et on n'entame pas le budget de tolérance.
            if (error as? ErreurRelais)?.estAnnulation == true { return }
            Journal.echec("relevé du statut d'inférence échoué : \(error)")
            echecsStatut += 1
            // `☠` Un à-coup isolé du tunnel ne doit pas effacer un état déjà
            // connu : sinon le bandeau « Machine injoignable » clignote alors
            // que le PC répond encore. On garde le dernier `.pret` tant qu'une
            // panne transitoire ne se répète pas — une vraie panne (jeton, PC
            // éteint) n'est PAS transitoire et s'affiche du premier coup.
            let transitoire = (error as? ErreurRelais)?.estTransitoire ?? false
            if ToleranceSonde.garderDernierEtat(
                erreurEstTransitoire: transitoire,
                aUnEtatConnu: statut.contenu != nil,
                echecsConsecutifs: echecsStatut
            ) { return }
            statut = .echec(Self.libelle(error))
        }
    }

    // MARK: - Conversations

    public func ouvrir(_ resume: ResumeConversation, force: Bool = false) async {
        guard force || conversation?.id != resume.id || etatFil != .pret else { return }
        arreter()
        conversation = resume
        etatFil = .chargement
        erreurGeneration = nil
        do {
            appliquer(try await conversations.detail(resume.id))
            etatFil = .pret
            dernierFil.ecrire(resume.id)
        } catch {
            oublierLeFil()
            etatFil = .echec(Self.libelle(error))
        }
    }

    /// Relit le fil depuis le PC, SANS la garde d'`ouvrir`.
    ///
    /// `☠` Une fois `etatFil == .pret`, toute demande d'ouverture de la même
    /// conversation retournait immédiatement — et c'était le seul chemin de
    /// lecture. Le fil restait donc figé sur ce que l'app avait elle-même
    /// observé : un message écrit au navigateur n'apparaissait jamais, et une
    /// réponse terminée côté PC après une coupure de flux restait inatteignable
    /// depuis le téléphone. Le seul contournement était de tuer l'app.
    public func recharger() async {
        // Jamais pendant une génération : la réponse en cours vit HORS de
        // `messages` (voir `MessageEnCours`), et la remplacer l'effacerait.
        guard let conversation, !enGeneration else { return }
        do {
            appliquer(try await conversations.detail(conversation.id))
            erreurGeneration = nil
        } catch {
            // Une relecture annulée (retour d'écran, tâche remplacée) n'est pas
            // un échec : l'afficher mettait « Relecture impossible — Relais
            // injoignable — cancelled » juste après une réponse réussie.
            if (error as? ErreurRelais)?.estAnnulation == true { return }
            Journal.echec("relecture du fil échouée : \(error)")
            erreurGeneration = "Relecture impossible — \(Self.libelle(error))"
        }
    }

    /// Referme le fil. Appelé avant de supprimer la conversation ouverte :
    /// l'ordre compte, `arreter()` annule d'abord la génération, sinon le flux
    /// continuerait d'écrire dans une conversation que le serveur vient de
    /// détruire.
    public func fermer() {
        arreter()
        oublierLeFil()
        dernierFil.ecrire(nil)
        conversation = nil
        erreurGeneration = nil
        etatFil = .vide
    }

    /// Le serveur fait foi : ce qu'il rend remplace l'état local, y compris les
    /// doutes posés par une fermeture de flux sans `fin`.
    private func appliquer(_ detail: ConversationDetaillee) {
        messages = detail.messages
        conversation = detail.conversation
        reglagesConversation = detail.reglages
        variantes = detail.variantes
        aRelire.removeAll()
    }

    /// La vue rendue par `POST /branche` : même contrat que le détail, moins la
    /// conversation et ses réglages — qui n'ont pas changé.
    func appliquer(_ etat: EtatBranche) {
        messages = etat.messages
        variantes = etat.variantes
        aRelire.removeAll()
    }

    /// Ce que la feuille de réglages vient d'écrire. Le fil doit le savoir : il
    /// affiche le prompt système en tête, et un fil qui montre l'ancien après un
    /// enregistrement est un écran menteur.
    func poser(reglages: ReglagesConversation) { reglagesConversation = reglages }

    /// Ce que la feuille d'outils vient d'écrire. Le fil doit le savoir : le
    /// rappel au-dessus du composeur lit cette valeur, et un fil qui montre
    /// l'ancienne sélection après un enregistrement est un écran menteur.
    func poser(outils: SelectionOutils) {
        reglagesConversation?.outilsActifs = outils.outilsActifs
    }

    /// Réservé aux branches : couper le chemin affiché avant d'en ouvrir un
    /// neuf. Rien n'est détruit côté PC.
    func remplacerMessages(_ liste: [MessageChat]) { messages = liste }

    // MARK: - Pièces jointes

    func ajouter(piece: PieceJointe) { piecesJointes.append(piece) }

    func majPiece(_ identifiant: UUID, _ etat: EtatPiece) {
        guard let rang = piecesJointes.firstIndex(where: { $0.id == identifiant }) else { return }
        piecesJointes[rang].etat = etat
    }

    public func retirer(_ piece: PieceJointe) {
        // Le fichier reste sur le disque du PC : le retirer d'ici veut dire
        // « ne l'envoie pas », pas « détruis-le ». Le magasin a ses quotas.
        piecesJointes.removeAll { $0.id == piece.id }
    }

    func viderPiecesJointes() { piecesJointes = [] }

    // MARK: - Machine

    func poser(echecMachine nouveau: String?) { echecMachine = nouveau }

    func poser(occupation nouvelle: OccupationContexte?) { occupation = nouvelle }

    func poser(enAttente texte: String?) { enAttente = texte }

    func poser(chargement: Bool) { chargementEnCours = chargement }

    private func oublierLeFil() {
        messages = []
        piecesJointes = []
        variantes = [:]
        occupation = nil
        reglagesConversation = nil
        aRelire.removeAll()
        enCours = nil
        enAttente = nil
    }

    /// Crée une conversation sur le PC et bascule dessus. Le titre est laissé au
    /// défaut du serveur : le renommage se fait depuis la liste, et inventer un
    /// titre avant le premier message n'apporte rien.
    public func nouvelleConversation() async {
        arreter()
        etatFil = .chargement
        erreurGeneration = nil
        do {
            let creee = try await conversations.creer(CreationConversation(
                modeleId: statutPret?.modele, outilsParDefaut: outilsParDefaut
            ))
            oublierLeFil()
            conversation = creee
            etatFil = .pret
            dernierFil.ecrire(creee.id)
            noterChangementDeListe()
        } catch {
            etatFil = .echec(Self.libelle(error))
        }
    }

    /// Le préfixe d'un identifiant PROVISOIRE, posé par l'app avant que le
    /// serveur ait rendu le vrai. Un tel message n'existe pas côté PC : aucune
    /// action de branche ne peut le viser, elle rendrait un 404.
    static let prefixeLocal = "local-"

    public static func estLocal(_ identifiant: String) -> Bool {
        identifiant.hasPrefix(prefixeLocal)
    }

    static func libelle(_ erreur: any Error) -> String {
        (erreur as? ErreurRelais)?.libelle ?? erreur.localizedDescription
    }

    // MARK: - Écritures réservées à la génération

    func poser(message: MessageChat) { messages.append(message) }
    func poser(enCours nouveau: MessageEnCours?) { enCours = nouveau }
    func ajouter(fragment: String) { enCours?.texte += fragment }
    func poser(erreur: String?) { erreurGeneration = erreur }
    /// `douteux` : le flux s'est fermé sans que le serveur ait dit `fin`. L'app
    /// ne SAIT pas si la réponse est complète — elle ne l'affirme donc pas.
    func marquer(_ identifiant: String, douteux: Bool) {
        if douteux { aRelire.insert(identifiant) } else { aRelire.remove(identifiant) }
    }
    /// Remplace la tâche de génération, en ANNULANT celle qui partait.
    ///
    /// `☠` Assigner sans annuler ne fait que lâcher la référence : la tâche
    /// continue, le flux reste ouvert, et le PC génère pour un lecteur qui
    /// n'enregistre plus rien. Pire, `enGeneration` repasse à faux, donc Chris
    /// peut renvoyer un message pendant que l'ancien flux consomme encore —
    /// deux générations concurrentes sur la même conversation. C'est
    /// l'annulation, et elle seule, qui referme la requête HTTP (via
    /// `AsyncStream.onTermination`, voir `FluxGeneration.ouvrir`).
    func poser(tache: Task<Void, Never>?) {
        // `Task` est une `struct` : pas d'identité de référence, mais elle est
        // `Equatable` et compare bien la tâche sous-jacente. La garde évite de
        // s'annuler soi-même — `consommer` pose `nil` en sortant, depuis
        // l'intérieur de la tâche.
        if tacheGeneration != tache { tacheGeneration?.cancel() }
        tacheGeneration = tache
    }
    func remplacerIdentifiant(de ancien: String, par neuf: String) {
        guard let rang = messages.firstIndex(where: { $0.id == ancien }) else { return }
        let ancienMessage = messages[rang]
        messages[rang] = MessageChat(
            id: neuf, conversationId: ancienMessage.conversationId, role: ancienMessage.role,
            contenu: ancienMessage.contenu, creeLe: ancienMessage.creeLe,
            parentId: ancienMessage.parentId
        )
    }
}

extension FileManager {
    /// Le dossier Application Support de l'app : survit aux lancements, pas aux
    /// réinstallations qui changent le bundle ID.
    static func dossierReglagesParDefaut() -> URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return (base ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("EchoHub", isDirectory: true)
    }
}
#endif
