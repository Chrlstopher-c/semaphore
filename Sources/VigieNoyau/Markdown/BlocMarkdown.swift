import Foundation

/// Alignement déclaré par la ligne de séparation d'un tableau (`|:---:|---:|`).
///
/// Le rendu web l'ignore ; on le garde parce qu'un tableau de mesures aligné à
/// droite se lit d'un coup d'œil, et que c'est justement la forme sous laquelle
/// les leads rendent leurs chiffres.
public enum AlignementColonne: Sendable, Hashable {
    case gauche
    case centre
    case droite
}

/// Une entrée de liste, à plat, avec sa profondeur.
///
/// Aplati plutôt qu'imbriqué : SwiftUI rend une liste indentée avec un simple
/// retrait, et une structure récursive coûterait une vue par niveau pour un
/// résultat visuellement identique.
public struct EntreeListe: Sendable, Hashable {
    /// 0 = premier niveau. Un cran par tranche de deux espaces d'indentation.
    public let niveau: Int
    /// La puce à écrire : « • » ou « 3. ». Calculée à l'analyse, pas au rendu.
    public let puce: String
    /// Case à cocher d'une liste de tâches. `nil` = entrée ordinaire.
    public let cochee: Bool?
    public let contenu: [FragmentTexte]

    public init(niveau: Int, puce: String, cochee: Bool? = nil, contenu: [FragmentTexte]) {
        self.niveau = niveau
        self.puce = puce
        self.cochee = cochee
        self.contenu = contenu
    }
}

/// Un tableau markdown, entête et corps séparés.
public struct TableauMarkdown: Sendable, Hashable {
    public let entete: [[FragmentTexte]]
    public let alignements: [AlignementColonne]
    public let lignes: [[[FragmentTexte]]]

    public init(
        entete: [[FragmentTexte]],
        alignements: [AlignementColonne],
        lignes: [[[FragmentTexte]]]
    ) {
        self.entete = entete
        self.alignements = alignements
        self.lignes = lignes
    }

    public var colonnes: Int { max(entete.count, lignes.map(\.count).max() ?? 0) }

    public func alignement(_ colonne: Int) -> AlignementColonne {
        colonne < alignements.count ? alignements[colonne] : .gauche
    }
}

/// Un bloc de markdown, tel que la vue le rendra.
///
/// `☠` C'est ce niveau qui manque à `AttributedString(markdown:)` : il rend
/// `## 7. Ouvert` en texte plat et un tableau de mesures en lignes de barres
/// verticales. Or c'est la forme sous laquelle un lead rend son travail — la
/// seule chose qu'on vient lire à la fin d'une mission serait donc la moins
/// lisible de l'écran.
public enum BlocMarkdown: Sendable, Hashable {
    /// Niveau 1 à 6, conservé tel quel : la vue décide de la taille.
    case titre(niveau: Int, contenu: [FragmentTexte])
    case paragraphe([FragmentTexte])
    case liste(entrees: [EntreeListe])
    /// Bloc de code clôturé. `langage` vient de l'info-string de la clôture.
    /// `ouvert` = la clôture finale n'est pas encore arrivée : c'est le cas
    /// NORMAL pendant le streaming, pas une erreur de syntaxe.
    case code(langage: String?, texte: String, ouvert: Bool)
    case tableau(TableauMarkdown)
    case citation([FragmentTexte])
    case filet

    /// Le texte nu du bloc — copie, résumé replié, accessibilité.
    public var texteNu: String {
        switch self {
        case .titre(_, let contenu): return contenu.texteNu
        case .paragraphe(let contenu): return contenu.texteNu
        case .citation(let contenu): return contenu.texteNu
        case .liste(let entrees): return entrees.map { $0.contenu.texteNu }.joined(separator: "\n")
        case .code(_, let texte, _): return texte
        case .tableau(let table):
            let corps = table.lignes.map { ligne in ligne.map(\.texteNu).joined(separator: " · ") }
            return ([table.entete.map(\.texteNu).joined(separator: " · ")] + corps).joined(separator: "\n")
        case .filet: return ""
        }
    }
}

/// Un bloc et son rang, pour que `ForEach` ait une identité stable sans forcer
/// `BlocMarkdown` à porter un identifiant qui n'a de sens qu'à l'affichage.
public struct BlocRange: Sendable, Hashable, Identifiable {
    public let id: Int
    public let bloc: BlocMarkdown

    public init(id: Int, bloc: BlocMarkdown) {
        self.id = id
        self.bloc = bloc
    }
}
