// Le câblage de Vigie : l'adresse du relais, le jeton d'appareil, le modèle, la veille. Construit une fois par l'app.
#if canImport(SwiftUI)
import Foundation
import Observation
import SwiftUI
import VigieNoyau

@MainActor @Observable
public final class Cablage {
    /// `☠` Quart v1 parle à un nœud Lanterne. Il ne reprend NI l'adresse NI le jeton de l'ancienne Vigie (relais
    /// ccremote du Pi, `vigie.v2.adresse` + trousseau `jeton-relais`) : les reprendre l'avait branché en silence sur
    /// l'ancien relais, dont les postes ne sont plus ceux du parc (la tour y apparaissait éteinte).
    public static let adresseParDefaut = URL(string: "https://noeud.example.com")!

    private static let cleAdresse = "quart.v1.adresse"
    private static let nomAppareil = "iPhone (Quart)"

    public let modele = ModeleRelais()
    public private(set) var adresse: URL
    public private(set) var connecte = false
    @ObservationIgnored private var amorce = false
    /// Lien par l'aiguilleur (voir CablageAiguilleur.swift) : état affiché, état retenu, client vivant.
    public internal(set) var lienAiguilleur: ClientAiguilleur.Lien = .deconnecte
    public internal(set) var etatAiguilleur: ClientAiguilleur.Etat?
    /// Les nœuds du réseau vus par le client (en ligne, appairés, préféré, relié) : réglages › Connexion.
    public internal(set) var noeudsAiguilleur: [NoeudVu] = []
    /// Nom du nœud relié (ou visé) par l'aiguilleur, quand il y en a un.
    public var nomNoeudActif: String? {
        guard let etat = etatAiguilleur, let id = etat.noeud else { return nil }
        return etat.noeuds[id]?.nom
    }
    @ObservationIgnored var clientAiguilleur: ClientAiguilleur?

    public init() {
        let memorisee = UserDefaults.standard.string(forKey: Self.cleAdresse).flatMap(URL.init(string:))
        adresse = memorisee ?? Self.adresseParDefaut
        adresseConnue = memorisee != nil
    }

    /// Une adresse de nœud a déjà été retenue (sinon l'écran d'appairage part d'un champ vide).
    public private(set) var adresseConnue: Bool

    /// Idempotent : le pupitre monte toutes les coquilles au lancement, et `.task` peut revenir.
    public func amorcer() async {
        guard !amorce else { return }
        amorce = true
        DelegueApplication.ecouteur = Aiguillage.partage
        Aiguillage.partage.modele = modele
        if let etat = Self.etatAiguilleurGarde() { brancherAiguilleur(etat) } else { brancher(jeton: Trousseau.lire()) }
        await CentreAlerte.partage.demarrer()
        if PreferencesAlerte.maintienEnVie { MaintienVie.partage.demarrer() }
    }

    public func connecter(adresse: URL, motDePasse: String) async throws {
        let jeton = try await ClientRelais.connecter(adresse: adresse, motDePasse: motDePasse)
        memoriser(adresse: adresse, jeton: jeton)
    }

    /// Appairage par code : le relais remet la clé de cet appareil, rangée comme un jeton de connexion.
    public func appairer(adresse: URL, code: String) async throws {
        let cle = try await ClientRelais.appairer(adresse: adresse, code: code, nom: Self.nomAppareil)
        memoriser(adresse: adresse, jeton: cle)
    }

    public func deconnecter() {
        Trousseau.ecrire(nil)
        oublierAiguilleur()
        modele.effacerOrganisation()
        brancher(jeton: nil)
    }

    private func memoriser(adresse: URL, jeton: String) {
        self.adresse = adresse
        adresseConnue = true
        UserDefaults.standard.set(adresse.absoluteString, forKey: Self.cleAdresse)
        Trousseau.ecrire(jeton)
        oublierAiguilleur() // revenir en direct : le lien par l'aiguilleur s'arrête, l'identité de l'iPhone reste
        brancher(jeton: jeton)
    }

    func brancher(jeton: String?) {
        let client = jeton.map { ClientRelais(adresse: adresse, jeton: $0) }
        brancher(client: client)
    }

    func brancher(client: ClientRelais?) {
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
