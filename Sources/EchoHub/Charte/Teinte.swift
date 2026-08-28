// Les couleurs du « Fil ». Sombre permanent, neutres légèrement froids, une
// seule teinte d'accent — la même pervenche que l'interface de bureau.
//
// `☠` Aucune couleur nue dans un écran : tout passe par ces jetons, par `Ton`
// ou par l'`Ambiance`. Chaque jeton porte son emploi ; sans emploi écrit, il ne
// doit pas exister. C'est la règle qui empêche une charte de pourrir.
#if canImport(SwiftUI)
import SwiftUI

public enum Teinte {

    // MARK: - Fonds

    /// La page. Plus sombre que le `#0E0E11` du bureau — mais pas noir pur :
    /// le noir vrai laisse une traînée au défilement sur cet OLED, et un fil de
    /// conversation défile en permanence.
    public static let fond = Color(echo: 0x0B0B0E)
    /// Bulle de Chris, cartes, rangées de liste.
    public static let surface = Color(echo: 0x16161A)
    /// Ce qui est posé SUR une surface : composeur, bloc de raisonnement replié.
    public static let surfaceHaute = Color(echo: 0x1D1D23)

    // MARK: - Traits et lumière

    public static let trait = Color.white.opacity(0.10)
    /// Haut du liseré directionnel — la lumière vient toujours du haut.
    public static let lumiereHaute = Color.white.opacity(0.14)
    /// Bas du même liseré. C'est l'écart entre les deux qui fait le volume ;
    /// sur fond sombre, une ombre ne se voit pas.
    public static let lumiereBasse = Color.white.opacity(0.05)

    // MARK: - Encres — une par registre, et pas une de plus

    /// Le registre `reponse` : ce que le modèle dit à Chris. Et les titres.
    /// Valeur du bureau (`--text`), à la lettre.
    public static let encre = Color(echo: 0xECECF1)
    /// Le registre `note` : le cheminement du modèle, les métadonnées.
    public static let encreDouce = Color(echo: 0x9494A6)
    /// Le registre `machine` : sorties d'outil brutes. Et le désactivé.
    public static let encreEteinte = Color(echo: 0x5C5C6B)

    // MARK: - Accent

    /// Pervenche — la seule teinte propre de l'app, et la MÊME que celle du
    /// bureau (`--accent`, `#8A7AFF`). Deux pervenches différentes se
    /// remarqueraient en passant du navigateur au téléphone, sur le même
    /// produit et souvent sur la même conversation.
    ///
    /// Elle dit deux choses et rien d'autre : « ceci est interactif » et « ça
    /// génère en ce moment ».
    public static let accent = Color(echo: 0x8A7AFF)
    /// L'accent enfoncé. Dérivé, jamais saisi à la main : deux teintes cousines
    /// écrites séparément divergent à la première retouche.
    ///
    /// Le voile d'un accent (fond de pastille) n'a PAS de jeton ici : il
    /// s'obtient par `Ton.actif.voile`, l'unique porte des fonds voilés. Un
    /// second chemin vers la même valeur finirait par diverger d'elle.
    public static let accentPresse = Color(echo: 0x8A7AFF).mix(with: .black, by: 0.25)

    // MARK: - États

    /// Modèle prêt, relais joignable, outil abouti.
    public static let ok = Color(echo: 0x4CC38A)
    /// Récupérable : plan dégradé, génération interrompue, réponse coupée.
    public static let alerte = Color(echo: 0xE5B454)
    /// Échec réel et geste destructif — supprimer une conversation. Le seul
    /// rouge de l'app.
    public static let panne = Color(echo: 0xE5644E)
}

extension Color {
    /// `Color(echo: 0x8A7AFF)` — sRGB, opaque.
    init(echo hexa: UInt32) {
        self.init(
            .sRGB,
            red: Double((hexa >> 16) & 0xFF) / 255,
            green: Double((hexa >> 8) & 0xFF) / 255,
            blue: Double(hexa & 0xFF) / 255,
            opacity: 1
        )
    }
}
#endif
