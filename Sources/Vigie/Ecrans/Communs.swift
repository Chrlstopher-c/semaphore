// Éléments d'écran partagés par les onglets : en-tête (surtitre + titre Manrope), état vide, bandeau d'erreur.
#if canImport(SwiftUI)
import SwiftUI

struct EnTeteEcran<Action: View>: View {
    @Environment(\.palette) private var p
    let surtitre: String
    let titre: String
    @ViewBuilder var action: () -> Action

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: Espace.xs) {
                Surtitre(texte: surtitre)
                Text(titre).font(Voix.titreEcran).tracking(-1).foregroundStyle(p.encre)
            }
            Spacer(minLength: Espace.l)
            action()
        }
        .padding(.horizontal, Espace.marge)
        .padding(.top, Espace.l)
        .padding(.bottom, Espace.s)
    }
}

extension EnTeteEcran where Action == EmptyView {
    init(surtitre: String, titre: String) {
        self.init(surtitre: surtitre, titre: titre) { EmptyView() }
    }
}

struct EtatVide: View {
    @Environment(\.palette) private var p
    let symbole: String
    let titre: String
    let texte: String

    var body: some View {
        VStack(spacing: Espace.m) {
            Image(systemName: symbole).font(.system(size: 26, weight: .semibold)).foregroundStyle(p.accentTexte)
                .frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(p.accentFond))
            Text(titre).font(Voix.entete).foregroundStyle(p.encre)
            Text(texte).font(Voix.petit).foregroundStyle(p.discret).multilineTextAlignment(.center)
        }
        .padding(Espace.xxl)
        .frame(maxWidth: .infinity)
    }
}

struct BandeauErreur: View {
    @Environment(\.palette) private var p
    let texte: String
    let fermer: () -> Void

    var body: some View {
        Button(action: fermer) {
            Text(texte).font(Voix.petit.weight(.semibold)).foregroundStyle(p.danger)
                .frame(maxWidth: .infinity, alignment: .leading).padding(Espace.m)
                .background(RoundedRectangle(cornerRadius: Rayon.controle, style: .continuous).fill(p.danger.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}
#endif
