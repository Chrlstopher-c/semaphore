// Les couleurs de « La Besace ». Les neutres et les états viennent du socle
// `Systeme` — UNE seule vérité pour les trois mondes. Ce qui reste propre au
// monde : un seul accent, un turquoise vif.
//
// `☠` Aucune couleur nue dans un écran : tout passe par ces jetons, par `Ton`
// ou par l'`Ambiance`. Chaque jeton porte son emploi ; sans emploi écrit, il ne
// doit pas exister. C'est la règle qui empêche une charte de pourrir.
//
// `☠` L'accent turquoise `#2AD4C6` n'est NI la pervenche `#8A7AFF` d'EchoHub NI
// le bleu de Vigie : les trois mondes cohabitent dans un seul bundle, et deux
// accents voisins se liraient comme une incohérence, pas comme une identité.
#if canImport(SwiftUI)
import SwiftUI
import Systeme

public enum Teinte {

    // MARK: - Fonds — socle `Neutre`, identiques dans les trois mondes

    /// La page.
    public static let fond = Neutre.fond
    /// Cartes d'item, rangées, champs.
    public static let surface = Neutre.surface
    /// Ce qui est posé SUR une surface : composeur de capture, feuille.
    public static let surfaceHaute = Neutre.surfaceHaute

    // MARK: - Traits et lumière — socle `Neutre`

    public static let trait = Neutre.trait
    /// Haut du liseré directionnel — la lumière vient toujours du haut.
    public static let lumiereHaute = Neutre.lumiereHaute
    /// Bas du même liseré. C'est l'écart qui fait le volume ; sur fond sombre,
    /// une ombre ne se voit pas.
    public static let lumiereBasse = Neutre.lumiereBasse

    // MARK: - Encres — socle `Neutre`, une par rôle et pas une de plus

    /// Le texte d'une note, les titres.
    public static let encre = Neutre.encre
    /// Le secondaire : légendes, méta, tags au repos, horodatage.
    public static let encreDouce = Neutre.encreDouce
    /// L'éteint : placeholders, désactivé, glyphes d'état vide.
    public static let encreEteinte = Neutre.encreEteinte

    // MARK: - Accent — le SEUL jeton couleur propre au monde

    /// Turquoise — la seule teinte propre du monde. Elle dit deux choses et rien
    /// d'autre : « ceci est interactif » et « la synchro est vivante ».
    public static let accent = Color(socle: 0x2AD4C6)
    /// L'accent enfoncé. Dérivé, jamais saisi à la main : deux teintes cousines
    /// écrites séparément divergent à la première retouche.
    ///
    /// Le voile d'un accent (fond de pastille) n'a PAS de jeton ici : il
    /// s'obtient par `Ton.actif.voile`, l'unique porte des fonds voilés.
    public static let accentPresse = Color(socle: 0x2AD4C6).mele(vers: .black, part: 0.22)

    // MARK: - États — socle `Semantique`, identiques dans les trois mondes

    /// Item synchronisé, serveur joignable.
    public static let ok = Semantique.ok
    /// Récupérable : hors ligne, capture en attente de rejeu, téléversement lent.
    public static let alerte = Semantique.alerte
    /// Échec réel et geste destructif — supprimer un item. Le seul rouge.
    public static let panne = Semantique.panne
}
#endif
