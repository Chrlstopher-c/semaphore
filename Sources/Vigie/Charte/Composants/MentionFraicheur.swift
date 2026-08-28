// L'âge de la donnée, en tête de chaque écran — une information de premier
// rang, pas une mention de bas de page. Se réévalue toute seule : un « il y a
// 2 min » figé redevient un mensonge en trente secondes.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

public struct MentionFraicheur: View {
    private let releveA: Date?

    public init(_ releveA: Date?) {
        self.releveA = releveA
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { horloge in
            texte(maintenant: horloge.date)
        }
    }

    @ViewBuilder private func texte(maintenant: Date) -> some View {
        if let releveA {
            Text(Fraicheur.texte(depuis: releveA, maintenant: maintenant))
                .donneePetite()
                .foregroundStyle(teinte(maintenant: maintenant))
        } else {
            Text("aucun relevé")
                .donneePetite()
                .foregroundStyle(Teinte.encreTernie)
        }
    }

    /// Les seuils du noyau (`Fraicheur`) : frais = ternie (rien à signaler),
    /// vieillissant = ambre, périmé = rouge — une donnée d'hier prise pour
    /// l'instant présent est pire qu'un écran vide.
    private func teinte(maintenant: Date) -> Color {
        guard let releveA else { return Teinte.encreTernie }
        switch Fraicheur.degre(depuis: releveA, maintenant: maintenant) {
        case .fraiche: return Teinte.encreTernie
        case .vieillissante: return Teinte.vigilance
        case .perimee: return Teinte.danger
        }
    }
}

/// L'état de la LIAISON, lu dans l'environnement — jamais celui d'une machine.
/// Le régime « registre du Pi » se peint en ardoise avec la lune : c'est le
/// régime des nuits, pas une panne.
///
/// `☠` Ne jamais y remettre le nom d'une machine. « PC éteint » s'affichait ici
/// en permanence, y compris sur un fil hébergé par le VPS — voir `Liaison`.
public struct PastilleLiaison: View {
    @Environment(Liaison.self) private var liaison

    public init() {}

    public var body: some View {
        HStack(spacing: Trame.fin + 1) {
            marque
            Text(liaison.libelle)
                .donneePetite()
                .foregroundStyle(teinte)
        }
        .animation(Elan.pose, value: liaison.regime)
    }

    @ViewBuilder private var marque: some View {
        switch liaison.regime {
        case .nominal:
            PointVeille(ton: .sain)
        case .registre:
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 9))
                .foregroundStyle(Teinte.veille)
        case .perdue:
            Image(systemName: "bolt.slash.fill")
                .font(.system(size: 9))
                .foregroundStyle(Teinte.vigilance)
        case .sessionRequise:
            Image(systemName: "lock.fill")
                .font(.system(size: 9))
                .foregroundStyle(Teinte.accent)
        }
    }

    private var teinte: Color {
        switch liaison.regime {
        case .nominal: return Teinte.encreTernie
        case .registre: return Teinte.veille
        case .perdue: return Teinte.vigilance
        case .sessionRequise: return Teinte.accent
        }
    }
}
#endif
