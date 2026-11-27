// La pastille d'état du moteur, comme dans l'en-tête de l'EchoHub web : vraie partout, parce que le GPU
// est exclusif (un seul modèle chargé à la fois) et que l'éjection doit rester atteignable de chaque écran.
// Sur 375 pt, le nom du modèle, le débit, l'éjection et le thème vivent dans son menu.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

/// Le thème de l'app, comme le bouton soleil/lune du web. Sombre par défaut.
public enum ThemeEchoHub: String, CaseIterable, Sendable {
    case sombre, clair

    static let cle = "echohub.theme"

    var schema: ColorScheme { self == .clair ? .light : .dark }
}

struct PastilleMoteur: View {
    @Environment(Salon.self) private var salon
    @AppStorage(ThemeEchoHub.cle) private var theme: ThemeEchoHub = .sombre

    var body: some View {
        Menu {
            Section(salon.statut.contenu?.modele.map(PhaseTour.nomCourt) ?? libelle) {
                if let debit { Text("Dernière réponse : \(debit)") }
                if etat == .pret {
                    Button(role: .destructive) {
                        Task { await salon.dechargerModele() }
                    } label: {
                        Label("Éjecter le modèle", systemImage: "eject")
                    }
                    .disabled(salon.chargementEnCours)
                }
            }
            Picker("Thème", selection: $theme) {
                Label("Sombre", systemImage: "moon").tag(ThemeEchoHub.sombre)
                Label("Clair", systemImage: "sun.max").tag(ThemeEchoHub.clair)
            }
        } label: {
            HStack(spacing: Trame.serre) {
                Circle().fill(couleur).frame(width: 7, height: 7)
                    .symbolEffect(.pulse, isActive: etat == .enCours)
                Text(salon.chargementEnCours && etat == .pret ? "Éjection…" : libelle)
                    .legende().foregroundStyle(Teinte.encre)
                if let debit, etat == .pret {
                    Text(debit).mesureFine().foregroundStyle(Teinte.encreDouce)
                }
            }
            .padding(.horizontal, Trame.element)
            .frame(height: 30)
            .background(Teinte.surface, in: .capsule)
            .overlay(Capsule().strokeBorder(Teinte.trait))
        }
        .accessibilityLabel("État du moteur : \(libelle)")
    }

    private var etat: EtatInference? { salon.statut.contenu?.etat }

    private var libelle: String {
        if case .echec = salon.statut { return "Injoignable" }
        switch etat {
        case .pret?: return "Prêt"
        case .enCours?: return "Chargement…"
        case .echoue?: return "Échec du chargement"
        case .inactif?: return "Aucun modèle"
        case nil: return "Relevé…"
        }
    }

    private var couleur: Color {
        if case .echec = salon.statut { return Teinte.encreEteinte }
        switch etat {
        case .pret?: return Teinte.ok
        case .enCours?: return Teinte.accent
        case .echoue?: return Teinte.panne
        default: return Teinte.encreEteinte
        }
    }

    /// Le débit de la dernière réponse, comme `DebitMoteur` du web hors génération.
    private var debit: String? {
        guard let valeur = salon.messages.last(where: { $0.tokensParSeconde != nil })?.tokensParSeconde
        else { return nil }
        return String(format: "%.1f tok/s", valeur).replacingOccurrences(of: ".", with: ",")
    }
}

extension View {
    /// La pastille au centre de la barre de navigation : chaque écran racine la porte.
    func pastilleMoteur() -> some View {
        toolbar {
            ToolbarItem(placement: .principal) { PastilleMoteur() }
        }
    }
}
#endif
