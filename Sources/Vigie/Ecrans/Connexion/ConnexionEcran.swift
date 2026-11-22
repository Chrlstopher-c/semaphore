// Appairage (pas d'équivalent dans l'étalon, dessiné dans sa grammaire) : mot-symbole serif, adresse du nœud, code à
// usage unique affiché sur la machine, capsule blanche. Repli : mot de passe du relais.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct ConnexionEcran: View {
    @Environment(Cablage.self) private var cablage
    @State private var adresse = ""
    @State private var code = ""
    @State private var parMotDePasse = false
    @State private var envoi = false
    @State private var erreur: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Quart").font(.system(size: 40, weight: .medium, design: .serif)).foregroundStyle(Q.texte)
                    .padding(.horizontal, 32).padding(.top, 72)
                Text("Pilote les sessions Claude Code du parc depuis l’iPhone.")
                    .font(Q.rangee)
                    .foregroundStyle(Q.secondaire)
                    .padding(.horizontal, 32).padding(.top, 8)
                TitreSection(texte: "Nœud").padding(.top, 24)
                Carte {
                    champ("Adresse", texte: $adresse, clavier: .URL)
                    Filet()
                    champ(parMotDePasse ? "Mot de passe" : "Code d’appairage", texte: $code, secret: parMotDePasse)
                }
                Text(parMotDePasse
                    ? "Le mot de passe du relais."
                    : "Le code s’affiche sur la machine (10 minutes, usage unique).")
                    .font(Q.detail).foregroundStyle(Q.tertiaire).padding(.horizontal, 32).padding(.top, 8)
                if let erreur {
                    Text(erreur)
                        .font(Q.detail)
                        .foregroundStyle(Q.retraitTexte)
                        .padding(.horizontal, 32)
                        .padding(.top, 12)
                }
                actions.padding(.top, 32)
            }
        }
        .background(Q.fondFil.ignoresSafeArea())
        .onAppear { if adresse.isEmpty && cablage.adresseConnue { adresse = cablage.adresse.absoluteString } }
        .sensoryFeedback(.error, trigger: erreur) { _, e in e != nil }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button { Task { await relier() } } label: {
                Group {
                    if envoi {
                        IndicateurTravail().frame(width: 18, height: 18)
                    } else {
                        Text("Relier cet iPhone")
                    }
                }
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(Q.carte)
                    .frame(maxWidth: .infinity, minHeight: 50).background(Q.texte, in: .capsule)
            }
            .buttonStyle(StyleAppui())
            .disabled(envoi || code.isEmpty || URL(string: adresse)?.host() == nil)
            Button(parMotDePasse ? "Utiliser un code d’appairage" : "Utiliser un mot de passe") {
                parMotDePasse.toggle(); code = ""; erreur = nil
            }
            .font(Q.detail).foregroundStyle(Q.lien).frame(minHeight: 44)
        }
        .padding(.horizontal, Q.marge)
    }

    private func champ(_ titre: String, texte: Binding<String>, clavier: UIKeyboardType = .default,
                       secret: Bool = false) -> some View {
        Group {
            if secret { SecureField(titre, text: texte) } else { TextField(titre, text: texte).keyboardType(clavier) }
        }
        .font(Q.rangee).foregroundStyle(Q.texte)
        .textInputAutocapitalization(.never).autocorrectionDisabled()
        .padding(.horizontal, Q.marge).frame(height: 52)
    }

    private func relier() async {
        guard let url = URL(string: adresse.trimmingCharacters(in: .whitespaces)) else { return }
        envoi = true
        defer { envoi = false }
        do {
            if parMotDePasse {
                try await cablage.connecter(adresse: url, motDePasse: code)
            } else {
                try await cablage.appairer(adresse: url, code: code.trimmingCharacters(in: .whitespaces).uppercased())
            }
        } catch {
            erreur = (error as? ErreurRelais)?.description ?? "Connexion impossible."
        }
    }
}
#endif
