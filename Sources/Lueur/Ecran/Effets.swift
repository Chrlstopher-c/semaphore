// Les animations intégrées au contrôleur : un interrupteur « Animation » (rallume la dernière, ou repose la couleur
// fixe), la grille des effets, leur vitesse.
#if canImport(SwiftUI) && canImport(UIKit)
import LueurNoyau
import SwiftUI
import Systeme

struct Effets: View {
    @Environment(Lampe.self) private var lampe
    @State private var vitesse: Double = 50
    @State private var enCours = false
    private let colonnes = Array(repeating: GridItem(.flexible(), spacing: Grille.serre), count: 2)

    var body: some View {
        VStack(alignment: .leading, spacing: Grille.element) {
            Toggle(isOn: animation) { Text("Animation").rubrique() }
                .frame(minHeight: Grille.cible)
            LazyVGrid(columns: colonnes, spacing: Grille.serre) {
                ForEach(lampe.effets) { effet in puce(effet) }
            }
            .opacity(enMarche ? 1 : 0.6)
            curseurVitesse
        }
        .animation(Mouvement.normal, value: enMarche)
        .sensoryFeedback(Toucher.selection, trigger: lampe.etat?.effet)
        .onChange(of: lampe.etat?.vitesse, initial: true) { _, v in
            if let v, !enCours { vitesse = Double(v) }
        }
    }

    private var enMarche: Bool { lampe.etat?.effet != nil }

    private var animation: Binding<Bool> {
        Binding(get: { enMarche }, set: { oui in
            let relance = lampe.etat?.dernierEffet ?? lampe.effets.first?.code
            lampe.envoyer(.effet(oui ? relance : nil))
        })
    }

    private func puce(_ effet: Effet) -> some View {
        let actif = lampe.etat?.effet == effet.code
        return Button {
            lampe.envoyer(.effet(effet.code))
        } label: {
            Text(effet.nom)
                .font(Voix.mention)
                .foregroundStyle(actif ? Neutre.encre : Neutre.encreDouce)
                .frame(maxWidth: .infinity, minHeight: Grille.cible, alignment: .leading)
                .padding(.horizontal, Grille.element)
                .background(actif ? Teinte.accent.opacity(0.18) : Neutre.surface,
                            in: .rect(cornerRadius: Rayon.controle, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Rayon.controle, style: .continuous)
                        .strokeBorder(actif ? Teinte.accent : Neutre.trait, lineWidth: Grille.trait)
                }
                .contentShape(.rect)
        }
        .buttonStyle(Presse())
    }

    private var curseurVitesse: some View {
        VStack(alignment: .leading, spacing: Grille.serre) {
            HStack {
                Text("Vitesse").rubrique()
                Spacer()
                Text("\(Int(vitesse))").font(Voix.mesure).foregroundStyle(Neutre.encreDouce)
            }
            Slider(value: $vitesse, in: 0...100, step: 1) { enCours = $0 }
                .frame(minHeight: Grille.cible)
                .onChange(of: vitesse) { _, v in if enCours { lampe.envoyer(.vitesse(Int(v))) } }
        }
    }
}
#endif
