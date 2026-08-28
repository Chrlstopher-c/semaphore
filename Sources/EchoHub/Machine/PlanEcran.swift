// Choisir un modèle, voir le plan que le PC propose, le dégrader s'il ne tient
// pas, l'appliquer, suivre l'état.
//
// `☠` L'app ne CALCULE aucun plan. Elle envoie les entrées mesurées, affiche ce
// que le planificateur rend, et repose ce même plan pour charger. Replanifier
// au moment du chargement produirait un autre plan — la VRAM libre a pu changer
// — et Chris obtiendrait autre chose que ce qu'il vient de valider.
//
// `☠` Après un échec on DÉGRADE, on ne réessaie pas. Relancer le plan qui vient
// d'échouer, ou pire monter un paramètre, c'était l'escalade de la v1 :
// contexte 55k → 131k après un échec de VRAM. C'est pourquoi il n'y a pas de
// bouton « Réessayer » sur cet écran.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct PlanEcran: View {
    let modele: ModeleEnregistre

    @Environment(Salon.self) private var salon
    @State private var etat: EtatChargement<ApercuPlan> = .chargement
    @State private var cible: CibleChargement.Cible?
    /// Le plan tel que le serveur l'a rendu. C'est LUI qu'on repose, jamais une
    /// reconstruction à partir de l'aperçu.
    @State private var planBrut: ValeurJSON?
    @State private var preferences = PreferencesChargement()
    @State private var calcul: Task<Void, Never>?
    @State private var applique = 0

    var body: some View {
        PageAtelier(modele.nomCourt) {
            if let echec = salon.echecMachine { EchecAction(raison: echec) }
            reglages
            contenu
        }
        .task { await planifier() }
        .onDisappear { calcul?.cancel() }
        .sensoryFeedback(Retour.engage, trigger: applique)
    }

    @ViewBuilder private var contenu: some View {
        switch etat {
        case .chargement, .vide:
            ChargementVue().transition(.scene)
        case .echec(let raison):
            refus(raison)
        case .pret(let apercu):
            SectionAtelier("Plan proposé") { corpsDuPlan(apercu) }
            budget(apercu)
            actions(apercu)
        }
    }

    /// `☠` Un refus de cible n'est pas une panne réseau : rien n'a échoué, il
    /// manque une valeur dans l'en-tête. Le dire ainsi évite d'envoyer Chris
    /// vérifier son tunnel pour un fichier qui ne déclare pas ses couches.
    private func refus(_ raison: String) -> some View {
        EtatCalme(
            symbole: "questionmark.folder", titre: "Rien à planifier", detail: raison,
            actionTitre: "Relancer le calcul", action: { Task { await planifier() } }
        )
        .transition(.scene)
    }

    private func corpsDuPlan(_ apercu: ApercuPlan) -> some View {
        Panneau {
            VStack(alignment: .leading, spacing: Trame.element) {
                entete(apercu)
                ForEach(apercu.lignes) { ligne in
                    LigneMesure(
                        libelle: ligne.libelle, valeur: ligne.valeur,
                        justification: ligne.justification,
                        ton: ligne.plafonnee ? .alerte : .neutre
                    )
                }
            }
        }
    }

    /// Le placement en une ligne : c'est la seule chose qu'on regarde d'abord.
    private func entete(_ apercu: ApercuPlan) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(apercu.couchesGpu) / \(apercu.couchesTotales) couches sur GPU")
                .mesure().foregroundStyle(Teinte.encre)
            Spacer(minLength: Trame.serre)
            if apercu.niveauDegradation > 0 {
                Sceau("Dégradé ×\(apercu.niveauDegradation)").ton(.alerte)
            }
        }
    }

    private func budget(_ apercu: ApercuPlan) -> some View {
        SectionAtelier("Budget VRAM") {
            Panneau {
                VStack(alignment: .leading, spacing: Trame.element) {
                    Jauge(part: apercu.part, ton: apercu.vramRestanteOctets < 0 ? .panne : .actif)
                    LigneMesure(
                        libelle: "Engagée", valeur: Mesures.octets(apercu.vramRequiseOctets)
                    )
                    LigneMesure(
                        libelle: "Disponible",
                        valeur: Mesures.octets(apercu.vramDisponibleOctets)
                    )
                    ForEach(apercu.postes) { poste in
                        LigneMesure(
                            libelle: poste.libelle, valeur: Mesures.octets(poste.octets),
                            justification: poste.justification
                        )
                    }
                    avertissements(apercu)
                }
            }
        }
    }

    @ViewBuilder private func avertissements(_ apercu: ApercuPlan) -> some View {
        ForEach(apercu.ejections, id: \.self) { identifiant in
            Text("À éjecter d'abord : \(identifiant)")
                .note().foregroundStyle(Teinte.alerte)
        }
        ForEach(apercu.avertissements, id: \.self) { texte in
            Text(texte).note().foregroundStyle(Teinte.alerte)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Ce que Chris peut demander

    private var reglages: some View {
        SectionAtelier("Ce que tu demandes") {
            Panneau {
                VStack(alignment: .leading, spacing: Trame.element) {
                    ChoixContexte(valeur: $preferences.contexte, plafond: modele.contexteMax)
                    ChoixCacheKv(valeur: $preferences.typeCacheKv)
                    Toggle(isOn: $preferences.flashAttention) {
                        Text("Flash attention").note().foregroundStyle(Teinte.encreDouce)
                    }
                    .tint(Teinte.accent)
                }
            }
        }
        .onChange(of: preferences) { _, _ in Task { await planifier() } }
    }

    private func actions(_ apercu: ApercuPlan) -> some View {
        VStack(spacing: Trame.element) {
            Button("Charger ce plan") { Task { await charger() } }
                .buttonStyle(.engage)
                .disabled(salon.chargementEnCours || planBrut == nil)
            if salon.statutPret?.etat == .echoue {
                Button("Dégrader et recalculer") { Task { await degrader() } }
                    .buttonStyle(.appui).mention().foregroundStyle(Teinte.alerte)
            }
        }
    }

    // MARK: - Actions

    /// Chaque changement de préférence redemande un plan complet — c'est ce qui
    /// garantit que ce qui est affiché est exactement ce que le planificateur
    /// produirait au chargement. La demande précédente est annulée : sur un
    /// réseau à quatre sauts, deux réponses dans le désordre afficheraient le
    /// plan de la préférence d'avant.
    private func planifier() async {
        calcul?.cancel()
        let tache = Task { await calculer() }
        calcul = tache
        await tache.value
    }

    private func calculer() async {
        if etat.contenu == nil { etat = .chargement }
        do {
            let visee = try await salon.viser(modele, preferences: preferences)
            guard !Task.isCancelled else { return }
            cible = visee
            adopter(try await salon.modeles.planifier(demande: visee.demande))
        } catch let refus as RefusCible {
            Journal.echec("cible non calculable : \(refus.manquant)")
            poser(.echec("\(refus.manquant). \(refus.remediation)"))
        } catch {
            Journal.echec("planification refusée : \(error)")
            poser(.echec(Salon.libelle(error)))
        }
    }

    /// `☠` Après un échec, on demande au serveur un plan STRICTEMENT plus
    /// conservateur, en lui laissant la cause qu'il a lui-même observée : la
    /// supposer depuis le téléphone dégraderait dans la mauvaise direction.
    private func degrader() async {
        guard let cible, let planBrut else { return }
        do {
            adopter(try await salon.modeles.degrader(
                demande: cible.demande, planEchoue: planBrut,
                cause: salon.statutPret?.cause
            ))
        } catch {
            Journal.echec("dégradation refusée : \(error)")
            poser(.echec(Salon.libelle(error)))
        }
    }

    private func charger() async {
        guard let cible, let planBrut, !salon.chargementEnCours else { return }
        applique += 1
        salon.poser(chargement: true)
        defer { salon.poser(chargement: false) }
        do {
            try await salon.appliquer(plan: planBrut, chemin: cible.cheminModele)
        } catch {
            Journal.echec("chargement refusé : \(error)")
            salon.poser(echecMachine: Salon.libelle(error))
        }
    }

    private func adopter(_ reponse: ValeurJSON) {
        guard !Task.isCancelled else { return }
        guard let apercu = ApercuPlan.lire(reponse: reponse), let plan = reponse["plan"] else {
            return poser(.echec("Le planificateur n'a rendu aucun plan lisible."))
        }
        planBrut = plan
        poser(.pret(apercu))
    }

    private func poser(_ nouveau: EtatChargement<ApercuPlan>) {
        guard !Task.isCancelled else { return }
        withAnimation(Elan.normal) { etat = nouveau }
    }
}

/// Le contexte demandé, en paliers.
///
/// `☠` Des paliers et non un curseur : un curseur de 0 à 262 144 sur 335 pt
/// donne un pas de 800 tokens par pixel, et chaque pixel parcouru redemande un
/// plan à travers le tunnel. « Auto » est le premier palier parce que c'est le
/// régime normal — le planificateur décide et explique.
struct ChoixContexte: View {
    @Binding var valeur: Int?
    let plafond: Int?

    private static let paliers = [8192, 16384, 32768, 65536, 131_072, 262_144]

    private var proposes: [Int] {
        guard let plafond else { return Self.paliers }
        return Self.paliers.filter { $0 <= plafond }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            Text("Contexte").note().foregroundStyle(Teinte.encreDouce)
            Picker("Contexte", selection: $valeur) {
                Text("Auto").tag(Int?.none)
                ForEach(proposes, id: \.self) { palier in
                    Text(Mesures.tokens(palier)).tag(Int?.some(palier))
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

/// Le cache KV. `q8_0` divise par deux ce qu'un long contexte coûte, pour une
/// perte que Chris juge lui-même — l'app n'en décide pas à sa place.
struct ChoixCacheKv: View {
    @Binding var valeur: String

    private static let types = ["f16", "q8_0", "q4_0"]

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            Text("Cache KV").note().foregroundStyle(Teinte.encreDouce)
            Picker("Cache KV", selection: $valeur) {
                ForEach(Self.types, id: \.self) { type in Text(type).tag(type) }
            }
            .pickerStyle(.segmented)
        }
    }
}
#endif
