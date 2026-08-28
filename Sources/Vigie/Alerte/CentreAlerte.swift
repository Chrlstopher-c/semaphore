// Le canal d'alerte : la seule pièce du programme qui sonne.
//
// Chaîne retenue, par ordre de fiabilité décroissante — décision de Chris du
// 2026-08-17, canal natif seul, aucun tiers :
//   1. veille audio + sondage (temps réel, mesuré à 300 s de survie au moins)
//   2. rattrapage à l'ouverture (déterministe)
//   3. `BGAppRefreshTask` (filet, ~50 % des créneaux honorés)
//   4. alarme de silence pré-armée (dénonce la mort de la chaîne)
//
// `☠` Accepté en connaissance de cause : `.timeSensitive` étant refusé en free
// provisioning, AUCUNE alerte ne perce un mode Concentration. App tuée,
// appareil redémarré ou signature expirée ⇒ plus rien jusqu'à la prochaine
// ouverture manuelle. Ce n'est pas un défaut à redécouvrir, c'est l'arbitrage.
#if canImport(SwiftUI)
import Foundation
import Observation
import UserNotifications
import VigieNoyau

@MainActor
@Observable
public final class CentreAlerte {
    public static let partage = CentreAlerte()

    public private(set) var etat = MemoireAlerte.lireEtat()
    /// Dernier refus de pose rendu par le système, affiché tel quel.
    public private(set) var dernierRefus: String?

    @ObservationIgnored private var client: ClientPi?
    @ObservationIgnored private var memoire = MemoireAlerte.lireMemoire()
    @ObservationIgnored private var sondageEnCours = false

    private init() {}

    // MARK: - Démarrage

    /// Branché une seule fois, par la coquille, juste après le câblage.
    public func brancher(client: ClientPi) {
        self.client = client
    }

    /// Demande l'autorisation, pose les catégories, arme ce qui doit l'être.
    /// Idempotent : un rappel au retour au premier plan ne coûte rien.
    public func demarrer() async {
        CategoriesAlerte.poser()
        await demanderAutorisation()
        etat.expirationSignature = await Armement.armerExpirationSignature()
        if let contact = etat.dernierContact {
            etat.alarmesArmees = await Armement.armerAlarmeDeSilence(dernierContact: contact)
        }
        MemoireAlerte.ecrire(etat)
    }

    private func demanderAutorisation() async {
        let centre = UNUserNotificationCenter.current()
        do {
            let accordee = try await centre.requestAuthorization(options: [.alert, .sound, .badge])
            etat.autorisation = accordee ? "accordée" : "refusée"
        } catch {
            Trace.erreur("alerte", "demande d'autorisation refusée par le système", error)
            etat.autorisation = "erreur : \(error.localizedDescription)"
        }
    }

    // MARK: - Sondage

    /// Un tour de veille : relève les faits, sonne ce qui est nouveau, réarme.
    ///
    /// `☠` Sérialisé par `sondageEnCours` : la boucle audio, le rattrapage
    /// d'ouverture et un réveil de fond peuvent se croiser à la seconde près, et
    /// deux tours concurrents sonneraient deux fois le même fait — la
    /// déduplication ne les départagerait qu'après la pose.
    public func sonder(origine: OrigineReleve) async {
        guard let client, !sondageEnCours else { return }
        sondageEnCours = true
        defer { sondageEnCours = false }

        var sonnes = 0
        sonnes += await sonnerLesFaits(client)
        sonnes += await sonnerLesMandats(client)
        sonnes += await sonnerLesRallonges(client)
        sonnes += await sonnerLesArbitrages(client)
        sonnes += await sonnerLesReponses(client)
        guard etat.derniereErreurTransport == nil else { return persister() }

        etat.noterContact(Date(), origine: origine)
        etat.alarmesArmees = await Armement.armerAlarmeDeSilence(dernierContact: Date())
        if sonnes > 0 { Trace.info("alerte", "\(sonnes) alerte(s) posée(s) — \(origine.libelle)") }
        persister()
    }

    private func sonnerLesFaits(_ client: ClientPi) async -> Int {
        let lecture = await client.lire(
            ListeNotificationsApi.self, Route.notifications, memoriser: .notifications
        )
        etat.derniereErreurTransport = lecture.erreur?.message
        guard let lot = lecture.charge else { return 0 }
        let releve = memoire.faits.retenir(lot)
        etat.rattrapageIncomplet = releve.rattrapageIncomplet
        return await poser(releve.nouvelles.map(TraductionAlerte.projet(pour:)))
    }

    /// `☠` Le serveur n'émet AUCUNE notification pour une proposition de mandat
    /// — seuls `equipe_terminee` et `equipe_echouee` existent côté harness. Le
    /// fait le plus important du produit est donc détecté ici, par différence
    /// sur la liste des propositions en attente.
    private func sonnerLesMandats(_ client: ClientPi) async -> Int {
        let lecture = await client.lire(
            [PropositionApi].self, Route.propositions, memoriser: .propositions
        )
        guard let mandats = lecture.charge else { return 0 }
        let nouveaux = memoire.mandats.nouveaux(mandats.map(\.id))
        let aSonner = mandats.filter { nouveaux.contains($0.id) }
        return await poser(aSonner.map(TraductionAlerte.projet(pour:)))
    }

