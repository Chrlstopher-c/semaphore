// Les verdicts du tri rapide, par geste ou par bouton, et leur annulation.
#if canImport(SwiftUI) && canImport(Photos)
import SwiftUI
import Systeme
import TamisNoyau

extension TriEcran {
    var commandes: some View {
        HStack(spacing: Grille.groupe) {
            rond("trash", ton: .depart, libelle: "Au panier") { juger(auPanier: true) }
            rond("arrow.uturn.backward", ton: .neutre, libelle: "Annuler", action: annuler)
                .disabled(historique.isEmpty)
            rond("heart", ton: .actif, libelle: "Garder") { juger(auPanier: false) }
        }
        .frame(maxWidth: .infinity)
        .disabled(courant == nil && historique.isEmpty)
        .sensoryFeedback(Toucher.engage, trigger: historique.count)
    }

    private func rond(_ symbole: String, ton: Ton, libelle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbole)
                .font(.system(.title2, weight: .semibold))
                .foregroundStyle(ton.couleur)
                .frame(width: Trame.bouton, height: Trame.bouton)
                .background(ton.voile, in: .circle)
        }
        .buttonStyle(.appui)
        .accessibilityLabel(libelle)
    }

    func juger(auPanier: Bool) {
        guard let courant, !enVol else { return }
        if auPanier {
            atelier.mettreAuPanier([courant.id])
            jete += courant.poids ?? 0
        } else {
            atelier.garder([courant.id])
        }
        historique.append(courant.id)
        guard !reduire else { return avancer() }
        enVol = true
        withAnimation(Mouvement.normal) {
            glisse = auPanier ? -Trame.envol : Trame.envol
        } completion: {
            avancer()
        }
    }

    /// La carte suivante prend la place, sans animer le retour à zéro de l'offset.
    private func avancer() {
        var sans = Transaction()
        sans.disablesAnimations = true
        withTransaction(sans) {
            if !file.isEmpty { file.removeFirst() }
            glisse = 0
        }
        enVol = false
    }

    func annuler() {
        guard let id = historique.popLast() else { return }
        if atelier.decisions.panier.contains(id) { jete -= atelier.index[id]?.poids ?? 0 }
        atelier.oublier([id])
        withAnimation(Mouvement.normal) { file.insert(id, at: 0) }
    }
}
#endif
