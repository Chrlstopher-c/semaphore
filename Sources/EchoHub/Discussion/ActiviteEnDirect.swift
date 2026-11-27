// Ce que le moteur fait EN CE MOMENT, sous la réponse en cours (`ActiviteEnDirect.tsx` du web) :
// la phase, le débit, les jetons écrits, « au travail depuis », l'outil en cours, le plan de l'agent,
// la fenêtre de contexte, et les commandes shell avec leur sortie en direct.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct ActiviteEnDirect: View {
    @Environment(Salon.self) private var salon

    var body: some View {
        if let activite = salon.activite {
            TimelineView(.periodic(from: .now, by: 1)) { contexte in
                contenu(activite, maintenant: contexte.date)
            }
            .transition(.scene)
        }
        ForEach(salon.commandesShell) { commande in
            CarteCommandeShell(commande: commande, client: salon.client)
        }
    }

    private func contenu(_ activite: ActiviteMoteur, maintenant: Date) -> some View {
        let silencieux = maintenant.timeIntervalSince(salon.activiteRecueLe) > RepereActivite.silence
        let repere = RepereActivite(activite, silencieux: silencieux)
        return VStack(alignment: .leading, spacing: Trame.serre) {
            HStack(spacing: Trame.serre) {
                Circle().fill(couleur(repere.ton)).frame(width: 6, height: 6)
                    .symbolEffect(.pulse, isActive: !silencieux)
                Text(repere.libelle).legende().foregroundStyle(Teinte.encre)
                if repere.montrerJetons {
                    Text("\(activite.tokens) jetons · \(debit(activite.tokensParSeconde))")
                        .mesureFine().foregroundStyle(Teinte.encreDouce)
                }
                if let lecture = activite.lecture, lecture.total > 0 {
                    Text("\(lecture.faits) / \(lecture.total) relus").mesureFine().foregroundStyle(Teinte.encreDouce)
                }
                Spacer(minLength: 0)
                if let debut = activite.debut {
                    Text(RepereActivite.duree(maintenant.timeIntervalSince(debut)))
                        .mesureFine().foregroundStyle(Teinte.encreEteinte)
                }
            }
            if repere.montrerOutil, let outil = activite.outil {
                HStack(spacing: Trame.serre) {
                    Text(LectureAppel.outilsConnus[outil.nom]?.libelle ?? outil.nom)
                        .legende().foregroundStyle(Teinte.encre)
                    if let chemin = outil.chemin {
                        Text(chemin).mesureFine().foregroundStyle(Teinte.encreDouce).lineLimit(1).truncationMode(.middle)
                    }
                }
            }
            if let taches = activite.taches, !taches.isEmpty {
                VStack(alignment: .leading, spacing: Trame.fin) {
                    ForEach(Array(taches.enumerated()), id: \.offset) { _, tache in
                        let etat = EtatTache(tache.etat)
                        HStack(alignment: .firstTextBaseline, spacing: Trame.serre) {
                            Text(etat.marque).mesureFine().foregroundStyle(couleur(etat))
                            Text(tache.titre).legende()
                                .foregroundStyle(etat == .fait || etat == .abandonne ? Teinte.encreEteinte : Teinte.encreDouce)
                                .strikethrough(etat == .abandonne)
                        }
                    }
                }
            }
            if let contexte = activite.contexte, contexte.total > 0 {
                ProgressView(value: Double(contexte.tokens), total: Double(contexte.total)) {
                    Text("Contexte \(contexte.tokens * 100 / contexte.total) %").mesureFine()
                        .foregroundStyle(Teinte.encreEteinte)
                }
                .tint(Teinte.accent)
            }
        }
        .padding(Trame.element)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Teinte.surface, in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Teinte.trait))
    }

    private func debit(_ valeur: Double) -> String {
        String(format: "%.1f tok/s", valeur).replacingOccurrences(of: ".", with: ",")
    }

    private func couleur(_ ton: RepereActivite.Ton) -> Color {
        switch ton {
        case .neutre: Teinte.encreDouce
        case .actif: Teinte.accent
        case .alerte: Teinte.alerte
        }
    }

    private func couleur(_ etat: EtatTache) -> Color {
        switch etat {
        case .enCours: Teinte.accent
        case .fait: Teinte.ok
        case .bloque: Teinte.alerte
        case .aFaire, .abandonne: Teinte.encreEteinte
        }
    }
}

/// Une commande lancée par l'agent : sa sortie en direct, et deux gestes tant qu'elle tourne.
struct CarteCommandeShell: View {
    let commande: CommandeShellEnDirect
    let client: ClientEchoHub
    @State private var echec: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            HStack(spacing: Trame.serre) {
                Image(systemName: "terminal").imageScale(.small).foregroundStyle(Teinte.encreDouce)
                Text(libelle).legende().foregroundStyle(Teinte.encre)
                Spacer(minLength: 0)
                if commande.etat == "en_cours" { geste("Passer en fond", .fond) }
                // Une commande passée en fond tourne encore : elle reste arrêtable, comme côté serveur.
                if commande.etat == "en_cours" || commande.etat == "en_fond" { geste("Arrêter", .arreter) }
            }
            if !commande.sortie.isEmpty {
                ScrollView(.vertical) {
                    Text(commande.sortie)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Teinte.encreDouce)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .defaultScrollAnchor(.bottom)
                .frame(maxHeight: 160)
            }
            if let echec { Text(echec).legende().foregroundStyle(Teinte.panne) }
        }
        .padding(Trame.element)
        .background(Teinte.surface, in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Teinte.trait))
    }

    private var libelle: String {
        switch commande.etat {
        case "en_cours": "Commande en cours"
        case "en_fond": "Commande passée en fond"
        case "arretee": "Commande arrêtée"
        default: commande.code.map { "Commande terminée (code \($0))" } ?? "Commande terminée"
        }
    }

    private func geste(_ titre: String, _ geste: GesteCommande) -> some View {
        Button(titre) {
            Task {
                do {
                    try await client.agirSurCommande(commande.id, geste: geste)
                    echec = nil
                } catch {
                    echec = Salon.libelle(error)
                }
            }
        }
        .buttonStyle(.appui)
        .legende()
        .foregroundStyle(geste == .arreter ? Teinte.panne : Teinte.accent)
    }
}
#endif
