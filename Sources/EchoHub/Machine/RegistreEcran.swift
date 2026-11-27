// Les modèles que le PC connaît et sait charger.
//
// `☠` Le registre n'inscrit que le CHARGEABLE. Ce qui occupe le disque sans
// être inscrit se lit dans `DisqueEcran` — deux listes distinctes, parce que
// « ce que je peux charger » et « ce qui prend de la place » sont deux
// questions, et les mélanger rendait la seconde invisible.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct RegistreEcran: View {
    @Environment(Salon.self) private var salon
    @State private var etat: EtatChargement<[ModeleEnregistre]> = .chargement
    @State private var echecAction: String?
    @State private var eprouves: [PlanEprouve] = []
    @State private var strata: SondeStrata?

    var body: some View {
        PageAtelier("Modèles du PC", rafraichir: charger) {
            if let echecAction { EchecAction(raison: echecAction) }
            if let echec = salon.echecMachine { EchecAction(raison: echec) }
            if !eprouves.isEmpty { CommeLaDerniereFois(plans: eprouves) }
            if let strata { CarteStrata(sonde: strata) }
            contenu
        }
        .task { await charger() }
    }

    @ViewBuilder private var contenu: some View {
        switch etat {
        case .chargement:
            ChargementVue().transition(.scene)
        case .vide:
            EtatCalme(
                symbole: "square.stack.3d.up.slash", titre: "Aucun modèle enregistré",
                detail: "Le disque du PC ne porte rien que le planificateur sache charger."
            )
            .transition(.scene)
        case .echec(let raison):
            EtatCalme(
                symbole: "antenna.radiowaves.left.and.right.slash", titre: "Registre injoignable",
                detail: raison, actionTitre: "Réessayer", action: { Task { await charger() } }
            )
            .transition(.scene)
        case .pret(let modeles):
            liste(modeles)
        }
    }

    /// Les favoris en tête : deux ou trois modèles servent vraiment, les autres
    /// dorment sur le disque.
    private func liste(_ modeles: [ModeleEnregistre]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(ordonnes(modeles).enumerated()), id: \.element.id) { rang, modele in
                LigneModele(
                    modele: modele,
                    charge: modele.id == salon.statutPret?.modele,
                    occupe: salon.chargementEnCours,
                    charger: { Task { await chargerModele(modele) } },
                    decharger: { Task { await decharger() } },
                    favori: { Task { await basculerFavori(modele) } }
                )
                .entreeEnScene(rang: rang)
            }
        }
    }

    private func ordonnes(_ modeles: [ModeleEnregistre]) -> [ModeleEnregistre] {
        modeles.sorted { gauche, droite in
            gauche.favori == droite.favori ? gauche.nomCourt < droite.nomCourt : gauche.favori
        }
    }

    // MARK: - Actions

    private func chargerModele(_ modele: ModeleEnregistre) async {
        await salon.chargerModele(modele)
        await charger()
    }

    private func decharger() async {
        await salon.dechargerModele()
        await charger()
    }

    private func basculerFavori(_ modele: ModeleEnregistre) async {
        do {
            try await salon.modeles.marquerFavori(modele.id, !modele.favori)
            echecAction = nil
        } catch {
            Journal.echec("favori non enregistré : \(error)")
            echecAction = Salon.libelle(error)
        }
        await charger()
    }

    private func charger() async {
        await salon.rafraichirStatut()
        do {
            let liste = try await salon.modeles.registre()
            eprouves = (try? await salon.modeles.plansEprouves()) ?? []
            strata = try? await salon.modeles.sonderStrata()
            withAnimation(Elan.normal) { etat = liste.isEmpty ? .vide : .pret(liste) }
        } catch {
            Journal.echec("registre des modèles illisible : \(error)")
            withAnimation(Elan.normal) { etat = .echec(Salon.libelle(error)) }
        }
    }
}

/// Une ligne du registre. Toucher ouvre la fiche ; le verbe charge ou décharge.
///
/// `☠` Un seul verbe par ligne. Le GPU est exclusif : proposer « Charger » sur
/// six modèles à la fois laisserait croire qu'on peut en tenir six.
struct LigneModele: View {
    let modele: ModeleEnregistre
    let charge: Bool
    let occupe: Bool
    let charger: () -> Void
    let decharger: () -> Void
    let favori: () -> Void

