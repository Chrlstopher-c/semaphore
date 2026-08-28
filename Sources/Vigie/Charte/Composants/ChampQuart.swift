// Le champ de saisie de la charte : étiquette à voix basse, fond creusé,
// filet qui s'allume au focus.
#if canImport(SwiftUI)
import SwiftUI

public struct ChampQuart: View {
    private let etiquette: String?
    @Binding private var texte: String
    private let placebo: String
    private let aide: String?
    private let lignes: ClosedRange<Int>
    /// La fonte de la saisie — `Typo.donnee` pour une commande de terminal.
    private let fonte: Font

    @FocusState private var enFocus: Bool

    public init(
        _ etiquette: String? = nil,
        texte: Binding<String>,
        placebo: String = "",
        aide: String? = nil,
        lignes: ClosedRange<Int> = 1...1,
        fonte: Font = Typo.phrase
    ) {
        self.etiquette = etiquette
        _texte = texte
        self.placebo = placebo
        self.aide = aide
        self.lignes = lignes
        self.fonte = fonte
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Trame.fin + 1) {
            if let etiquette {
                Text(etiquette)
                    .insigne()
                    .foregroundStyle(Teinte.encreDouce)
            }
            champ
            if let aide {
                Text(aide)
                    .mention()
                    .foregroundStyle(Teinte.encreTernie)
            }
        }
    }

    private var champ: some View {
        TextField(placebo, text: $texte, axis: lignes.upperBound > 1 ? .vertical : .horizontal)
            .lineLimit(lignes)
            .focused($enFocus)
            .font(fonte)
            .foregroundStyle(Teinte.encre)
            .tint(Teinte.accent)
            .padding(.horizontal, Trame.element)
            .padding(.vertical, Trame.serre + 2)
            .background(Teinte.fondCreux, in: RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous)
                    .strokeBorder(enFocus ? Teinte.accent.opacity(0.6) : Teinte.filetAppuye, lineWidth: Trame.trait)
            )
            .animation(Elan.vif, value: enFocus)
    }
}
#endif
