// La vue Système du web (`EcranSysteme.tsx`) en deux écrans : la machine (profil matériel, services) et les
// moteurs (llama.cpp, vLLM, installation d'une version en direct).
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct ProfilServicesEcran: View {
    @Environment(Salon.self) private var salon
    @State private var profil: ValeurJSON?
    @State private var services: [ServicePile] = []
    @State private var echec: String?

    var body: some View {
        PageAtelier("Machine et services", rafraichir: charger) {
            if let echec { EchecAction(raison: echec) }
            if let profil { materiel(profil) }
            if !services.isEmpty {
                SectionAtelier("Services") {
                    VStack(alignment: .leading, spacing: Trame.element) {
                        ForEach(services) { service in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: Trame.fin) {
                                    Text(service.nom).mention().foregroundStyle(Teinte.encre)
                                    Text(service.role).legende().foregroundStyle(Teinte.encreDouce)
                                    if let detail = service.detail {
                                        Text(detail).mesureFine().foregroundStyle(Teinte.encreEteinte).lineLimit(2)
                                    }
                                }
                                Spacer(minLength: 0)
                                Sceau(service.etat).ton(service.etat == "ok" ? .ok : .panne)
                            }
                        }
                    }
                }
            }
        }
        // Le web rafraîchit les services toutes les 15 s.
        .task {
            while !Task.isCancelled {
                await charger()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    @ViewBuilder private func materiel(_ profil: ValeurJSON) -> some View {
        SectionAtelier("Matériel") {
            VStack(alignment: .leading, spacing: Trame.serre) {
                if let gpu = profil["gpu_principal"], let nom = gpu["nom"]?.texteOuNil {
                    Text(nom).mention().foregroundStyle(Teinte.encre)
                    if let totale = gpu["vram_totale_octets"]?.entierOuNil, let libre = gpu["vram_libre_octets"]?.entierOuNil {
                        Jauge(part: totale > 0 ? Double(totale - libre) / Double(totale) : nil)
                        LigneMesure(libelle: "VRAM", valeur: "\(Mesures.octets(libre)) libres sur \(Mesures.octets(totale))")
                    }
                    if let charge = gpu["utilisation_pct"]?.entierOuNil { LigneMesure(libelle: "Charge GPU", valeur: "\(charge) %") }
                    if let degres = gpu["temperature_c"]?.entierOuNil { LigneMesure(libelle: "Température", valeur: "\(degres) °C") }
                    if let sm = gpu["architecture_sm"]?.texteOuNil { LigneMesure(libelle: "Architecture", valeur: sm) }
                } else {
                    Text("Aucun GPU mesuré.").note().foregroundStyle(Teinte.encreDouce)
                }
                if let totale = profil.chemin("memoire", "totale_octets")?.entierOuNil,
                   let dispo = profil.chemin("memoire", "disponible_octets")?.entierOuNil {
                    LigneMesure(libelle: "RAM", valeur: "\(Mesures.octets(dispo)) disponibles sur \(Mesures.octets(totale))")
                }
                if let pilote = profil.chemin("pilote", "version")?.texteOuNil { LigneMesure(libelle: "Pilote", valeur: pilote) }
                if let plateforme = profil["plateforme"]?.texteOuNil { LigneMesure(libelle: "Plateforme", valeur: plateforme) }
                ForEach((profil["avertissements"]?.listeOuNil ?? []).compactMap(\.texteOuNil), id: \.self) {
                    Text($0).legende().foregroundStyle(Teinte.alerte)
                }
            }
        }
    }

    private func charger() async {
        do {
            profil = try await salon.modeles.profilMachine()
            services = try await DepotSysteme(client: salon.client).services()
            echec = nil
        } catch {
            echec = Salon.libelle(error)
        }
    }
}

struct MoteursEcran: View {
    @Environment(Salon.self) private var salon
    @State private var moteurs: EtatMoteurs?
    @State private var versions: [VersionVllm] = []
    @State private var echec: String?
    @State private var aSupprimer: VersionVllm?

    private var depot: DepotSysteme { DepotSysteme(client: salon.client) }

    var body: some View {
        PageAtelier("Moteurs", rafraichir: { await charger(verifier: true) }) {
            if let echec { EchecAction(raison: echec) }
            if let moteurs {
                CarteMoteur(titre: "llama.cpp", sante: moteurs.llamacpp)
                CarteMoteur(titre: "vLLM", sante: moteurs.vllm)
            }
            SectionAtelier("Versions de vLLM") {
                VStack(alignment: .leading, spacing: Trame.element) {
                    if versions.isEmpty { Text("Aucune version installée.").note().foregroundStyle(Teinte.encreDouce) }
                    ForEach(versions) { version in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: Trame.fin) {
                                Text(version.version).mention().foregroundStyle(Teinte.encre)
                                Text([version.versionTorch.map { "torch \($0)" }, version.tailleOctets.map(Mesures.octets)]
                                    .compactMap { $0 }.joined(separator: " · "))
                                    .mesureFine().foregroundStyle(Teinte.encreEteinte)
                                Text(version.diagnostic).legende().foregroundStyle(Teinte.encreDouce).lineLimit(3)
                            }
                            Spacer(minLength: 0)
                            VerbeAtelier(libelle: "Supprimer", ton: .panne) { aSupprimer = version }
                        }
                    }
                }
            }
            InstallationVllm(depot: depot) { await charger(verifier: false) }
        }
        .task { await charger(verifier: false) }
        .confirmationDialog(
            "Supprimer vLLM \(aSupprimer?.version ?? "") ?", isPresented: Binding(get: { aSupprimer != nil }, set: { if !$0 { aSupprimer = nil } }),
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                if let version = aSupprimer { Task { await supprimer(version) } }
            }
        } message: {
            Text("Son environnement est effacé du disque ; la réinstaller prend plusieurs minutes.")
        }
    }

    private func charger(verifier: Bool) async {
        do {
            moteurs = try await depot.moteurs()
            versions = try await depot.versionsVllm(verifier: verifier)
            echec = nil
        } catch {
            echec = Salon.libelle(error)
        }
    }

    private func supprimer(_ version: VersionVllm) async {
        do {
            try await depot.supprimer(version.version)
            await charger(verifier: false)
        } catch {
            echec = Salon.libelle(error)
        }
    }
}

