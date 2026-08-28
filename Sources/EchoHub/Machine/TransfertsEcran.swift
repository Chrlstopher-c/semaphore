// Les transferts en cours, et leur progression RÉELLE.
//
// `☠` La progression affichée est la progression reçue. Le flux SSE du PC pose
// un état complet à chaque relevé ; l'écran le peint et n'interpole rien. Quand
// le Hub n'a pas annoncé les tailles, il n'y a PAS de barre — seulement les
// octets reçus. Une barre à progression inconnue ment sur ce qu'elle sait, et
// une barre qui avance toute seule ment tout court.
//
// `☠` Le flux est fermé dès que l'écran disparaît (`onDisappear` annule la
// tâche, l'`AsyncStream` referme la requête). Sans ça, le PC diffuserait dans
// le vide vers un téléphone en veille.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct TransfertsEcran: View {
    @Environment(Salon.self) private var salon
    @State private var transferts: [Telechargement] = []
    @State private var etat: EtatChargement<Bool> = .chargement
    @State private var suivi: Task<Void, Never>?
    @State private var echecAction: String?

    var body: some View {
        PageAtelier("Transferts", rafraichir: charger) {
            if let echecAction { EchecAction(raison: echecAction) }
            contenu
        }
        .task {
            await charger()
            demarrerLeSuivi()
        }
        .onDisappear {
            suivi?.cancel()
            suivi = nil
        }
    }

    @ViewBuilder private var contenu: some View {
        switch etat {
        case .chargement:
            ChargementVue().transition(.scene)
        case .vide:
            EtatCalme(
                symbole: "arrow.down.circle", titre: "Aucun transfert",
                detail: "Rien n'est en cours, et rien n'a été lancé depuis le dernier "
                    + "démarrage du PC."
            )
            .transition(.scene)
        case .echec(let raison):
            EtatCalme(
                symbole: "antenna.radiowaves.left.and.right.slash", titre: "Transferts injoignables",
                detail: raison, actionTitre: "Réessayer", action: { Task { await charger() } }
            )
            .transition(.scene)
        case .pret:
            SectionAtelier("En cours et passés") {
                VStack(spacing: Trame.groupe) {
                    ForEach(transferts) { transfert in
                        LigneTransfert(
                            transfert: transfert,
                            annuler: { Task { await annuler(transfert) } },
                            relancer: { Task { await relancer(transfert) } }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Actions

    /// Le flux global : un état complet par transfert, à chaque changement.
    /// Rien n'est accumulé — chaque relevé remplace le précédent dans la liste.
    private func demarrerLeSuivi() {
        guard suivi == nil else { return }
        suivi = Task {
            for await evenement in FluxTelechargements.ouvrir(client: salon.client) {
                guard !Task.isCancelled else { return }
                switch evenement {
                case .etat(let transfert): fondre(transfert)
                case .echec(let raison): echecAction = raison
                case .fin: return
                }
            }
        }
    }

    /// Remplace la ligne en place, ou l'ajoute. Jamais un rechargement complet :
    /// une liste reconstruite à chaque relevé rejouerait l'entrée en scène de
    /// tout le monde, plusieurs fois par seconde.
    private func fondre(_ transfert: Telechargement) {
        guard let rang = transferts.firstIndex(where: { $0.id == transfert.id }) else {
            withAnimation(Elan.normal) {
                transferts.append(transfert)
                etat = .pret(true)
            }
            return
        }
        transferts[rang] = transfert
    }

    private func charger() async {
        do {
            let liste = try await salon.modeles.telechargements()
            transferts = liste
            withAnimation(Elan.normal) { etat = liste.isEmpty ? .vide : .pret(true) }
        } catch {
            Journal.echec("liste des transferts illisible : \(error)")
            withAnimation(Elan.normal) { etat = .echec(Salon.libelle(error)) }
        }
    }

    /// `☠` Les octets déjà écrits sont CONSERVÉS. Un transfert de plusieurs
    /// gigaoctets doit pouvoir reprendre ; les jeter demanderait un geste que
    /// cet écran ne propose pas, précisément pour qu'il ne soit pas fait par
    /// mégarde depuis un téléphone.
    private func annuler(_ transfert: Telechargement) async {
        do {
            fondre(try await salon.modeles.annulerTelechargement(transfert.id))
            echecAction = nil
        } catch {
            Journal.echec("annulation de \(transfert.id) refusée : \(error)")
            echecAction = Salon.libelle(error)
        }
    }

    private func relancer(_ transfert: Telechargement) async {
        do {
            fondre(try await salon.modeles.relancerTelechargement(transfert.id))
            echecAction = nil
        } catch {
            Journal.echec("relance de \(transfert.id) refusée : \(error)")
            echecAction = Salon.libelle(error)
        }
    }
}

/// Un transfert : ce qu'il est, où il en est, et le seul verbe qui s'applique.
struct LigneTransfert: View {
    let transfert: Telechargement
    let annuler: () -> Void
    let relancer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            HStack(alignment: .top, spacing: Trame.element) {
                VStack(alignment: .leading, spacing: Trame.fin) {
                    Text(transfert.nomCourt).mention().foregroundStyle(Teinte.encre).lineLimit(2)
                    Text(transfert.depot).mesureFine().foregroundStyle(Teinte.encreEteinte)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Sceau(transfert.etat.libelle).ton(ton)
            }
            // Pas de barre sans total annoncé : `Jauge` ne se dessine pas sur
            // un `nil`, et l'avancement en octets reste vrai dans tous les cas.
            Jauge(part: transfert.progression, ton: ton)
            LigneMesure(libelle: "Reçu", valeur: transfert.avancement)
            echec
            verbe
        }
    }

    @ViewBuilder private var echec: some View {
        if let erreur = transfert.erreur {
            Text(erreur).brut().foregroundStyle(Teinte.panne)
                .fixedSize(horizontal: false, vertical: true)
        }
        if let remede = transfert.remediation {
            Text(remede).brut().foregroundStyle(Teinte.encreEteinte)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var verbe: some View {
        if transfert.actif {
            VerbeAtelier(libelle: "Annuler", ton: .alerte, action: annuler)
        } else if transfert.etat == .interrompu || transfert.etat == .erreur
            || transfert.etat == .annule {
            VerbeAtelier(libelle: "Reprendre", action: relancer)
        }
    }

    private var ton: Ton {
        switch transfert.etat {
        case .enCours, .enAttente: return .actif
        case .termine: return .ok
        case .interrompu, .annule: return .alerte
        case .erreur: return .panne
        }
    }
}
#endif
