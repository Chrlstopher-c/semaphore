// Les commandes du chat à l'écran : la palette « / » au-dessus de la saisie, la carte d'étapes de
// `/compact`, le séparateur d'un `/clear` (annulable) et les consignes glissées à l'agent.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

/// S'ouvre pendant la frappe du NOM d'une commande ; un toucher complète la saisie.
struct PaletteCommandes: View {
    let propositions: [DefinitionCommande]
    let choisir: (DefinitionCommande) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(propositions) { definition in
                Button { choisir(definition) } label: {
                    VStack(alignment: .leading, spacing: Trame.fin) {
                        Text(definition.usage).mesureFine().foregroundStyle(Teinte.encre)
                        if !definition.description.isEmpty {
                            Text(definition.description).legende().foregroundStyle(Teinte.encreDouce)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: Trame.cible, alignment: .leading)
                    .padding(.horizontal, Trame.ecran)
                    .contentShape(.rect)
                }
                .buttonStyle(.appui)
            }
        }
        .padding(.vertical, Trame.fin)
        .background(Teinte.surface)
        .transition(.scene)
    }
}

/// La carte de `/compact` : ses étapes, son chrono, son issue.
struct CarteCommande: View {
    let commande: EtatCommande

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            HStack(spacing: Trame.serre) {
                Text("/\(commande.nom)").mesureFine().foregroundStyle(Teinte.encre)
                Spacer(minLength: 0)
                Text(duree).mesureFine().foregroundStyle(Teinte.encreEteinte)
            }
            ForEach(commande.etapes, id: \.cle) { etape in
                HStack(spacing: Trame.serre) {
                    Image(systemName: symbole(etape.etat)).imageScale(.small)
                        .foregroundStyle(etape.etat == "fait" ? Teinte.ok : etape.etat == "en_cours" ? Teinte.accent : Teinte.encreEteinte)
                        .symbolEffect(.pulse, isActive: etape.etat == "en_cours")
                    Text(etape.libelle).legende()
                        .foregroundStyle(etape.etat == "a_faire" ? Teinte.encreEteinte : Teinte.encreDouce)
                }
            }
            if !commande.detail.isEmpty {
                Text(commande.detail).legende().foregroundStyle(Teinte.encreDouce)
            }
            if let erreur = commande.erreur {
                Text(erreur).legende().foregroundStyle(Teinte.panne)
            }
        }
        .padding(Trame.element)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Teinte.surface, in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Teinte.trait))
    }

    private var duree: String {
        String(format: "%.1f s", Double(commande.dureeMs) / 1000).replacingOccurrences(of: ".", with: ",")
    }

    private func symbole(_ etat: String) -> String {
        switch etat {
        case "fait": return "checkmark.circle.fill"
        case "en_cours": return "circle.dotted"
        default: return "circle"
        }
    }
}

/// Un `/clear` : au-dessus, le modèle ne voit plus rien. Annulable.
struct SeparateurEffacement: View {
    let effacement: InfoEffacement
    let annuler: () -> Void

    var body: some View {
        HStack(spacing: Trame.serre) {
            Rectangle().fill(Teinte.trait).frame(height: Trame.trait)
            Text("Contexte effacé").legende().foregroundStyle(Teinte.encreEteinte).fixedSize()
            Button("Annuler", action: annuler).buttonStyle(.appui).legende().foregroundStyle(Teinte.accent)
            Rectangle().fill(Teinte.trait).frame(height: Trame.trait)
        }
        .frame(minHeight: Trame.cible)
    }
}

/// Ce que Chris a glissé à l'agent pendant qu'il travaille : lu à la fin de son étape.
struct LignesConsignes: View {
    @Environment(Salon.self) private var salon

    var body: some View {
        ForEach(Array(salon.consignesGlissees.enumerated()), id: \.offset) { _, consigne in
            HStack(spacing: Trame.serre) {
                Image(systemName: "arrow.turn.down.right").imageScale(.small).foregroundStyle(Teinte.accent)
                Text(consigne).legende().foregroundStyle(Teinte.encreDouce).lineLimit(1)
                Spacer(minLength: 0)
                Text("glissé à l'agent").legende().foregroundStyle(Teinte.encreEteinte)
            }
            .padding(.horizontal, Trame.ecran)
            .padding(.vertical, Trame.fin)
            .transition(.scene)
        }
    }
}
#endif
