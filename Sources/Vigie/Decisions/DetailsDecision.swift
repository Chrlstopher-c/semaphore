// Le contenu propre à chaque nature de décision. Trois circuits séparés côté
// serveur, trois lectures séparées ici : un mandat ouvre une équipe, une
// rallonge règle un fil, un arbitrage tranche un travail déjà en cours.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct DetailMandat: View {
    let proposition: PropositionApi

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            Text(proposition.projet)
                .phraseForte()
                .foregroundStyle(Teinte.encre)
            // H-61 : le droit réel au même rang que le titre, jamais replié.
            bandeDroit
            Text(proposition.objectif)
                .note()
                .foregroundStyle(Teinte.encreDouce)
                .multilineTextAlignment(.leading)
            VStack(spacing: 0) {
                LigneCle("Budget", valeur: Lisible.montant(proposition.budgetMaxUsd))
                LigneCle(
                    "Moteur",
                    valeur: Lisible.moteur(modele: proposition.modele, effort: proposition.effort),
                    derniere: proposition.perimetre.isEmpty && proposition.critereArret == nil
                )
                if !proposition.perimetre.isEmpty {
                    LigneCleLongue(
                        "Périmètre (descriptif — ne verrouille rien)",
                        valeur: proposition.perimetre,
                        derniere: proposition.critereArret == nil
                    )
                }
                if let critere = proposition.critereArret {
                    LigneCleLongue("Critère d'arrêt", valeur: critere, derniere: true)
                }
            }
        }
    }

    /// `☠` Seul `acces` porte le droit ; `perimetre` est descriptif. L'écriture
    /// se peint en danger — une équipe qui modifie du code n'est pas une
    /// équipe qui lit.
    private var bandeDroit: some View {
        let ecrit = proposition.acces.ouvreLEcriture
        let ton: Ton = ecrit ? .danger : .sain
        return HStack(spacing: Trame.serre) {
            Image(systemName: ecrit ? "pencil.circle.fill" : "eye.fill")
                .font(.system(size: 13, weight: .semibold))
            Text(Lisible.portee(proposition.acces))
                .phraseForte()
            Spacer(minLength: 0)
        }
        .foregroundStyle(ton.teinte)
        .padding(.horizontal, Trame.element)
        .padding(.vertical, Trame.serre)
        .background(ton.voile, in: RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous))
    }
}

struct DetailRallonge: View {
    let demande: RallongeApi

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            Text(Lisible.objetRallonge(demande))
                .phraseForte()
                .foregroundStyle(Teinte.encre)
            Text(demande.motif)
                .note()
                .foregroundStyle(Teinte.encreDouce)
            // `☠` Les deux volets sont indépendants : n'afficher que ce qui est
            // réellement demandé. Un plafond fabriqué à « hérité » ferait
            // accorder un réglage que personne n'a demandé.
            VStack(spacing: 0) {
                if let plage = Lisible.plage(debut: demande.fenetreDebut, fin: demande.fenetreFin) {
                    LigneCle("Plage", valeur: plage)
                }
                if let duree = Lisible.duree(debut: demande.fenetreDebut, fin: demande.fenetreFin) {
                    LigneCle("Durée", valeur: duree)
                }
                if case .valeur(let plafond) = demande.plafondDemande {
                    LigneCle("Plafond demandé", valeur: "\(plafond) équipe\(plafond > 1 ? "s" : "") sans clic")
                } else if case .illimite = demande.plafondDemande {
                    LigneCle("Plafond demandé", valeur: "aucun plafond (illimité)")
                }
                if let objectif = demande.fenetreObjectif {
                    LigneCleLongue("Objectif", valeur: objectif)
                }
                LigneCle("Ouvre une équipe", valeur: "non — réglage du fil", derniere: true)
            }
        }
    }
}

struct DetailArbitrage: View {
    let mission: MissionApi

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            Text(mission.title)
                .phraseForte()
                .foregroundStyle(Teinte.encre)
            if let libelle = mission.inspection.libelle {
                Text(libelle)
                    .note()
                    .foregroundStyle(Teinte.encreDouce)
            }
            if let motif = mission.inspection.motif {
                Text(motif)
                    .mention()
                    .foregroundStyle(Teinte.encreTernie)
            }
            VStack(spacing: 0) {
                LigneCle("Projet", valeur: mission.project)
                LigneCle("Dépense", valeur: ConsommationEquipe.montant(mission.cost))
                LigneCle(
                    "Verdict",
                    valeur: mission.inspection.lastVerdict?.rawValue ?? "—",
                    teinteValeur: Teinte.danger,
                    derniere: true
                )
            }
        }
    }
}
#endif
