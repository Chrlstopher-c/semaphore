import Foundation

/// Un fil de discussion avec l'orchestrateur, tel que `GET /orchestrator/conversations`
/// le rend.
public struct FilApi: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let titre: String
    public let creeA: Int
    public let majA: Int
    /// Une session SDK tourne réellement derrière ce fil.
    public let active: Bool
    /// `nil` = orchestrateur inactif ou pas encore de mesure. À afficher « — »,
    /// jamais un pourcentage inventé.
    public let contextPct: Int?
    public let compactions: Int
    /// Dernier couple utilisé DANS CE FIL — ce sur quoi rouvrir. `nil` sur un fil
    /// vierge, et c'est alors seulement que les défauts s'appliquent.
    public let model: String?
    public let effort: String?
    /// `nil` ⇒ fil antérieur au sélecteur : « non précisée », jamais une machine
    /// par défaut que personne n'a choisie.
    public let machine: String?
    public let autonomieDebut: Int?
    public let autonomieFin: Int?
    public let autonomieObjectif: String?
    public let plafondAutonomie: ReglagePlafondApi
}

/// Le détail d'un fil, tel que `GET /orchestrator/conversations/{id}` le rend.
///
/// `☠` CE N'EST PAS `FilApi` + des champs. Malgré l'héritage déclaré côté
/// TypeScript, la route (`vueDetailConversation`) NE SERT PAS `creeA`, `majA` ni
/// `machine`. Les déclarer non optionnels ici ferait échouer le décodage du seul
/// écran qui compte. La machine d'un fil se lit sur la liste, pas sur le détail.
public struct DetailFilApi: Decodable, Sendable {
    public let id: String
    public let titre: String
    public let events: [EvenementApi]
    /// Curseur de streaming : à repasser en `?since=` au sondage suivant.
    public let cursor: Int
    public let generating: Bool
    public let active: Bool
    public let contextPct: Int?
    public let compactions: Int
    public let model: String?
    public let effort: String?
    /// `nil` = jamais tranché sur ce fil (le défaut du compte s'applique) ;
    /// `false` = coupé explicitement. Les confondre forcerait un réglage à
    /// chaque message d'un fil qui n'a rien demandé.
    public let fastMode: Bool?
    /// Le bloc en cours de frappe — c'est LUI qui fait le streaming visible.
    public let partial: PartielApi?
    public let autonomieDebut: Int?
    public let autonomieFin: Int?
    public let autonomieObjectif: String?
    public let plafondAutonomie: ReglagePlafondApi
}

/// Réponse de `GET /orchestrator/conversations/{id}/events?since=`.
public struct EvenementsFilApi: Decodable, Sendable {
    public let events: [EvenementApi]
    public let cursor: Int
    public let generating: Bool
    public let active: Bool
    public let contextPct: Int?
    public let compactions: Int
    public let partial: PartielApi?
}

/// Un bloc du fil, dans l'ordre d'arrivée.
public struct EvenementApi: Decodable, Sendable, Hashable, Identifiable {
    /// Curseur de streaming ET identité stable de la ligne — contrairement au
    /// fil d'une mission, il n'y a rien à synthétiser ici.
    public let seq: Int
    public let type: TypeEvenementApi
    /// Sur un `mandat`, ce champ porte l'IDENTIFIANT de la proposition, pas un
    /// texte : la carte se remplit en croisant avec `/orchestrator/propositions`.
    public let contenu: String
    public let at: Int
    /// Portés PAR ÉVÈNEMENT : changer de modèle en cours de fil ne doit pas
    /// réécrire l'attribution des réponses déjà rendues.
    public let model: String?
    public let effort: String?
    /// Appels d'outils : ce que l'appel a demandé, et ce qu'il a rendu.
    /// `resultat` à `nil` veut dire « pas encore revenu », JAMAIS « vide ».
    public let detail: String?
    public let resultat: String?
    public let pieces: [PieceJointeApi]

    public var id: Int { seq }
}

/// Bloc en cours de frappe. Même forme pour un fil et pour une mission — l'écran
/// l'affiche avec le même composant, et le serveur l'a voulu ainsi.
public struct PartielApi: Decodable, Sendable, Hashable {
    public let type: TypeEvenementApi
    public let contenu: String
}

/// Pièce jointe d'un message opérateur.
public struct PieceJointeApi: Decodable, Sendable, Hashable {
    public let nom: String
    public let type: String
    public let taille: Int
    /// Chemin HTTP relatif servi par le control plane et relayé par pi-web.
    /// `☠` C'est la SEULE route qui rend des octets : elle exige la session, un
    /// chargeur d'image nu échouerait dessus.
    public let url: String
}

/// Plafond d'autonomie d'un fil : combien d'équipes il peut lancer sans clic.
///
/// `☠` Trois états DISTINCTS, et la distinction n'est pas cosmétique : confondre
/// « non réglé » et « illimité » afficherait un fil neuf comme délibérément
/// affranchi.
public enum ReglagePlafondApi: Sendable, Hashable, Decodable {
    /// Le fil ne règle rien : le défaut du parc s'applique.
    case herite
    /// Le plafond a été explicitement retiré DE CE FIL.
    case illimite
    case valeur(Int)
    /// Jeton que le serveur n'aurait pas dû produire. Conservé plutôt que fondu
    /// dans `herite` : un réglage illisible n'est pas un réglage absent.
    case illisible(String)

    public init(jeton: String) {
        switch jeton {
        case "", "herite": self = .herite
        case "illimite": self = .illimite
        default:
            if let n = Int(jeton), n > 0 { self = .valeur(n) } else { self = .illisible(jeton) }
        }
    }

    public init(from decodeur: Decoder) throws {
        self.init(jeton: try decodeur.singleValueContainer().decode(String.self))
    }

    /// Le réglage en français, jamais le jeton brut.
    public var libelle: String {
        switch self {
        case .herite: return "défaut du parc"
        case .illimite: return "aucun plafond (illimité)"
        case .valeur(let n): return "\(n) équipe\(n > 1 ? "s" : "") sans clic"
        case .illisible(let brut): return brut
        }
    }
}
