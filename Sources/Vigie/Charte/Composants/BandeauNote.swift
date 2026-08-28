// Le message posé en place : un refus métier, une donnée datée, un canal qui
// tient. Voile du ton, texte lisible, jamais un toast pour ce qui doit rester
// sous les yeux.
#if canImport(SwiftUI)
import SwiftUI

public struct BandeauNote: View {
    private let texte: String
    private let ton: Ton
    private let symbole: String?

    public init(_ texte: String, ton: Ton, symbole: String? = nil) {
        self.texte = texte
        self.ton = ton
        self.symbole = symbole
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Trame.serre) {
            Image(systemName: symbole ?? symboleParDefaut)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ton.teinte)
            Text(texte)
                .note()
                .foregroundStyle(Teinte.encre)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Trame.element)
        .background(ton.voile, in: RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous))
    }

    /// Symboles anciens (iOS 13-14) : un symbole absent se rend en carré vide,
    /// sans erreur ni avertissement.
    private var symboleParDefaut: String {
        switch ton {
        case .danger: return "exclamationmark.triangle.fill"
        case .vigilance: return "clock.fill"
        case .sain: return "checkmark.circle.fill"
        case .veille: return "moon.zzz.fill"
        case .attention: return "hand.raised.fill"
        case .neutre: return "info.circle.fill"
        }
    }
}
#endif
