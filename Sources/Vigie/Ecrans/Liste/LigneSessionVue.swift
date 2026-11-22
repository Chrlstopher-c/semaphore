// Une ligne de la liste Code (étalon 014) : glyphe d'état à gauche, titre sur une ligne, méta + glyphe de l'appareil,
// point bleu à droite quand une fin de tour n'a pas été vue. Pas de séparateur, pas de chevron.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct LigneSessionVue: View {
    let ligne: LigneSession

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            GlypheStatut(statut: ligne.statut).frame(width: 44, alignment: .center)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 6 }
            VStack(alignment: .leading, spacing: 4) {
                Text(ligne.titre).font(.system(size: 18)).foregroundStyle(Q.titre).lineLimit(1)
                HStack(spacing: 6) {
                    if !ligne.sousTitre.isEmpty {
                        Text(ligne.sousTitre).font(Q.detail).foregroundStyle(Q.meta).lineLimit(1)
                    }
                    GlypheAppareil(appareil: ligne.appareil, enLigne: ligne.appareilEnLigne)
                }
            }
            Spacer(minLength: 12)
            if ligne.nonLue {
                Circle().fill(Q.accent).frame(width: 8, height: 8)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 6 }
            }
        }
        .padding(.leading, 14).padding(.trailing, 24)
        .frame(height: 75)
        .contentShape(.rect)
    }
}

/// Glyphe d'état : cercle au repos, roue pendant le travail, triangle en erreur, cercle plein accent pour une question.
struct GlypheStatut: View {
    let statut: IconeStatut

    var body: some View {
        switch statut {
        case .travail: IndicateurTravail().frame(width: 18, height: 18)
        case .erreur:
            Image(systemName: "exclamationmark.triangle").font(.system(size: 15)).foregroundStyle(Q.secondaire)
        case .question: Circle().fill(Q.accent).frame(width: 10, height: 10)
        case .repos: Circle().strokeBorder(Q.cercle, lineWidth: 1.5).frame(width: 11, height: 11)
        }
    }
}

/// Roue de travail : arc ouvert qui tourne (étalon : spinner fin, pas de `ProgressView` système).
struct IndicateurTravail: View {
    @State private var tourne = false

    var body: some View {
        Circle().trim(from: 0, to: 0.72)
            .stroke(Q.secondaire, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            .rotationEffect(.degrees(tourne ? 360 : 0))
            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: tourne)
            .onAppear { tourne = true }
            .accessibilityLabel("Travaille")
    }
}

/// L'appareil qui tient la session : portable vert en ligne, barré hors ligne, nuage pour une session de claude.ai.
struct GlypheAppareil: View {
    let appareil: IconeAppareil
    let enLigne: Bool

    var body: some View {
        Image(systemName: symbole).font(.system(size: 13)).foregroundStyle(couleur)
    }

    private var symbole: String {
        if appareil == .nuage { return "cloud" }
        if !enLigne { return appareil == .portable ? "laptopcomputer.slash" : "desktopcomputer.trianglebadge.exclamationmark" }
        switch appareil {
        case .portable: return "laptopcomputer"
        case .tour: return "desktopcomputer"
        case .pi: return "cpu"
        case .nuage: return "cloud"
        case .autre: return "server.rack"
        }
    }

    private var couleur: Color { appareil == .nuage ? Q.meta : (enLigne ? Q.enLigne : Q.meta) }
}
#endif
