// Les choix de Chris, gardés d'un lancement à l'autre.
#if canImport(UIKit)
import Foundation
import IrisNoyau

struct Reglages: Codable, Equatable {
    var objectif: Objectif = .arriere
    var qualite: Qualite = .hd720
    var cadrage: Cadrage = .adapter

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
