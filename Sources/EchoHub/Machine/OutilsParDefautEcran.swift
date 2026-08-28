// Les outils mis à disposition du modèle dans les conversations NEUVES.
//
// `☠` Ce défaut n'existe pas côté serveur : `outils_actifs` est une colonne de
// `chat_reglages`, strictement par conversation. Ce que l'app fait, c'est poser
// sa sélection au moment où elle crée la conversation — `POST
// /chat/conversations` accepte déjà un objet `reglages`. Aucune route n'a été
// ajoutée au PC pour ça, et il n'en fallait pas.
//
// `☠` TROIS états, pas deux, et l'écran les distingue explicitement :
// « Tous les outils du PC » suivra le registre quand un onzième outil y sera
// enregistré ; « les dix cochés » restera à dix. Les confondre est exactement
// ce que le contrat du serveur prend soin d'éviter.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct OutilsParDefautEcran: View {
    @Environment(Salon.self) private var salon
    @State private var catalogue: EtatChargement<[OutilDisponible]> = .chargement
    @State private var selection = SelectionOutils()
    @State private var limites = ""

    var body: some View {
        PageAtelier("Outils par défaut", rafraichir: charger) {
            entete
            contenu
            bac
        }
        .task {
            selection = salon.outilsParDefaut
            await charger()
        }
    }

    private var entete: some View {
        Panneau {
            VStack(alignment: .leading, spacing: Trame.element) {
                LigneMesure(
                    libelle: "Appliqué aux conversations neuves",
                    valeur: selection.resume(surTotal: catalogue.contenu?.count),
                    ton: selection.outilsActifs?.isEmpty == true ? .alerte : .neutre
                )
                Text("Une conversation déjà ouverte n'est pas touchée : ses outils se règlent "
                    + "depuis son propre fil.")
                    .note().foregroundStyle(Teinte.encreDouce)
                    .fixedSize(horizontal: false, vertical: true)
                if selection.restreinte {
                    VerbeAtelier(libelle: "Revenir à « tous les outils du PC »") {
                        Task { await poser(SelectionOutils()) }
                    }
                }
            }
        }
    }

    @ViewBuilder private var contenu: some View {
        switch catalogue {
        case .chargement:
            ChargementVue().transition(.scene)
        case .vide:
            EtatCalme(
                symbole: "wrench.and.screwdriver", titre: "Aucun outil enregistré",
                detail: "Le PC n'expose aucun outil : le défaut n'a rien sur quoi porter."
            )
            .transition(.scene)
        case .echec(let raison):
            EtatCalme(
                symbole: "antenna.radiowaves.left.and.right.slash", titre: "Outils injoignables",
                detail: raison, actionTitre: "Réessayer", action: { Task { await charger() } }
            )
            .transition(.scene)
        case .pret(let outils):
            familles(outils)
        }
    }

    private func familles(_ outils: [OutilDisponible]) -> some View {
        let groupes = Dictionary(grouping: outils, by: \.groupe)
        return ForEach(groupes.keys.sorted(), id: \.self) { groupe in
            SectionAtelier(groupe) {
                VStack(spacing: 0) {
                    ForEach(groupes[groupe] ?? []) { outil in
                        LigneOutil(outil: outil, actif: selection.contient(outil.nom)) {
                            Task { await basculer(outil, parmi: outils) }
                        }
                    }
                }
            }
        }
    }

    /// `☠` Couper un outil retire aussi sa DÉCLARATION du prompt système : le
    /// socle du harnais annonce au modèle les outils réellement disponibles. Le
    /// contexte consommé change donc, et c'est ce que le coût par outil dit.
    @ViewBuilder private var bac: some View {
        if !limites.isEmpty {
            SectionAtelier("Ce que le bac à sable garantit") {
                Panneau {
                    Text(limites).brut().foregroundStyle(Teinte.encreDouce)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Actions

    private func charger() async {
        do {
            let outils = try await salon.outils.catalogue()
            await salon.releverLesOutils()
            withAnimation(Elan.normal) { catalogue = outils.isEmpty ? .vide : .pret(outils) }
        } catch {
            Journal.echec("catalogue d'outils illisible : \(error)")
            withAnimation(Elan.normal) { catalogue = .echec(Salon.libelle(error)) }
        }
        limites = (try? await salon.outils.limitesBac()) ?? ""
    }

    private func basculer(_ outil: OutilDisponible, parmi outils: [OutilDisponible]) async {
        await poser(selection.basculant(outil.nom, parmi: outils.map(\.nom)))
    }

    /// Écriture locale : rien ne part vers le PC ici. Ce défaut ne quitte le
    /// téléphone qu'au moment où une conversation est créée.
    private func poser(_ nouvelle: SelectionOutils) async {
        withAnimation(Elan.micro) { selection = nouvelle }
        await salon.mettreAJourOutilsParDefaut(nouvelle)
    }
}
#endif
