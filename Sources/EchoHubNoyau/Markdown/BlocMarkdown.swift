import Foundation

/// Les formes de l'arbre Markdown — le contrat entre l'analyse et le rendu.
///
/// `☠` Rien ici n'est du balisage : uniquement des chaînes brutes que SwiftUI
/// composera en `Text`. C'est la raison d'être d'un analyseur maison plutôt que
/// d'`AttributedString(markdown:)`, qui ne connaît PAS les blocs clôturés par
/// ` ``` ` — et abîmerait donc exactement le cas qui compte : une réponse
/// contenant du code.
public enum SegmentInline: Sendable, Equatable {
    case texte(String)
    case fort(String)
    case emphase(String)
    case code(String)
    case lien(texte: String, cible: String)

    /// Le texte affiché, quelle que soit la forme. Sert au bouton copier et à
    /// l'accessibilité.
    public var brut: String {
        switch self {
        case .texte(let valeur), .fort(let valeur), .emphase(let valeur), .code(let valeur):
            return valeur
        case .lien(let valeur, _):
            return valeur
        }
    }
}

/// Six niveaux : les modèles descendent couramment à `####` pour détailler un
/// sous-point, et un titre non reconnu réapparaîtrait tel quel à l'écran.
public struct ItemListe: Sendable, Equatable {
    public var contenu: [SegmentInline]
    /// `nil` plutôt qu'une liste vide : « pas de sous-liste » et « sous-liste
    /// sans item » sont deux états, et seul le premier se rend sans imbrication.
    public var sousListe: ListeMarkdown?
}

public struct ListeMarkdown: Sendable, Equatable {
    public var ordonnee: Bool
    public var items: [ItemListe]
}

/// L'alignement d'une colonne, lu dans ses délimiteurs (`:---`, `---:`,
/// `:---:`). Le défaut est `gauche` : c'est ce que dit un `---` nu.
public enum Alignement: Sendable, Equatable {
    case gauche, centre, droite
}

/// Un tableau à barres verticales. Les rangées sont normalisées à la largeur
/// des en-têtes : une cellule manquante vaut vide, elle ne décale pas les
/// colonnes. Le corps peut être VIDE — c'est l'état normal pendant le
/// streaming, juste après l'arrivée de la ligne de délimiteurs.
public struct TableauMarkdown: Sendable, Equatable {
    public var entetes: [[SegmentInline]]
    public var alignements: [Alignement]
    public var lignes: [[[SegmentInline]]]

    public var colonnes: Int { entetes.count }
}

public enum BlocMarkdown: Sendable, Equatable {
    case titre(niveau: Int, contenu: [SegmentInline])
    case paragraphe([SegmentInline])
    /// `complet` vaut `false` tant que la clôture n'est pas arrivée. Le texte
    /// déjà reçu s'affiche quand même : rien ne disparaît de l'écran parce que
    /// sa construction n'est pas terminée — et pendant une génération, le
    /// dernier bloc est TOUJOURS dans cet état.
    case code(langage: String, texte: String, complet: Bool)
    case liste(ListeMarkdown)
    case citation([SegmentInline])
    case tableau(TableauMarkdown)
    case separateur
}

/// Un bloc et sa POSITION.
///
/// `☠` L'identité vient du rang, pas du contenu : deux blocs identiques
/// existent couramment dans une réponse — deux séparateurs, deux paragraphes
/// « Oui. ». Une `ForEach` identifiée par le contenu en perdrait un, et le
/// symptôme serait une ligne manquante au milieu d'un texte, sans erreur.
public struct BlocIndexe: Sendable, Equatable, Identifiable {
    public let id: Int
    public let bloc: BlocMarkdown

    public init(id: Int, bloc: BlocMarkdown) {
        self.id = id
        self.bloc = bloc
    }
}
