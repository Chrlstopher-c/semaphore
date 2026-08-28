// La feuille de tenue d'un fil (⋯) : l'état complet, le renommage, la
// machine, l'autonomie, les rappels, la compaction et l'archivage — toutes
// les routes du contrat qui n'avaient aucune surface.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct ReglagesFilFeuille: View {
    @Environment(\.clientPi) private var client
    @Environment(\.miroir) private var miroir
    @Environment(\.dismiss) private var congedier

    let identifiant: String
    let detail: DetailFilApi?
    let filConnu: FilApi?
    /// Rebattre la conversation après un geste abouti.
    let apres: () async -> Void
    /// Le fil archivé n'existe plus : la conversation se referme.
    let apresArchivage: () -> Void

    @State private var machines: [MachineApi] = []
    @State private var titreRenommage = ""
    @State private var avis: String?
    @State private var enCours = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Trame.section) {
                Text("Tenue du fil")
                    .titreFeuille()
                    .foregroundStyle(Teinte.encre)
                sectionEtat
                sectionRenommage
                sectionMachine
                AutonomieFil(identifiant: identifiant, detail: detail, avis: $avis, apres: apres)
                RappelsFil(identifiant: identifiant)
                sectionGestes
            }
            .padding(Trame.ecran)
        }
        .scrollIndicators(.hidden)
        .rendLeClavier()
        .avisFugace($avis)
        .task { await ouvrir() }
    }

    // MARK: - État

    /// Ce que le fil est, mesuré : contexte, compactions, moteur, âge.
    private var sectionEtat: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            TeteDeSection("État")
            VStack(spacing: 0) {
                LigneCle("Moteur", valeur: moteur)
                LigneCle("Contexte", valeur: contexte)
                LigneCle("Compactions", valeur: "\(detail?.compactions ?? filConnu?.compactions ?? 0)")
                LigneCle("Machine", valeur: filConnu?.machine ?? "non précisée")
                if let cree = filConnu?.creeA {
                    LigneCle("Ouvert", valeur: Lisible.heure(cree))
                }
                if let maj = filConnu?.majA {
                    LigneCle("Dernière activité", valeur: Lisible.heure(maj), derniere: true)
                }
            }
        }
    }

    private var moteur: String {
        let modele = detail?.model ?? filConnu?.model
        let effort = detail?.effort ?? filConnu?.effort
        return Lisible.moteur(modele: modele, effort: effort)
    }

    private var contexte: String {
        guard let pct = detail?.contextPct ?? filConnu?.contextPct else { return "—" }
        return "\(pct) %"
    }

    // MARK: - Renommage

    private var sectionRenommage: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            TeteDeSection("Titre")
            HStack(spacing: Trame.serre) {
                ChampQuart(texte: $titreRenommage, placebo: filConnu?.titre ?? detail?.titre ?? "Titre")
                Button("Renommer") { Task { await renommer() } }
                    .buttonStyle(.allurePuce)
                    .disabled(enCours || titreRenommage.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - Machine

    /// `☠` Déplacer un fil qui porte une équipe vivante est REFUSÉ par le
    /// serveur (400, message en clair) : le refus s'affiche mot pour mot.
    private var sectionMachine: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            TeteDeSection("Machine")
            if machines.isEmpty {
                Text("Aucune machine connue du Pi pour l'instant.")
                    .mention()
                    .foregroundStyle(Teinte.encreTernie)
            } else {
                HStack(spacing: Trame.serre) {
                    ForEach(machines) { machine in
                        pucesMachine(machine)
                    }
                }
            }
        }
    }

    private func pucesMachine(_ machine: MachineApi) -> some View {
        let actuelle = filConnu?.machine == machine.id
        return Button {
            Task { await rattacher(machine.id) }
        } label: {
            HStack(spacing: Trame.fin) {
                PointVeille(ton: machine.enLigne ? .sain : .veille)
                Text(machine.id)
            }
        }
        .buttonStyle(.allurePuce(actuelle ? .attention : .neutre))
        .disabled(actuelle || enCours)
    }

    // MARK: - Gestes de fin

    private var sectionGestes: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            TeteDeSection("Gestes")
            Button("Compacter le fil") { Task { await compacter() } }
                .buttonStyle(.allureDouce)
                .disabled(enCours)
            BoutonArme("Maintenir pour archiver", libelleArme: "Archivage…") {
                Task { await archiver() }
            }
            Text("Compacter résume l'historique pour libérer du contexte. Archiver "
                + "retire le fil de la liste — l'orchestrateur n'y répondra plus.")
                .mention()
                .foregroundStyle(Teinte.encreTernie)
        }
    }

    // MARK: - Réseau

    private func ouvrir() async {
        if let cache = await miroir.lire([MachineApi].self, .machines) {
            machines = cache.valeur
        }
        guard machines.isEmpty else { return }
        let lecture = await client.lire([MachineApi].self, Route.machines, memoriser: .machines)
        if let charge = lecture.charge { machines = charge }
    }

    private func renommer() async {
        let titre = titreRenommage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !titre.isEmpty else { return }
        await geste(Route.renommerFil(identifiant), ["titre": .texte(titre)])
        titreRenommage = ""
    }

    private func rattacher(_ machine: String) async {
        await geste(Route.machineDuFil(identifiant), ["machine": .texte(machine)])
    }

    private func compacter() async {
        await geste(Route.compacterFil(identifiant), nil)
    }

    private func archiver() async {
        guard !enCours else { return }
        enCours = true
        defer { enCours = false }
        switch await client.ecrire(Route.archiverFil(identifiant)) {
        case .success:
            congedier()
            apresArchivage()
        case .failure(let erreur):
            avis = erreur.message
        }
    }

    /// L'effet du serveur est LA phrase à montrer : elle dit ce que le code de
    /// statut ne dit pas (rien à compacter, fil retenu…).
    private func geste(_ chemin: String, _ corps: CorpsJSON?) async {
        guard !enCours else { return }
        enCours = true
        defer { enCours = false }
        switch await client.ecrire(chemin, corps) {
        case .success(let accuse):
            avis = accuse.effet
            await apres()
        case .failure(let erreur):
            avis = erreur.message
        }
    }
}
#endif
