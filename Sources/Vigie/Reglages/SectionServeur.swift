// Section « Serveur » : adresse du Pi, état de la liaison, déconnexion.
// L'adresse est adossée à `Cablage.changerAdresse` — jamais une copie locale
// de la logique déjà écrite pour l'écran de connexion.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct SectionServeur: View {
    @Environment(Cablage.self) private var cablage
    @Environment(Liaison.self) private var liaison
    @Environment(\.clientPi) private var client

    @State private var adresse = ""
    @State private var erreur: String?
    @State private var enCours = false
    let avis: @MainActor (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            TeteDeSection("Serveur") {
                PastilleLiaison()
            }
            Panneau {
                VStack(alignment: .leading, spacing: Trame.bloc) {
                    champAdresse
                    raccourcis
                    if let erreur { BandeauNote(erreur, ton: .danger) }
                    boutonAppliquer
                    FiletFin()
                    precisionLiaison
                    boutonDeconnexion
                }
            }
        }
        .onAppear { adresse = cablage.adresse.absoluteString }
    }

    private var champAdresse: some View {
        ChampQuart(
            "Adresse du Pi",
            texte: $adresse,
            placebo: "https://…",
            aide: "Tunnel Cloudflare par défaut. Bascule sur l'adresse LAN quand il est coupé."
        )
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .keyboardType(.URL)
    }

    /// Les deux adresses du produit : le tunnel de `deploy-web-pi.sh`, et le
    /// repli LAN — saisissable ici et sur l'écran de connexion, nulle part
    /// ailleurs.
    private var raccourcis: some View {
        HStack(spacing: Trame.serre) {
            Button("Tunnel par défaut") { adresse = Cablage.adresseParDefaut.absoluteString }
                .buttonStyle(.allurePuce)
            Button("Repli LAN") { adresse = "http://10.0.0.2:8766" }
                .buttonStyle(.allurePuce)
        }
    }

    private var boutonAppliquer: some View {
        Button(enCours ? "Application…" : "Appliquer l'adresse") {
            Task { await appliquer() }
        }
        .buttonStyle(.allureDouce)
        .disabled(enCours || adresse.isEmpty)
    }

    @ViewBuilder private var precisionLiaison: some View {
        if let precision = liaison.precision {
            Text(precision)
                .mention()
                .foregroundStyle(Teinte.encreTernie)
        }
    }

    /// `☠` Efface le jeton du trousseau ET le miroir (`fermerSession`) : le
    /// miroir porte des titres de projets, il ne survit pas à une session
    /// close. Maintien armé — le geste destructif engageant de la charte.
    private var boutonDeconnexion: some View {
        BoutonArme("Maintenir pour fermer la session", libelleArme: "Déconnexion…") {
            Task {
                await client.fermerSession()
                liaison.exigerSession()
            }
        }
    }

    private func appliquer() async {
        let propre = adresse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: propre), url.scheme != nil, url.host != nil else {
            erreur = "Adresse inutilisable."
            return
        }
        erreur = nil
        enCours = true
        if url != cablage.adresse {
            await cablage.changerAdresse(url)
        }
        enCours = false
        avis("Adresse appliquée")
    }
}
#endif
