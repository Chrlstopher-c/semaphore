// Ce que le modèle a le droit d'appeler dans CETTE conversation.
//
// L'app savait déjà afficher joliment un appel d'outil (`CarteOutil`), mais rien
// ne permettait de les couper — ni de voir ce que leur déclaration coûte en
// contexte. Sur une conversation où l'on veut une réponse rapide sans recherche
// web, il n'y avait aucun geste possible depuis le téléphone.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct OutilsFeuille: View {
    @Environment(Salon.self) private var salon
    @Environment(\.dismiss) private var fermer
    @State private var catalogue: EtatChargement<[OutilDisponible]> = .chargement
    @State private var selection = SelectionOutils()
    @State private var erreur: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Teinte.fond.ignoresSafeArea()
                ScrollView { contenu }
            }
            .navigationTitle("Outils")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { fermer() }
                        .buttonStyle(.appui)
                        .foregroundStyle(Teinte.accent)
                }
            }
            .task { await charger() }
        }
    }

    @ViewBuilder private var contenu: some View {
        VStack(alignment: .leading, spacing: Trame.section) {
            if let erreur { EchecAction(raison: erreur) }
            switch catalogue {
            case .chargement:
                ChargementVue().transition(.scene)
            case .vide:
                Text("Le PC n'enregistre aucun outil.")
                    .note().foregroundStyle(Teinte.encreDouce).padding(.horizontal, Trame.ecran)
            case .echec(let raison):
                EtatCalme(
                    symbole: "wrench.and.screwdriver",
                    titre: "Outils injoignables",
                    detail: raison,
                    actionTitre: "Réessayer",
                    action: { Task { await charger() } }
                )
            case .pret(let outils):
                entete(outils)
                familles(outils)
                defaut
            }
        }
        .padding(.vertical, Trame.groupe)
    }

    /// L'état en toutes lettres, en tête : « tous » et « 9 sur 9 » ne veulent
    /// pas dire la même chose — le premier suivra le registre du PC quand un
    /// dixième outil y sera enregistré.
    private func entete(_ outils: [OutilDisponible]) -> some View {
        VStack(alignment: .leading, spacing: Trame.fin) {
            Text(selection.resume(surTotal: outils.count))
                .titreSection().foregroundStyle(Teinte.encre)
            Text("Couper un outil retire aussi sa déclaration du prompt système : "
                + "le modèle cesse de savoir qu'il existe, et le contexte s'allège d'autant.")
                .note().foregroundStyle(Teinte.encreDouce)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Trame.ecran)
    }

    /// Le pont vers le réglage global. `☠` Sans lui, le défaut d'outils
    /// n'était atteignable que depuis l'onglet Machine — c'est-à-dire loin du
    /// moment où l'on décide.
    private var defaut: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            Button("Poser cette sélection par défaut") { Task { await poserParDefaut() } }
                .buttonStyle(.appui).mention().foregroundStyle(Teinte.accent)
            Text("Les conversations NEUVES partiront avec. Celles qui existent déjà ne "
                + "changent pas.")
                .legende().foregroundStyle(Teinte.encreEteinte)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Trame.ecran)
    }

    private func poserParDefaut() async {
        await salon.mettreAJourOutilsParDefaut(selection)
    }

    private func familles(_ outils: [OutilDisponible]) -> some View {
        let groupes = Dictionary(grouping: outils, by: \.groupe)
        return ForEach(groupes.keys.sorted(), id: \.self) { groupe in
            VStack(alignment: .leading, spacing: Trame.element) {
                Text(groupe).rubrique().padding(.horizontal, Trame.ecran)
                ForEach(groupes[groupe] ?? []) { outil in
                    LigneOutil(outil: outil, actif: selection.contient(outil.nom)) {
                        Task { await basculer(outil, parmi: outils) }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func charger() async {
        guard let conversation = salon.conversation else { return }
        do {
            let outils = try await salon.outils.catalogue()
            selection = try await salon.outils.selection(conversation.id)
            salon.poser(outils: selection)
            withAnimation(Elan.normal) { catalogue = outils.isEmpty ? .vide : .pret(outils) }
        } catch {
            Journal.echec("catalogue d'outils illisible : \(error)")
            withAnimation(Elan.normal) { catalogue = .echec(Salon.libelle(error)) }
        }
    }

    /// Bascule optimiste : l'interrupteur suit le doigt, et REVIENT si le PC
    /// refuse. L'inverse — attendre le serveur — donne un interrupteur qui colle,
    /// et fait rappuyer.
    private func basculer(_ outil: OutilDisponible, parmi outils: [OutilDisponible]) async {
        guard let conversation = salon.conversation else { return }
        let avant = selection
        let apres = selection.basculant(outil.nom, parmi: outils.map(\.nom))
        withAnimation(Elan.micro) { selection = apres }
        do {
            selection = try await salon.outils.definir(conversation.id, apres)
            salon.poser(outils: selection)
            withAnimation(Elan.normal) { erreur = nil }
        } catch {
            Journal.echec("sélection d'outils non enregistrée : \(error)")
            withAnimation(Elan.normal) {
                selection = avant
                erreur = Salon.libelle(error)
            }
        }
    }
}

/// Un outil, ce qu'il fait, et ce que sa DÉCLARATION coûte à chaque tour.
struct LigneOutil: View {
    let outil: OutilDisponible
    let actif: Bool
    let basculer: () -> Void

    var body: some View {
        Button(action: basculer) {
            HStack(alignment: .top, spacing: Trame.element) {
                VStack(alignment: .leading, spacing: Trame.fin) {
                    Text(outil.nom)
                        .mention()
                        .foregroundStyle(actif ? Teinte.encre : Teinte.encreEteinte)
                    Text(outil.description).note().foregroundStyle(Teinte.encreDouce)
                    cout
                }
                Spacer(minLength: 0)
                Image(systemName: actif ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(actif ? Teinte.accent : Teinte.encreEteinte)
            }
            .padding(.horizontal, Trame.ecran)
            .padding(.vertical, Trame.serre)
            .contentShape(.rect)
        }
        .buttonStyle(.appui)
    }

    /// `☠` Affichée SEULEMENT quand le serveur l'a mesurée. Sans modèle chargé,
    /// le champ vaut `null` — et un « 0 tokens » se lirait « cet outil ne coûte
    /// rien », alors qu'un outil déclaré occupe la fenêtre à CHAQUE tour.
    @ViewBuilder private var cout: some View {
        if let tokens = outil.tokensDefinition {
            Text("\(tokens) tokens de déclaration")
                .mesureFine()
                .foregroundStyle(Teinte.encreEteinte)
        }
    }
}
#endif
