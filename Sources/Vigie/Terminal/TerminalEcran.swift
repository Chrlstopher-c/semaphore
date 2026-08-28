#if canImport(SwiftUI)
import Foundation
import SwiftUI
import VigieNoyau

/// Le terminal tmux — là où un client natif écrase le plus nettement Safari
/// mobile : envoyer un Ctrl-C à tmux depuis un navigateur est impossible.
public struct TerminalEcran: View {
    @Environment(\.clientPi) private var client
    @Environment(\.miroir) private var miroir
    @Environment(Cadence.self) private var cadence

    @State private var sessions: [SessionTmuxApi] = []
    @State private var releveA: Date?
    @State private var posteAbsent = false
    @State private var avertissement: String?
    @State private var feuilleNouvelle = false
    @State private var sessionATerminer: String?
    @State private var avis: String?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            entete
            corps
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Teinte.fond)
        .task { await relireLeMiroir() }
        .cadencePar("terminal") { await battre() }
        .avisFugace($avis)
        .navigationDestination(for: String.self) { nom in
            SessionEcran(nom: nom).toolbar(.hidden, for: .navigationBar)
        }
        .feuilleQuart(presentee: $feuilleNouvelle, hauteurs: [.medium]) {
            NouvelleSessionFeuille(creer: creerSession)
        }
        .confirmationDialog(
            "Terminer la session « \(sessionATerminer ?? "") » ?",
            isPresented: presenceSessionATerminer,
            titleVisibility: .visible
        ) {
            Button("Terminer", role: .destructive) {
                if let nom = sessionATerminer { Task { await terminerSession(nom) } }
            }
            Button("Annuler", role: .cancel) {}
        }
    }

    private var entete: some View {
        EnTeteEcran("Terminal", releveA: releveA) {
            Button {
                feuilleNouvelle = true
            } label: {
                Image(systemName: "plus.circle.fill")
            }
            .buttonStyle(.allureIcone)
            .foregroundStyle(Teinte.accent)
            .accessibilityLabel("Nouvelle session")
        }
    }

    private var presenceSessionATerminer: Binding<Bool> {
        Binding(
            get: { sessionATerminer != nil },
            set: { present in if !present { sessionATerminer = nil } }
        )
    }

    // MARK: - Corps

    private var corps: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Trame.element) {
                if let avertissement, !sessions.isEmpty {
                    BandeauNote(avertissement, ton: posteAbsent ? .veille : .vigilance)
                }
                contenu
            }
            .padding(.horizontal, Trame.ecran)
            .padding(.bottom, Trame.section)
        }
        .scrollIndicators(.hidden)
        .refreshable { await battre() }
    }

    @ViewBuilder private var contenu: some View {
        if !sessions.isEmpty {
            ForEach(Array(sessions.enumerated()), id: \.element.id) { rang, session in
                carte(session, rang: rang)
            }
        } else if releveA == nil, avertissement == nil {
            ForEach(0..<3, id: \.self) { rang in
                Panneau { SilhouetteAttente(lignes: [0.45, 0.7]) }
                    .entreeEnScene(rang: rang)
            }
        } else if posteAbsent {
            EtatCalme(
                symbole: "moon.zzz.fill",
                titre: "Poste éteint",
                explication: avertissement
                    ?? "Le poste ne répond pas. Les sessions réapparaîtront à son réveil."
            )
        } else if let avertissement {
            BandeauNote(avertissement, ton: .danger)
        } else {
            EtatCalme(
                symbole: "terminal.fill",
                titre: "Aucune session",
                explication: "Lance une session tmux pour ouvrir un terminal depuis ton téléphone.",
                ton: .neutre
            )
        }
    }

    private func carte(_ session: SessionTmuxApi, rang: Int) -> some View {
        NavigationLink(value: session.name) {
            CarteSession(session: session)
        }
        .buttonStyle(.allureCarte)
        .contextMenu {
            Button("Terminer la session", systemImage: "xmark.circle", role: .destructive) {
                sessionATerminer = session.name
            }
        }
        .entreeEnScene(rang: rang)
    }

    // MARK: - Relevés

    @MainActor private func relireLeMiroir() async {
        guard let donnee = await miroir.lire(SessionsPosteApi.self, .sessionsPoste) else { return }
        sessions = TriSessions.triees(donnee.valeur.sessions ?? [])
        releveA = donnee.releveA
    }

    @MainActor private func battre() async {
        switch await client.lirePoste(SessionsPosteApi.self, Route.sessionsPoste, memoriser: .sessionsPoste) {
        case .fraiche(let charge):
            sessions = TriSessions.triees(charge.sessions ?? [])
            posteAbsent = false
            avertissement = nil
            releveA = Date()
        case .pcAbsent(let message):
            posteAbsent = true
            avertissement = message
        case .refus(let message):
            posteAbsent = false
            avertissement = message
        case .echec(let erreur) where erreur.genre != .transport:
            posteAbsent = false
            avertissement = erreur.message
        case .echec:
            break // panne de transport : l'en-tête la dit déjà
        }
    }

    // MARK: - Écritures

    @MainActor private func creerSession(_ nom: String) async {
        let nomFinal = nom.trimmingCharacters(in: .whitespaces).isEmpty ? "claude" : nom
        switch await client.ordonner(OrdrePosteApi.self, Route.lancerSession(nomFinal)) {
        case .fraiche:
            feuilleNouvelle = false
            avis = "Session \(nomFinal) lancée"
            cadence.battreMaintenant("terminal")
        case .pcAbsent(let message), .refus(let message):
            avis = message
        case .echec(let erreur):
            if erreur.genre != .transport { avis = erreur.message }
        }
    }

    @MainActor private func terminerSession(_ nom: String) async {
        switch await client.ordonner(OrdrePosteApi.self, Route.tuerSession(nom)) {
        case .fraiche:
            sessions.removeAll { $0.name == nom }
            avis = "Session \(nom) terminée"
        case .pcAbsent(let message), .refus(let message):
            avis = message
        case .echec(let erreur):
            if erreur.genre != .transport { avis = erreur.message }
        }
        cadence.battreMaintenant("terminal")
    }
}
#endif