private struct CarteMoteur: View {
    let titre: String
    let sante: SanteBinaireMoteur

    var body: some View {
        SectionAtelier(titre) {
            VStack(alignment: .leading, spacing: Trame.serre) {
                HStack {
                    Text(sante.version ?? "—").mention().foregroundStyle(Teinte.encre)
                    Spacer(minLength: 0)
                    Sceau(sante.statut).ton(sante.fonctionnel ? .ok : (sante.installe ? .alerte : .neutre))
                }
                Text(sante.diagnostic).legende().foregroundStyle(Teinte.encreDouce).fixedSize(horizontal: false, vertical: true)
                if !sante.remediation.isEmpty {
                    Text(sante.remediation).legende().foregroundStyle(Teinte.alerte).fixedSize(horizontal: false, vertical: true)
                }
                if let archis = sante.architecturesGpu, !archis.isEmpty {
                    Text(archis.joined(separator: " · ")).mesureFine().foregroundStyle(Teinte.encreEteinte)
                }
            }
        }
    }
}

/// Installer une version de vLLM, suivie pas à pas. Quitter l'écran ferme le flux, ce qui annule l'installation.
private struct InstallationVllm: View {
    let depot: DepotSysteme
    let apres: () async -> Void
    @State private var version = ""
    @State private var remplacer = false
    @State private var pas: [EvenementInstallation] = []
    @State private var echec: String?
    @State private var suivi: Task<Void, Never>?

    var body: some View {
        SectionAtelier("Installer une version") {
            VStack(alignment: .leading, spacing: Trame.element) {
                TextField("Version, ex. 0.31.0", text: $version)
                    .keyboardType(.numbersAndPunctuation).autocorrectionDisabled().textInputAutocapitalization(.never)
                Toggle("Réinstaller si déjà présente", isOn: $remplacer).tint(Teinte.accent)
                if suivi == nil {
                    VerbeAtelier(libelle: "Installer") { lancer() }.disabled(version.isEmpty)
                } else {
                    VerbeAtelier(libelle: "Annuler l'installation", ton: .alerte) { Task { await annuler() } }
                }
                if let dernier = pas.last { Jauge(part: dernier.progression) }
                if let echec { Text(echec).legende().foregroundStyle(Teinte.panne) }
                ForEach(Array(pas.suffix(30).enumerated()), id: \.offset) { _, evenement in
                    Text(evenement.message).font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(evenement.niveau == "erreur" ? Teinte.panne : Teinte.encreDouce)
                }
            }
        }
        .onDisappear { suivi?.cancel() }
    }

    private func lancer() {
        pas = []
        echec = nil
        let demandee = version.trimmingCharacters(in: .whitespaces)
        suivi = Task {
            for await evenement in depot.installer(demandee, remplacer: remplacer) {
                switch evenement {
                case .pas(let un):
                    pas.append(un)
                    if un.termine, un.succes == false { echec = un.message }
                case .echec(let raison): echec = raison
                }
            }
            suivi = nil
            await apres()
        }
    }

    private func annuler() async {
        do { try await depot.annulerInstallation(version.trimmingCharacters(in: .whitespaces)) } catch { echec = Salon.libelle(error) }
        suivi?.cancel()
    }
}
#endif
