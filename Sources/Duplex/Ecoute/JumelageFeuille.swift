// La saisie du code à six chiffres affiché par le PC. Première rencontre
// seulement : ensuite, le jeton conservé fait sauter cette étape.
//
// Rendu sobre, jetons du socle uniquement — la direction artistique viendra après.
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
                champ
                if let restants = duplexeur.essaisRestants { avertissement(restants) }
                bouton
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Grille.ecran)
            .padding(.vertical, Grille.section)
        }
    }

    private var entete: some View {
        VStack(alignment: .leading, spacing: Grille.serre) {
            Text("Jumeler")
                .font(Voix.titreEcran)
                .foregroundStyle(Neutre.encre)
            Text("""
                \(duplexeur.nomPoste ?? "Le PC") affiche un code à six chiffres. \
                Recopie-le ici — une seule fois, ce PC sera reconnu ensuite.
                """)
                .font(Voix.note)
                .foregroundStyle(Neutre.encreDouce)
        }
    }

    private var champ: some View {
        TextField("000000", text: $code)
            .textFieldStyle(.plain)
            .font(Voix.titreSection)
            .foregroundStyle(Neutre.encre)
            .tint(Teinte.accent)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .padding(Grille.bloc)
            .background(Neutre.surfaceHaute)
            .clipShape(.rect(cornerRadius: Rayon.controle, style: .continuous))
            .onChange(of: code) { _, nouveau in
                // Le champ ne garde que des chiffres, et jamais plus de six : la
                // machine refuserait un code mal formé sans rien dire, et Chris
                // croirait avoir tapé juste.
                let propre = String(nouveau.filter(\.isNumber).prefix(Cadence.longueurCode))
                if propre != nouveau { code = propre }
            }
    }

    private func avertissement(_ restants: Int) -> some View {
        Text(restants > 1
            ? "Code refusé. Encore \(restants) essais."
            : "Code refusé. Dernier essai avant que le PC ferme la connexion.")
            .font(Voix.note)
            .foregroundStyle(Semantique.alerte)
    }

    private var bouton: some View {
        Button {
            Task { await duplexeur.saisirCode(code) }
        } label: {
            Text(duplexeur.etape == .codeEnVerification ? "Vérification…" : "Valider")
                .font(Voix.entete)
                .foregroundStyle(Neutre.fond)
                .frame(maxWidth: .infinity, minHeight: Grille.cible)
                .background(pret ? Teinte.accent : Neutre.surfaceHaute)
                .clipShape(.rect(cornerRadius: Rayon.controle, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!pret)
    }

    private var pret: Bool {
        code.count == Cadence.longueurCode && duplexeur.etape != .codeEnVerification
    }
}
#endif
