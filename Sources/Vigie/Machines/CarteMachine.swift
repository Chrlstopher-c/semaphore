// Une machine du parc, et un compte Claude : les deux cartes de l'écran.
//
// `☠` Une machine hors ligne n'est PAS peinte en rouge : le poste éteint la
// nuit est le régime nominal, ses équipes repartent à son retour (H-75). La
// charge PROCESSEUR n'est jamais colorée non plus — 100 % de CPU est le régime
// attendu d'une machine qui travaille.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct CarteMachine: View {
    let machine: MachineApi
    let metriques: MetriquesHote?
    let equipes: Int

    private var degre: DegreSanteMachine {
        SanteMachine.degre(enLigne: machine.enLigne, metriques: metriques)
    }

    var body: some View {
        Panneau(rail: rail) {
            VStack(alignment: .leading, spacing: Trame.element) {
                entete
                if let metriques {
                    mesures(metriques)
                } else {
                    Text(machine.enLigne
                        ? "Relevé indisponible — le lien répond, la mesure non."
                        : "Hors ligne — aucun relevé. Ses équipes repartiront à son retour.")
                        .mention()
                        .foregroundStyle(Teinte.encreTernie)
                }
                if let motif = SanteMachine.motif(enLigne: machine.enLigne, metriques: metriques),
                   metriques != nil {
                    Text(motif)
                        .mention()
                        .foregroundStyle(ton.teinte)
                }
            }
        }
    }

    private var entete: some View {
        HStack(spacing: Trame.serre) {
            PointVeille(ton: machine.enLigne ? .sain : .veille)
            Text(machine.id)
                .phraseForte()
                .foregroundStyle(Teinte.encre)
            Spacer(minLength: 0)
            PuceDonnee(equipes == 0 ? "aucune équipe" : "\(equipes) équipe\(equipes > 1 ? "s" : "")")
            Sceau(libelleEtat, ton: ton)
        }
    }

    private func mesures(_ mesures: MetriquesHote) -> some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            if let memoire = mesures.partMemoire {
                JaugeFine(
                    "Mémoire",
                    part: memoire,
                    detail: FormatMachine.memoire(
                        utiliseeMo: mesures.memUtiliseeMo, totaleMo: mesures.memTotaleMo
                    ),
                    seuilVigilance: 0.85,
                    seuilDanger: 0.95
                )
            }
            if let disque = mesures.partDisque {
                JaugeFine(
                    "Disque",
                    part: disque,
                    detail: FormatMachine.disque(
                        utiliseGo: mesures.disqueUtiliseGo, totalGo: mesures.disqueTotalGo
                    ),
                    seuilVigilance: 0.8,
                    seuilDanger: 0.9
                )
            }
            lignes(mesures)
        }
    }

    private func lignes(_ mesures: MetriquesHote) -> some View {
        VStack(spacing: 0) {
            LigneCle("Processeur", valeur: processeur(mesures))
            LigneCle(
                "Température",
                valeur: FormatMachine.temperature(mesures.tempCpuC),
                teinteValeur: teinteTemperature(mesures.tempCpuC)
            )
            LigneCle("Réseau", valeur: reseau(mesures))
            if let gpu = mesures.gpu {
                LigneCle("GPU", valeur: gpuLisible(gpu))
            }
            LigneCle("En marche depuis", valeur: FormatMachine.duree(mesures.uptimeS), derniere: true)
        }
    }

    /// `☠` `nil` au premier passage = « la mesure arrive au prochain relevé »,
    /// pas une sonde cassée — le mot le dit.
    private func processeur(_ mesures: MetriquesHote) -> String {
        switch mesures.chargeProcesseur {
        case .mesuree(let pct): return "\(pct) %"
        case .enCoursDeMesure: return "en cours de mesure"
        }
    }

    private func reseau(_ mesures: MetriquesHote) -> String {
        let montant = mesures.debitMontant.valeur.map(FormatMachine.debit) ?? FormatMachine.absente
        let descendant = mesures.debitDescendant.valeur.map(FormatMachine.debit) ?? FormatMachine.absente
        return "↑ \(montant) · ↓ \(descendant)"
    }

    /// `☠` Une carte GPU absente ne s'affiche pas du tout — « 0 % » ferait
    /// croire à une carte inactive, pas absente.
    private func gpuLisible(_ gpu: MetriquesGpu) -> String {
        let util = FormatMachine.pourcentage(gpu.utilPct)
        let memoire = FormatMachine.memoireGpu(utiliseeMo: gpu.memUtiliseeMo, totaleMo: gpu.memTotaleMo)
        return "\(util) · \(memoire)"
    }

    private func teinteTemperature(_ celsius: Int?) -> Color {
        guard let celsius else { return Teinte.encre }
        if celsius >= SeuilsMachine.temperatureDangerC { return Teinte.danger }
        if celsius >= SeuilsMachine.temperatureVigilanceC { return Teinte.vigilance }
        return Teinte.encre
    }

    // MARK: - États

    private var libelleEtat: String {
        switch degre {
        case .horsLigne: return "hors ligne"
        case .sansReleve: return "sans relevé"
        case .sain: return "en ligne"
        case .vigilance: return "sous tension"
        case .danger: return "saturée"
        }
    }

    private var ton: Ton {
        switch degre {
        case .horsLigne: return .veille
        case .sansReleve: return .neutre
        case .sain: return .sain
        case .vigilance: return .vigilance
        case .danger: return .danger
        }
    }

    private var rail: Ton? {
        switch degre {
        case .vigilance: return .vigilance
        case .danger: return .danger
        default: return nil
        }
    }
}

