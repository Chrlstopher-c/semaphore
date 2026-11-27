// Les couleurs du monde EchoHub : celles de l'EchoHub web (`frontend/src/shared/design/tokens.css`),
// en sombre et en clair. Exception assumée au socle commun `Systeme` (décision de Chris, 27/11/2026) :
// ce monde est l'EchoHub de la tour dans la poche, il en porte la charte, pas celle des autres mondes.
//
// `☠` Aucune couleur nue dans un écran : tout passe par ces jetons, par `Ton`
// ou par l'`Ambiance`. Chaque jeton porte son emploi ; sans emploi écrit, il ne
// doit pas exister.
#if canImport(SwiftUI)
import SwiftUI
import Systeme

public enum Teinte {

    // MARK: - Fonds — `--bg`, `--surface`, `--surface-2` du web

    /// La page.
    public static let fond = paire(0x0A0A0A, 0xFFFFFF)
    /// Bulle de Chris, cartes, rangées de liste.
    public static let surface = paire(0x111111, 0xFAFAFA)
    /// Ce qui est posé SUR une surface : composeur, bloc de raisonnement replié.
    public static let surfaceHaute = paire(0x1A1A1A, 0xF2F2F2)

    // MARK: - Filets — `--border`, `--border-strong` : des traits fins, l'ombre seulement pour flotter

    public static let trait = paire(0x1F1F1F, 0xEBEBEB)
    /// Haut du liseré directionnel.
    public static let lumiereHaute = paire(0x2E2E2E, 0xDEDEDE)
    /// Bas du même liseré.
    public static let lumiereBasse = paire(0x1F1F1F, 0xEBEBEB)

    // MARK: - Encres — `--text`, `--text-2`, `--text-3`

    /// Le registre `reponse` : ce que le modèle dit à Chris. Et les titres.
    public static let encre = paire(0xEDEDED, 0x171717)
    /// Le registre `note` : le cheminement du modèle, les métadonnées.
    public static let encreDouce = paire(0xB4B4B4, 0x4D4D4D)
    /// Le registre `machine` : sorties d'outil brutes. Et le désactivé.
    public static let encreEteinte = paire(0x8F8F8F, 0x6B6B6B)

    // MARK: - Accent — `--accent`

    /// Le même bleu que l'EchoHub web : on passe du navigateur au téléphone sur le même produit.
    /// Il dit deux choses et rien d'autre : « ceci est interactif » et « ça génère en ce moment ».
    public static let accent = paire(0x52A8FF, 0x006BDE)
    /// L'accent enfoncé (`--accent-hover` du web, l'inverse en clair : plus sombre).
    public static let accentPresse = paire(0x7CBCFF, 0x0058B8)

    // MARK: - États — `--ok`, `--caution`, `--critical`

    /// Modèle prêt, relais joignable, outil abouti.
    public static let ok = paire(0x45DC7C, 0x0F7A3D)
    /// Récupérable : plan dégradé, génération interrompue, réponse coupée.
    public static let alerte = paire(0xF5A623, 0xA35200)
    /// Échec réel et geste destructif — supprimer une conversation. Le seul rouge de l'app.
    public static let panne = paire(0xFF6166, 0xC4202A)

    /// Une teinte par thème, résolue par iOS au moment du rendu.
    private static func paire(_ sombre: UInt32, _ clair: UInt32) -> Color {
        #if canImport(UIKit)
        Color(UIColor { trait in
            UIColor(Color(socle: trait.userInterfaceStyle == .light ? clair : sombre))
        })
        #else
        Color(socle: sombre)
        #endif
    }
}
#endif
