#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

/// L'écran de session : le mot de passe, et l'adresse du Pi.
///
/// L'adresse est ici et pas seulement dans les réglages, parce que c'est le
/// seul écran atteignable quand rien ne répond : un tunnel Cloudflare coupé se
/// contourne en basculant sur l'adresse LAN — encore faut-il pouvoir la saisir
/// sans passer par un écran qui exige une session.
public struct EcranConnexion: View {
    @Environment(Cablage.self) private var cablage
    @Environment(Liaison.self) private var liaison
    @Environment(\.clientPi) private var client

    @State private var motDePasse = ""
    @State private var adresse = ""
    @State private var erreur: String?
    @State private var enCours = false
    @FocusState private var focusMotDePasse: Bool

    public init() {}

    public var body: some View {
        ZStack {
            Teinte.fond.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Trame.section) {
                    frontispice
                    formulaire
                }
                .padding(.horizontal, Trame.ecran)
                .padding(.top, Trame.section * 2)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .rendLeClavier()
        .onAppear {
            adresse = cablage.adresse.absoluteString
            focusMotDePasse = true
        }
    }

    private var frontispice: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            HStack(spacing: Trame.element) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(Teinte.accent)
                Text("Vigie")
                    .font(.system(size: 40, weight: .semibold, design: .serif))
                    .foregroundStyle(Teinte.encre)
            }
            Text("Le Pi demande le mot de passe de l'interface. Il est retenu "
                + "par le trousseau : cette saisie est la seule.")
                .note()
                .foregroundStyle(Teinte.encreDouce)
        }
        .entreeEnScene()
    }

    private var formulaire: some View {
        Panneau {
            VStack(alignment: .leading, spacing: Trame.bloc) {
                ChampQuart(
                    "Adresse du Pi",
                    texte: $adresse,
                    placebo: "https://…",
                    aide: "Tunnel par défaut. Bascule sur l'adresse LAN quand il est coupé."
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)

                champMotDePasse
                if let erreur { BandeauNote(erreur, ton: .danger) }
                bouton
            }
        }
        .entreeEnScene(rang: 1)
    }

    private var champMotDePasse: some View {
        VStack(alignment: .leading, spacing: Trame.fin + 1) {
            Text("Mot de passe")
                .insigne()
                .foregroundStyle(Teinte.encreDouce)
            SecureField("", text: $motDePasse)
                .textContentType(.password)
                .focused($focusMotDePasse)
                .phrase()
                .foregroundStyle(Teinte.encre)
                .tint(Teinte.accent)
                .padding(.horizontal, Trame.element)
                .padding(.vertical, Trame.serre + 2)
                .background(
                    Teinte.fondCreux,
                    in: RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous)
                        .strokeBorder(
                            focusMotDePasse ? Teinte.accent.opacity(0.6) : Teinte.filetAppuye,
                            lineWidth: Trame.trait
                        )
                )
                .animation(Elan.vif, value: focusMotDePasse)
                .onSubmit { Task { await ouvrir() } }
        }
    }

    private var bouton: some View {
        Button {
            Task { await ouvrir() }
        } label: {
            HStack(spacing: Trame.serre) {
                if enCours { SouffleActivite(teinte: Teinte.encreSurAccent) }
                Text(enCours ? "Ouverture…" : "Ouvrir la session")
            }
        }
        .buttonStyle(.allureAccent)
        .disabled(enCours || motDePasse.isEmpty)
        .opacity(motDePasse.isEmpty ? 0.55 : 1)
    }

    // MARK: - Logique (inchangée)

    private func ouvrir() async {
        guard !enCours, !motDePasse.isEmpty else { return }
        enCours = true
        erreur = nil
        guard await appliquerAdresse() else {
            enCours = false
            return
        }
        switch await client.ouvrirSession(motDePasse: motDePasse) {
        case .success:
            motDePasse = ""
            liaison.sessionOuverte()
        case .failure(let refus):
            erreur = refus.message
        }
        enCours = false
    }

    /// L'adresse est appliquée AVANT la tentative : sans ça, corriger l'adresse
    /// puis appuyer sur « Ouvrir » enverrait la requête à l'ancienne.
    private func appliquerAdresse() async -> Bool {
        let propre = adresse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: propre), url.scheme != nil, url.host != nil else {
            erreur = "Adresse du Pi inutilisable."
            return false
        }
        guard url != cablage.adresse else { return true }
        await cablage.changerAdresse(url)
        return true
    }
}
#endif
