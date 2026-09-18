// L'état vivant du monde Duplex : ce que les écrans lisent, et le seul endroit
// qui orchestre le noyau pur, le réseau et la lecture. Le pendant de la `Boite`
// de Saily. Il ne contient AUCUNE règle de forme.
#if canImport(SwiftUI)
import DuplexNoyau
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@Observable
@MainActor
public final class Duplexeur {

    // MARK: - Ce que les écrans lisent

    public private(set) var postes: [PosteTrouve] = []
    public private(set) var choisi: PosteTrouve?
    public private(set) var etape: EtapeLiaison = .repos
    public private(set) var ecoute = false
    /// Ce que le PC dit de lui-même : émission en cours, source captée, AirPlay.
    public private(set) var etatPoste: EtatPoste?
    /// La dernière panne à montrer. Nulle dès qu'un geste repart.
    public private(set) var panne: ErreurDuplex?
    /// Le relevé de qualité, rafraîchi pendant l'écoute.
    public private(set) var qualite = Qualite()

    /// Ce qu'on affiche du flux : de quoi voir si ça tient, sans ouvrir un
    /// terminal — il n'y a ni Mac ni débogueur au bout de cette app.
    public struct Qualite: Equatable, Sendable {
        public var remplissageMs: Double = 0
        public var trous = 0
        public var ruptures = 0
        public var famines = 0
        public var amorce = false
    }

    public var sources: [SourceAudio] {
        if case let .liee(_, sources) = etape { return sources }
        return []
    }

    public var nomPoste: String? {
        if case let .liee(nom, _) = etape { return nom }
        return choisi?.nom
    }

    /// Vrai quand le PC affiche un code et attend qu'on le recopie.
    public var attendUnCode: Bool {
        switch etape {
        case .codeAttendu, .codeEnVerification: return true
        default: return false
        }
    }

    public var essaisRestants: Int? {
        if case let .codeAttendu(restants) = etape, restants < MachineJumelage.essaisAutorises {
            return restants
        }
        return nil
    }

    // MARK: - Ce qui n'appartient qu'au duplexeur

    @ObservationIgnored private let decouverte = Decouverte()
    @ObservationIgnored private let canal = CanalControle()
    @ObservationIgnored private let tampon = TamponAudio()
    @ObservationIgnored private let reception: ReceptionAudio
    @ObservationIgnored private let moteur: MoteurLecture
    @ObservationIgnored private let magasin: any MagasinJetons
    @ObservationIgnored private var machine: MachineJumelage
    @ObservationIgnored private var boucleDecouverte: Task<Void, Never>?
    @ObservationIgnored private var boucleCanal: Task<Void, Never>?
    @ObservationIgnored private var boucleQualite: Task<Void, Never>?

    public init(magasin: (any MagasinJetons)? = nil) {
        let dossier = FileManager.dossierDuplexParDefaut()
        self.magasin = magasin ?? MagasinJetonsDisque(dossier: dossier)
        self.machine = MachineJumelage(appareil: Self.nomAppareil())
        reception = ReceptionAudio(tampon: tampon)
        moteur = MoteurLecture(tampon: tampon)
    }

    // MARK: - Cycle de vie

    /// Premier geste : parcourir le réseau. Rien d'autre ne part tant que Chris
    /// n'a pas choisi un PC — on n'ouvre pas un canal vers une machine qu'il ne
    /// regarde pas.
    public func demarrer() async {
        guard boucleDecouverte == nil else { return }
        boucleDecouverte = Task { [decouverte] in
            await decouverte.demarrer()
            for await releve in await decouverte.flux() {
                await self.poserPostes(releve)
            }
        }
        boucleCanal = Task { [canal] in
            for await evenement in await canal.flux() {
                await self.traiter(evenement)
            }
        }
    }

    /// Pose le relevé de la découverte. Le PC choisi qui disparaît de la liste
    /// n'est PAS oublié : il peut n'avoir qu'éternué en mDNS, et effacer la
    /// sélection couperait une écoute qui, elle, tient toujours.
    private func poserPostes(_ releve: [PosteTrouve]) {
        postes = releve
    }

    /// Mise en arrière-plan : la découverte s'arrête, l'écoute NON. Le maintien
    /// en vie du centre tient le processus, et couper le son parce que l'écran
    /// s'éteint serait exactement l'inverse de ce qu'on veut d'une enceinte.
    public func suspendreDecouverte() {
        Task { await decouverte.arreter() }
    }

    public func reprendreDecouverte() {
        Task { await decouverte.demarrer() }
    }

    // MARK: - Choisir un PC

    public func choisir(_ poste: PosteTrouve) async {
        guard choisi?.id != poste.id else { return }
        await deconnecter()
        choisi = poste
        panne = nil
        machine = MachineJumelage(appareil: Self.nomAppareil())
        etape = .repos
        await connecter(poste)
    }