    private func sonnerLesRallonges(_ client: ClientPi) async -> Int {
        let lecture = await client.lire(
            [RallongeApi].self, Route.rallonges, memoriser: .rallonges
        )
        guard let rallonges = lecture.charge else { return 0 }
        let nouvelles = memoire.rallonges.nouveaux(rallonges.map(\.id))
        let aSonner = rallonges.filter { nouvelles.contains($0.id) }
        return await poser(aSonner.map(TraductionAlerte.projet(pour:)))
    }

    /// `☠` Une inspection qui attend un arbitrage BLOQUE une équipe qui tourne
    /// et dépense. Elle est restée muette jusqu'au 2026-08-17 : elle apparaissait
    /// dans la file du Quart et ne réveillait personne — la seule décision du
    /// produit dont le coût continue de courir pendant qu'on l'ignore.
    private func sonnerLesArbitrages(_ client: ClientPi) async -> Int {
        let lecture = await client.lire([MissionApi].self, Route.missions, memoriser: .missions)
        guard let missions = lecture.charge else { return 0 }
        let enAttente = missions.filter(\.inspection.attendArbitrage)
        let nouveaux = memoire.arbitrages.nouveaux(enAttente.map(\.id))
        let aSonner = enAttente.filter { nouveaux.contains($0.id) }
        return await poser(aSonner.map(TraductionAlerte.projet(pour:)))
    }

    /// Les fils quittés en pleine génération. Voir `AttenteFils` : la liste des
    /// fils n'est lue QUE si quelque chose est réellement attendu.
    private func sonnerLesReponses(_ client: ClientPi) async -> Int {
        guard !memoire.filsAttendus.vide else { return 0 }
        let lecture = await client.lire([FilApi].self, Route.fils, memoriser: .fils)
        guard let fils = lecture.charge else { return 0 }
        let maintenant = Int(Date().timeIntervalSince1970 * 1000)
        let repondus = memoire.filsAttendus.repondus(fils, maintenant: maintenant)
        return await poser(repondus.map(TraductionAlerte.projet(pour:)))
    }

    /// Noté depuis l'écran de conversation : on quitte un fil qui travaille
    /// encore, on veut être prévenu de sa réponse.
    public func attendreLaReponse(fil identifiant: String, titre: String, majA: Int) {
        memoire.filsAttendus.attendre(
            id: identifiant,
            titre: titre,
            majA: majA,
            maintenant: Int(Date().timeIntervalSince1970 * 1000)
        )
        MemoireAlerte.ecrire(memoire)
    }

    /// Le fil est rouvert : on le lit en direct, il n'y a plus rien à annoncer.
    public func cesserDAttendre(fil identifiant: String) {
        guard !memoire.filsAttendus.vide else { return }
        memoire.filsAttendus.oublier(identifiant)
        MemoireAlerte.ecrire(memoire)
    }

    private func poser(_ projets: [ProjetNotification]) async -> Int {
        var posees = 0
        for projet in projets {
            if let refus = await Sonneur.poser(projet) {
                dernierRefus = refus
                continue
            }
            etat.noterAlerte(projet)
            posees += 1
        }
        return posees
    }

    private func persister() {
        MemoireAlerte.ecrire(memoire)
        MemoireAlerte.ecrire(etat)
    }

    // MARK: - Ponts vers les autres domaines

    /// Rapporté par `MaintienVie` : l'écran du canal doit dire si le canal 1
    /// tient, et les Réglages lisent le même état.
    public func rapporterAudio(actif: Bool, interruptions: Int, reprises: Int, incident: String?) {
        etat.audioActif = actif
        etat.audioInterruptions = interruptions
        etat.audioReprises = reprises
        etat.audioIncident = incident
        MemoireAlerte.ecrire(etat)
    }

    /// Rapporté par `MaintienVieLocalisation` : le canal 2, celui qui tient
    /// pendant qu'une autre app détient l'audio.
    public func rapporterLocalisation(actif: Bool, releves: Int, statut: String) {
        etat.localisationActive = actif
        etat.localisationReleves = releves
        etat.localisationStatut = statut
        MemoireAlerte.ecrire(etat)
    }

    /// `☠` Un réveil de fond RÉELLEMENT servi par iOS est une information rare :
    /// c'est ce qui distingue un canal vivant d'un canal qu'on croit vivant.
    public func noterReveil(enregistre: Bool, replanifie: Bool) {
        etat.reveilEnregistre = enregistre
        etat.reveilReplanifie = replanifie
        MemoireAlerte.ecrire(etat)
    }
}
#endif
