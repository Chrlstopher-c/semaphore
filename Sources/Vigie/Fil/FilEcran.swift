#if canImport(SwiftUI)
import Foundation
import SwiftUI
import VigieNoyau

/// Les fils de l'orchestrateur : la liste, la création, puis la conversation.
public struct FilEcran: View {
    @Environment(\.clientPi) private var client
    @Environment(\.miroir) private var miroir
    @Environment(Cadence.self) private var cadence

    @State private var fils: [FilApi] = []
    @State private var machines: [MachineApi] = []
    @State private var releveA: Date?
    @State private var refus: ErreurApi?
    @State private var feuilleNouveau = false
    @State private var filARenommer: FilApi?
    @State private var avis: String?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            entete
            corps
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Teinte.fond)
        .task { await ouvrir() }
        .cadencePar("fil") { await battre() }
        .avisFugace($avis)
        .navigationDestination(for: RouteFil.self) { route in
            switch route {
            case .conversation(let identifiant, let titre):
                ConversationEcran(identifiant: identifiant, titre: titre)
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
        .feuilleQuart(presentee: $feuilleNouveau, hauteurs: [.medium]) {
            NouveauFilFeuille(machines: machines, creer: creerFil)
        }
        .feuilleQuart(presentee: renommagePresente, hauteurs: [.medium]) {
            if let fil = filARenommer {
                RenommerFilFeuille(fil: fil) { titre in
                    await renommer(fil, titre: titre)
                }
            }
        }
    }

    private var entete: some View {
        EnTeteEcran("Fil", releveA: releveA) {
            Button {
                feuilleNouveau = true
            } label: {
                Image(systemName: "plus.circle.fill")
            }
            .buttonStyle(.allureIcone)
            .foregroundStyle(Teinte.accent)
            .accessibilityLabel("Nouveau fil")
        }
    }

    private var renommagePresente: Binding<Bool> {
        Binding(
            get: { filARenommer != nil },
            set: { present in if !present { filARenommer = nil } }
        )
    }

    // MARK: - Corps

    private var corps: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Trame.element) {
                if let refus, refus.genre != .transport, !fils.isEmpty {
                    BandeauNote(refus.message, ton: .vigilance)
                }
                contenu
            }
            .padding(.horizontal, Trame.ecran)
            .padding(.bottom, Trame.section)
        }
        .scrollIndicators(.hidden)
        .refreshable { await battre() }
    }

    @ViewBuilder private var contenu: some View {
        if !fils.isEmpty {
            ForEach(Array(fils.enumerated()), id: \.element.id) { rang, fil in
                carte(fil, rang: rang)
            }
        } else if releveA == nil && refus == nil {
            ForEach(0..<3, id: \.self) { rang in
                Panneau { SilhouetteAttente(lignes: [0.5, 0.75]) }
                    .entreeEnScene(rang: rang)
            }
        } else if let refus, refus.genre != .transport {
            BandeauNote(refus.message, ton: .danger)
        } else {
            EtatCalme(
                symbole: "bubble.left.and.bubble.right.fill",
                titre: "Aucun fil",
                explication: "Ouvre une conversation avec l'orchestrateur par le bouton +."
            )
        }
    }

    /// Le menu au maintien porte les gestes de tenue du fil — le toucher franc
    /// ouvre la conversation. `contextMenu` est un idiome système : il ne vole
    /// jamais le toucher du `NavigationLink`, contrairement à un geste custom.
    private func carte(_ fil: FilApi, rang: Int) -> some View {
        NavigationLink(value: RouteFil.conversation(fil.id, fil.titre)) {
            CarteFil(fil: fil)
        }
        .buttonStyle(.allureCarte)
        .contextMenu {
            Button("Renommer", systemImage: "pencil") { filARenommer = fil }
            Button("Compacter", systemImage: "arrow.down.right.and.arrow.up.left") {
                Task { await compacter(fil) }
            }
            Button("Archiver", systemImage: "archivebox", role: .destructive) {
                Task { await archiver(fil) }
            }
        }
        .entreeEnScene(rang: rang)
    }

    // MARK: - Relevés

    private func ouvrir() async {
        if let cache = await miroir.lire([FilApi].self, .fils) {
            fils = cache.valeur
            releveA = cache.releveA
        }
        if let cache = await miroir.lire([MachineApi].self, .machines) {
            machines = cache.valeur
        }
    }

    @MainActor private func battre() async {
        let lecture = await client.lire([FilApi].self, Route.fils, memoriser: .fils)
        if let charge = lecture.charge {
            fils = charge
            releveA = Date()
        }
        refus = lecture.erreur
        if machines.isEmpty {
            let parc = await client.lire([MachineApi].self, Route.machines, memoriser: .machines)
            if let charge = parc.charge { machines = charge }
        }
    }

    // MARK: - Gestes

    @MainActor private func creerFil(titre: String, machine: String?) async -> Bool {
        var champs: [String: ValeurJSON] = [:]
        if !titre.isEmpty { champs["titre"] = .texte(titre) }
        if let machine { champs["machine"] = .texte(machine) }
        switch await client.ecrire(Route.fils, CorpsJSON(champs)) {
        case .success(let accuse):
            avis = accuse.effet
            await battre()
            return true
        case .failure(let erreur):
            avis = erreur.message
            return false
        }
    }

    @MainActor private func renommer(_ fil: FilApi, titre: String) async {
        switch await client.ecrire(Route.renommerFil(fil.id), ["titre": .texte(titre)]) {
        case .success(let accuse): avis = accuse.effet
        case .failure(let erreur): avis = erreur.message
        }
        filARenommer = nil
        cadence.battreMaintenant("fil")
    }

    /// `☠` `compacted: false` n'est PAS une erreur : rien à compacter, ou tour
    /// en cours. L'effet du serveur dit pourquoi — on l'affiche tel quel.
    @MainActor private func compacter(_ fil: FilApi) async {
        switch await client.ecrire(Route.compacterFil(fil.id)) {
        case .success(let accuse): avis = accuse.effet
        case .failure(let erreur): avis = erreur.message
        }
    }

    @MainActor private func archiver(_ fil: FilApi) async {
        switch await client.ecrire(Route.archiverFil(fil.id)) {
        case .success(let accuse): avis = accuse.effet
        case .failure(let erreur): avis = erreur.message
        }
        cadence.battreMaintenant("fil")
    }
}

