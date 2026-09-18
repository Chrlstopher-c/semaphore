// La salle d'écoute : le PC relié, sa source, l'anneau, et pendant l'écoute
// les trois mesures du flux. C'est l'écran qu'on regarde une heure durant —
// un seul objet au centre, tout le reste en petit et éteint.
#if canImport(SwiftUI)
import DuplexNoyau
import SwiftUI
import Systeme

struct SalleEcoute: View {
    @Environment(Duplexeur.self) private var duplexeur

    var body: some View {
        VStack(spacing: Grille.groupe) {
            Spacer(minLength: 0)
            identite
            AnneauEcoute(regime: regime) {
                Task { await duplexeur.basculerEcoute() }
            }
            legende
            if duplexeur.ecoute {
                Releve(qualite: duplexeur.qualite).transition(.item)
            }
            if let etat = duplexeur.etatPoste, etat.airplay.actif {
                Text("Le PC joue aussi vers \(etat.airplay.appareil) par AirPlay.")
                    .font(Voix.note)
                    .foregroundStyle(Neutre.encreEteinte)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Grille.groupe)
        .animation(Mouvement.normal, value: duplexeur.ecoute)
    }

    private var regime: AnneauEcoute.Regime {
        guard duplexeur.ecoute else { return .silencieux }
        return duplexeur.qualite.amorce ? .ecoute : .amorcage
    }

    // MARK: - Le nom du PC et sa source

    private var identite: some View {
        VStack(spacing: Grille.serre) {
            Text(duplexeur.nomPoste ?? "PC")
                .font(Voix.nomPoste)
                .foregroundStyle(Neutre.encre)
                .multilineTextAlignment(.center)
            ChoixSource()
        }
    }

    // MARK: - Ce que l'anneau veut dire

    private var legende: some View {
        VStack(spacing: Grille.fin) {
            Text(titre).font(Voix.entete).foregroundStyle(Neutre.encre)
            Text(detail).font(Voix.note).foregroundStyle(Neutre.encreDouce)
                .multilineTextAlignment(.center)
        }
        .id(regime)
        .transition(.item)
        .animation(Mouvement.normal, value: regime)
    }

    private var titre: String {
        switch regime {
        case .silencieux: return "Écouter"
        case .amorcage: return "Mise en tampon"
        case .ecoute: return "En écoute"
        }
    }

    private var detail: String {
        switch regime {
        case .silencieux: return "Le son du PC se mêle à ce que le téléphone joue déjà."
        case .amorcage: return "Le son part dès que le tampon est plein."
        case .ecoute: return "Toucher l'anneau pour arrêter."
        }
    }
}

/// Le relevé du flux : tampon, trous, coupures. Sans Mac ni débogueur au bout
/// de cette app, c'est la seule fenêtre sur ce que fait le son — mais elle se
/// lit du coin de l'œil, jamais elle n'attire.
struct Releve: View {
    let qualite: Duplexeur.Qualite

    var body: some View {
        VStack(spacing: Grille.element) {
            HStack(alignment: .firstTextBaseline, spacing: Grille.section) {
                mesure("Tampon", "\(Int(qualite.remplissageMs)) ms")
                mesure("Trous", "\(qualite.trous)")
                mesure("Coupures", "\(coupures)", ton: coupures > 0 ? .alerte : .neutre)
            }
            JaugeTampon(remplissageMs: qualite.remplissageMs)
        }
    }

    private var coupures: Int { qualite.famines + qualite.ruptures }

    private func mesure(_ libelle: String, _ valeur: String, ton: Ton = .neutre) -> some View {
        VStack(spacing: Grille.fin) {
            Text(valeur).font(Voix.mesure).foregroundStyle(ton.couleur)
            Text(libelle).rubrique()
        }
        .animation(Mouvement.normal, value: ton)
    }
}

/// Le remplissage du tampon sur un fil : la cible au milieu, deux fois la cible
/// au bout. Seule l'échelle du remplissage s'anime — jamais sa mise en page.
struct JaugeTampon: View {
    let remplissageMs: Double

    private var part: CGFloat {
        CGFloat(min(max(remplissageMs / (CorrectionDerive.cibleMs * 2), 0), 1))
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Neutre.surfaceHaute)
            Capsule()
                .fill(Neutre.encreEteinte)
                .scaleEffect(x: part, anchor: .leading)
                .animation(Mouvement.normal, value: part)
            Rectangle()
                .fill(Neutre.encreDouce)
                .frame(width: Grille.trait, height: Grille.serre)
                .frame(maxWidth: .infinity)
        }
        .frame(width: Trame.jaugeLargeur, height: Trame.jauge)
        .accessibilityHidden(true)
    }
}
#endif
