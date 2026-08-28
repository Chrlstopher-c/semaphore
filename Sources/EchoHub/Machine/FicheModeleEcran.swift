// Un modèle : ce que son en-tête déclare, ce qu'on en déduit, ce qui cloche, et
// les gestes qui le concernent.
//
// `☠` Trois natures de savoir, et l'écran ne doit jamais les confondre :
// - les MÉTADONNÉES sont lues dans l'en-tête du fichier ;
// - les CAPACITÉS sont déduites, chacune avec les indices qui l'ont produite ;
// - la COHÉRENCE confronte le déclaré au présent.
// Les afficher du même trait ferait passer une déduction pour un fait vérifié —
// c'est exactement l'erreur qui faisait télécharger douze gigaoctets pour un
// modèle qui ne savait pas ce qu'on croyait.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct FicheModeleEcran: View {
    let modele: ModeleEnregistre

    @Environment(Salon.self) private var salon
    @Environment(\.dismiss) private var fermer
    @State private var fiche: FicheMetadonnees?
    @State private var capacites: [CapaciteDeduite] = []
    @State private var rapport: RapportCoherence?
    @State private var etat: EtatChargement<Bool> = .chargement
    @State private var oubliDemande = false
    @State private var echecAction: String?

    var body: some View {
        PageAtelier(modele.nomCourt, rafraichir: charger) {
            if let echecAction { EchecAction(raison: echecAction) }
            identite
            contenu
            gestes
        }
        .task { await charger() }
        .confirmationDialog(
            "Oublier ce modèle ?", isPresented: $oubliDemande, titleVisibility: .visible
        ) {
            Button("Oublier du registre", role: .destructive) { Task { await oublier() } }
            Button("Annuler", role: .cancel) {}
        } message: {
            // `☠` La portée RÉELLE, et elle est rassurante ici : oublier n'est
            // pas supprimer. Confondre les deux ferait hésiter sur un geste
            // réversible, ou pire, rassurerait sur celui qui ne l'est pas.
            Text("Le fichier reste sur le disque du PC. Seule l'entrée du registre disparaît "
                + "— une synchronisation la remettra.")
        }
    }

    private var identite: some View {
        Panneau {
            VStack(alignment: .leading, spacing: Trame.element) {
                HStack {
                    Text(modele.depot).note().foregroundStyle(Teinte.encreDouce).lineLimit(2)
                    Spacer(minLength: Trame.serre)
                    if modele.id == salon.statutPret?.modele {
                        Sceau("Chargé", symbole: "checkmark.circle.fill").ton(.ok)
                    }
                }
                LigneMesure(libelle: "Taille", valeur: modele.tailleLisible)
                LigneMesure(libelle: "Format", valeur: modele.format)
                if let fichier = modele.fichier {
                    Text(fichier).brut().foregroundStyle(Teinte.encreEteinte)
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
                symbole: "doc.questionmark", titre: "Fiche illisible", detail: raison,
                actionTitre: "Réessayer", action: { Task { await charger() } }
            )
            .transition(.scene)
        case .pret:
            sectionCoherence
            sectionMetadonnees
            sectionCapacites
        }
    }

    /// La cohérence passe EN PREMIER : c'est la réponse à « pourquoi ce modèle
    /// refuse de se charger ». Une fiche de métadonnées au-dessus ferait
    /// chercher la cause plus bas.
    @ViewBuilder private var sectionCoherence: some View {
        if let rapport, !rapport.incoherences.isEmpty {
            SectionAtelier(rapport.chargeable ? "Réserves" : "Ce qui bloque") {
                Panneau {
                    VStack(alignment: .leading, spacing: Trame.element) {
                        ForEach(rapport.incoherences) { ecart in
                            LigneIncoherence(incoherence: ecart)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var sectionMetadonnees: some View {
        if let fiche {
            SectionAtelier("Lu dans l'en-tête") {
                Panneau {
                    VStack(alignment: .leading, spacing: Trame.element) {
                        ForEach(fiche.lignes) { ligne in
                            LigneMesure(libelle: ligne.libelle, valeur: ligne.valeur)
                        }
                    }
                }
            }
        }
    }

    /// `☠` « Déduites », et le mot compte. Le Hub n'a pas de champ « capacités » :
    /// ce sont des conclusions tirées de déclarations, et chacune porte ses
    /// indices. Les afficher comme un fait vérifié serait mentir par mise en forme.
    @ViewBuilder private var sectionCapacites: some View {
        if !capacites.isEmpty {
            SectionAtelier("Capacités déduites") {
                Panneau {
                    VStack(alignment: .leading, spacing: Trame.element) {
                        ForEach(capacites) { capacite in
                            LigneCapacite(capacite: capacite)
                        }
                    }
                }
            }
        }
    }

    private var gestes: some View {
        VStack(spacing: Trame.element) {
            NavigationLink { PlanEcran(modele: modele) } label: {
                Text("Voir le plan de chargement")
                    .entete().foregroundStyle(Teinte.fond)
                    .frame(maxWidth: .infinity, minHeight: Trame.cible)
                    .background(Teinte.accent)
                    .clipShape(.rect(cornerRadius: Galbe.controle, style: .continuous))
            }
            .buttonStyle(.appui)
            Button("Oublier du registre") { oubliDemande = true }
                .buttonStyle(.appui).mention().foregroundStyle(Teinte.encreDouce)
        }
    }

    // MARK: - Actions

    /// Les trois relevés partent ENSEMBLE : ils sont indépendants, et les
    /// enchaîner ferait trois traversées du tunnel bout à bout.
    private func charger() async {
        if etat.contenu == nil { etat = .chargement }
        do {
            async let brutes = salon.modeles.metadonnees(modele.id)
            async let deduites = salon.modeles.capacites(modele.id)
            async let coherence = salon.modeles.coherence(modele.id)
            fiche = FicheMetadonnees.lire(try await brutes)
            capacites = try await deduites
            rapport = try await coherence
            withAnimation(Elan.normal) { etat = .pret(true) }
        } catch {
            Journal.echec("fiche de \(modele.id) illisible : \(error)")
            withAnimation(Elan.normal) { etat = .echec(Salon.libelle(error)) }
        }
    }

    private func oublier() async {
        do {
            try await salon.modeles.oublier(modele.id)
            fermer()
        } catch {
            Journal.echec("oubli de \(modele.id) refusé : \(error)")
            echecAction = Salon.libelle(error)
        }
    }
}

/// Un écart entre le déclaré et le présent. `bloquant` veut dire : le
/// chargement échouera, inutile d'essayer — c'est le seul cas qui porte le rouge.
struct LigneIncoherence: View {
    let incoherence: Incoherence

    private var ton: Ton { incoherence.niveau == .bloquant ? .panne : .alerte }

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.fin) {
            HStack(alignment: .top, spacing: Trame.serre) {
                Image(systemName: incoherence.niveau == .bloquant
                    ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .imageScale(.small)
                    .foregroundStyle(ton.couleur)
                Text(incoherence.message).note().foregroundStyle(Teinte.encre)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !incoherence.remediation.isEmpty {
                Text(incoherence.remediation)
                    .brut().foregroundStyle(Teinte.encreEteinte)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Une capacité et les indices qui l'ont produite. Les indices ne sont pas une
/// coquetterie : ils sont ce qui distingue une déduction d'une mesure.
struct LigneCapacite: View {
    let capacite: CapaciteDeduite

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.fin) {
            Text(capacite.capacite.replacingOccurrences(of: "_", with: " "))
                .mention().foregroundStyle(Teinte.encre)
            Text(capacite.indices.map { "\($0.source) : \($0.valeur)" }.joined(separator: " · "))
                .brut().foregroundStyle(Teinte.encreEteinte)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
#endif
