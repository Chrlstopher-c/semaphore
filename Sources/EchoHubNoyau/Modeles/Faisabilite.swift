import Foundation

/// Une variante tient-elle sur la machine ? Poids annoncés par le Hub contre mémoire libre mesurée
/// (`faisabilite/evaluation.ts` du web). Le cache KV et le contexte ne sont pas comptés : estimation, pas plan.
public enum Faisabilite: Sendable, Equatable {
    case tientVram, debordeRam, neTientPas, indeterminee

    public var libelle: String {
        switch self {
        case .tientVram: "tient en VRAM"
        case .debordeRam: "tient, couches en RAM"
        case .neTientPas: "ne tient pas"
        case .indeterminee: "indéterminable"
        }
    }

    public struct Budget: Sendable, Equatable {
        public let vramLibreOctets: Int
        public let ramDisponibleOctets: Int

        public init(vramLibreOctets: Int, ramDisponibleOctets: Int) {
            self.vramLibreOctets = vramLibreOctets
            self.ramDisponibleOctets = ramDisponibleOctets
        }

        /// `nil` sans GPU mesuré : rien ne peut être affirmé.
        public static func depuis(profil: ValeurJSON) -> Budget? {
            guard profil["a_gpu"]?.booleenOuNil == true,
                  let vram = profil.chemin("gpu_principal", "vram_libre_octets")?.entierOuNil else { return nil }
            return Budget(vramLibreOctets: vram, ramDisponibleOctets: profil.chemin("memoire", "disponible_octets")?.entierOuNil ?? 0)
        }
    }

    public static func evaluer(poidsOctets: Int?, budget: Budget?) -> Faisabilite {
        guard let budget, let poids = poidsOctets, poids > 0 else { return .indeterminee }
        if poids <= budget.vramLibreOctets { return .tientVram }
        return poids <= budget.vramLibreOctets + budget.ramDisponibleOctets ? .debordeRam : .neTientPas
    }
}
