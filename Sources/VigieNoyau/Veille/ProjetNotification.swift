import Foundation

/// Ce qu'une alerte locale doit dire, décidé HORS de `UserNotifications`.
///
/// `☠` Le niveau d'insistance s'arrête à `active`, et ce n'est pas un oubli :
/// `timeSensitive` et `critical` exigent des entitlements qu'Apple accorde sur
/// dossier. En free provisioning, les demander ne produit pas une erreur — ça
/// produit une notification SILENCIEUSEMENT rétrogradée. Aucun mode Concentration
/// ne sera percé ; c'est acté, on ne le contourne pas, on l'écrit.
public enum Insistance: String, Codable, Sendable {
    /// Sans son, sans réveil d'écran. Pour ce qui documente sans réclamer.
    case discrete
    /// Son standard, bannière, écran allumé. Le maximum atteignable ici.
    case active
}

/// La nature du fait alerté. Détermine la catégorie (donc les boutons) et le
/// regroupement dans le centre de notifications.
public enum GenreAlerte: String, Codable, Sendable, CaseIterable {
    /// Un mandat attend une autorisation humaine. Le seul genre qui porte des
    /// boutons engageants.
    case mandat
    /// Une demande d'élargissement d'autonomie.
    case rallonge
    /// Une inspection a rendu un verdict de boucle et attend un arbitrage.
    /// `☠` Sans boutons, délibérément : contrairement à un mandat, on ne peut
    /// pas trancher sans avoir lu le motif du verdict. Deux boutons sur l'écran
    /// verrouillé feraient arrêter — ou laisser courir — une équipe à l'aveugle.
    case arbitrage
    /// Un fil quitté en pleine génération vient de répondre.
    case reponse
    /// Une équipe a rendu.
    case equipe
    /// Une équipe s'est arrêtée sur un échec.
    case echec
    /// L'alarme de silence — voir `AlarmeSilence`.
    case silence
    /// La signature de l'IPA expire.
    case signature
    /// Tout le reste : ce que le parc dit sans qu'on ait à agir.
    case parc

    /// Identifiant de catégorie `UNNotificationCategory`. Préfixe `vigie.` pour
    /// ne jamais collisionner avec les catégories du laboratoire EchoLabs, qui
    /// partage le même identifiant de paquet.
    public var categorie: String {
        switch self {
        case .mandat: return "vigie.mandat"
        case .rallonge: return "vigie.rallonge"
        case .arbitrage: return "vigie.arbitrage"
        case .reponse: return "vigie.fil"
        case .equipe, .echec, .parc: return "vigie.parc"
        case .silence: return "vigie.silence"
        case .signature: return "vigie.signature"
        }
    }

    public var libelle: String {
        switch self {
        case .mandat: return "Mandat"
        case .rallonge: return "Rallonge"
        case .arbitrage: return "Arbitrage"
        case .reponse: return "Réponse"
        case .equipe: return "Équipe"
        case .echec: return "Échec"
        case .silence: return "Silence"
        case .signature: return "Signature"
        case .parc: return "Parc"
        }
    }
}

/// Une notification locale entièrement décidée, prête à être posée.
///
/// Le domaine `Alerte` la traduit en `UNNotificationRequest` et rien de plus :
/// aucune règle de contenu ne vit du côté d'UIKit, donc tout est éprouvable
/// sur une machine sans iPhone.
public struct ProjetNotification: Sendable, Equatable, Identifiable {
    /// Stable et déterministe : c'est lui qui empêche un fait d'être sonné deux
    /// fois si un réveil de fond et le premier plan se croisent.
    public let identifiant: String
    public let genre: GenreAlerte
    public let titre: String
    public let sousTitre: String?
    public let corps: String
    /// Regroupement dans le centre de notifications. Un fil par projet ou par
    /// conversation : dix équipes d'un même projet se replient sous un résumé.
    public let fil: String?
    /// Ce que l'action de la notification devra retrouver : identifiants de fil,
    /// de mission, de proposition. Uniquement des chaînes — c'est tout ce qui
    /// traverse `userInfo` sans surprise.
    public let donnees: [String: String]
    public let insistance: Insistance
    /// Délai avant présentation. `nil` ⇒ tout de suite (déclencheur immédiat).
    public let delai: TimeInterval?

    public var id: String { identifiant }

    public init(
        identifiant: String,
        genre: GenreAlerte,
        titre: String,
        sousTitre: String? = nil,
        corps: String,
        fil: String? = nil,
        donnees: [String: String] = [:],
        insistance: Insistance = .active,
        delai: TimeInterval? = nil
    ) {
        self.identifiant = identifiant
        self.genre = genre
        self.titre = titre
        self.sousTitre = sousTitre
        self.corps = corps
        self.fil = fil
        self.donnees = donnees
        self.insistance = insistance
        self.delai = delai
    }
}

extension ProjetNotification {
    /// Clés de `donnees`, écrites une fois. Une clé recopiée à la main dans un
    /// écran finit toujours par diverger de celle qui a été postée.
    public enum Cle {
        public static let fil = "fil"
        public static let mission = "mission"
        public static let proposition = "proposition"
        public static let rallonge = "rallonge"
        public static let genre = "genre"
    }
}
