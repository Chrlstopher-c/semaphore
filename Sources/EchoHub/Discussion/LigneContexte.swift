// L'occupation de la fenêtre de contexte, sous le composeur.
//
// `☠` Une longue conversation finit par déborder la fenêtre et le modèle
// « oublie » le début, sans qu'aucun signe ne l'ait annoncé. Sur un téléphone,
// où l'on ne voit que trois messages à la fois, c'est encore moins détectable
// qu'au bureau. Une ligne, pas un panneau : le détail poste par poste est une
// pièce d'écran large.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct LigneContexte: View {
    @Environment(Salon.self) private var salon

    var body: some View {
        if let occupation = salon.occupation, occupation.mesurable, let part = occupation.part {
            HStack(spacing: Trame.serre) {
                jauge(part)
                Text(lecture(occupation)).mesureFine().foregroundStyle(ton(occupation).couleur)
                Spacer(minLength: 0)
                if let depassement = occupation.depassementTokens, depassement > 0 {
                    Text("\(depassement) au-delà").mesureFine().foregroundStyle(Teinte.panne)
                }
            }
            .padding(.horizontal, Trame.ecran)
            .padding(.bottom, Trame.fin)
            .transition(.scene)
        }
    }

    private func jauge(_ part: Double) -> some View {
        GeometryReader { cadre in
            ZStack(alignment: .leading) {
                Capsule().fill(Teinte.trait)
                Capsule()
                    .fill(salon.occupation.map { ton($0).couleur } ?? Teinte.encreDouce)
                    .frame(width: cadre.size.width * part)
            }
        }
        .frame(width: Trame.souffle, height: Trame.trait * 3)
    }

    /// « 31 k / 57 k ». Des milliers, pas des unités : sur une fenêtre de
    /// 57 344 tokens, les trois derniers chiffres ne décident de rien et font
    /// danser la largeur à chaque tour.
    private func lecture(_ occupation: OccupationContexte) -> String {
        let mesures = (occupation.tokensMesures ?? 0) / 1000
        let total = (occupation.contexteTotal ?? 0) / 1000
        return "\(mesures) k / \(total) k"
    }

    /// Le ton monte avec l'occupation. Le seuil d'alerte est haut exprès : dire
    /// « attention » à 50 % apprendrait à ignorer le signal.
    private func ton(_ occupation: OccupationContexte) -> Ton {
        if let depassement = occupation.depassementTokens, depassement > 0 { return .panne }
        guard let part = occupation.part else { return .neutre }
        if part >= 0.9 { return .panne }
        return part >= 0.75 ? .alerte : .neutre
    }
}
#endif
