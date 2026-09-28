// Le câblage de Vigie : l'adresse du relais, le jeton d'appareil, le modèle, la veille. Construit une fois par l'app.
#if canImport(SwiftUI)
import Foundation
import Observation
import SwiftUI
import VigieNoyau

@MainActor @Observable
public final class Cablage {
    /// Adresse injectée par `build.sh` depuis `.env.local` (jamais dans le dépôt) ; l'exemple sinon.
    public static let adresseParDefaut: URL = {
        let brut = Bundle.main.object(forInfoDictionaryKey: "EchoAdresseCcremote") as? String
        return URL(string: brut?.isEmpty == false ? brut! : "https://ccremote.example.com")!
    }()

    private static let cleAdresse = "vigie.v2.adresse"

    public let modele = ModeleRelais()
    public private(set) var adresse: URL
    public private(set) var connecte = false
    @ObservationIgnored private var amorce = false

    public init() {
        let memorisee = UserDefaults.standard.string(forKey: Self.cleAdresse).flatMap(URL.init(string:))
        adresse = memorisee ?? Self.adresseParDefaut
    }

    /// Idempotent : le pupitre monte toutes les coquilles au lancement, et `.task` peut revenir.
    public func amorcer() async {
        guard !amorce else { return }
        amorce = true
        DelegueApplication.ecouteur = Aiguillage.partage
        Aiguillage.partage.modele = modele
        brancher(jeton: Trousseau.lire())
        await CentreAlerte.partage.demarrer()
        if PreferencesAlerte.maintienEnVie { MaintienVie.partage.demarrer() }
    }

    public func connecter(adresse: URL, motDePasse: String) async throws {
        let jeton = try await ClientRelais.connecter(adresse: adresse, motDePasse: motDePasse)
        self.adresse = adresse
        UserDefaults.standard.set(adresse.absoluteString, forKey: Self.cleAdresse)
        Trousseau.ecrire(jeton)
        brancher(jeton: jeton)
    }

    public func deconnecter() {
        Trousseau.ecrire(nil)
        brancher(jeton: nil)
    }

    private func brancher(jeton: String?) {
        let client = jeton.map { ClientRelais(adresse: adresse, jeton: $0) }
        connecte = client != nil
        modele.brancher(client)
        CentreAlerte.partage.brancher(client: client)
        modele.demarrer()
    }
}

extension View {
    /// Pose le câblage dans l'environnement. `☠` En DERNIER dans la chaîne d'une coquille : un overlay posé après
    /// serait hors de portée et ferait tomber l'app au lancement (voir skill swift-ios).
    public func cable(_ cablage: Cablage) -> some View {
        environment(cablage).environment(cablage.modele)
    }
}
#endif