    var body: some View {
        HStack(spacing: Trame.element) {
            Button(action: favori) {
                Image(systemName: modele.favori ? "star.fill" : "star")
                    .imageScale(.small)
                    .foregroundStyle(modele.favori ? Teinte.alerte : Teinte.encreEteinte)
                    .frame(width: Trame.cible, height: Trame.cible)
                    .contentShape(.rect)
            }
            .buttonStyle(.appui)
            .accessibilityLabel(modele.favori ? "Retirer des favoris" : "Mettre en favori")
            NavigationLink { FicheModeleEcran(modele: modele) } label: { identite }
                .buttonStyle(.appui)
            Spacer(minLength: 0)
            action
        }
        .frame(minHeight: Trame.rangee)
    }

    private var identite: some View {
        VStack(alignment: .leading, spacing: Trame.fin) {
            Text(modele.nomCourt)
                .mention()
                .foregroundStyle(charge ? Teinte.accent : Teinte.encre)
                .lineLimit(1)
            HStack(spacing: Trame.serre) {
                // Une mesure : chiffres à chasse fixe, sinon la largeur danse
                // d'une ligne à l'autre.
                Text(modele.tailleLisible).mesureFine()
                if let quantification = modele.quantification {
                    Text("·").mesureFine()
                    Text(quantification).mesureFine()
                }
                if let contexte = modele.contexteMax {
                    Text("·").mesureFine()
                    Text(Mesures.tokens(contexte)).mesureFine()
                }
            }
            .foregroundStyle(Teinte.encreEteinte)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }

    @ViewBuilder private var action: some View {
        if charge {
            VerbeAtelier(libelle: "Décharger", ton: .alerte, occupe: occupe, action: decharger)
        } else {
            VerbeAtelier(libelle: "Charger", occupe: occupe, action: charger)
        }
    }
}

/// Les plans qui ont réellement chargé un modèle (`ChargementEprouve.tsx`) : le geste le plus sûr depuis le téléphone.
private struct CommeLaDerniereFois: View {
    @Environment(Salon.self) private var salon
    let plans: [PlanEprouve]

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            Text("Comme la dernière fois").rubrique()
            ForEach(plans) { plan in
                HStack(spacing: Trame.element) {
                    VStack(alignment: .leading, spacing: Trame.fin) {
                        Text(PhaseTour.nomCourt(plan.identifiant)).mention().foregroundStyle(Teinte.encre).lineLimit(1)
                        Text(plan.resume).mesureFine().foregroundStyle(Teinte.encreDouce)
                    }
                    Spacer(minLength: 0)
                    VerbeAtelier(libelle: "Recharger", occupe: salon.chargementEnCours) {
                        Task { await salon.chargerPlanEprouve(plan) }
                    }
                    .disabled(salon.statutPret?.modele == plan.identifiant)
                }
                .frame(minHeight: Trame.rangee)
            }
        }
        .padding(.bottom, Trame.groupe)
    }
}

/// Strata, le serveur de modèle de l'hôte : son état, et le charger à la place du modèle actif.
private struct CarteStrata: View {
    @Environment(Salon.self) private var salon
    let sonde: SondeStrata

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            HStack {
                Text("Strata").rubrique()
                Spacer(minLength: 0)
                Sceau(sonde.joignable ? (sonde.charge ? "Modèle servi" : "Joignable") : "Arrêté")
                    .ton(sonde.joignable ? .ok : .neutre)
            }
            if let modele = sonde.modele {
                Text(PhaseTour.nomCourt(modele) + (sonde.contexte.map { " · \($0 / 1024) k" } ?? ""))
                    .mesureFine().foregroundStyle(Teinte.encreDouce)
            }
            if sonde.joignable {
                VerbeAtelier(libelle: "Charger Strata", occupe: salon.chargementEnCours) {
                    Task { await salon.chargerStrata() }
                }
            } else if let detail = sonde.detail {
                Text(detail).legende().foregroundStyle(Teinte.encreEteinte).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, Trame.groupe)
    }
}
#endif
