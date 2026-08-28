// Section « Alerte » : l'interrupteur du maintien en vie, l'état du canal tel
// que le domaine Alerte le rapporte, et les heures calmes.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct SectionAlerte: View {
    @State private var maintienEnVie = PreferencesAlerte.maintienEnVie
    @State private var heuresCalmesActives = PreferencesAlerte.heuresCalmesActives
    @State private var heureDebut = PreferencesAlerte.heureDebut
    @State private var heureFin = PreferencesAlerte.heureFin

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            TeteDeSection("Alerte")
            Panneau {
                VStack(alignment: .leading, spacing: Trame.bloc) {
                    blocMaintienEnVie
                    FiletFin()
                    blocEtatCanal
                    FiletFin()
                    blocHeuresCalmes
                }
            }
            NavigationLink(value: Domaine.alerte) {
                HStack(spacing: Trame.serre) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("État complet du canal d'alerte")
                }
            }
            .buttonStyle(.allureDouce)
        }
    }

    // MARK: - Maintien en vie

    private var blocMaintienEnVie: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle("Maintien en vie", isOn: $maintienEnVie)
                .phrase()
                .foregroundStyle(Teinte.encre)
                .tint(Teinte.accent)
            Text("Session audio silencieuse en arrière-plan — le canal temps réel, mesuré.")
                .mention()
                .foregroundStyle(Teinte.encreTernie)
        }
        .onChange(of: maintienEnVie) { _, valeur in
            PreferencesAlerte.maintienEnVie = valeur
            // Appliqué tout de suite : attendre le prochain lancement laisserait
            // l'interrupteur mentir une soirée entière.
            if valeur {
                MaintienVie.partage.demarrer()
            } else {
                MaintienVie.partage.arreter()
            }
        }
        .sensoryFeedback(Haptique.selection, trigger: maintienEnVie)
    }

    /// Lu depuis le pont UserDefaults — `nil` tant qu'Alerte n'a rien écrit.
    @ViewBuilder private var blocEtatCanal: some View {
        if let etat = PreferencesAlerte.etatCanalConnu() {
            VStack(spacing: 0) {
                LigneCle(
                    "Session audio",
                    valeur: etat.audioActif ? "active" : "coupée",
                    teinteValeur: etat.audioActif ? Teinte.sain : Teinte.veille
                )
                LigneCle("Autorisation", valeur: etat.autorisation)
                LigneCle(
                    "Dernier contact",
                    valeur: etat.dernierContact.map { Fraicheur.texte(depuis: $0) } ?? "aucun",
                    derniere: true
                )
            }
        } else {
            Text("État non mesuré — la veille n'a pas encore démarré.")
                .mention()
                .foregroundStyle(Teinte.encreTernie)
        }
    }

    // MARK: - Heures calmes

    private var blocHeuresCalmes: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            Toggle("Heures calmes", isOn: $heuresCalmesActives)
                .phrase()
                .foregroundStyle(Teinte.encre)
                .tint(Teinte.accent)
                .onChange(of: heuresCalmesActives) { _, valeur in
                    PreferencesAlerte.heuresCalmesActives = valeur
                }
            if heuresCalmesActives {
                reglageHeures
                Text("Seuls Mandat et Échec sonnent pendant les heures calmes — une "
                    + "décision reste une décision à 3 h du matin. Le reste attend.")
                    .mention()
                    .foregroundStyle(Teinte.encreTernie)
            }
        }
        .animation(Elan.pose, value: heuresCalmesActives)
        .sensoryFeedback(Haptique.selection, trigger: heuresCalmesActives)
    }

    private var reglageHeures: some View {
        VStack(spacing: Trame.serre) {
            Stepper("Début · \(heureLisible(heureDebut))", value: $heureDebut, in: 0...23)
                .onChange(of: heureDebut) { _, valeur in PreferencesAlerte.heureDebut = valeur }
            Stepper("Fin · \(heureLisible(heureFin))", value: $heureFin, in: 0...23)
                .onChange(of: heureFin) { _, valeur in PreferencesAlerte.heureFin = valeur }
        }
        .note()
        .foregroundStyle(Teinte.encre)
    }

    private func heureLisible(_ heure: Int) -> String {
        String(format: "%02d h", heure)
    }
}
#endif
