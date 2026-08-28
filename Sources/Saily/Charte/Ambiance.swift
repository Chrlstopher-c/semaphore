// Le système parent/enfant de la charte.
//
// Une `Ambiance` descend l'arbre des vues par l'environnement SwiftUI : un
// conteneur la pose, tous ses descendants en héritent, et chaque TYPE d'enfant
// décide ce qu'il en fait. Une seule règle qui les gouverne : un enfant peut
// RESTREINDRE ce que son parent accorde, jamais l'élargir.
//
// `☠` Saily n'a PAS de « registre » comme EchoHub (reponse/note/machine) : ce
// monde n'affiche pas un modèle qui raisonne, il affiche des choses capturées.
// L'ambiance porte donc deux propriétés — la profondeur et le ton — et pas une
// de plus. Copier le registre d'EchoHub ici serait un jeton sans emploi, ce que
// la charte interdit.
#if canImport(SwiftUI)
import SwiftUI

/// La profondeur où l'on se trouve. Chaque conteneur qui se peint monte d'un
/// cran : une carte dans une carte se distingue sans qu'aucune vue n'ait à
/// savoir où elle est posée.
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

/// Ce dont un enfant hérite de son parent.
public struct Ambiance: Sendable, Equatable {
    public var palier: Palier
    public var ton: Ton

    public init(palier: Palier = .page, ton: Ton = .neutre) {
        self.palier = palier
        self.ton = ton
    }

    /// Descend d'un palier en gardant le ton. Les conteneurs appellent ceci.
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

    /// Surcharge le seul ton, en gardant le palier du parent.
    public func ton(_ valeur: Ton) -> some View {
        modifier(SurchargeTon(valeur: valeur))
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
#endif
