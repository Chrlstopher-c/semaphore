// Section « À propos » : version, bundle, et l'échéance de la signature —
// l'information la plus utile de l'écran : en free provisioning elle expire
// tous les sept jours SANS AVERTIR, et l'app cesse de se lancer.
// Le diagnostic s'ouvre par un appui long sur la ligne de version.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct SectionAPropos: View {
    @State private var expiration: Date?
    @State private var diagnosticVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            TeteDeSection("À propos")
            Panneau {
                VStack(alignment: .leading, spacing: 0) {
                    LigneCle("Bundle", valeur: Self.bundleId)
                    ligneVersion
                    blocExpiration
                }
            }
        }
        .task { chargerExpiration() }
        .sensoryFeedback(Haptique.garde, trigger: diagnosticVisible) { _, nouveau in nouveau }
        .feuilleQuart(presentee: $diagnosticVisible, hauteurs: [.large]) { DiagnosticEcran() }
    }

    /// L'appui long ici est permis : la ligne n'est PAS un bouton — il n'y a
    /// aucun geste interne à qui voler le toucher.
    private var ligneVersion: some View {
        LigneCle("Version", valeur: "\(Self.version) (\(Self.build))")
            .contentShape(.rect)
            .onLongPressGesture(minimumDuration: 0.6) { diagnosticVisible = true }
            .accessibilityHint("Appui long : diagnostic de l'appareil")
    }

    @ViewBuilder private var blocExpiration: some View {
        if let expiration {
            JaugeFine(
                "Signature",
                part: Self.fractionEcoulee(jusqua: expiration),
                detail: Self.libelleExpiration(jusqua: expiration),
                seuilVigilance: 5.0 / 7,
                seuilDanger: 6.0 / 7
            )
            .padding(.top, Trame.serre)
        } else {
            LigneCle("Signature", valeur: "illisible", teinteValeur: Teinte.encreTernie, derniere: true)
        }
    }

    // MARK: - Lecture disque

    /// `☠` Un profil illisible n'est pas une panne : l'app tourne quand même,
    /// on perd seulement l'avertissement — et l'écran le dit.
    private func chargerExpiration() {
        guard let url = Bundle.main.url(
            forResource: ExpirationSignature.nomFichier,
            withExtension: ExpirationSignature.extensionFichier
        ) else {
            Trace.info("reglages", "profil de provisionnement absent du bundle")
            return
        }
        do {
            expiration = ExpirationSignature.lire(try Data(contentsOf: url))
        } catch {
            Trace.erreur("reglages", "profil de provisionnement illisible", error)
        }
    }

    // MARK: - Mise en forme

    private static func fractionEcoulee(jusqua expiration: Date) -> Double {
        let joursRestants = expiration.timeIntervalSinceNow / 86_400
        return min(max(1 - joursRestants / 7, 0), 1)
    }

    private static func libelleExpiration(jusqua expiration: Date) -> String {
        let joursRestants = expiration.timeIntervalSinceNow / 86_400
        guard joursRestants > 0 else { return "expirée — resigner l'IPA sans délai" }
        if joursRestants < 1 {
            return "expire dans \(Int((joursRestants * 24).rounded())) h — resigner aujourd'hui"
        }
        return "expire dans \(Int(joursRestants.rounded(.down))) j"
    }

    private static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    private static var bundleId: String {
        Bundle.main.bundleIdentifier ?? "—"
    }
}
#endif
