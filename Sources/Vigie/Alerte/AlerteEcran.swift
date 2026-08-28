#if canImport(SwiftUI)
import Foundation
import SwiftUI
import VigieNoyau

/// L'état du canal d'alerte — le seul écran qui dise si la chaîne tient
/// debout, et surtout qui dise NON quand elle ne tient pas. Un canal mort et
/// un parc calme produisent exactement le même silence.
///
/// Il montre ce qui a RÉELLEMENT eu lieu (dernier réveil servi par iOS,
/// dernier contact, dernières alertes posées), et porte la liste des faits du
/// parc avec leurs deux destinataires — Chris (`read`) et l'orchestrateur
/// (`delivered`), jamais fondus.
public struct AlerteEcran: View {
    @Environment(\.clientPi) private var client
    @Environment(\.miroir) private var miroir
    @Environment(TableauDeVeille.self) private var veille

    @State private var centre = CentreAlerte.partage
    @State private var maintien = MaintienVie.partage
    @State private var faits: [NotificationApi] = []
    @State private var nonLues = 0
    @State private var marquageEnCours = false
    @State private var avis: String?

    public init() {}

    private var etat: EtatCanal { centre.etat }

    public var body: some View {
        VStack(spacing: 0) {
            EnTeteEcran("Alerte", releveA: etat.dernierContact, retour: true)
            corps
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Teinte.fond)
        .avisFugace($avis)
        .cadencePar("alerte") { await battre() }
    }

