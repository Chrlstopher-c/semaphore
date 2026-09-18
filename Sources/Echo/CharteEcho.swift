#if canImport(SwiftUI)
import Duplex
import EchoHub
import Saily
import SwiftUI
import Systeme
import Vigie

/// La charte du chrome — le seul jeton que le centre de contrôle ajoute au
/// socle. Le décor du chrome vient de `Systeme` (`Neutre`, `Voix`, `Grille`) ;
/// ici ne vit que l'accent pierre, quasi achromatique : la navigation s'efface,
/// la couleur appartient aux mondes.
enum TeinteEcho {
    /// Pierre — l'accent du chrome. Assez proche des encres pour ne jamais
    /// concurrencer l'accent d'un monde.
    static let accent = Color(socle: 0xAEA69A)
    /// L'accent enfoncé, dérivé — jamais saisi à la main.
    static let accentPresse = Color(socle: 0xAEA69A).mele(vers: .black, part: 0.2)

    /// L'accent du monde pointé, lu à la source dans sa charte — pour teinter
    /// subtilement la sélection, jamais pour peindre le chrome au repos.
    static func accent(du monde: Monde) -> Color {
        switch monde {
        case .quart: return Vigie.Teinte.accent
        case .machine: return EchoHub.Teinte.accent
        case .saily: return Saily.Teinte.accent
        case .duplex: return Duplex.Teinte.accent
        }
    }
}
#endif
