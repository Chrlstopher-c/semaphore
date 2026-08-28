#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

/// Le détail d'une session tmux : la capture du panneau rafraîchie à 400 ms
/// tant que l'écran est regardé, le composeur, et la barre de touches.
///
/// `☠` Régime `.generation` : le seul autre endroit de l'app, avec un fil en
/// train de générer, où quelqu'un regarde l'écran changer en direct. Le
/// désabonnement est automatique en quittant l'écran (`cadencePar`).
struct SessionEcran: View {
    let nom: String

    @Environment(\.clientPi) private var client
    @Environment(\.miroir) private var miroir
    @Environment(Cadence.self) private var cadence
    @Environment(\.dismiss) private var fermer

    @State private var captureEpuree = ""
    @State private var releveA: Date?
    @State private var posteAbsent = false
    @State private var avertissement: String?
    @State private var saisie = ""
    @State private var enEnvoi = false
    @State private var ctrlArme = false
    @State private var colleBas = true
    @State private var confirmationTerminer = false
    @State private var avis: String?

    private static let ancreBas = "terminal.bas"
    private static let seuilColle: CGFloat = 48

    private var identifiantCadence: String { "terminal.session.\(nom)" }

    var body: some View {
        VStack(spacing: 0) {
            entete
            panneauCapture
            composeur
        }
        .background(Teinte.fond)
        .task { await relireLeMiroir() }
        .cadencePar(identifiantCadence, regime: .generation) { await battre() }
        .avisFugace($avis)
        .confirmationDialog(
            "Terminer la session « \(nom) » ?",
            isPresented: $confirmationTerminer,
            titleVisibility: .visible
        ) {
            Button("Terminer", role: .destructive) { Task { await terminerEtRevenir() } }
            Button("Annuler", role: .cancel) {}
        }
    }

    private var entete: some View {
        EnTeteEcran(nom, releveA: releveA, retour: true) {
            Button {
                confirmationTerminer = true
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.allureIcone)
            .foregroundStyle(Teinte.danger)
            .accessibilityLabel("Terminer la session")
        }
    }

    // MARK: - Capture

    private var panneauCapture: some View {
        ScrollViewReader { defilement in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    contenuCapture
                    Color.clear.frame(height: 1).id(Self.ancreBas)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Teinte.terminalFond)
            .onScrollGeometryChange(for: CGFloat.self) { geometrie in
                geometrie.contentSize.height - geometrie.contentOffset.y - geometrie.containerSize.height
            } action: { _, distance in
                colleBas = distance < Self.seuilColle
            }
            .onChange(of: captureEpuree) { _, _ in
                guard colleBas else { return }
                defilement.scrollTo(Self.ancreBas, anchor: .bottom)
            }
            .overlay(alignment: .bottomTrailing) { boutonRetourBas(defilement) }
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder private var contenuCapture: some View {
        if captureEpuree.isEmpty, releveA == nil {
            silhouette
        } else if captureEpuree.isEmpty {
            panneauVide
        } else {
            Text(captureEpuree)
                .texteTerminal()
                .foregroundStyle(Teinte.terminalTexte)
                .textSelection(.enabled)
                .padding(Trame.element)
        }
    }

    /// Des barres qui respirent dans les teintes du terminal — jamais un
    /// tourniquet sur ce fond presque noir.
    private var silhouette: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array([0.7, 0.45, 0.85, 0.3, 0.6].enumerated()), id: \.offset) { _, part in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Teinte.terminalTexte.opacity(0.12))
                    .frame(width: 220 * part, height: 11)
            }
        }
        .padding(Trame.ecran)
    }

    private var panneauVide: some View {
        VStack(spacing: Trame.element) {
            Image(systemName: "terminal")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Teinte.terminalTexte.opacity(0.4))
            Text("Panneau vide")
                .note()
                .foregroundStyle(Teinte.terminalTexte.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    /// Même pastille que dans un fil — un seul geste « redescendre » dans toute
    /// l'application. Le seuil, lui, reste propre à l'écran : ici la capture
    /// vaut pour son bas, et décoller de quelques lignes suffit à vouloir y
    /// revenir.
    @ViewBuilder private func boutonRetourBas(_ defilement: ScrollViewProxy) -> some View {
        if !colleBas, !captureEpuree.isEmpty {
            RetourAuBas(intitule: "Revenir au bas du panneau") {
                defilement.scrollTo(Self.ancreBas, anchor: .bottom)
                colleBas = true
            }
            .padding(Trame.element)
        }
    }

    // MARK: - Composeur

    private var composeur: some View {
        VStack(spacing: 0) {
            if let avertissement {
                BandeauNote(avertissement, ton: posteAbsent ? .veille : .vigilance)
                    .padding(.horizontal, Trame.ecran)
                    .padding(.top, Trame.serre)
            }
            ligneSaisie
            BarreTouches(
                ctrlArme: ctrlArme,
                basculerCtrl: { ctrlArme.toggle() },
                envoyer: { sequence in
                    ctrlArme = false
                    await envoyer(sequence)
                }
            )
        }
        .background(Teinte.fond)
        .animation(Elan.pose, value: avertissement)
    }

    private var ligneSaisie: some View {
        HStack(alignment: .bottom, spacing: Trame.serre) {
            ChampQuart(texte: $saisie, placebo: "Commande…", lignes: 1...4, fonte: Typo.donnee)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button {
                Task { await envoyerCommande() }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Teinte.encreSurAccent)
                    .frame(width: 38, height: 38)
                    .background(saisieVide ? Teinte.surfaceHaute : Teinte.accent, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(saisieVide || enEnvoi)
            .accessibilityLabel("Envoyer la commande")
        }
        .padding(.horizontal, Trame.ecran)
        .padding(.vertical, Trame.serre)
    }

    private var saisieVide: Bool {
        saisie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Relevés et écritures

    @MainActor private func relireLeMiroir() async {
        guard let donnee = await miroir.lire(CapturePosteApi.self, .capture(session: nom)) else { return }
        appliquer(donnee.valeur)
        releveA = donnee.releveA
    }

    @MainActor private func battre() async {
        let lecture = await client.lirePoste(
            CapturePosteApi.self, Route.capturerSession(nom), memoriser: .capture(session: nom)
        )
        switch lecture {
        case .fraiche(let charge):
            appliquer(charge)
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

    private func appliquer(_ charge: CapturePosteApi) {
        guard let sortie = charge.output else { return }
        captureEpuree = EpurationAnsi.epurer(sortie)
    }

    @MainActor private func envoyerCommande() async {
        guard !saisieVide, !enEnvoi else { return }
        let texte = saisie
        saisie = ""
        ctrlArme = false
        enEnvoi = true
        await envoyer(texte)
        enEnvoi = false
    }

    /// `☠` Le serveur ajoute TOUJOURS Entrée après 200 ms : une touche de la
    /// barre valide autant qu'une commande tapée.
    @MainActor private func envoyer(_ octets: String) async {
        guard !octets.isEmpty else { return }
        switch await client.ordonner(OrdrePosteApi.self, Route.envoyerAuTerminal(nom), ["keys": .texte(octets)]) {
        case .fraiche:
            break
        case .pcAbsent(let message), .refus(let message):
            avis = message
        case .echec(let erreur) where erreur.genre != .transport:
            avis = erreur.message
        case .echec:
            break
        }
        cadence.battreMaintenant(identifiantCadence)
    }

    @MainActor private func terminerEtRevenir() async {
        _ = await client.ordonner(OrdrePosteApi.self, Route.tuerSession(nom))
        fermer()
    }
}
#endif
