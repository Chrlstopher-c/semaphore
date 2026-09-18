// Les PC trouvés sur le réseau, et l'état calme quand il n'y en a aucun.
#if canImport(SwiftUI)
import DuplexNoyau
import SwiftUI
import Systeme

struct PostesListe: View {
    @Environment(Duplexeur.self) private var duplexeur

    var body: some View {
        VStack(alignment: .leading, spacing: Grille.element) {
            if postes.isEmpty {
                if !duplexeur.etablie { etatVide }
            } else {
                Text(duplexeur.etablie ? "Autres PC sur le réseau" : "Sur le réseau").rubrique()
                ForEach(Array(postes.enumerated()), id: \.element.id) { rang, poste in
                    RangeePoste(poste: poste, etape: etape(de: poste)) {
                        Task { await duplexeur.choisir(poste) }
                    }
                    .entreeEnScene(rang: rang)
                    .transition(.item)
                }
            }
        }
        .animation(Mouvement.normal, value: postes.map(\.id))
    }

    /// Une fois relié, le PC choisi vit dans la salle : le montrer aussi dans
    /// la liste serait le nommer deux fois.
    private var postes: [PosteTrouve] {
        guard duplexeur.etablie, let choisi = duplexeur.choisi else { return duplexeur.postes }
        return duplexeur.postes.filter { $0.id != choisi.id }
    }

    private func etape(de poste: PosteTrouve) -> EtatLiaison? {
        guard duplexeur.choisi?.id == poste.id else { return nil }
        return EtatLiaison(etape: duplexeur.etape, choisi: true)
    }

    private var etatVide: some View {
        EtatCalme(
            symbole: "dot.radiowaves.left.and.right",
            titre: "Aucun PC en vue",
            detail: "Duplex doit tourner sur le PC, et les deux appareils partager le même Wi-Fi."
        ) {
            Veilleuse(libelle: "Recherche en cours")
        }
        .padding(.top, Grille.section)
    }
}

/// Une rangée de PC : son nom, et où en est la liaison avec lui.
struct RangeePoste: View {
    let poste: PosteTrouve
    /// L'étape de liaison si c'est le PC choisi, nul sinon.
    let etape: EtatLiaison?
    let surAppui: () -> Void

    var body: some View {
        Button(action: surAppui) {
            HStack(spacing: Grille.element) {
                tuile
                VStack(alignment: .leading, spacing: Grille.fin) {
                    Text(poste.nom).font(Voix.entete).foregroundStyle(Neutre.encre)
                    Text(poste.service).font(Voix.brut).foregroundStyle(Neutre.encreEteinte).lineLimit(1)
                }
                Spacer(minLength: Grille.serre)
                if let etape {
                    Sceau(etape.libelle, ton: etape.ton).id(etape).transition(.item)
                } else {
                    Image(systemName: "chevron.right")
                        .font(Voix.legende)
                        .foregroundStyle(Neutre.encreEteinte)
                }
            }
            .padding(Grille.element)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Neutre.surface)
            .clipShape(.rect(cornerRadius: Rayon.carte, style: .continuous))
            .lisere()
            .contentShape(.rect)
        }
        .buttonStyle(.appui)
        .animation(Mouvement.normal, value: etape)
        .accessibilityLabel(poste.nom)
        .accessibilityAddTraits(etape != nil ? .isSelected : [])
    }

    /// Le glyphe du PC dans une tuile : c'est la tuile qui s'allume quand le PC
    /// est choisi, pas la rangée entière — l'accent reste un point.
    private var tuile: some View {
        Image(systemName: "desktopcomputer")
            .font(.system(.body, weight: .medium))
            .foregroundStyle(etape != nil ? Teinte.accent : Neutre.encreDouce)
            .frame(width: Grille.cible, height: Grille.cible)
            .background(Neutre.surfaceHaute)
            .clipShape(.rect(cornerRadius: Rayon.controle, style: .continuous))
    }
}

/// Le témoin d'une recherche qui tourne : un point qui respire, à côté d'un
/// libellé. Il dit « ça cherche encore » sans tourniquet ; sous « Réduire les
/// animations » le point reste allumé, fixe.
struct Veilleuse: View {
    let libelle: String
    @Environment(\.accessibilityReduceMotion) private var reduireMouvement
    @State private var allumee = false

    var body: some View {
        HStack(spacing: Grille.serre) {
            Circle()
                .fill(Teinte.accent)
                .frame(width: Grille.serre, height: Grille.serre)
                .opacity(reduireMouvement ? 1 : (allumee ? 1 : 0.3))
            Text(libelle).font(Voix.legende).foregroundStyle(Neutre.encreDouce)
        }
        .onAppear(perform: respirer)
        .accessibilityElement(children: .combine)
    }

    private func respirer() {
        guard !reduireMouvement else { return }
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            allumee = true
        }
    }
}
#endif
