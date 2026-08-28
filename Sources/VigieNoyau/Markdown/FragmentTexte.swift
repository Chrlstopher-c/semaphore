import Foundation

/// Les styles qu'un fragment de texte porte simultanément.
///
/// `☠` Un jeu d'options et non un enum : `**du `code` gras**` existe, et le
/// front actuel le perd. Le modèle doit pouvoir dire « gras ET mono », sinon le
/// rendu tranche arbitrairement en faveur du dernier marqueur rencontré.
public struct StyleInline: OptionSet, Sendable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let gras = StyleInline(rawValue: 1 << 0)
    public static let italique = StyleInline(rawValue: 1 << 1)
    /// Code inline. `☠` Se rend SANS fond ni bordure (relevé prod le 01/08) :
    /// encadrer chaque terme technique dans un corps serif fabrique des pavés
    /// qui hachent la ligne. Seule la police change.
    public static let code = StyleInline(rawValue: 1 << 2)
    public static let barre = StyleInline(rawValue: 1 << 3)
}

/// Un morceau de texte homogène : même style, même destination.
///
/// L'unité de rendu du markdown inline. Une ligne de markdown en produit
/// plusieurs, que la vue recompose en un seul `Text` par concaténation.
public struct FragmentTexte: Sendable, Hashable {
    public let texte: String
    public let styles: StyleInline
    /// Cible d'un lien `[libellé](cible)`. `nil` = texte ordinaire.
    public let lien: String?

    public init(_ texte: String, styles: StyleInline = [], lien: String? = nil) {
        self.texte = texte
        self.styles = styles
        self.lien = lien
    }

    public var estVide: Bool { texte.isEmpty }
}

extension Array where Element == FragmentTexte {
    /// Le texte nu, sans balisage : sert aux résumés repliés, à la copie et aux
    /// libellés d'accessibilité.
    public var texteNu: String {
        map(\.texte).joined()
    }
}
