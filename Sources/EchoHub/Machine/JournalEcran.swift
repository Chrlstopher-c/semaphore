// Ce qui s'est passé aux derniers chargements, et l'état vivant des services.
//
// `☠` `/inference/etat` rend un état MÉMORISÉ : un moteur mort continue d'y
// apparaître « prêt ». Les sondes de cet écran interrogent les services
// MAINTENANT — c'est la différence entre confirmer une bonne nouvelle et la
// vérifier.
//
// `☠` La santé de la recherche web mérite sa place ici pour une raison qui ne
// saute pas aux yeux : c'est SearXNG qui alimente l'outil de recherche du
// modèle. Éteint, le modèle n'échoue pas — il répond avec ce qu'il croit
// savoir. Le symptôme est une réponse plausible et périmée, que rien d'autre
// ne signale.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct JournalEcran: View {
    @Environment(Salon.self) private var salon
    @State private var sessions: [SessionChargement] = []
    @State private var moteur: SanteMoteur?
    @State private var recherche: SanteRecherche?
    @State private var etat: EtatChargement<Bool> = .chargement
    @State private var echecReleve: String?

    var body: some View {
        PageAtelier("Journal et santé", rafraichir: charger) {
            if let echecReleve { EchecAction(raison: echecReleve) }
            santes
            contenu
        }
        .task { await charger() }
    }

    private var santes: some View {
        SectionAtelier("Sondé à l'instant") {
            Panneau {
                VStack(alignment: .leading, spacing: Trame.element) {
                    CarteSonde(
                        titre: "Moteur d'inférence",
                        disponible: moteur?.disponible,
                        detail: moteur?.detail,
                        mesure: moteur?.latenceMs.map { String(format: "%.0f ms", $0) }
                    )
                    Divider().overlay(Teinte.trait)
                    CarteSonde(
                        titre: "Recherche web (SearXNG)",
                        disponible: recherche?.disponible,
                        detail: recherche?.detail,
                        mesure: recherche?.latenceLisible
                    )
                    Text("Recherche éteinte : le modèle ne le dira pas — il répondra avec ce "
                        + "qu'il croit savoir.")
                        .brut().foregroundStyle(Teinte.encreEteinte)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder private var contenu: some View {
        switch etat {
        case .chargement, .vide:
            ChargementVue().transition(.scene)
        case .echec(let raison):
            EtatCalme(
                symbole: "list.bullet.rectangle", titre: "Journal injoignable", detail: raison,
                actionTitre: "Réessayer", action: { Task { await charger() } }
            )
            .transition(.scene)
        case .pret:
            journal
        }
    }

    @ViewBuilder private var journal: some View {
        if sessions.isEmpty {
            EtatCalme(
                symbole: "list.bullet.rectangle", titre: "Aucun chargement journalisé",
                detail: "Le PC n'a rien chargé depuis son dernier démarrage."
            )
        } else {
            SectionAtelier("Derniers chargements") {
                VStack(spacing: Trame.groupe) {
                    ForEach(sessions) { session in LigneSession(session: session) }
                }
            }
        }
    }

    /// Les trois relevés partent ensemble. Les deux sondes sont tolérantes à
    /// l'échec : un service muet est une information, pas une panne d'écran.
    private func charger() async {
        if etat.contenu == nil { etat = .chargement }
        async let sonde = try? salon.modeles.sante()
        async let web = try? salon.rechercheWeb.sante()
        do {
            sessions = try await salon.modeles.journalChargements(limite: 10)
            echecReleve = nil
            withAnimation(Elan.normal) { etat = .pret(true) }
        } catch {
            Journal.echec("journal des chargements illisible : \(error)")
            withAnimation(Elan.normal) { etat = .echec(Salon.libelle(error)) }
        }
        moteur = await sonde
        recherche = await web
    }
}

/// Une sonde. `☠` Trois états, pas deux : disponible, indisponible, et PAS
/// ENCORE SONDÉ. Afficher « injoignable » pendant le premier relevé serait un
/// mensonge d'une seconde à chaque ouverture d'écran.
struct CarteSonde: View {
    let titre: String
    let disponible: Bool?
    let detail: String?
    let mesure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.fin) {
            HStack {
                Text(titre).note().foregroundStyle(Teinte.encreDouce)
                Spacer(minLength: Trame.serre)
                Sceau(libelle, symbole: symbole).ton(ton)
            }
            if let mesure {
                LigneMesure(libelle: "Latence", valeur: mesure)
            }
            if let detail, !detail.isEmpty {
                Text(detail).brut().foregroundStyle(Teinte.encreEteinte)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var libelle: String {
        switch disponible {
        case true: return "Répond"
        case false: return "Muet"
        case nil: return "Sonde…"
        }
    }

    private var symbole: String {
        switch disponible {
        case true: return "checkmark.circle.fill"
        case false: return "xmark.octagon.fill"
        case nil: return "hourglass"
        }
    }

    private var ton: Ton {
        switch disponible {
        case true: return .ok
        case false: return .panne
        case nil: return .neutre
        }
    }
}

/// Un chargement passé : son issue, sa cause qualifiée, son plan, son déroulé.
struct LigneSession: View {
    let session: SessionChargement
    @State private var deplie = false

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            entete
            if let cause = session.cause {
                LigneMesure(libelle: "Cause", valeur: cause.replacingOccurrences(of: "_", with: " "),
                            ton: .panne)
            }
            if !session.message.isEmpty {
                Text(session.message).note().foregroundStyle(Teinte.encreDouce)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !session.remediation.isEmpty {
                Text(session.remediation).brut().foregroundStyle(Teinte.encreEteinte)
                    .fixedSize(horizontal: false, vertical: true)
            }
            deroule
        }
    }

    private var entete: some View {
        HStack(alignment: .top, spacing: Trame.element) {
            VStack(alignment: .leading, spacing: Trame.fin) {
                Text(session.modele).mention().foregroundStyle(Teinte.encre).lineLimit(2)
                HStack(spacing: Trame.serre) {
                    Text(session.moteur).mesureFine()
                    if let duree = session.dureeLisible {
                        Text("·").mesureFine()
                        Text(duree).mesureFine()
                    }
                    if let plan = session.plan {
                        Text("·").mesureFine()
                        Text("\(plan.couchesGpu)/\(plan.couchesTotales) couches").mesureFine()
                    }
                }
                .foregroundStyle(Teinte.encreEteinte)
            }
            Spacer(minLength: 0)
            Sceau(libelle, symbole: symbole).ton(ton)
        }
    }

    /// Le déroulé est REPLIÉ par défaut : il fait dix à trente lignes, et on ne
    /// l'ouvre que quand l'issue surprend. Même raison que le bloc de
    /// raisonnement dans le fil.
    @ViewBuilder private var deroule: some View {
        if !session.entrees.isEmpty {
            Button {
                withAnimation(Elan.surface) { deplie.toggle() }
            } label: {
                HStack(spacing: Trame.fin) {
                    Image(systemName: deplie ? "chevron.down" : "chevron.right").imageScale(.small)
                    Text("\(session.entrees.count) étapes").legende()
                }
                .foregroundStyle(Teinte.encreDouce)
                .contentShape(.rect)
            }
            .buttonStyle(.appui)
            if deplie {
                VStack(alignment: .leading, spacing: Trame.fin) {
                    ForEach(session.entrees) { entree in
                        Text("[\(entree.phase)] \(entree.message)")
                            .brut()
                            .foregroundStyle(couleur(entree))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .transition(.scene)
            }
        }
    }

    private func couleur(_ entree: EntreeJournal) -> Color {
        if entree.estEchec { return Teinte.panne }
        return entree.estAvertissement ? Teinte.alerte : Teinte.encreEteinte
    }

    private var libelle: String {
        switch session.etat {
        case .pret: return "Chargé"
        case .enCours: return "En cours"
        case .echoue: return "Échec"
        case .inactif: return "Inactif"
        }
    }

    private var symbole: String {
        switch session.etat {
        case .pret: return "checkmark.circle.fill"
        case .enCours: return "hourglass"
        case .echoue: return "exclamationmark.triangle.fill"
        case .inactif: return "questionmark.circle"
        }
    }

    private var ton: Ton {
        switch session.etat {
        case .pret: return .ok
        case .enCours: return .actif
        case .echoue: return .panne
        case .inactif: return .neutre
        }
    }
}
#endif
