// Un dépôt du Hub, ses variantes, et le geste qui lance un transfert.
//
// `☠` C'est ici que se joue la seule décision coûteuse de l'atelier. Un dépôt
// GGUF porte couramment dix variantes, de Q2 à F16, et vingt gigaoctets
// séparent les deux extrêmes. L'écran liste donc les fichiers AVEC leur taille,
// un par rangée, et le transfert se lance sur une variante — jamais sur le
// dépôt entier par défaut, qui prendrait tout.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct FicheDepotEcran: View {
    let depot: String

    @Environment(Salon.self) private var salon
    @State private var etat: EtatChargement<ResultatDepot> = .chargement
    @State private var lance: String?
    @State private var echecAction: String?
    @State private var occupe = false

    var body: some View {
        PageAtelier(nomCourt, rafraichir: charger) {
            if let echecAction { EchecAction(raison: echecAction) }
            if let lance {
                Text("Transfert lancé : \(lance). Il se suit depuis « Transferts ».")
                    .note().foregroundStyle(Teinte.ok)
                    .fixedSize(horizontal: false, vertical: true)
            }
            contenu
        }
        .task { await charger() }
    }

    private var nomCourt: String {
        depot.split(separator: "/").last.map(String.init) ?? depot
    }

    @ViewBuilder private var contenu: some View {
        switch etat {
        case .chargement, .vide:
            ChargementVue().transition(.scene)
        case .echec(let raison):
            EtatCalme(
                symbole: "questionmark.folder", titre: "Fiche introuvable", detail: raison,
                actionTitre: "Réessayer", action: { Task { await charger() } }
            )
            .transition(.scene)
        case .pret(let fiche):
            identite(fiche)
            annonce(fiche)
            variantes(fiche)
        }
    }

    private func identite(_ fiche: ResultatDepot) -> some View {
        Panneau {
            VStack(alignment: .leading, spacing: Trame.element) {
                Text(fiche.depot).note().foregroundStyle(Teinte.encreDouce).lineLimit(3)
                HStack(spacing: Trame.serre) {
                    if fiche.dejaTelecharge { Sceau("Sur le disque").ton(.ok) }
                    if fiche.gated { Sceau("Licence à accepter").ton(.alerte) }
                }
                if fiche.gated {
                    Text("Ce dépôt exige une acceptation de licence sur le Hub. Un transfert "
                        + "lancé d'ici échouera tant qu'elle n'est pas donnée.")
                        .note().foregroundStyle(Teinte.alerte)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// `☠` « Annoncé » et pas « mesuré ». Ces valeurs servent à CHOISIR un
    /// dépôt, jamais à dimensionner un chargement : le planificateur ne
    /// travaille que sur l'en-tête du fichier une fois qu'il est là.
    private func annonce(_ fiche: ResultatDepot) -> some View {
        SectionAtelier("Ce que le Hub annonce") {
            Panneau {
                VStack(alignment: .leading, spacing: Trame.element) {
                    if let architecture = fiche.annonce.architecture {
                        LigneMesure(libelle: "Architecture", valeur: architecture)
                    }
                    if let contexte = fiche.annonce.contexte {
                        LigneMesure(libelle: "Contexte", valeur: Mesures.tokens(contexte))
                    }
                    if let taille = fiche.tailleLisible {
                        LigneMesure(libelle: "Dépôt entier", valeur: taille)
                    }
                    if !fiche.capacitesDeduites.isEmpty {
                        Text("Capacités déduites de ses déclarations, pas vérifiées :")
                            .note().foregroundStyle(Teinte.encreDouce)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(fiche.capacitesDeduites) { capacite in
                            LigneCapacite(capacite: capacite)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private func variantes(_ fiche: ResultatDepot) -> some View {
        if fiche.fichiersGguf.isEmpty {
            EtatCalme(
                symbole: "doc.questionmark", titre: "Aucune variante GGUF",
                detail: "Ce dépôt ne porte pas de fichier de poids que le PC sache charger."
            )
        } else {
            SectionAtelier("Variantes") {
                VStack(spacing: Trame.element) {
                    ForEach(fiche.fichiersGguf) { fichier in
                        LigneVariante(fichier: fichier, occupe: occupe) {
                            Task { await telecharger(fiche.depot, fichier.nom) }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func charger() async {
        do {
            let fiche = try await salon.modeles.ficheDepot(depot)
            withAnimation(Elan.normal) { etat = .pret(fiche) }
        } catch {
            Journal.echec("fiche du dépôt \(depot) illisible : \(error)")
            withAnimation(Elan.normal) { etat = .echec(Salon.libelle(error)) }
        }
    }

    private func telecharger(_ depot: String, _ fichier: String) async {
        occupe = true
        defer { occupe = false }
        do {
            let transfert = try await salon.modeles.demarrerTelechargement(
                depot: depot, fichier: fichier
            )
            withAnimation(Elan.normal) {
                lance = transfert.nomCourt
                echecAction = nil
            }
        } catch {
            Journal.echec("transfert de \(fichier) refusé : \(error)")
            withAnimation(Elan.normal) { echecAction = Salon.libelle(error) }
        }
    }
}

/// Une variante du dépôt. `☠` L'étiquette vient du NOM DE FICHIER : c'est une
/// intention de son auteur, pas un fait vérifié. La taille, elle, est annoncée
/// par le Hub — et c'est elle qui décide.
struct LigneVariante: View {
    let fichier: FichierDepot
    let occupe: Bool
    let telecharger: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Trame.element) {
            VStack(alignment: .leading, spacing: Trame.fin) {
                Text(fichier.nom).mention().foregroundStyle(Teinte.encre).lineLimit(2)
                HStack(spacing: Trame.serre) {
                    if let taille = fichier.tailleLisible { Text(taille).mesureFine() }
                    if let etiquette = fichier.etiquette {
                        Text("·").mesureFine()
                        Text(etiquette).mesureFine()
                    }
                }
                .foregroundStyle(Teinte.encreEteinte)
            }
            Spacer(minLength: 0)
            VerbeAtelier(libelle: "Télécharger", occupe: occupe, action: telecharger)
        }
        .padding(.vertical, Trame.serre)
    }
}
#endif
