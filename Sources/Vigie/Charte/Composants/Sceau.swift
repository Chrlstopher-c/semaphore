// Sceau, point de veille, puce de donnée — les trois marques d'état de la
// charte. Petites, denses, toujours passées par `Ton`.
#if canImport(SwiftUI)
import SwiftUI

/// Capsule d'état : « en pause », « écriture », « 3 ». Voile + encre du ton.
public struct Sceau: View {
    private let texte: String
    private let ton: Ton

    public init(_ texte: String, ton: Ton) {
        self.texte = texte
        self.ton = ton
    }

    public var body: some View {
        Text(texte)
            .insigne()
            .foregroundStyle(ton.teinte)
            .padding(.horizontal, Trame.serre)
            .padding(.vertical, 3)
            .background(ton.voile, in: Capsule())
            .lineLimit(1)
    }
}

/// Le point vital. `☠` Il ne respire que si quelque chose est RÉELLEMENT en
/// vol : un point qui pulse en permanence n'apprend rien et fatigue l'œil.
public struct PointVeille: View {
    private let ton: Ton
    private let vivant: Bool
    @State private var souffle = false

    public init(ton: Ton, vivant: Bool = false) {
        self.ton = ton
        self.vivant = vivant
    }

    public var body: some View {
        Circle()
            .fill(ton.teinte)
            .frame(width: 7, height: 7)
            .opacity(vivant && souffle ? 0.35 : 1)
            .animation(
                vivant ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : .default,
                value: souffle
            )
            .onAppear { souffle = vivant }
            .onChange(of: vivant) { _, encore in souffle = encore }
    }
}

/// Métadonnée en mono : modèle, machine, pourcentage. Discrète, sans voile.
public struct PuceDonnee: View {
    private let texte: String

    public init(_ texte: String) {
        self.texte = texte
    }

    public var body: some View {
        Text(texte)
            .donneePetite()
            .foregroundStyle(Teinte.encreDouce)
            .padding(.horizontal, Trame.serre)
            .padding(.vertical, 3)
            .background(Teinte.fondCreux, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .lineLimit(1)
    }
}
#endif
