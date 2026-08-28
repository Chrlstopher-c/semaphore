import Foundation

/// L'encodage et le décodage JSON du contrat Saily, décidés en UN seul endroit.
///
/// `☠` Contrairement au contrat EchoHub, celui-ci N'A AUCUNE conversion :
///
/// 1. **Pas de `snake_case`** — les clés de `contracts.ts` sont déjà en
///    `camelCase` (`createdAt`, `updatedAt`, `deletedAt`) et correspondent une à
///    une aux propriétés Swift. Une stratégie `.convertFromSnakeCase` les
///    casserait toutes.
/// 2. **Pas de stratégie de date** — les horodatages sont des NOMBRES
///    (millisecondes, `Date.now()` côté Bun), décodés en `Int`. Aucun
///    `DateDecodingStrategy` n'entre en jeu, et le champ de mines des fractions
///    de seconde ISO n'existe pas ici.
///
/// Deux encodeurs/décodeurs neutres, donc, mais nommés : le jour où le contrat
/// bougera, c'est le seul endroit à toucher.
public enum CodageJSON {
    public static func decodeur() -> JSONDecoder { JSONDecoder() }
    public static func encodeur() -> JSONEncoder { JSONEncoder() }
}
