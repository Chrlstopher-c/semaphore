// Réglages : le relais (adresse, déconnexion) et la veille (maintien en vie, santé du canal d'alerte).
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct ReglagesEcran: View {
    @Environment(Cablage.self) private var cablage
    @Environment(\.palette) private var p
    @State private var maintien = PreferencesAlerte.maintienEnVie

    var body: some View {
        NavigationStack {
            Form {
                Section("Relais") {
                    LabeledContent("Adresse", value: cablage.adresse.host() ?? cablage.adresse.absoluteString)
                    Button("Se déconnecter", role: .destructive) { cablage.deconnecter() }
                }
                Section {
                    Toggle("Veille en arrière-plan", isOn: $maintien).tint(p.accent)
                        .onChange(of: maintien) { _, actif in basculerVeille(actif) }
                } header: { Text("Veille") } footer: {
                    Text("Garde Vigie éveillée pour sonner les objectifs atteints et les questions, écran éteint.")
                }
                SanteVeille()
                Section { Text("ccremote v2 · un outil Echo Agency").font(Voix.etiquette).foregroundStyle(p.discret) }
            }
            .scrollContentBackground(.hidden)
            .background(p.fond.ignoresSafeArea())
            .navigationTitle("Réglages")
        }
        .tint(p.accent)
    }

    private func basculerVeille(_ actif: Bool) {
        PreferencesAlerte.maintienEnVie = actif
        if actif { MaintienVie.partage.demarrer() } else { MaintienVie.partage.arreter() }
    }
}

/// Ce que sait la veille d'elle-même : un canal qu'on croit vivant n'est pas un canal vivant.
private struct SanteVeille: View {
    private var etat: EtatCanal { CentreAlerte.partage.etat }

    var body: some View {
        Section("Santé de la veille") {
            LabeledContent("Notifications", value: etat.autorisation)
            LabeledContent("Dernier contact", value: etat.dernierContact.map(relatif) ?? "jamais")
            LabeledContent("Veille audio", value: etat.audioActif ? "active" : "coupée")
            LabeledContent("Réveils de fond servis", value: "\(etat.reveilsReels)")
            if let fin = etat.expirationSignature { LabeledContent("Signature valable jusqu’au", value: fin.formatted(date: .abbreviated, time: .omitted)) }
        }
    }

    private func relatif(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named, unitsStyle: .wide))
    }
}
#endif
