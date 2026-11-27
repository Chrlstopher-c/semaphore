// L'espace de travail de l'agent (`EspaceTravail.tsx` du web) : sur 375 pt, ses panneaux deviennent des segments
// d'une feuille — plan de l'agent, aperçu de l'app, terminal, moteur, fenêtre de contexte.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct EspaceTravailFeuille: View {
    enum Panneau: String, CaseIterable { case agent = "Agent", apercu = "Aperçu", terminal = "Terminal", moteur = "Moteur", contexte = "Contexte" }

    @Environment(Salon.self) private var salon
    @Environment(\.dismiss) private var fermer
    @State private var panneau: Panneau = .agent

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Panneau", selection: $panneau) {
                    ForEach(Panneau.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(Trame.ecran)
                Group {
                    switch panneau {
                    case .agent: PanneauAgent()
                    case .apercu: PanneauApercu()
                    case .terminal: PanneauTerminal()
                    case .moteur: ScrollView { CarteStatut(etat: salon.statut).padding(Trame.ecran) }
                    case .contexte: PanneauContexte()
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .background(Teinte.fond)
            .navigationTitle("Espace de travail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("OK") { fermer() } } }
        }
    }
}

private struct PanneauAgent: View {
    @Environment(Salon.self) private var salon

    var body: some View {
        if salon.dernierPlan.isEmpty {
            Vide(texte: "L'agent n'a pas encore posé de plan dans cette session.")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Trame.element) {
                    if salon.activite == nil { Text("Dernier plan connu").rubrique() }
                    ListePlan(taches: salon.dernierPlan)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Trame.ecran)
            }
        }
    }
}

private struct PanneauApercu: View {
    @Environment(Salon.self) private var salon
    @State private var requete: URLRequest?
    @State private var message: String?
    @State private var rechargement = 0

    var body: some View {
        Group {
            if let requete {
                ApercuWeb(requete: requete, rechargement: rechargement)
                    .overlay(alignment: .topTrailing) {
                        Button { rechargement += 1 } label: { Image(systemName: "arrow.clockwise") }
                            .buttonStyle(.bordered).padding(Trame.element)
                            .accessibilityLabel("Recharger")
                    }
            } else {
                Vide(texte: message ?? "Recherche de l'app de l'agent…")
            }
        }
        .task(id: salon.conversation?.projet) { await charger() }
    }

    private func charger() async {
        guard let projet = salon.conversation?.projet else {
            requete = nil
            message = "Aucun projet lié : l'aperçu montre l'app que l'agent lance dans son projet."
            return
        }
        do {
            let etat = try await salon.projets.apercu(projet)
            guard let port = etat.port ?? etat.ports.first else {
                requete = nil
                message = "Aucune app ne tourne dans l'atelier pour l'instant."
                return
            }
            requete = try await salon.client.requeteApercu(atelier: port)
        } catch {
            requete = nil
            message = Salon.libelle(error)
        }
    }
}

private struct PanneauTerminal: View {
    @Environment(Salon.self) private var salon

    var body: some View {
        let journal = JournalCommandes.lire(
            salon.messages.filter { $0.role == .assistant }.map(\.contenu) + (salon.enCours.map { [$0.texte] } ?? []),
            actif: salon.enCours != nil
        )
        if journal.isEmpty {
            Vide(texte: "Aucune commande lancée par l'agent dans cette session.")
        } else {
            ScrollViewReader { lecteur in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Trame.element) {
                        ForEach(Array(journal.enumerated()), id: \.offset) { rang, ligne in
                            VStack(alignment: .leading, spacing: Trame.fin) {
                                Text((ligne.python ? ">>> " : "$ ") + ligne.commande)
                                    .font(Typo.brut).foregroundStyle(Teinte.accent)
                                if !ligne.sortie.isEmpty {
                                    Text(ligne.sortie).font(Typo.brut).foregroundStyle(Teinte.encreDouce)
                                        .textSelection(.enabled)
                                }
                            }
                            .id(rang)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Trame.ecran)
                }
                .onAppear { lecteur.scrollTo(journal.count - 1, anchor: .bottom) }
            }
        }
    }
}

private struct PanneauContexte: View {
    @Environment(Salon.self) private var salon

    var body: some View {
        if let occupation = salon.occupation, occupation.mesurable {
            List {
                Section {
                    LabeledContent("Utilisés", value: milliers(occupation.tokensMesures))
                    LabeledContent("Fenêtre", value: milliers(occupation.contexteTotal))
                    LabeledContent("Libres", value: milliers(occupation.tokensLibres))
                    if let depassement = occupation.depassementTokens, depassement > 0 {
                        LabeledContent("Au-delà", value: milliers(depassement)).foregroundStyle(Teinte.panne)
                    }
                }
                Section("Par poste") {
                    ForEach(occupation.postes, id: \.poste) { part in
                        VStack(alignment: .leading, spacing: Trame.fin) {
                            HStack {
                                Text(Self.libelles[part.poste] ?? part.poste)
                                Spacer()
                                Text(milliers(part.tokens)).mesureFine().foregroundStyle(Teinte.encreDouce)
                            }
                            ProgressView(value: min(part.part, 1)).tint(Teinte.accent)
                        }
                    }
                }
                if !occupation.avertissements.isEmpty {
                    Section("Avertissements") {
                        ForEach(occupation.avertissements, id: \.self) { Text($0).foregroundStyle(Teinte.alerte) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        } else {
            Vide(texte: salon.occupation?.raison ?? "Mesurée à la fin du prochain tour.")
        }
    }

    static let libelles = [
        "systeme": "Consignes système", "utilisateur": "Messages de Chris", "images": "Images",
        "raisonnement": "Réflexion", "assistant": "Réponses", "libre": "Libre",
    ]

    private func milliers(_ valeur: Int?) -> String {
        guard let valeur else { return "—" }
        return valeur >= 1000 ? "\(valeur / 1000) k" : "\(valeur)"
    }
}

private struct Vide: View {
    let texte: String

    var body: some View {
        Text(texte).font(Typo.corps).foregroundStyle(Teinte.encreDouce)
            .multilineTextAlignment(.center).padding(Trame.bloc)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
