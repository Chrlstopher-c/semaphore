// L'en-tête d'écran : titre serif, liaison et fraîcheur sur la ligne du
// dessous, accessoires à droite. La barre système est masquée par la coquille ;
// les écrans poussés portent leur chevron de retour ici.
#if canImport(SwiftUI)
import SwiftUI

public struct EnTeteEcran<Accessoire: View>: View {
    @Environment(\.dismiss) private var congedier

    private let titre: String
    private let releveA: Date?
    private let retour: Bool
    private let accessoire: Accessoire

    public init(
        _ titre: String,
        releveA: Date? = nil,
        retour: Bool = false,
        @ViewBuilder accessoire: () -> Accessoire
    ) {
        self.titre = titre
        self.releveA = releveA
        self.retour = retour
        self.accessoire = accessoire()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Trame.serre) {
                if retour { chevron }
                Text(titre)
                    .grandTitre()
                    .foregroundStyle(Teinte.encre)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
                accessoire
            }
            HStack(spacing: Trame.serre) {
                PastilleLiaison()
                if releveA != nil {
                    Text("·").mention().foregroundStyle(Teinte.encreTernie)
                    MentionFraicheur(releveA)
                }
            }
            .padding(.leading, retour ? Trame.cible : 0)
        }
        .padding(.horizontal, Trame.ecran)
        .padding(.top, Trame.serre)
        .padding(.bottom, Trame.element)
    }

    private var chevron: some View {
        Button {
            congedier()
        } label: {
            Image(systemName: "chevron.left")
        }
        .buttonStyle(.allureIcone)
        .foregroundStyle(Teinte.encre)
        // La cible fait 44 pt mais le glyphe se colle à la marge.
        .padding(.leading, -Trame.element)
        .accessibilityLabel("Retour")
    }
}

extension EnTeteEcran where Accessoire == EmptyView {
    public init(_ titre: String, releveA: Date? = nil, retour: Bool = false) {
        self.init(titre, releveA: releveA, retour: retour) { EmptyView() }
    }
}
#endif
