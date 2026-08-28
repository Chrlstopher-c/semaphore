// L'écran caché : ce que l'appareil accorde réellement, mesuré à l'ouverture.
// On y arrive par un appui long sur la ligne de version des Réglages — jamais
// par un bouton visible, ce n'est pas un écran de produit.
#if canImport(SwiftUI)
import SwiftUI
import UserNotifications
import VigieNoyau

struct DiagnosticEcran: View {
    @Environment(\.miroir) private var miroir

    @State private var releve = ReleveChaine()
    @State private var maintien = MaintienVie.partage
    @State private var essaiPose: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Trame.section) {
                entete
                bloc("Notifications", releve.notifications)
                bloc("Maintien en vie", lignesMaintien)
                bloc("Stockage", releve.stockage)
                bloc("Environnement", releve.environnement)
                essaiDeLocale
            }
            .padding(Trame.ecran)
        }
        .scrollIndicators(.hidden)
        .task { await relever() }
        .refreshable { await relever() }
    }

    private var entete: some View {
        VStack(alignment: .leading, spacing: Trame.fin) {
            Text("Diagnostic")
                .titreFeuille()
                .foregroundStyle(Teinte.encre)
            Text("Relevé de l'appareil, pas une table de documentation. Tire pour "
                + "refaire la mesure.")
                .mention()
                .foregroundStyle(Teinte.encreTernie)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bloc(_ titre: String, _ lignes: [LigneSonde]) -> some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            TeteDeSection(titre)
            Panneau {
                VStack(spacing: 0) {
                    ForEach(Array(lignes.enumerated()), id: \.element.id) { rang, ligne in
                        LigneCle(
                            ligne.intitule,
                            valeur: ligne.verdict,
                            teinteValeur: ligne.ton == .neutre ? Teinte.encre : ligne.ton.teinte,
                            derniere: rang == lignes.count - 1
                        )
                    }
                }
            }
        }
    }

    /// Lu en direct sur l'objet partagé : ces compteurs bougent pendant qu'on
    /// regarde l'écran, et c'est précisément ce qu'on veut voir.
    private var lignesMaintien: [LigneSonde] {
        [
            LigneSonde("Session audio", maintien.statut, maintien.actif ? .sain : .vigilance),
            LigneSonde("Interruptions", "\(maintien.interruptions)"),
            LigneSonde("Reprises", "\(maintien.reprises)"),
            LigneSonde(
                "Dernier incident",
                maintien.dernierIncident ?? "aucun",
                maintien.dernierIncident == nil ? .neutre : .vigilance
            ),
        ]
    }

    // MARK: - Essai de pose

    /// `☠` Le seul essai qui compte vraiment : une locale posée depuis cet
    /// écran, à voir arriver écran verrouillé. Dix secondes laissent le temps
    /// de verrouiller le téléphone.
    private var essaiDeLocale: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            TeteDeSection("Essai")
            Button("Poser une locale dans 10 s") {
                Task { await poserUneLocale() }
            }
            .buttonStyle(.allureDouce)
            if let essaiPose {
                Text(essaiPose)
                    .note()
                    .foregroundStyle(Teinte.encreDouce)
            }
        }
    }

    private func poserUneLocale() async {
        let centre = UNUserNotificationCenter.current()
        let contenu = UNMutableNotificationContent()
        contenu.title = "Essai de chaîne"
        contenu.body = "Posée depuis le diagnostic. Si tu lis ceci écran verrouillé, "
            + "la pose de locales fonctionne."
        contenu.sound = .default
        let requete = UNNotificationRequest(
            identifier: "diagnostic.essai",
            content: contenu,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        )
        do {
            try await centre.add(requete)
            essaiPose = "Posée. Verrouille l'écran."
        } catch {
            Trace.erreur("diagnostic", "pose de la locale d'essai refusée", error)
            essaiPose = "Refusée : \(error.localizedDescription)"
        }
    }

    private func relever() async {
        releve = await SondeChaine.relever(miroir: miroir)
    }
}
#endif
