// Réglages › Liaison › Synchronisation : par machine, où en est la copie des favoris gardée sur cet iPhone (à jour,
// hors ligne, ne répond pas, dernière erreur). Une machine éteinte ou muette ne retire rien de l'iPhone.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct SynchroReglages: View {
    @Environment(ModeleRelais.self) private var modele

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TitreSection(texte: "Machines")
                Carte {
                    if identifiants.isEmpty {
                        RangeeReglage(titre: "Aucune machine connue", couleur: Q.tertiaire, chevron: false)
                    }
                    ForEach(Array(identifiants.enumerated()), id: \.offset) { rang, identifiant in
                        if rang > 0 { Filet(retrait: 60) }
                        ligne(identifiant)
                    }
                }
                Text("Les favoris restent sur cet iPhone, même quand une machine est éteinte ou ne répond pas.")
                    .font(Q.detail).foregroundStyle(Q.secondaire).padding(.horizontal, 32).padding(.top, 8)
            }
            .padding(.bottom, 32)
        }
        .barreFeuille("Synchronisation")
    }

    private var identifiants: [String] {
        Set(modele.machines.map(\.id)).union(modele.organisation.machines.keys).sorted()
    }

    @ViewBuilder private func ligne(_ identifiant: String) -> some View {
        let machine = modele.machines.first { $0.id == identifiant }
        let entree = modele.organisation.machines[identifiant]
        let etat = EtatSynchro.de(machine: machine, entree: entree, relaisJoint: modele.lien == .connecte)
        RangeeReglage(symbole: machine.map(GlypheMachine.symbole) ?? "desktopcomputer", titre: identifiant,
                      valeur: etat.libelle(maintenant: Date()),
                      couleur: machine?.enLigne == true ? Q.texte : Q.secondaire, chevron: false)
        if let erreur = entree?.erreur {
            Text("Dernière erreur : \(erreur)").font(Q.detail).foregroundStyle(Q.secondaire)
                .padding(.horizontal, Q.marge).padding(.bottom, 10)
        }
    }
}
#endif
