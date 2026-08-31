#if canImport(SwiftUI)
import Foundation
import Observation
import SwiftUI
import VigieNoyau

/// Le câblage de l'application : les quatre objets partagés, construits une fois
/// et injectés dans l'environnement.
///
/// Un domaine ne construit JAMAIS son propre client ni son propre miroir. C'est
/// ce qui garantit une seule session HTTP, un seul fichier de miroir, une seule
/// minuterie — et donc un seul endroit où regarder quand quelque chose cloche.
@MainActor @Observable
public final class Cablage {

    /// Adresse par défaut : le tunnel Cloudflare du Pi (`deploy-web-pi.sh`).
    /// Le repli LAN se saisit dans les Réglages,
    /// et sert quand le tunnel est coupé mais que le WiFi de la maison est là.
    public static let adresseParDefaut = URL(string: adresseEmbarquee(
        "EchoAdresseCcremote", repli: "https://ccremote.example.com"))!

    private static let cleAdresse = "vigie.adresse"

    public let miroir: DepotMiroir
    public let client: ClientPi
    public let cadence: Cadence
    public let liaison: Liaison

    public private(set) var adresse: URL

    public init(adresse: URL? = nil) {
        let choisie = adresse ?? Self.adresseMemorisee()
        self.adresse = choisie
        let depot = DepotMiroir()
        miroir = depot
        client = ClientPi(adresse: choisie, miroir: depot)
        cadence = Cadence()
        liaison = Liaison()
    }

    /// Ouvre le miroir, branche le bandeau d'état sur le flux du client, et
    /// arme le canal d'alerte. Appelé une seule fois par la coquille, avant le
    /// premier écran.
    public func amorcer() async {
        await miroir.charger()
        CentreAlerte.partage.brancher(client: client)
        ActionRecue.partage.brancher(client: client)
        await CentreAlerte.partage.demarrer()
        // Le canal 1. Coupé, il ne reste que le rattrapage d'ouverture et les
        // réveils de fond — c'est un réglage, donc une décision de Chris.
        if PreferencesAlerte.maintienEnVie { MaintienVie.partage.demarrer() }
        // Tâche non structurée assumée : elle vit aussi longtemps que
        // l'application. C'est le seul drain du flux de verdicts — l'ouvrir
        // ailleurs volerait les événements à celui-ci.
        Task { @MainActor [client, liaison] in
            for await verdict in client.verdicts { liaison.appliquer(verdict) }
        }
    }

    public func changerAdresse(_ nouvelle: URL) async {
        adresse = nouvelle
        UserDefaults.standard.set(nouvelle.absoluteString, forKey: Self.cleAdresse)
        await client.changerAdresse(nouvelle)
    }

    private static func adresseMemorisee() -> URL {
        guard let brut = UserDefaults.standard.string(forKey: cleAdresse),
              let url = URL(string: brut) else { return adresseParDefaut }
        return url
    }
}

// MARK: - Environnement

/// `ClientPi` et `DepotMiroir` sont des acteurs, donc pas observables : ils
/// passent par des clés d'environnement classiques plutôt que par `.environment(_:)`.
/// Les valeurs par défaut visent un miroir jetable, pas le vrai fichier : si un
/// écran est monté sans câblage (aperçu, test), il ne doit surtout pas écraser
/// l'état réel de l'application.
private let miroirJetable = DepotMiroir(
    fichier: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("vigie-sans-cablage.json")
)

private struct CleClientPi: EnvironmentKey {
    // `☠` Le défaut ne peut pas être une constante : `ClientPi` est isolé au
    // MainActor, et une valeur par défaut d'EnvironmentKey est évaluée depuis
    // un contexte non isolé. La calculer à la demande, sur le MainActor,
    // satisfait la concurrence stricte sans changer le comportement.
    @MainActor static let clientJetable = ClientPi(
        adresse: Cablage.adresseParDefaut,
        miroir: miroirJetable
    )

    static var defaultValue: ClientPi {
        MainActor.assumeIsolated { clientJetable }
    }
}

private struct CleMiroirDepot: EnvironmentKey {
    static let defaultValue = miroirJetable
}

extension EnvironmentValues {
    /// La seule sortie réseau. `@Environment(\.clientPi) private var client`
    public var clientPi: ClientPi {
        get { self[CleClientPi.self] }
        set { self[CleClientPi.self] = newValue }
    }

    /// L'état local persistant. `@Environment(\.miroir) private var miroir`
    public var miroir: DepotMiroir {
        get { self[CleMiroirDepot.self] }
        set { self[CleMiroirDepot.self] = newValue }
    }
}

extension View {
    /// Injecte les quatre objets partagés d'un coup. Posé une seule fois, sur la
    /// vue racine.
    public func cable(_ cablage: Cablage) -> some View {
        self
            .environment(\.clientPi, cablage.client)
            .environment(\.miroir, cablage.miroir)
            .environment(cablage.cadence)
            .environment(cablage.liaison)
            .environment(cablage)
    }
}

/// Lit une adresse posée dans `Info.plist` au moment de compiler.
///
/// `☠` Le dépôt est public : aucune adresse réelle n'y est écrite. `build.sh`
/// génère `.build/Info.plist` depuis `Info.template.plist` en y injectant les
/// valeurs de `.env.local`, jamais suivi par git. Clé absente ou vide — clone
/// frais, suite de tests — on rend le repli, qui est un exemple.
func adresseEmbarquee(_ cle: String, repli: String) -> String {
    guard let brut = Bundle.main.object(forInfoDictionaryKey: cle) as? String else { return repli }
    let nettoyee = brut.trimmingCharacters(in: .whitespacesAndNewlines)
    return nettoyee.isEmpty ? repli : nettoyee
}

#endif
