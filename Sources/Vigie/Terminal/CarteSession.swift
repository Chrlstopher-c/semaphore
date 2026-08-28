// Une session tmux : son nom en mono, son âge, et « suivie ailleurs » quand
// un autre terminal la regarde — probablement la plus vivante.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct CarteSession: View {
    let session: SessionTmuxApi

    var body: some View {
        Panneau {
            HStack(spacing: Trame.element) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Teinte.veille)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.name)
                        .donnee()
                        .foregroundStyle(Teinte.encre)
                    Text("ouverte \(age)")
                        .mention()
                        .foregroundStyle(Teinte.encreTernie)
                }
                Spacer(minLength: 0)
                if session.attached {
                    Sceau("suivie ailleurs", ton: .sain)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Teinte.encreTernie)
            }
        }
    }

    /// `☠` `created` est en SECONDES — tmux les rend ainsi, tout le reste du
    /// contrat est en millisecondes. Les mélanger a déjà produit un « reset
    /// dans 495278229 h » sur ce produit.
    private var age: String {
        Fraicheur.texte(depuis: Date(timeIntervalSince1970: Double(session.created)))
    }
}
#endif
