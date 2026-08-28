import Foundation
import Testing
@testable import VigieNoyau

@Suite("Alarme de silence")
struct AlarmeSilenceTests {

    @Test("trois alarmes armées quand le contact vient d'avoir lieu")
    func troisAlarmes() {
        let maintenant = Date(timeIntervalSince1970: 1_700_000_000)
        let projets = AlarmeSilence.projets(dernierContact: maintenant, maintenant: maintenant)
        #expect(projets.count == 3)
        let attendus: [TimeInterval] = [21_600, 50_400, 93_600]
        #expect(projets.map(\.delai) == attendus)
        #expect(projets.allSatisfy { $0.genre == .silence })
    }

    @Test("une échéance déjà dépassée n'est pas reposée à zéro")
    func echeanceDepassee() {
        let contact = Date(timeIntervalSince1970: 1_700_000_000)
        let projets = AlarmeSilence.projets(
            dernierContact: contact,
            maintenant: contact.addingTimeInterval(7 * 3600)
        )
        #expect(projets.count == 2)
        #expect(projets.first?.identifiant == AlarmeSilence.identifiant(1))
        // TimeInterval explicite : face à un optionnel, un littéral entier nu
        // fait basculer la comparaison sur AnyHashable, qui rend toujours faux.
        #expect(projets.first?.delai == TimeInterval(7 * 3600))
    }

    @Test("plus rien à armer au-delà de la dernière échéance")
    func toutDepasse() {
        let contact = Date(timeIntervalSince1970: 1_700_000_000)
        let projets = AlarmeSilence.projets(
            dernierContact: contact,
            maintenant: contact.addingTimeInterval(30 * 3600)
        )
        #expect(projets.isEmpty)
    }

    @Test("la première échéance ne sonne pas, les suivantes si")
    func insistanceCroissante() {
        let maintenant = Date()
        let projets = AlarmeSilence.projets(dernierContact: maintenant, maintenant: maintenant)
        #expect(projets[0].insistance == .discrete)
        #expect(projets[1].insistance == .active)
        #expect(projets[2].insistance == .active)
    }

    @Test("le budget iOS des requêtes en attente est celui du système")
    func budget() {
        #expect(AlarmeSilence.budgetRequetes == 64)
        #expect(AlarmeSilence.identifiants.count == 3)
    }
}

@Suite("Suivi des demandes en attente")
struct SuiviDecisionsTests {

    @Test("le premier relevé annonce déjà — une demande en attente est actionnable")
    func premierReleveAnnonce() {
        var suivi = SuiviDecisions()
        #expect(suivi.nouveaux(["p-1", "p-2"]) == ["p-1", "p-2"])
        #expect(suivi.nouveaux(["p-1", "p-2"]).isEmpty)
    }

    @Test("un identifiant tranché sort de la mémoire")
    func oubliDesTranches() {
        var suivi = SuiviDecisions()
        _ = suivi.nouveaux(["p-1", "p-2"])
        _ = suivi.nouveaux(["p-2"])
        #expect(suivi.taille == 1)
        #expect(!suivi.dejaVu("p-1"))
        #expect(suivi.dejaVu("p-2"))
    }

    @Test("la mémoire de veille se sérialise d'un bloc")
    func memoireCodable() throws {
        var memoire = MemoireVeille()
        _ = memoire.mandats.nouveaux(["p-1"])
        let octets = try JSONEncoder().encode(memoire)
        let relue = try JSONDecoder().decode(MemoireVeille.self, from: octets)
        #expect(relue == memoire)
        #expect(relue.mandats.dejaVu("p-1"))
    }
}

@Suite("Traduction des faits en alertes")
struct TraductionAlerteTests {

    private func fait(type: String, fil: String?) throws -> NotificationApi {
        let brut = """
        {"id":"n-1","type":"\(type)","title":"Équipe terminée","body":"Rapport rendu.",
         "missionId":"m-1","conversationId":\(fil.map { "\"\($0)\"" } ?? "null"),
         "createdAt":1700000000000,"read":false,"delivered":false,"deliveryError":null}
        """
        return try JSONDecoder().decode(NotificationApi.self, from: Data(brut.utf8))
    }

