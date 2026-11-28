// Les choix de Chris, gardés d'un lancement à l'autre.
#if canImport(UIKit)
import Foundation
import IrisNoyau

struct Reglages: Codable, Equatable {
    var objectif: Objectif = .arriere
    var qualite: Qualite = .hd720
    var cadence: Cadence = .i30
    var cadrage: Cadrage = .adapter

    init() {}

    /// Les réglages d'avant la cadence se relisent : un champ absent garde sa valeur par défaut.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        objectif = try c.decodeIfPresent(Objectif.self, forKey: .objectif) ?? .arriere
        qualite = try c.decodeIfPresent(Qualite.self, forKey: .qualite) ?? .hd720
        cadence = try c.decodeIfPresent(Cadence.self, forKey: .cadence) ?? .i30
        cadrage = try c.decodeIfPresent(Cadrage.self, forKey: .cadrage) ?? .adapter
    }

    private static let cle = "iris.reglages"

    static func charger() -> Reglages {
        guard let donnees = UserDefaults.standard.data(forKey: cle),
              let lus = try? JSONDecoder().decode(Reglages.self, from: donnees) else { return Reglages() }
        return lus
    }

    func enregistrer() {
        guard let donnees = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(donnees, forKey: Self.cle)
    }
}
#endif
