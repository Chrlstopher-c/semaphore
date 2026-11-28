// Les routines du ruban, telles que les sert le Pi : une routine = une heure de début + des jours + un scénario
// (la suite d'étapes qu'elle joue). Chaque routine a ses propres instructions : le scénario porte en général son id.
import Foundation

public struct Routine: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var nom: String
    /// « HH:MM », heure de DÉBUT du scénario.
    public var heure: String
    public var scenario: String
    /// Jours ISO : 1 = lundi … 7 = dimanche.
    public var jours: [Int]
    public var active: Bool
    /// Prochain passage calculé par le Pi (« 2026-11-29T07:00 »), absent si en pause.
    public var prochain: String?

    enum CodingKeys: String, CodingKey {
        case id, nom = "name", heure = "time", scenario, jours = "days", active = "enabled", prochain = "next_run"
    }

    public init(id: String, nom: String, heure: String, scenario: String, jours: [Int], active: Bool,
                prochain: String? = nil) {
        self.id = id
        self.nom = nom
        self.heure = heure
        self.scenario = scenario
        self.jours = jours
        self.active = active
        self.prochain = prochain
    }

    /// Le corps de `PUT /api/routines/{id}` : sans l'id ni le prochain passage.
    public var corps: Data {
        let objet: [String: Any] = ["name": nom, "time": heure, "scenario": scenario, "days": jours, "enabled": active]
        return (try? JSONSerialization.data(withJSONObject: objet, options: [.sortedKeys])) ?? Data()
    }
}

public struct Scenario: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var nom: String
    public var duree: Double
    public var etapes: [Etape]

    enum CodingKeys: String, CodingKey { case id, nom = "name", duree = "duration", etapes = "steps" }

    public init(id: String, nom: String, etapes: [Etape]) {
        self.id = id
        self.nom = nom
        self.etapes = etapes
        self.duree = Horaire.total(etapes)
    }

    /// Le corps de `PUT /api/scenarios/{id}` : le nom et les étapes nettoyées.
    public var corps: Data {
        struct Corps: Encodable { let name: String; let steps: [Etape] }
        let encodeur = JSONEncoder()
        encodeur.outputFormatting = .sortedKeys
        return (try? encodeur.encode(Corps(name: nom, steps: etapes.map(\.propre)))) ?? Data()
    }
}

/// Une étape d'instructions. Les champs utiles dépendent du genre (voir `propre`).
public struct Etape: Codable, Hashable, Sendable {
    public enum Genre: String, Codable, CaseIterable, Sendable {
        case fondu = "fade", pulsation = "pulse", maintien = "hold", animation = "effect", extinction = "off"
        case retour = "restore"

        public var nom: String {
            switch self {
            case .fondu: return "Fondu"
            case .pulsation: return "Pulsation"
            case .maintien: return "Maintien"
            case .animation: return "Animation"
            case .extinction: return "Extinction"
            case .retour: return "Retour"
            }
        }

        /// Ce que fait l'étape, en une phrase.
        public var explication: String {
            switch self {
            case .fondu: return "Glisse vers une couleur et une intensité."
            case .pulsation: return "Respire entre un creux et un pic."
            case .maintien: return "Garde la lumière telle qu'elle est."
            case .animation: return "Lance une animation du ruban."
            case .extinction: return "Fond vers le noir, puis éteint."
            case .retour: return "Revient à la lumière d'avant la routine."
            }
        }
    }

    public enum Courbe: String, Codable, CaseIterable, Sendable {
        case douce = "inout", reguliere = "linear", accelere = "in", ralentit = "out"

        public var nom: String {
            switch self {
            case .douce: return "Douce"
            case .reguliere: return "Régulière"
            case .accelere: return "Accélère"
            case .ralentit: return "Ralentit"
            }
        }
    }

    public var genre: Genre
    public var couleur: String?
    public var intensite: Int?
    public var duree: Double?
    public var courbe: Courbe?
    public var effet: Int?
    public var vitesse: Int?
    public var creux: Int?
    public var pic: Int?
    public var onde: Double?

    enum CodingKeys: String, CodingKey {
        case genre = "kind", couleur = "color", intensite = "brightness", duree = "duration", courbe = "ease"
        case effet = "code", vitesse = "speed", creux = "low", pic = "high", onde = "period"
    }

    public init(genre: Genre, couleur: String? = nil, intensite: Int? = nil, duree: Double? = nil,
                courbe: Courbe? = nil, effet: Int? = nil, vitesse: Int? = nil, creux: Int? = nil, pic: Int? = nil,
                onde: Double? = nil) {
        self.genre = genre
        self.couleur = couleur
        self.intensite = intensite
        self.duree = duree
        self.courbe = courbe
        self.effet = effet
        self.vitesse = vitesse
        self.creux = creux
        self.pic = pic
        self.onde = onde
    }

    /// Une étape neuve d'un genre, qui reprend la couleur de la précédente quand elle en a une.
    public static func neuve(_ genre: Genre, apres precedente: Etape? = nil) -> Etape {
        let c = precedente?.couleur ?? "#ffb46b"
        switch genre {
        case .fondu: return Etape(genre: .fondu, couleur: c, intensite: 80, duree: 60, courbe: .douce)
        case .pulsation: return Etape(genre: .pulsation, couleur: c, duree: 30, creux: 20, pic: 100, onde: 2)
        case .maintien: return Etape(genre: .maintien, duree: 60)
        case .animation: return Etape(genre: .animation, duree: 60, effet: 0x93, vitesse: 50)
        case .extinction: return Etape(genre: .extinction, duree: 2)
        case .retour: return Etape(genre: .retour)
        }
    }

    /// Seulement les champs de son genre (le Pi renvoie aussi « ease » partout).
    public var propre: Etape {
        switch genre {
        case .fondu: return Etape(genre: genre, couleur: couleur, intensite: intensite, duree: duree, courbe: courbe)
        case .pulsation: return Etape(genre: genre, couleur: couleur, duree: duree, creux: creux, pic: pic, onde: onde)
        case .maintien, .extinction: return Etape(genre: genre, duree: duree)
        case .animation: return Etape(genre: genre, duree: duree, effet: effet, vitesse: vitesse)
        case .retour: return Etape(genre: genre)
        }
    }
}