    @Test("un fait porte son fil, sa mission et son genre")
    func faitTraduit() throws {
        let projet = TraductionAlerte.projet(pour: try fait(type: "equipe_terminee", fil: "c-9"))
        #expect(projet.identifiant == "fait.n-1")
        #expect(projet.genre == .equipe)
        #expect(projet.fil == "fil.c-9")
        #expect(projet.donnees[ProjetNotification.Cle.fil] == "c-9")
        #expect(projet.donnees[ProjetNotification.Cle.mission] == "m-1")
    }

    @Test("un type inconnu reste alerté, en genre parc")
    func typeInconnu() throws {
        let projet = TraductionAlerte.projet(pour: try fait(type: "quota_atteint", fil: nil))
        #expect(projet.genre == .parc)
        #expect(projet.fil == nil)
    }

    @Test("un échec se distingue d'une réussite")
    func echecDistinct() throws {
        let projet = TraductionAlerte.projet(pour: try fait(type: "equipe_echouee", fil: "c-1"))
        #expect(projet.genre == .echec)
        #expect(projet.genre.categorie == GenreAlerte.equipe.categorie)
    }

    @Test("le droit réel du mandat est dans le sous-titre")
    func mandatDroitVisible() throws {
        let brut = """
        {"id":"p-1","conversationId":"c-1","projet":"vitrail","objectif":"Corriger le rendu",
         "critereArret":null,"perimetre":"lecture seule annoncée","acces":"ecriture",
         "budgetMaxUsd":12.5,"modele":null,"effort":null,"statut":"en_attente",
         "missionId":null,"detail":null,"creeA":1700000000000,"majA":1700000000000}
        """
        let mandat = try JSONDecoder().decode(PropositionApi.self, from: Data(brut.utf8))
        let projet = TraductionAlerte.projet(pour: mandat)
        #expect(projet.sousTitre == "vitrail · écriture · 12,50 $")
        #expect(projet.donnees[ProjetNotification.Cle.proposition] == "p-1")
        #expect(projet.genre.categorie == "vigie.mandat")
    }

    @Test("les sommes s'écrivent en français")
    func sommeFrancaise() {
        #expect(TraductionAlerte.somme(12) == "12,00 $")
        #expect(TraductionAlerte.somme(3.5) == "3,50 $")
        #expect(TraductionAlerte.somme(0.05) == "0,05 $")
    }

    @Test("la portée d'une rallonge dit ce qui est demandé")
    func porteeRallonge() throws {
        let brut = """
        {"id":"r-1","conversationId":"c-1","plafondDemande":null,"fenetreDebut":1700000000000,
         "fenetreFin":1700003600000,"fenetreObjectif":"nuit","motif":"finir la migration",
         "statut":"en_attente","detail":null,"creeA":1700000000000}
        """
        let rallonge = try JSONDecoder().decode(RallongeApi.self, from: Data(brut.utf8))
        let projet = TraductionAlerte.projet(pour: rallonge)
        #expect(projet.sousTitre == "plage d'autonomie")
        #expect(projet.genre == .rallonge)
    }
}

@Suite("Expiration de la signature")
struct ExpirationSignatureTests {

