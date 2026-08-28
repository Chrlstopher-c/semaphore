// La surface de la dictée : un bouton, un liseré d'écoute, et l'empêchement dit
// en clair quand il y en a un.
//
// Parti pris de charte : la dictée ne porte JAMAIS l'orange accent, réservé à
// « ta main est requise ». Pendant qu'on parle, rien n'est requis — c'est
// `veille` qui tient l'état, franchement distinct de l'orange comme du
// framboise du bouton d'arrêt voisin.
#if canImport(SwiftUI)
import SwiftUI

/// Le micro du composeur. Un appui ouvre la dictée, un autre la ferme : pas de
/// maintien, on parle parfois longtemps et le pouce ne doit pas être un timer.
struct BoutonDictee: View {
    let dictant: Bool
    let basculer: () -> Void

    var body: some View {
        Button(action: basculer) {
            ZStack {
                if dictant {
                    Circle()
                        .fill(Ton.veille.voile)
                        .frame(width: 34, height: 34)
                }
                Image(systemName: dictant ? "stop.fill" : "mic")
                    .font(.system(size: dictant ? 13 : 16, weight: .medium))
                    .foregroundStyle(dictant ? Teinte.veille : Teinte.encreDouce)
            }
            .frame(width: 40, height: 40)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .animation(Elan.vif, value: dictant)
        .sensoryFeedback(Haptique.selection, trigger: dictant)
        .accessibilityLabel(dictant ? "Arrêter la dictée" : "Dicter le message")
    }
}

/// Le liseré d'écoute, posé au-dessus du composeur pendant la dictée.
///
/// Il ne répète pas la transcription : elle s'écrit déjà dans le champ, sous les
/// yeux, corrigeable au clavier sans arrêter le micro. Il dit la seule chose que
/// le champ ne dit pas — que rien ne sort de l'appareil.
struct LisereDictee: View {
    var body: some View {
        HStack(spacing: Trame.serre) {
            SouffleActivite(teinte: Teinte.veille)
            Text("DICTÉE · SUR L'APPAREIL")
                .insigne()
                .foregroundStyle(Teinte.veille)
            Spacer(minLength: 0)
            Text("le silence ne coupe pas")
                .donneeMinuscule()
                .foregroundStyle(Teinte.encreTernie)
        }
        .padding(.horizontal, Trame.element)
        .padding(.vertical, Trame.serre)
        .background(Ton.veille.voile, in: RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
#endif
