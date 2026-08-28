import Foundation

/// Où se trouve un message parmi ses frères, et lequel afficher à côté.
///
/// `☠` Pure exprès. C'est de l'arithmétique sur un dictionnaire rendu par le
/// serveur, donc une RÈGLE — et une règle tombée dans une vue est une règle que
/// `swift test` ne voit jamais. Le seul projet à avoir un « ‹ 2 / 3 › » faux
/// d'un cran est celui qui l'a calculé dans un `body`.
///
/// `variantes` associe à chaque message du chemin actif la liste ORDONNÉE des
/// identifiants qui partagent son parent, lui compris
/// (`backend/chat/modeles.py`, `EtatBranche`).
public enum NavigationVariante {
    /// Le rang (à partir de 1) et le nombre de frères. `nil` quand le tour n'a
    /// qu'une version : un « 1 / 1 » n'apprend rien et occupe une rangée.
    public static func position(
        de identifiant: String, dans variantes: [String: [String]]
    ) -> (rang: Int, total: Int)? {
        guard let freres = variantes[identifiant], freres.count > 1,
              let rang = freres.firstIndex(of: identifiant) else { return nil }
        return (rang + 1, freres.count)
    }

    /// Le frère situé `decalage` crans plus loin. `nil` en bout de liste — la
    /// flèche est alors désactivée, jamais masquée.
    public static func voisin(
        de identifiant: String, decalage: Int, dans variantes: [String: [String]]
    ) -> String? {
        guard let freres = variantes[identifiant],
              let rang = freres.firstIndex(of: identifiant) else { return nil }
        let vise = rang + decalage
        guard freres.indices.contains(vise) else { return nil }
        return freres[vise]
    }
}
