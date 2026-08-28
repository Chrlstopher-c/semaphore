// Une mesure du pouls : la valeur en mono, l'étiquette à voix basse. La tuile
// ne s'allume que si elle réclame l'œil — une rangée entièrement colorée ne
// signale plus rien.
#if canImport(SwiftUI)
import SwiftUI

public struct TuileChiffre: View {
    private let etiquette: String
    private let valeur: String
    private let ton: Ton

    public init(_ etiquette: String, valeur: String, ton: Ton = .neutre) {
        self.etiquette = etiquette
        self.valeur = valeur
        self.ton = ton
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(valeur)
                .chiffre()
                .foregroundStyle(ton == .neutre ? Teinte.encre : ton.teinte)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(etiquette)
                .mention()
                .foregroundStyle(Teinte.encreTernie)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Trame.element)
        .padding(.vertical, Trame.serre + 2)
        .background(Teinte.surface, in: RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous)
                .strokeBorder(ton == .neutre ? Teinte.filet : ton.voile, lineWidth: Trame.trait)
        )
    }
}
#endif
