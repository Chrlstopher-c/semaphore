// Une année de la photothèque, dessinée comme une couche : sa longueur est son
// poids, rapporté à l'année la plus lourde. La part au panier se lit en rouge au
// bout de la couche — ce qui va partir. Toucher l'année déplie ses mois.
#if canImport(SwiftUI) && canImport(Photos)
import SwiftUI
import Systeme
import TamisNoyau

struct StrateBloc: View {
    @Environment(Atelier.self) private var atelier
    let strate: Strate
    let reference: Int64
    @Binding var ouverte: Int?

    private var depliee: Bool { ouverte == strate.id }

    var body: some View {
        VStack(alignment: .leading, spacing: Grille.serre) {
            Button(action: basculer) { ligneAnnee }
                .buttonStyle(.appui)
            if depliee {
                VStack(alignment: .leading, spacing: Grille.fin) {
                    ForEach(strate.mois) { couche in
                        NavigationLink(value: destination(couche)) { ligneMois(couche) }
                            .buttonStyle(.appui)
                    }
                }
                .transition(.item)
            }
        }
        .animation(Mouvement.normal, value: depliee)
    }

    private func basculer() {
        ouverte = depliee ? nil : strate.id
    }

    private var ligneAnnee: some View {
        VStack(alignment: .leading, spacing: Grille.serre) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(strate.id)).font(Voix.annee).foregroundStyle(Neutre.encre)
                Text("\(strate.annee.nombre.formatted()) éléments")
                    .font(Voix.note).foregroundStyle(Neutre.encreEteinte)
                Spacer(minLength: Grille.serre)
                Text(Octets.lisible(strate.annee.poids)).font(Voix.mesure).foregroundStyle(Neutre.encreDouce)
                Image(systemName: "chevron.down")
                    .font(Voix.legende).foregroundStyle(Neutre.encreEteinte)
                    .rotationEffect(.degrees(depliee ? 180 : 0))
            }
            TraitCouche(poids: strate.annee.poids, panier: strate.annee.poidsPanier,
                   reference: reference, epaisseur: Trame.strate)
        }
        .frame(minHeight: Grille.cible)
        .contentShape(.rect)
    }

    private func ligneMois(_ couche: TamisNoyau.Couche) -> some View {
        HStack(spacing: Grille.element) {
            Text(Calendrier.mois(couche.mois ?? 1))
                .font(Voix.note).foregroundStyle(Neutre.encreDouce)
                .frame(width: Trame.libelleMois, alignment: .leading)
            TraitCouche(poids: couche.poids, panier: couche.poidsPanier,
                   reference: strate.annee.poids, epaisseur: Trame.strateMois)
            Text(Octets.lisible(couche.poids)).font(Voix.mesure).foregroundStyle(Neutre.encreEteinte)
        }
        .frame(minHeight: Grille.cible)
        .contentShape(.rect)
    }

    private func destination(_ couche: TamisNoyau.Couche) -> Destination {
        let plage = PlageDates.mois(annee: couche.annee, mois: couche.mois ?? 1)
        let ids = Tamisage(plage: plage, epargnerFavoris: false).passer(atelier.cliches).map(\.id)
        return .grille(titre: "\(Calendrier.mois(couche.mois ?? 1)) \(couche.annee)", ids: ids)
    }
}

/// Le trait d'une couche : piste éteinte, poids en encre, part au panier en rouge.
private struct TraitCouche: View {
    let poids: Int64
    let panier: Int64
    let reference: Int64
    let epaisseur: CGFloat

    var body: some View {
        GeometryReader { geo in
            let largeur = geo.size.width * fraction(poids)
            ZStack(alignment: .leading) {
                Capsule().fill(Neutre.surface)
                Capsule().fill(Neutre.encreDouce).frame(width: largeur)
                Capsule().fill(Teinte.depart)
                    .frame(width: largeur * (poids > 0 ? CGFloat(panier) / CGFloat(poids) : 0))
                    .offset(x: largeur * (1 - (poids > 0 ? CGFloat(panier) / CGFloat(poids) : 0)))
            }
        }
        .frame(height: epaisseur)
        .animation(Mouvement.normal, value: panier)
        .accessibilityHidden(true)
    }

    private func fraction(_ valeur: Int64) -> CGFloat {
        guard reference > 0, valeur > 0 else { return 0 }
        return max(CGFloat(valeur) / CGFloat(reference), Trame.largeurMin)
    }
}

enum Calendrier {
    /// 3 → « mars ».
    static func mois(_ numero: Int) -> String {
        let noms = Calendar.current.standaloneMonthSymbols
        return noms.indices.contains(numero - 1) ? noms[numero - 1] : "?"
    }
}
#endif
