// Le vocabulaire d'état hérité de la première charte, conservé parce que
// `ConduiteApresConflit` (intouchable) le porte dans son contrat. Les écrans
// de la charte « Quart de nuit » le traduisent en `Ton` — il ne porte plus
// aucune couleur lui-même.
#if canImport(SwiftUI)
public enum EtatSemantique: Sendable {
    /// Nominal : lien établi, geste abouti.
    case sain
    /// Attention sans urgence : attente légitime, réessai possible.
    case vigilance
    /// Rupture : le geste échouerait à l'identique, ou une panne réelle.
    case danger
    /// Réclame une décision humaine.
    case accent
    /// Purement informatif.
    case neutre
}
#endif