    private var corps: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Trame.section) {
                verdict
                sectionFaits
                sectionCanaux
                sectionArmement
                sectionJournal
            }
            .padding(.horizontal, Trame.ecran)
            .padding(.bottom, Trame.section)
        }
        .scrollIndicators(.hidden)
        .refreshable { await battre() }
    }

    // MARK: - Verdict

    /// Trois conditions montrées séparément : un verdict unique ne dirait pas
    /// laquelle manque, donc ne dirait pas quoi faire.
    @ViewBuilder private var verdict: some View {
        if !etat.autorisationAccordee {
            BandeauNote(
                "Notifications \(etat.autorisation) — rien ne sonnera. Réglages iOS → Vigie.",
                ton: .danger
            )
        } else if !etat.audioActif {
            BandeauNote(
                "Veille audio coupée : les alertes n'arriveront qu'à l'ouverture ou sur un "
                    + "réveil de fond, qu'iOS accorde environ une fois sur deux.",
                ton: .vigilance
            )
        } else if let panne = etat.derniereErreurTransport {
            BandeauNote("Dernier relevé en échec : \(panne)", ton: .vigilance)
        } else if etat.rattrapageIncomplet {
            BandeauNote(
                "Des faits ont quitté la fenêtre du serveur avant d'être vus : le "
                    + "rattrapage est incomplet.",
                ton: .vigilance
            )
        } else {
            BandeauNote("Le canal tient : veille audio active, dernier relevé abouti.", ton: .sain)
        }
    }

    // MARK: - Faits du parc

    private var sectionFaits: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            TeteDeSection("Faits du parc") {
                if nonLues > 0 {
                    Button(marquageEnCours ? "Marquage…" : "Tout marquer lu") {
                        Task { await toutMarquerLu() }
                    }
                    .buttonStyle(.allurePuce)
                    .disabled(marquageEnCours)
                }
            }
            if faits.isEmpty {
                Text("Aucun fait dans la fenêtre du serveur (les 50 derniers au plus).")
                    .mention()
                    .foregroundStyle(Teinte.encreTernie)
            } else {
                VStack(spacing: Trame.serre) {
                    ForEach(faits) { fait in
                        LigneFait(fait: fait) {
                            Task { await marquerLu(fait) }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Canaux

    private var sectionCanaux: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            TeteDeSection("Canaux")
            Panneau {
                VStack(spacing: 0) {
                    LigneCle("1 · Veille audio", valeur: maintien.statut, teinteValeur: teinte(etat.audioActif))
                    LigneCle(
                        "Interruptions / reprises",
                        valeur: "\(etat.audioInterruptions) / \(etat.audioReprises)"
                    )
                    LigneCle(
                        "2 · Dernier contact",
                        valeur: age(etat.dernierContact),
                        teinteValeur: teinte(etat.dernierContact != nil)
                    )
                    LigneCle("Origine", valeur: etat.derniereOrigine?.libelle ?? "—")
                    // `☠` Le réveil RÉELLEMENT servi, jamais celui qui a été
                    // demandé — les deux se ressemblent dans le code et n'ont
                    // rien à voir dans la réalité.
                    LigneCle(
                        "3 · Réveil de fond servi",
                        valeur: age(etat.dernierReveilReel),
                        teinteValeur: teinte(etat.dernierReveilReel != nil)
                    )
                    LigneCle("Réveils servis", valeur: "\(etat.reveilsReels)")
                    LigneCle("Planification", valeur: libellePlanification, derniere: true)
                }
            }
        }
    }

    private var libellePlanification: String {
        guard etat.reveilEnregistre else { return "refusée par le système" }
        return etat.reveilReplanifie ? "acceptée" : "non replanifiée"
    }

    // MARK: - Pré-armé

    private var sectionArmement: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            TeteDeSection("Pré-armé")
            Panneau {
                VStack(spacing: 0) {
                    LigneCle(
                        "4 · Alarmes de silence",
                        valeur: "\(etat.alarmesArmees.count) armée\(etat.alarmesArmees.count > 1 ? "s" : "")",
                        teinteValeur: teinte(!etat.alarmesArmees.isEmpty)
                    )
                    LigneCle("Prochaine", valeur: prochaineAlarme)
                    LigneCle("Signature", valeur: echeanceSignature, derniere: true)
                }
            }
            Text("Les seules alertes qui survivent à la mort de Vigie : déposées à "
                + "l'avance dans le centre de notifications, elles dénoncent le silence.")
                .mention()
                .foregroundStyle(Teinte.encreTernie)
        }
    }

    private var prochaineAlarme: String {
        guard let prochaine = etat.alarmesArmees.min() else { return "aucune" }
        return Lisible.heure(Int(prochaine.timeIntervalSince1970 * 1000))
    }

    private var echeanceSignature: String {
        guard let expiration = etat.expirationSignature else { return "illisible" }
        let jours = expiration.timeIntervalSinceNow / 86_400
        guard jours > 0 else { return "expirée" }
        return "\(Int(jours.rounded(.down))) j restants"
    }

    // MARK: - Journal local

    private var sectionJournal: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            TeteDeSection("Alertes posées par cet appareil") {
                Sceau("\(etat.faitsSonnes)", ton: .neutre)
            }
            if etat.derniers.isEmpty {
                Text("Aucune alerte posée depuis cet appareil.")
                    .mention()
                    .foregroundStyle(Teinte.encreTernie)
            } else {
                Panneau {
                    VStack(spacing: 0) {
                        ForEach(Array(etat.derniers.enumerated()), id: \.element.id) { rang, echo in
                            LigneCle(
                                "\(echo.genre.libelle) · \(Lisible.heure(Int(echo.instant.timeIntervalSince1970 * 1000)))",
                                valeur: echo.titre,
                                derniere: rang == etat.derniers.count - 1
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Relevés et gestes

    @MainActor private func battre() async {
        await centre.sonder(origine: .premierPlan)
        await relireLesFaits()
    }

    /// Le sondage du centre vient de déposer la liste au miroir : on la relit
    /// là plutôt que d'acheter un second aller-retour.
    @MainActor private func relireLesFaits() async {
        guard let donnee = await miroir.lire(ListeNotificationsApi.self, .notifications) else { return }
        faits = donnee.valeur.notifications.sorted { $0.createdAt > $1.createdAt }
        // `☠` Le badge se lit sur `unread`, jamais sur `count` : la liste est
        // plafonnée à 50 et mentirait au-delà.
        nonLues = donnee.valeur.unread
        veille.notificationsNonLues = nonLues
    }

    @MainActor private func marquerLu(_ fait: NotificationApi) async {
        guard !fait.read else { return }
        switch await client.ecrire(Route.marquerNotificationLue(fait.id)) {
        case .success:
            await rafraichirLesFaits()
        case .failure(let erreur):
            avis = erreur.message
        }
    }

    @MainActor private func toutMarquerLu() async {
        guard !marquageEnCours else { return }
        marquageEnCours = true
        defer { marquageEnCours = false }
        switch await client.ecrire(Route.marquerToutesNotificationsLues) {
        case .success(let accuse):
            avis = accuse.effet
            await rafraichirLesFaits()
        case .failure(let erreur):
            avis = erreur.message
        }
    }

    @MainActor private func rafraichirLesFaits() async {
        let lecture = await client.lire(
            ListeNotificationsApi.self, Route.notifications, memoriser: .notifications
        )
        if lecture.charge != nil { await relireLesFaits() }
    }

    // MARK: - Mise en forme

    private func teinte(_ bon: Bool) -> Color {
        bon ? Teinte.sain : Teinte.vigilance
    }

    private func age(_ instant: Date?) -> String {
        guard let instant else { return "jamais" }
        return Fraicheur.texte(depuis: instant)
    }
}

/// Un fait du parc : le point non-lu, le titre, et les DEUX destinataires —
/// marquer lu ne dit rien de la remise à l'orchestrateur, et l'inverse est le
/// cas normal la nuit.
private struct LigneFait: View {
    let fait: NotificationApi
    let marquerLu: () -> Void

    var body: some View {
        Button {
            marquerLu()
        } label: {
            Panneau(rail: fait.read ? nil : .attention) {
                VStack(alignment: .leading, spacing: Trame.fin + 1) {
                    HStack(spacing: Trame.serre) {
                        Text(fait.title)
                            .phraseForte()
                            .foregroundStyle(fait.read ? Teinte.encreDouce : Teinte.encre)
                        Spacer(minLength: 0)
                        Text(Lisible.heure(fait.createdAt))
                            .donneeMinuscule()
                            .foregroundStyle(Teinte.encreTernie)
                    }
                    if !fait.body.isEmpty {
                        Text(fait.body)
                            .note()
                            .foregroundStyle(Teinte.encreDouce)
                            .lineLimit(3)
                    }
                    HStack(spacing: Trame.serre) {
                        remise
                        Spacer(minLength: 0)
                        if !fait.read {
                            Text("toucher pour marquer lu")
                                .donneeMinuscule()
                                .foregroundStyle(Teinte.encreTernie)
                        }
                    }
                }
            }
        }
        .buttonStyle(.allureCarte)
        .disabled(fait.read)
    }

    @ViewBuilder private var remise: some View {
        if fait.delivered {
            Sceau("orchestrateur au courant", ton: .sain)
        } else if let panne = fait.deliveryError {
            Sceau("remise en échec : \(panne)", ton: .vigilance)
        } else {
            Sceau("pas encore remis à l'orchestrateur", ton: .veille)
        }
    }
}
#endif
