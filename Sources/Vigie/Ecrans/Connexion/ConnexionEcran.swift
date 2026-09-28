// Se connecter au relais : adresse + mot de passe, échangés contre un jeton d'appareil gardé dans le trousseau.
#if canImport(SwiftUI)
import SwiftUI

struct ConnexionEcran: View {
    @Environment(Cablage.self) private var cablage
    @Environment(\.palette) private var p
    @State private var adresse = ""
    @State private var motDePasse = ""
    @State private var erreur: String?
    @State private var envoi = false

    var body: some View {
        VStack(alignment: .leading, spacing: Espace.xl) {
            Spacer()
            VStack(alignment: .leading, spacing: Espace.s) {
                Surtitre(texte: "Sessions Claude Code")
                Text("Vigie").font(.custom("Manrope", size: 44).weight(.heavy)).tracking(-2).foregroundStyle(p.encre)
                Text("Toutes les sessions du parc, depuis le téléphone.").font(Voix.courant).foregroundStyle(p.encreDouce)
            }
            champs
            if let erreur { BandeauErreur(texte: erreur) { self.erreur = nil } }
            Button(envoi ? "Connexion…" : "Se connecter") { Task { await connecter() } }
                .buttonStyle(StyleBoutonPlein())
                .frame(maxWidth: .infinity)
                .disabled(envoi || motDePasse.isEmpty)
            Spacer()
            Text("un outil Echo Agency").font(Voix.etiquette).foregroundStyle(p.discret).frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Espace.marge)
        .background(p.fond.ignoresSafeArea())
        .onAppear { if adresse.isEmpty { adresse = cablage.adresse.absoluteString } }
        .sensoryFeedback(.error, trigger: erreur)
    }

    private var champs: some View {
        VStack(spacing: Espace.m) {
            ChampSaisie(libelle: "Adresse du relais", texte: $adresse, clavier: .URL)
            ChampSaisie(libelle: "Mot de passe", texte: $motDePasse, secret: true)
        }
    }

    private func connecter() async {
        guard let url = URL(string: adresse.trimmingCharacters(in: .whitespaces)) else {
            erreur = "Adresse invalide."
            return
        }
        envoi = true
        defer { envoi = false }
        do {
            try await cablage.connecter(adresse: url, motDePasse: motDePasse)
        } catch {
            erreur = "\(error)"
        }
    }
}

struct ChampSaisie: View {
    @Environment(\.palette) private var p
    let libelle: String
    @Binding var texte: String
    var clavier: UIKeyboardType = .default
    var secret = false

    var body: some View {
        VStack(alignment: .leading, spacing: Espace.xs) {
            Text(libelle).font(Voix.petit.weight(.bold)).foregroundStyle(p.encreDouce)
            Group {
                if secret { SecureField("", text: $texte) } else { TextField("", text: $texte).keyboardType(clavier) }
            }
            .font(.system(size: 16)) // 16 pt : iOS ne zoome pas sur le champ
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .padding(.horizontal, Espace.m).frame(height: 48)
            .background(RoundedRectangle(cornerRadius: Rayon.controle, style: .continuous).fill(p.surface))
            .overlay(RoundedRectangle(cornerRadius: Rayon.controle, style: .continuous).strokeBorder(p.filet))
        }
    }
}
#endif
