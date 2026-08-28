// L'état vide de la charte — conçu, pas subi. « Rien à trancher » est le
// régime des nuits : il se peint en ardoise, avec la lune, jamais en gris
// triste ni en rouge.
#if canImport(SwiftUI)
import SwiftUI

public struct EtatCalme: View {
    private let symbole: String
    private let titre: String
    private let explication: String
    private let ton: Ton

    public init(symbole: String, titre: String, explication: String, ton: Ton = .veille) {
        self.symbole = symbole
        self.titre = titre
        self.explication = explication
        self.ton = ton
    }

    public var body: some View {
        VStack(spacing: Trame.element) {
            Image(systemName: symbole)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(ton.teinte.opacity(0.8))
            VStack(spacing: Trame.fin) {
                Text(titre)
                    .phraseForte()
                    .foregroundStyle(Teinte.encre)
                Text(explication)
                    .note()
                    .foregroundStyle(Teinte.encreTernie)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Trame.section + Trame.element)
        .padding(.horizontal, Trame.ecran)
    }
}

/// Silhouette d'attente. `☠` Réservée au TOUT PREMIER lancement : dès qu'une
/// donnée datée existe, c'est elle qu'on montre, avec son âge — jamais un
/// squelette par-dessus du réel.
public struct SilhouetteAttente: View {
    private let lignes: [CGFloat]
    @State private var souffle = false

    public init(lignes: [CGFloat] = [0.55, 0.85, 0.4]) {
        self.lignes = lignes
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Trame.serre + 2) {
            ForEach(Array(lignes.enumerated()), id: \.offset) { _, part in
                GeometryReader { cadre in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Teinte.surfaceHaute)
                        .frame(width: cadre.size.width * part)
                }
                .frame(height: 12)
            }
        }
        .opacity(souffle ? 0.5 : 1)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: souffle)
        .onAppear { souffle = true }
    }
}
#endif
