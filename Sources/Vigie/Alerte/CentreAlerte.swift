// Le centre de veille : relève les notifications du relais, sonne ce qui est nouveau, réarme l'alarme de silence.
// Appelé par la veille audio, la veille par localisation, les réveils de fond et le premier plan : un seul tour à la
// fois, sinon deux tours croisés sonneraient deux fois la même chose.
#if canImport(SwiftUI)
import Foundation
import Observation
import UserNotifications
import VigieNoyau

@MainActor @Observable
public final class CentreAlerte {
    public static let partage = CentreAlerte()

    public private(set) var etat = MemoireAlerte.lireEtat()
    public private(set) var dernierRefus: String?
    @ObservationIgnored private var client: ClientRelais?
    @ObservationIgnored private var filigrane = MemoireAlerte.lireMemoire()
    @ObservationIgnored private var sondageEnCours = false

    public func brancher(client: ClientRelais?) {
        self.client = client
    }

    /// Demande l'autorisation, pose les catégories, arme l'échéance de signature. Idempotent.
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
        do {
            let accordee = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            etat.autorisation = accordee ? "accordée" : "refusée"
        } catch {
            Trace.erreur("alerte", "demande d'autorisation refusée par le système", error)
            etat.autorisation = "erreur : \(error.localizedDescription)"
        }
    }

    /// Un tour de veille : relève les notifications (sans attendre), sonne les nouvelles, réarme le silence.
    public func sonder(origine: OrigineReleve) async {
        guard let client, !sondageEnCours else { return }
        sondageEnCours = true
        defer { sondageEnCours = false }
        do {
            let reponse: ReponseAttente = try await client.lire(Route.attente(version: -1, notifications: filigrane.dernierSeq,
                                                                             attendre: 0))
            await sonner(reponse.notifications)
            await noterContact(origine: origine)
        } catch {
            dernierRefus = "\(error)"
            Trace.erreur("alerte", "relevé impossible (\(origine.libelle))", error)
        }
    }

    /// Appelé aussi par le modèle du relais quand le premier plan reçoit des notifications en direct.
    public func sonner(_ lot: [NotificationRelais]) async {
        let nouvelles = filigrane.retenir(lot)
        MemoireAlerte.ecrire(filigrane)
        for n in nouvelles { _ = await Sonneur.poser(TraductionAlerte.projet(pour: n)) }
    }

    private func noterContact(origine: OrigineReleve) async {
        let maintenant = Date()
        etat.dernierContact = maintenant
        etat.derniereOrigine = origine
        if origine == .reveilDeFond {
            etat.dernierReveilReel = maintenant
            etat.reveilsReels += 1
        }
        etat.alarmesArmees = await Armement.armerAlarmeDeSilence(dernierContact: maintenant)
        MemoireAlerte.ecrire(etat)
    }

    // MARK: - Ponts vers le maintien en vie

    public func rapporterAudio(actif: Bool, interruptions: Int, reprises: Int, incident: String?) {
        etat.audioActif = actif
        etat.audioInterruptions = interruptions
        etat.audioReprises = reprises
        etat.audioIncident = incident
        MemoireAlerte.ecrire(etat)
    }

    public func rapporterLocalisation(actif: Bool, releves: Int, statut: String) {
        etat.localisationActive = actif
        etat.localisationReleves = releves
        etat.localisationStatut = statut
        MemoireAlerte.ecrire(etat)
    }

    /// Un réveil de fond RÉELLEMENT servi par iOS distingue un canal vivant d'un canal qu'on croit vivant.
    public func noterReveil(enregistre: Bool, replanifie: Bool) {
        etat.reveilEnregistre = enregistre
        etat.reveilReplanifie = replanifie
        MemoireAlerte.ecrire(etat)
    }
}
#endif
