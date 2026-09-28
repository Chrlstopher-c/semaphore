// L'émetteur : relie caméra, encodeur, diffusion et relais, et tient l'état que l'écran affiche.
#if canImport(UIKit)
import AVFoundation
import IrisNoyau
import Observation
import os
import UIKit

@MainActor @Observable
final class Emetteur {
    private(set) var relais: EtatRelais = .repos
    private(set) var recepteurs: [Recepteur] = []
    private(set) var liaisons: [String: EtatLiaison] = [:]
    private(set) var infos: [String: String] = [:]
    private(set) var enDirect = false
    private(set) var panne: String?
    private(set) var reglages: Reglages

    @ObservationIgnored let capture: CaptureCamera
    @ObservationIgnored private let encodeur: Encodeur
    @ObservationIgnored private let diffusion: Diffusion
    @ObservationIgnored private var signalisation: Signalisation?
    @ObservationIgnored private var tacheRelais: Task<Void, Never>?
    @ObservationIgnored private var visible = false
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private let journal = Logger(subsystem: "com.echo.labs", category: "iris")

    private init() {
        let depart = Reglages.charger()
        reglages = depart
        let encodeur = Encodeur(debit: depart.qualite.debit)
        let diffusion = Diffusion(
            cle: Parametres.cle,
            demanderCle: { @Sendable in encodeur.forcerCle() },
            signaler: { @Sendable nom, etat in Task { @MainActor in Emetteur.partage.noter(nom, etat) } }
        )
        encodeur.brancher { @Sendable unite, cle in diffusion.envoyer(unite, cle: cle) }
        self.encodeur = encodeur
        self.diffusion = diffusion
        capture = CaptureCamera(recevoir: { @Sendable image, instant in encodeur.encoder(image, instant: instant) })
    }

    /// L'unique émetteur du processus (une caméra, un monde). Pas de `@State Emetteur()` :
    /// SwiftUI réévalue cet initialiseur à chaque reconstruction de la coquille, et les
    /// rappels réseau partaient vers une instance jetée — liste des PC et état du relais perdus.
    static let partage = Emetteur()

    // MARK: - Cycle de vie

    func montrer(_ visible: Bool) {
        self.visible = visible
        ajusterRelais()
    }

    func basculer() async {
        if enDirect { arreter() } else { await demarrer() }
    }

    private func demarrer() async {
        panne = nil
        guard Parametres.urlRelais != nil else {
            panne = "Relais Iris non configuré : ECHO_CLE_IRIS et ECHO_ADRESSE_IRIS dans .env.local, puis recompiler."
            return
        }
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            panne = "Accès à la caméra refusé : Réglages › Echo › Appareil photo."
            return
        }
        do {
            try await capture.demarrer(objectif: reglages.objectif, qualite: reglages.qualite)
        } catch {
            journal.error("caméra : \(error.localizedDescription, privacy: .public)")
            panne = "Caméra indisponible (\(reglages.objectif.libelle))."
            return
        }
        enDirect = true
        UIApplication.shared.isIdleTimerDisabled = true
        ajusterRelais()
        accorder()
    }

    private func arreter() {
        capture.arreter()
        enDirect = false
        UIApplication.shared.isIdleTimerDisabled = false
        accorder()
        ajusterRelais()
    }

    // MARK: - Réglages

    func choisir(objectif: Objectif) async {
        reglages.objectif = objectif
        await reconfigurer()
    }

    func choisir(qualite: Qualite) async {
        reglages.qualite = qualite
        encodeur.changerDebit(qualite.debit)
        await reconfigurer()
    }

    func choisir(cadrage: Cadrage) async {
        reglages.cadrage = cadrage
        reglages.enregistrer()
        await signalisation?.envoyer(MessageSortant.reglages(cadrage: cadrage))
    }

    private func reconfigurer() async {
        reglages.enregistrer()
        guard enDirect else { return }
        do {
            try await capture.demarrer(objectif: reglages.objectif, qualite: reglages.qualite)
            encodeur.forcerCle()
        } catch {
            journal.error("reconfiguration : \(error.localizedDescription, privacy: .public)")
            panne = "\(reglages.objectif.libelle) indisponible sur cet iPhone."
        }
    }

    // MARK: - Relais et liaisons

    /// Le relais n'est joint que si l'écran est visible ou que le flux part :
    /// la page web garde la place quand Iris dort.
    private func ajusterRelais() {
        let voulu = visible || enDirect
        if voulu, tacheRelais == nil, relais != .remplace { lancerRelais() }
        if !voulu, let tache = tacheRelais {
            tache.cancel()
            tacheRelais = nil
            signalisation = nil
        }
    }

    func reprendreRelais() {
        relais = .repos
        tacheRelais?.cancel()
        tacheRelais = nil
        ajusterRelais()
    }

    private func lancerRelais() {
        guard let url = Parametres.urlRelais else { return }
        generation += 1
        let numero = generation
        let signalisation = Signalisation(
            url: url,
            recevoir: { @Sendable message in await MainActor.run { Emetteur.partage.recevoir(message, de: numero) } },
            changerEtat: { @Sendable etat in await MainActor.run { Emetteur.partage.changer(etat, de: numero) } }
        )
        self.signalisation = signalisation
        tacheRelais = Task { await signalisation.tourner() }
    }

    /// `numero` : une signalisation annulée finit par annoncer `.repos` ; si une nouvelle
    /// l'a déjà remplacée, cet état périmé ne doit pas écraser le sien.
    private func changer(_ etat: EtatRelais, de numero: Int) {
        guard numero == generation else { return }
        relais = etat
        if etat == .connecte, let signalisation {
            let texte = MessageSortant.reglages(cadrage: reglages.cadrage)
            Task { await signalisation.envoyer(texte) }
        }
        if etat == .remplace { tacheRelais = nil }
    }

    private func recevoir(_ message: MessageRelais, de numero: Int) {
        guard numero == generation else { return }
        switch message {
        case .recepteurs(let liste):
            recepteurs = liste
            let noms = Set(liste.map(\.nom))
            infos = infos.filter { noms.contains($0.key) }
            accorder()
        case .etat(let de, let texte):
            infos[de] = texte
        case .ignore:
            break
        }
    }

    private func accorder() {
        diffusion.accorder(enDirect ? recepteurs.filter(\.veut) : [])
    }

    fileprivate func noter(_ nom: String, _ etat: EtatLiaison?) {
        liaisons[nom] = etat
        if etat == nil || etat == .injoignable { infos[nom] = nil }
        if etat == .injoignable {
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(6))
                self?.accorder()
            }
        }
    }
}
#endif
