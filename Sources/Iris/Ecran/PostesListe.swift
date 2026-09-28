// Les ordinateurs présentés par le relais : qui reçoit, qui attend, qui dort.
#if canImport(SwiftUI)
import IrisNoyau
import SwiftUI
import Systeme

struct PostesListe: View {
    @Environment(Emetteur.self) private var emetteur

    var body: some View {
        VStack(alignment: .leading, spacing: Grille.serre) {
            Text("Ordinateurs").rubrique()
            VStack(spacing: 0) {
                if emetteur.recepteurs.isEmpty {
                    Text(vide).font(Voix.note).foregroundStyle(Neutre.encreEteinte)
                        .frame(maxWidth: .infinity, minHeight: Grille.cible + Grille.element)
                } else {
                    ForEach(Array(emetteur.recepteurs.enumerated()), id: \.element.id) { rang, poste in
                        if rang > 0 { Rectangle().fill(Neutre.trait).frame(height: Grille.trait) }
                        ligne(poste)
                    }
                }
            }
            .padding(.horizontal, Grille.bloc)
            .background(Neutre.surface, in: .rect(cornerRadius: Rayon.carte, style: .continuous))
        }
    }

    private var vide: String {
        emetteur.relais == .connecte ? "Aucun ordinateur en ligne" : "Relais non joint"
    }

    private func ligne(_ poste: Recepteur) -> some View {
        let etat = Etat(poste: poste, liaison: emetteur.liaisons[poste.nom], enDirect: emetteur.enDirect)
        return HStack(spacing: Grille.element) {
            Circle().fill(etat.couleur).frame(width: Trame.point, height: Trame.point)
            VStack(alignment: .leading, spacing: Grille.fin) {
                Text(poste.nom).font(Voix.entete).foregroundStyle(Neutre.encre)
                Text(emetteur.infos[poste.nom] ?? etat.libelle)
                    .font(Voix.mesure).foregroundStyle(Neutre.encreDouce)
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: Grille.cible + Grille.element)
        .animation(Mouvement.normal, value: etat)
    }
}

/// L'état lisible d'un PC, déduit de ce qu'il demande et de la liaison ouverte.
private enum Etat: Equatable {
    case veille, attente, connexion, direct, injoignable

    init(poste: Recepteur, liaison: EtatLiaison?, enDirect: Bool) {
        switch (poste.veut, liaison) {
        case (false, _): self = .veille
        case (true, .etablie?): self = .direct
        case (true, .connexion?): self = .connexion
        case (true, .injoignable?): self = .injoignable
        case (true, nil): self = enDirect ? .connexion : .attente
        }
    }

    var libelle: String {
        switch self {
        case .veille: return "En veille — webcam inutilisée"
        case .attente: return "Demande l'image"
        case .connexion: return "Liaison…"
        case .direct: return "Reçoit l'image"
        case .injoignable: return "Injoignable sur le réseau local"
        }
    }

    var couleur: Color {
        switch self {
        case .veille: return Neutre.encreEteinte.opacity(0.5)
        case .attente: return Teinte.accent
        case .connexion: return Semantique.alerte
        case .direct: return Semantique.ok
        case .injoignable: return Semantique.panne
        }
    }
}
#endif
