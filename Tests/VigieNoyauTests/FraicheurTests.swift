import Foundation
import Testing
@testable import VigieNoyau

@Suite("Fraîcheur — l'âge d'une donnée en clair")
struct FraicheurTests {
    private let repere = Date(timeIntervalSince1970: 1_700_000_000)

    private func texte(ageEnSecondes: Double) -> String {
        Fraicheur.texte(depuis: repere, maintenant: repere.addingTimeInterval(ageEnSecondes))
    }

    @Test("les paliers de rédaction")
    func paliers() {
        #expect(texte(ageEnSecondes: 0) == "à l'instant")
        #expect(texte(ageEnSecondes: 9) == "à l'instant")
        #expect(texte(ageEnSecondes: 45) == "il y a 45 s")
        #expect(texte(ageEnSecondes: 90) == "il y a 1 min")
        #expect(texte(ageEnSecondes: 3 * 3600) == "il y a 3 h")
        #expect(texte(ageEnSecondes: 30 * 3600) == "hier")
        #expect(texte(ageEnSecondes: 4 * 86_400) == "il y a 4 j")
    }

    @Test("une horloge qui recule ne produit jamais d'âge négatif")
    func horlogeQuiRecule() {
        #expect(texte(ageEnSecondes: -120) == "à l'instant")
        #expect(Fraicheur.age(depuis: repere, maintenant: repere.addingTimeInterval(-500)) == 0)
    }

    @Test("les degrés suivent les seuils de la charte")
    func degres() {
        #expect(Fraicheur.degre(depuis: repere, maintenant: repere.addingTimeInterval(60)) == .fraiche)
        #expect(Fraicheur.degre(depuis: repere, maintenant: repere.addingTimeInterval(600)) == .vieillissante)
        #expect(Fraicheur.degre(depuis: repere, maintenant: repere.addingTimeInterval(7200)) == .perimee)
    }

    @Test("la mention dit que la donnée a été VUE, pas qu'elle a changé")
    func mention() {
        #expect(Fraicheur.mention(depuis: repere, maintenant: repere.addingTimeInterval(3600)) == "relevé il y a 1 h")
    }
}