    public func deconnecter() async {
        await arreterEcoute()
        await canal.fermer()
        etatPoste = nil
        etape = .fermee
    }

    private func connecter(_ poste: PosteTrouve) async {
        do {
            let url = try await decouverte.resoudre(poste: poste.id)
            await canal.ouvrir(url)
        } catch let erreur as ErreurDuplex {
            guard !erreur.estAnnulation else { return }
            panne = erreur
            etape = .fermee
        } catch {
            panne = .injoignable(error.localizedDescription)
            etape = .fermee
        }
    }

    // MARK: - Le jumelage

    public func saisirCode(_ code: String) async {
        await appliquer(machine.recevoir(.codeSaisi(code)))
    }

    private func traiter(_ evenement: EvenementCanal) async {
        switch evenement {
        case .ouvert:
            let jeton = choisi.flatMap { magasin.jeton(poste: $0.id) }
            await appliquer(machine.recevoir(.canalOuvert(jetonConnu: jeton)))
        case let .recu(message):
            if case let .etat(etat) = message { etatPoste = etat }
            await appliquer(machine.recevoir(.recu(message)))
        case let .ferme(erreur):
            await arreterEcoute()
            await appliquer(machine.recevoir(.canalFerme))
            if let erreur, !erreur.estAnnulation { panne = erreur }
        }
    }

    /// Exécute ce que la machine a décidé, puis publie son étape. La machine ne
    /// touche jamais au réseau ni au disque : c'est ce qui la rend éprouvable
    /// sans appareil, et c'est ici que ses décisions prennent effet.
    private func appliquer(_ actions: [ActionJumelage]) async {
        for action in actions {
            switch action {
            case let .emettre(message):
                await emettre(message)
            case let .conserverJeton(jeton):
                if let poste = choisi { magasin.conserver(jeton: jeton, poste: poste.id) }
            case .oublierJeton:
                if let poste = choisi { magasin.oublier(poste: poste.id) }
            case .fermerCanal:
                await canal.fermer()
            }
        }
        etape = machine.etape
        if case let .refusee(raison) = machine.etape { panne = .refuse(raison) }
    }

    private func emettre(_ message: MessageTelephone) async {
        do {
            try await canal.emettre(message)
        } catch let erreur as ErreurDuplex where !erreur.estAnnulation {
            panne = erreur
        } catch {}
    }

    // MARK: - L'écoute

    /// Ouvre le port UDP, l'annonce au PC, démarre la lecture. L'ordre compte :
    /// le port doit ÉCOUTER avant d'être annoncé, sinon les premiers paquets
    /// tombent dans le vide et la reprise démarre avec un trou.
    public func demarrerEcoute() async {
        guard machine.etablie, !ecoute else { return }
        panne = nil
        do {
            let port = try await reception.ouvrir()
            try moteur.demarrer()
            await emettre(.fluxDemarrer(port: port))
            ecoute = true
            lancerReleve()
        } catch let erreur as ErreurDuplex {
            reception.fermer()
            moteur.arreter()
            if !erreur.estAnnulation { panne = erreur }
        } catch {
            reception.fermer()
            moteur.arreter()
            panne = .injoignable(error.localizedDescription)
        }
    }

    public func arreterEcoute() async {
        guard ecoute else { return }
        ecoute = false
        boucleQualite?.cancel()
        boucleQualite = nil
        await emettre(.fluxArreter)
        moteur.arreter()
        reception.fermer()
        qualite = Qualite()
    }

    public func basculerEcoute() async {
        if ecoute {
            await arreterEcoute()
        } else {
            await demarrerEcoute()
        }
    }

    public func choisirSource(_ source: SourceAudio) async {
        await emettre(.sourceChoisir(id: source.id))
    }

    /// Le relevé de qualité, deux fois par seconde. Bornée par l'annulation de
    /// la tâche à l'arrêt de l'écoute — jamais une boucle qui survit au geste.
    private func lancerReleve() {
        boucleQualite?.cancel()
        boucleQualite = Task { [tampon, reception] in
            while !Task.isCancelled {
                let suivi = reception.releve
                self.qualite = Qualite(
                    remplissageMs: tampon.remplissageMs, trous: suivi.trous,
                    ruptures: suivi.ruptures, famines: tampon.famines, amorce: tampon.amorce
                )
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    // MARK: - Outils

    private static func nomAppareil() -> String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return "iPhone"
        #endif
    }
}

extension FileManager {
    /// Le dossier de Duplex : survit aux lancements. Distinct de ceux des autres
    /// mondes pour qu'ils ne se marchent pas dessus.
    static func dossierDuplexParDefaut() -> URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return (base ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("Duplex", isDirectory: true)
    }
}
#endif
