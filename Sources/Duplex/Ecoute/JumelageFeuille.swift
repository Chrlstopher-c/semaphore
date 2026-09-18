// La saisie du code à six chiffres affiché par le PC. Première rencontre
// seulement : ensuite, le jeton conservé fait sauter cette étape.
#if canImport(SwiftUI)
import DuplexNoyau
import SwiftUI
import Systeme

struct JumelageFeuille: View {
    @Environment(Duplexeur.self) private var duplexeur
    /// Le champ appartient à la vue, jamais au duplexeur : c'est un état
    /// d'interface, et le laisser traîner dans la logique le ferait survivre à
    /// la fermeture de la feuille.
    @State private var code = ""

    var body: some View {
        ZStack {
            Neutre.fond.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Grille.groupe) {
                entete
                ChampCode(code: $code, actif: !verification)
                if let restants = duplexeur.essaisRestants {
                    avertissement(restants).transition(.item)
                }
                bouton
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Grille.ecran)
            .padding(.top, Grille.section)
            .padding(.bottom, Grille.groupe)
            .animation(Mouvement.normal, value: duplexeur.essaisRestants)
        }
        // Un refus vide le champ : retaper par-dessus six chiffres faux, c'est
        // d'abord les effacer un à un. La butée dit que le PC a répondu non.
        .onChange(of: duplexeur.essaisRestants) { _, restants in
            if restants != nil { code = "" }
        }
        .sensoryFeedback(Toucher.butee, trigger: duplexeur.essaisRestants) { _, restants in restants != nil }
    }

    private var entete: some View {
        VStack(alignment: .leading, spacing: Grille.serre) {
            Text("Jumelage").rubrique()
            Text(duplexeur.nomPoste ?? "Le PC")
                .font(Voix.titreEcran)
                .foregroundStyle(Neutre.encre)
            Text("Recopie le code à six chiffres affiché sur son écran. Une seule fois : ce PC sera reconnu ensuite.")
                .font(Voix.note)
                .foregroundStyle(Neutre.encreDouce)
        }
    }

    private func avertissement(_ restants: Int) -> some View {
        Bandeau(
            "Code refusé.",
            remede: restants > 1
                ? "Encore \(restants) essais."
                : "Dernier essai avant que le PC ferme la connexion.",
            ton: .alerte
        )
    }

    private var bouton: some View {
        Button {
            Task { await duplexeur.saisirCode(code) }
        } label: {
            if verification {
                ProgressView().tint(Neutre.encreDouce)
            } else {
                Text("Valider")
            }
        }
        .buttonStyle(.engage)
        .disabled(!pret)
        .sensoryFeedback(Toucher.engage, trigger: verification) { _, enCours in enCours }
    }

    private var verification: Bool {
        duplexeur.etape == .codeEnVerification
    }

    private var pret: Bool {
        code.count == Cadence.longueurCode && !verification
    }
}
#endif
