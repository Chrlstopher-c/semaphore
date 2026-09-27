import Foundation
@testable import TamisNoyau

enum Aides {
    static let calendrier: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    static func date(_ annee: Int, _ mois: Int = 1, _ jour: Int = 1, _ minute: Int = 0) -> Date {
        calendrier.date(from: DateComponents(year: annee, month: mois, day: jour, minute: minute))!
    }

    static func cliche(
        _ id: String, _ date: Date?, _ media: Media = .photo, traits: Set<Trait> = [],
        poids: Int64? = 1_000, pixels: Int = 100, duree: Double = 0, rafale: String? = nil
    ) -> Cliche {
        Cliche(id: id, date: date, media: media, traits: traits, largeur: pixels, hauteur: 1,
               duree: duree, rafale: rafale, poids: poids)
    }
}
