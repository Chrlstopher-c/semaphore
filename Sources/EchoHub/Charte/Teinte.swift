// Les couleurs du « Fil ». Les neutres et les sémantiques viennent du socle
// commun `Systeme` — le graphite chaud partagé par les trois mondes. Le SEUL
// jeton couleur propre à EchoHub est l'accent pervenche.
//
// `☠` Aucune couleur nue dans un écran : tout passe par ces jetons, par `Ton`
// ou par l'`Ambiance`. Chaque jeton porte son emploi ; sans emploi écrit, il ne
// doit pas exister. C'est la règle qui empêche une charte de pourrir.
#if canImport(SwiftUI)
import SwiftUI
import Systeme

public enum Teinte {

    // MARK: - Fonds — neutres du socle

    /// La page.
    public static let fond = Neutre.fond
    /// Bulle de Chris, cartes, rangées de liste.
    public static let surface = Neutre.surface
    /// Ce qui est posé SUR une surface : composeur, bloc de raisonnement replié.
    public static let surfaceHaute = Neutre.surfaceHaute

    // MARK: - Traits et lumière

    public static let trait = Neutre.trait
    /// Haut du liseré directionnel — la lumière vient toujours du haut.
    public static let lumiereHaute = Neutre.lumiereHaute
    /// Bas du même liseré. C'est l'écart entre les deux qui fait le volume ;
    /// sur fond sombre, une ombre ne se voit pas.
    public static let lumiereBasse = Neutre.lumiereBasse

    // MARK: - Encres — une par registre, et pas une de plus

    /// Le registre `reponse` : ce que le modèle dit à Chris. Et les titres.
    public static let encre = Neutre.encre
    /// Le registre `note` : le cheminement du modèle, les métadonnées.
    public static let encreDouce = Neutre.encreDouce
    /// Le registre `machine` : sorties d'outil brutes. Et le désactivé.
    public static let encreEteinte = Neutre.encreEteinte

    // MARK: - Accent — le seul jeton couleur propre à EchoHub

    /// Pervenche — la seule teinte propre de l'app, et la MÊME que celle du
    /// bureau (`--accent`, `#8A7AFF`). Deux pervenches différentes se
    /// remarqueraient en passant du navigateur au téléphone, sur le même
    /// produit et souvent sur la même conversation.
    ///
    /// Elle dit deux choses et rien d'autre : « ceci est interactif » et « ça
    /// génère en ce moment ».
    public static let accent = Color(socle: 0x8A7AFF)
    /// L'accent enfoncé. Dérivé, jamais saisi à la main : deux teintes cousines
    /// écrites séparément divergent à la première retouche.
    ///
    /// Le voile d'un accent (fond de pastille) n'a PAS de jeton ici : il
    /// s'obtient par `Ton.actif.voile`, l'unique porte des fonds voilés. Un
    /// second chemin vers la même valeur finirait par diverger d'elle.
    public static let accentPresse = Color(socle: 0x8A7AFF).mix(with: .black, by: 0.25)

    // MARK: - États — sémantiques du socle

    /// Modèle prêt, relais joignable, outil abouti.
    public static let ok = Semantique.ok
    /// Récupérable : plan dégradé, génération interrompue, réponse coupée.
    public static let alerte = Semantique.alerte
    /// Échec réel et geste destructif — supprimer une conversation. Le seul
    /// rouge de l'app.
    public static let panne = Semantique.panne
}
#endif