/// Les destinations du domaine Fil. Le titre voyage avec l'identifiant :
/// l'écran s'ouvre avec son nom avant la première réponse. Vide quand on
/// arrive par une notification — la conversation le retrouve alors du miroir.
enum RouteFil: Hashable {
    case conversation(String, String)
}

/// Une carte de fil : le point de vie, le titre, et les mesures en puces.
private struct CarteFil: View {
    let fil: FilApi

    var body: some View {
        Panneau {
            VStack(alignment: .leading, spacing: Trame.serre) {
                HStack(spacing: Trame.serre) {
                    PointVeille(ton: fil.active ? .sain : .neutre, vivant: fil.active)
                    Text(fil.titre)
                        .phraseForte()
                        .foregroundStyle(Teinte.encre)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(Lisible.heure(fil.majA))
                        .donneePetite()
                        .foregroundStyle(Teinte.encreTernie)
                }
                HStack(spacing: Trame.serre) {
                    if let modele = fil.model { PuceDonnee(modele) }
                    if let machine = fil.machine { PuceDonnee(machine) }
                    if fil.compactions > 0 { PuceDonnee("\(fil.compactions) compactions") }
                    Spacer(minLength: 0)
                    if let contexte = fil.contextPct {
                        Text("ctx \(contexte) %")
                            .donneePetite()
                            .foregroundStyle(contexte >= 80 ? Teinte.vigilance : Teinte.encreDouce)
                    }
                }
            }
        }
    }
}
#endif
