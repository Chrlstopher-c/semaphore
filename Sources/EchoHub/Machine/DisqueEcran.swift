// Ce que le disque du PC porte réellement, inscrit au registre ou non.
//
// `☠` C'est le seul écran de l'app qui détruit des données que rien ne
// réplique. Effacer un dossier ici, ce sont des gigaoctets qui partent du
// disque du PC, et aucun geste ne les ramène — seul un nouveau téléchargement.
// D'où le ton `panne`, la confirmation, et une phrase qui dit la portée réelle
// plutôt que « Êtes-vous sûr ? ».
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct DisqueEcran: View {
    @Environment(Salon.self) private var salon
    @State private var etat: EtatChargement<[DossierDisque]> = .chargement
    @State private var aEffacer: DossierDisque?
    @State private var bilan: String?
    @State private var echecAction: String?
    @State private var occupe = false

    var body: some View {
        PageAtelier("Disque du PC", rafraichir: charger) {
            if let echecAction { EchecAction(raison: echecAction) }
            if let bilan { Text(bilan).note().foregroundStyle(Teinte.ok) }
            entete
            contenu
        }
        .task { await charger() }
        .confirmationDialog(
            "Effacer du disque ?", isPresented: confirmation, titleVisibility: .visible
        ) {
            Button("Effacer définitivement", role: .destructive) { Task { await effacer() } }
            Button("Annuler", role: .cancel) { aEffacer = nil }
        } message: {
            Text(portee)
        }
    }

    private var confirmation: Binding<Bool> {
        Binding(get: { aEffacer != nil }, set: { if !$0 { aEffacer = nil } })
    }

    /// La portée réelle, chiffrée : ce qui part, et combien. « Êtes-vous sûr ? »
    /// n'aide personne à décider.
    private var portee: String {
        guard let aEffacer else { return "" }
        return "Les \(aEffacer.tailleLisible) du dossier « \(aEffacer.dossier) » partent du "
            + "disque du PC. Rien ne les ramène : il faudra les retélécharger."
    }

    private var entete: some View {
        Panneau {
            VStack(alignment: .leading, spacing: Trame.element) {
                LigneMesure(libelle: "Occupé", valeur: Mesures.octets(total))
                Text("Le registre n'inscrit que le chargeable. Cette liste montre TOUT — y "
                    + "compris ce qu'il refuse, et pourquoi.")
                    .note().foregroundStyle(Teinte.encreDouce)
                    .fixedSize(horizontal: false, vertical: true)
                VerbeAtelier(libelle: "Synchroniser le registre", occupe: occupe) {
                    Task { await synchroniser() }
                }
            }
        }
    }

    private var total: Int {
        (etat.contenu ?? []).reduce(0) { $0 + $1.tailleOctets }
    }

    @ViewBuilder private var contenu: some View {
        switch etat {
        case .chargement:
            ChargementVue().transition(.scene)
        case .vide:
            EtatCalme(
                symbole: "internaldrive", titre: "Disque vide",
                detail: "La racine des modèles du PC ne contient aucun dossier."
            )
            .transition(.scene)
        case .echec(let raison):
            EtatCalme(
                symbole: "antenna.radiowaves.left.and.right.slash", titre: "Disque injoignable",
                detail: raison, actionTitre: "Réessayer", action: { Task { await charger() } }
            )
            .transition(.scene)
        case .pret(let dossiers):
            SectionAtelier("Dossiers") {
                VStack(spacing: Trame.element) {
                    ForEach(dossiers) { dossier in
                        LigneDossier(dossier: dossier, occupe: occupe) { aEffacer = dossier }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func charger() async {
        do {
            let dossiers = try await salon.modeles.disque()
            withAnimation(Elan.normal) { etat = dossiers.isEmpty ? .vide : .pret(dossiers) }
        } catch {
            Journal.echec("inventaire du disque illisible : \(error)")
            withAnimation(Elan.normal) { etat = .echec(Salon.libelle(error)) }
        }
    }

    private func effacer() async {
        guard let cible = aEffacer else { return }
        aEffacer = nil
        occupe = true
        defer { occupe = false }
        do {
            let resultat = try await salon.modeles.supprimerDuDisque(cible.dossier)
            bilan = "\(resultat.libere) libérés."
            echecAction = nil
        } catch {
            Journal.echec("suppression de \(cible.dossier) refusée : \(error)")
            echecAction = Salon.libelle(error)
        }
        await charger()
    }

    private func synchroniser() async {
        occupe = true
        defer { occupe = false }
        do {
            bilan = try await salon.modeles.synchroniserRegistre().bilan
            echecAction = nil
        } catch {
            Journal.echec("synchronisation refusée : \(error)")
            echecAction = Salon.libelle(error)
        }
        await charger()
    }
}

/// Un dossier du disque. Quand il n'est pas inscrit, la RAISON est affichée :
/// un fichier auxiliaire et un téléchargement inachevé ne se corrigent pas de
/// la même façon, et sans la cause il n'y a rien à décider.
struct LigneDossier: View {
    let dossier: DossierDisque
    let occupe: Bool
    let effacer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            HStack(alignment: .top, spacing: Trame.element) {
                VStack(alignment: .leading, spacing: Trame.fin) {
                    Text(dossier.dossier).mention().foregroundStyle(Teinte.encre).lineLimit(2)
                    HStack(spacing: Trame.serre) {
                        Text(dossier.tailleLisible).mesureFine()
                        Text("·").mesureFine()
                        Text("\(dossier.nbFichiersPoids) fichier(s) de poids").mesureFine()
                    }
                    .foregroundStyle(Teinte.encreEteinte)
                }
                Spacer(minLength: 0)
                if !dossier.inscrit { Sceau("Hors registre").ton(.alerte) }
            }
            if !dossier.raison.isEmpty {
                Text(dossier.raison).brut().foregroundStyle(Teinte.encreDouce)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !dossier.remediation.isEmpty {
                Text(dossier.remediation).brut().foregroundStyle(Teinte.encreEteinte)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VerbeAtelier(libelle: "Effacer du disque", ton: .panne, occupe: occupe, action: effacer)
        }
        .padding(.vertical, Trame.serre)
    }
}
#endif
