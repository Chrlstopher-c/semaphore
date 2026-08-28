// Le système parent/enfant de la charte.
//
// Une `Ambiance` descend l'arbre des vues par l'environnement SwiftUI : un
// conteneur la pose, tous ses descendants en héritent, et chaque TYPE d'enfant
// décide ce qu'il en fait. Trois propriétés héritées, une seule règle qui les
// gouverne toutes : un enfant peut RESTREINDRE ce que son parent accorde,
// jamais l'élargir.
#if canImport(SwiftUI)
import SwiftUI

/// La profondeur où l'on se trouve. Chaque conteneur qui se peint monte d'un
/// cran et republie le cran atteint : une carte dans une carte se distingue
/// sans qu'aucune vue n'ait à savoir où elle est posée.
public enum Palier: Int, Sendable, Comparable, CaseIterable {
    case page = 0, surface = 1, releve = 2

    public static func < (gauche: Palier, droite: Palier) -> Bool {
        gauche.rawValue < droite.rawValue
    }

    public var fond: Color {
        switch self {
        case .page: return Teinte.fond
        case .surface: return Teinte.surface
        case .releve: return Teinte.surfaceHaute
        }
    }

    public var suivant: Palier {
        Palier(rawValue: min(rawValue + 1, Palier.releve.rawValue)) ?? .releve
    }
}

/// **Jusqu'où un texte a le droit de se faire remarquer.**
///
/// C'est la question centrale d'une app qui affiche un modèle de raisonnement,
/// et elle se tranche par écrit, sinon elle se tranche par accident : un modèle
/// qui « pense » écrit souvent plus pour lui que pour Chris, et son `<think>`
/// dépasse fréquemment sa réponse en longueur. Il ne doit pas disparaître —
/// c'est ce qu'on vient lire quand une réponse surprend — mais il ne doit
/// jamais se disputer l'œil avec elle.
///
/// Les trois valeurs sont ORDONNÉES du plus adressé au plus brut, et c'est cet
/// ordre qui porte la règle : `restreint(par:)` prend le MAXIMUM de rusticité.
public enum Registre: Int, Sendable, Comparable, CaseIterable {
    /// Ce que le modèle dit à Chris. Le seul texte de l'app en encre pleine.
    case reponse = 0
    /// Son cheminement : `<think>`, commentaires entre deux appels d'outil.
    case note = 1
    /// Ce qu'un outil a reçu et rendu : JSON, chemins, sorties brutes.
    case machine = 2

    public static func < (gauche: Registre, droite: Registre) -> Bool {
        gauche.rawValue < droite.rawValue
    }

    /// `☠` Un enfant peut DESCENDRE de registre, jamais remonter. Un bloc de
    /// raisonnement pose `note` ; rien à l'intérieur ne peut revenir en
    /// `reponse`, même par erreur d'appelant — c'est le maximum qui l'impose,
    /// pas la politesse de la vue.
    public func restreint(par plancher: Registre) -> Registre {
        Registre(rawValue: max(rawValue, plancher.rawValue)) ?? .machine
    }

    public var encre: Color {
        switch self {
        case .reponse: return Teinte.encre
        case .note: return Teinte.encreDouce
        case .machine: return Teinte.encreEteinte
        }
    }

    public var police: Font {
        switch self {
        case .reponse: return Typo.corps
        case .note: return Typo.pensee
        case .machine: return Typo.brut
        }
    }

    /// La respiration du texte descend avec lui : une page se lit, une note se
    /// scanne, un dump se compacte. Valeurs et raisons dans `Typo`.
    public var interligne: CGFloat {
        switch self {
        case .reponse: return Typo.interligneReponse
        case .note: return Typo.interligneNote
        case .machine: return Typo.interligneMachine
        }
    }
}

/// Ce dont un enfant hérite de son parent.
public struct Ambiance: Sendable, Equatable {
    public var palier: Palier
    public var ton: Ton
    public var registre: Registre

    public init(palier: Palier = .page, ton: Ton = .neutre, registre: Registre = .reponse) {
        self.palier = palier
        self.ton = ton
        self.registre = registre
    }

    /// Descend d'un palier en gardant le reste. Les conteneurs appellent ceci,
    /// jamais l'inverse.
    public func montee() -> Ambiance {
        var suivante = self
        suivante.palier = palier.suivant
        return suivante
    }
}

private struct CleAmbiance: EnvironmentKey {
    static let defaultValue = Ambiance()
}

extension EnvironmentValues {
    public var ambiance: Ambiance {
        get { self[CleAmbiance.self] }
        set { self[CleAmbiance.self] = newValue }
    }
}

extension View {
    /// Pose l'ambiance courante pour toute la sous-arborescence.
    public func ambiance(_ valeur: Ambiance) -> some View {
        environment(\.ambiance, valeur)
    }

    /// Surcharge le seul ton, en gardant palier et registre du parent.
    public func ton(_ valeur: Ton) -> some View {
        modifier(SurchargeTon(valeur: valeur))
    }

    /// Descend le registre sur cette branche. Ne peut que descendre : c'est
    /// `Registre.restreint(par:)` qui l'impose.
    public func registre(_ plancher: Registre) -> some View {
        modifier(SurchargeRegistre(plancher: plancher))
    }

    /// Peint un texte selon le registre hérité — encre, police ET interligne
    /// ensemble. Le glissement de registre est la signature de l'app : les
    /// trois doivent changer d'un coup, jamais l'un sans les autres.
    public func selonRegistre() -> some View {
        modifier(PeintureRegistre())
    }
}

private struct SurchargeTon: ViewModifier {
    @Environment(\.ambiance) private var heritee
    let valeur: Ton

    func body(content: Content) -> some View {
        var revue = heritee
        revue.ton = valeur
        return content.environment(\.ambiance, revue)
    }
}

private struct SurchargeRegistre: ViewModifier {
    @Environment(\.ambiance) private var heritee
    let plancher: Registre

    func body(content: Content) -> some View {
        var revue = heritee
        revue.registre = heritee.registre.restreint(par: plancher)
        return content.environment(\.ambiance, revue)
    }
}

private struct PeintureRegistre: ViewModifier {
    @Environment(\.ambiance) private var ambiance

    func body(content: Content) -> some View {
        content
            .font(ambiance.registre.police)
            .foregroundStyle(ambiance.registre.encre)
            .lineSpacing(ambiance.registre.interligne)
    }
}
#endif