    private var profil: Data {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict>
        <key>CreationDate</key><date>2026-08-17T09:00:00Z</date>
        <key>Name</key><string>iOS Team Provisioning Profile</string>
        <key>ExpirationDate</key><date>2026-08-24T09:31:12Z</date>
        </dict></plist>
        """
        var octets = Data([0x30, 0x82, 0x0A, 0x00])
        octets.append(Data(plist.utf8))
        octets.append(Data([0x00, 0xFF, 0x00]))
        return octets
    }

    @Test("la date d'expiration se lit à travers l'emballage CMS")
    func lectureProfil() throws {
        let date = try #require(ExpirationSignature.lire(profil))
        let attendue = try #require(ExpirationSignature.dateISO("2026-08-24T09:31:12Z"))
        #expect(date == attendue)
    }

    @Test("la clé lue est bien ExpirationDate et pas la première date venue")
    func bonneCle() throws {
        let date = try #require(ExpirationSignature.lire(profil))
        let creation = try #require(ExpirationSignature.dateISO("2026-08-17T09:00:00Z"))
        #expect(date != creation)
    }

    @Test("un fichier illisible ne fait pas échouer la lecture")
    func profilIllisible() {
        #expect(ExpirationSignature.lire(Data([0x30, 0x82, 0x01])) == nil)
        #expect(ExpirationSignature.lire(Data()) == nil)
    }

    @Test("l'alerte tombe un jour avant l'échéance")
    func alerteJMoinsUn() throws {
        let expiration = Date(timeIntervalSince1970: 1_700_000_000)
        let maintenant = expiration.addingTimeInterval(-4 * 86_400)
        let projet = try #require(ExpirationSignature.projet(expiration: expiration, maintenant: maintenant))
        #expect(projet.delai == TimeInterval(3 * 86_400))
        #expect(projet.genre == .signature)
    }

    @Test("aucune alerte si l'échéance est déjà passée")
    func echeancePassee() {
        let expiration = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(ExpirationSignature.projet(expiration: expiration, maintenant: expiration) == nil)
    }
}

@Suite("État du canal")
struct EtatCanalTests {

    @Test("un réveil de fond réel est compté à part d'un relevé de premier plan")
    func reveilReelDistinct() {
        var etat = EtatCanal()
        let instant = Date()
        etat.noterContact(instant, origine: .premierPlan)
        #expect(etat.dernierReveilReel == nil)
        #expect(etat.reveilsReels == 0)
        etat.noterContact(instant, origine: .reveilDeFond)
        #expect(etat.dernierReveilReel == instant)
        #expect(etat.reveilsReels == 1)
        #expect(etat.dernierContact == instant)
    }

    @Test("le journal des alertes est borné")
    func journalBorne() {
        var etat = EtatCanal()
        for rang in 0..<30 {
            etat.noterAlerte(
                ProjetNotification(
                    identifiant: "f-\(rang)", genre: .equipe, titre: "Fait \(rang)", corps: ""
                )
            )
        }
        #expect(etat.derniers.count == 20)
        #expect(etat.derniers.first?.titre == "Fait 29")
        #expect(etat.faitsSonnes == 30)
    }

    @Test("le canal n'est complet que si les trois conditions tiennent")
    func canalComplet() {
        var etat = EtatCanal()
        #expect(!etat.complet)
        etat.autorisation = "accordée"
        etat.audioActif = true
        #expect(!etat.complet)
        etat.noterContact(Date(), origine: .ouverture)
        #expect(etat.complet)
    }

    @Test("l'état se sérialise pour survivre à une mise à mort")
    func etatCodable() throws {
        var etat = EtatCanal()
        etat.noterContact(Date(timeIntervalSince1970: 1_700_000_000), origine: .reveilDeFond)
        etat.autorisation = "accordée"
        let relu = try JSONDecoder().decode(EtatCanal.self, from: JSONEncoder().encode(etat))
        #expect(relu == etat)
    }

    @Test("le canal tient quand le relais de localisation a pris la main")
    func canalCompletParLocalisation() {
        var etat = EtatCanal()
        etat.autorisation = "accordée"
        etat.noterContact(Date(), origine: .veilleLocalisation)
        // Une autre app détient l'audio : le canal 1 est tombé.
        etat.audioActif = false
        #expect(!etat.complet)
        etat.localisationActive = true
        #expect(etat.complet)
    }

    /// `☠` Le décodage synthétisé de Swift échoue sur une clé absente, même
    /// quand la propriété porte une valeur par défaut. Ce test tient la
    /// compatibilité avec les états écrits dans `UserDefaults` AVANT que le
    /// relais de localisation existe : s'il casse, tout l'historique du canal
    /// repart de zéro au premier lancement, en silence.
    @Test("un état écrit avant le relais de localisation se relit encore")
    func etatAncienDecodable() throws {
        let ancien = """
        {"reveilsReels":0,"reveilReplanifie":false,"reveilEnregistre":true,\
        "autorisation":"accordée","audioActif":true,"audioInterruptions":2,\
        "audioReprises":1,"alarmesArmees":[],"rattrapageIncomplet":false,\
        "faitsSonnes":7,"derniers":[]}
        """
        let etat = try JSONDecoder().decode(EtatCanal.self, from: Data(ancien.utf8))
        #expect(etat.audioInterruptions == 2)
        #expect(etat.faitsSonnes == 7)
        #expect(etat.localisationActive == nil)
        #expect(!etat.localisationTient)
    }
}