/// Un compte Claude et ses deux fenêtres. `☠` En pourcentage, jamais en
/// dollars : sur abonnement les champs monétaires sont nuls — une jauge bâtie
/// dessus laisserait saturer le quota sans prévenir.
struct CarteCompte: View {
    let compte: AccountApi
    let equipes: Int

    var body: some View {
        Panneau(rail: compte.isUsingOverage ? .danger : nil) {
            VStack(alignment: .leading, spacing: Trame.element) {
                entete
                JaugeFine("Fenêtre 5 h", part: Double(compte.fiveHour.util) / 100, detail: reset(compte.fiveHour))
                JaugeFine("Fenêtre 7 j", part: Double(compte.sevenDay.util) / 100, detail: reset(compte.sevenDay))
            }
        }
    }

    private var entete: some View {
        HStack(spacing: Trame.serre) {
            Text(compte.label)
                .phraseForte()
                .foregroundStyle(Teinte.encre)
            // Vide tant qu'aucune sonde n'a répondu — honnête, jamais inventé.
            if !compte.plan.isEmpty { PuceDonnee(compte.plan) }
            if equipes > 0 { PuceDonnee("\(equipes) équipe\(equipes > 1 ? "s" : "")") }
            Spacer(minLength: 0)
            sceauStatut
        }
    }

    /// `☠` « saturé » et « dépassement payant » sont deux choses : le second
    /// continue de tourner et coûte de l'argent réel.
    @ViewBuilder private var sceauStatut: some View {
        if compte.isUsingOverage {
            Sceau("dépassement payant", ton: .danger)
        } else if compte.status == .rejete {
            Sceau("saturé", ton: .vigilance)
        } else if compte.status == .avertissement {
            Sceau("se remplit", ton: .vigilance)
        }
    }

    /// « dans 3 h 30 » dit s'il faut attendre, « 22:30 » dit s'il faut aller
    /// dormir : les deux mentions se complètent.
    private func reset(_ fenetre: FenetreApi) -> String {
        guard let heure = fenetre.resetAt else { return fenetre.resetLabel }
        return "\(fenetre.resetLabel) · \(heure)"
    }
}
#endif
