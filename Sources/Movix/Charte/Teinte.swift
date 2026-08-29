// Les couleurs du monde Movix. Les neutres et les états viennent du socle
// `Systeme` — UNE seule vérité pour les mondes. Ce qui reste propre au monde :
// un seul accent.
//
// `☠` L'accent framboise `#E8477C` ne doit voisiner aucun autre accent du
// bundle : ni la pervenche `#8A7AFF` d'EchoHub, ni le turquoise `#2AD4C6` de
// Saily, ni le bleu de Vigie, ni le rouge de panne `#E05B49`. C'est une teinte
// chaude et vive, à part, qui dit « divertissement » sans se confondre avec un
// état d'erreur.
#if canImport(SwiftUI)
import SwiftUI
import Systeme

public enum Teinte {

    // MARK: - Fonds — socle `Neutre`

    public static let fond = Neutre.fond
    public static let surface = Neutre.surface
    public static let surfaceHaute = Neutre.surfaceHaute

    // MARK: - Traits — socle `Neutre`

    public static let trait = Neutre.trait

    // MARK: - Encres — socle `Neutre`

    public static let encre = Neutre.encre
    public static let encreDouce = Neutre.encreDouce
    public static let encreEteinte = Neutre.encreEteinte

    // MARK: - Accent — le SEUL jeton couleur propre au monde

    /// Framboise vif — « ceci est interactif », l'identité du monde.
    public static let accent = Color(socle: 0xE8477C)
    /// L'accent enfoncé, dérivé — jamais saisi à la main.
    public static let accentPresse = Color(socle: 0xE8477C).mele(vers: .black, part: 0.22)

    // MARK: - États — socle `Semantique`

    public static let ok = Semantique.ok
    public static let alerte = Semantique.alerte
    public static let panne = Semantique.panne
}
#endif
