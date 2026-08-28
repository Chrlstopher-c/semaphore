#if canImport(SwiftUI)
import AVFoundation
import Foundation
import Observation
import VigieNoyau

/// Maintient Vigie en vie en arrière-plan via une session audio silencieuse,
/// et fait tourner dedans le bus d'alerte — le canal numéro un, mesuré.
///
/// Porté du banc d'essai EchoLabs, éprouvé sur l'appareil : iOS suspend une app
/// ordinaire en 1 à 2 s, mais une app qui joue RÉELLEMENT de l'audio y échappe
/// tant que la lecture dure — mesuré à 300 s minimum. `mixWithOthers` : la
/// session ne réclame jamais l'exclusivité, elle n'interrompt aucune autre app.
///
/// `☠` L'inverse n'est pas vrai : une app qui prend l'audio en exclusif
/// interrompt CETTE session, et le processus redevient suspendable dans la
/// seconde. D'où la reprise automatique sur `interruptionNotification` — sans
/// elle, le maintien en vie meurt au premier morceau joué ailleurs. Et le démon
/// audio du système peut se réinitialiser sans préavis
/// (`mediaServicesWereResetNotification`) : la session ET le lecteur sont alors
/// invalides d'un coup, pas seulement suspendus.
@MainActor
@Observable
public final class MaintienVie {
    public static let partage = MaintienVie()

    public private(set) var actif = false
    public private(set) var statut = "inactif"
    public private(set) var interruptions = 0
    public private(set) var reprises = 0
    public private(set) var dernierIncident: String?
    /// Vrai tant qu'une autre app détient l'audio en exclusif. Lu par
    /// `MaintienVieLocalisation`, qui ne doit prendre le relais que dans cette
    /// fenêtre-là — jamais quand c'est Chris qui a coupé l'interrupteur.
    public private(set) var audioInterrompu = false

    @ObservationIgnored private var lecteur: AVAudioPlayer?
    @ObservationIgnored private var observateurs: [NSObjectProtocol] = []
    @ObservationIgnored private var boucle: Task<Void, Never>?
    /// Distingue « Chris a coupé l'interrupteur » d'une interruption passagère :
    /// seule la reprise automatique doit réengager sans qu'il l'ait redemandé.
    @ObservationIgnored private var demande = false

    private static let intervalleSondageS: Double = 25

    private init() {}

    public func demarrer() {
        demande = true
        // Demandée ici, une seule fois : l'invite système doit être posée AVANT
        // qu'une autre app prenne l'audio, sinon le relais arrive trop tard.
        MaintienVieLocalisation.partage.demanderAutorisation()
        guard !actif else { return }
        observerIncidents()
        engager()
    }

    public func arreter() {
        demande = false
        audioInterrompu = false
        MaintienVieLocalisation.partage.arreter()
        boucle?.cancel()
        boucle = nil
        observateurs.forEach(NotificationCenter.default.removeObserver)
        observateurs.removeAll()
        lecteur?.stop()
        lecteur = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        actif = false
        rapporter()
        statut = "inactif"
    }

    /// Reprend la session après une capture micro (la dictée), qui a dû poser sa
    /// propre catégorie sur la session — unique pour tout le processus.
    ///
    /// `☠` Sans ce rappel, la première dictée tuait le canal numéro un en
    /// silence : la catégorie de capture arrête la boucle, et personne n'émet
    /// d'`interruptionNotification` pour une interruption qu'on s'inflige
    /// soi-même.
    ///
    /// - Returns: `true` si le maintien en vie a repris la main. L'appelant ne
    ///   doit alors surtout pas désactiver la session.
    public func reprendreApresCapture() -> Bool {
        guard demande else { return false }
        lecteur?.stop()
        lecteur = nil
        actif = false
        engager()
        return true
    }

    private func engager() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let lecteur = try AVAudioPlayer(data: Self.boucleSilencieuse())
            lecteur.numberOfLoops = -1
            lecteur.volume = 0.01
            guard lecteur.play() else {
                statut = "lecture refusée par le système"
                return
            }
            self.lecteur = lecteur
            actif = true
            statut = "session active — le processus survit"
            rapporter()
            demarrerBoucleDeSondage()
        } catch {
            actif = false
            statut = "échec : \(error.localizedDescription)"
            Trace.erreur("alerte", "maintien en vie audio impossible", error)
        }
    }

    /// `☠` C'est ICI que vit le bus, pas dans un `.cadencePar` d'écran :
    /// l'écran « État du canal » n'est pas dans la barre, il n'est presque
    /// jamais affiché. Tant que la session audio tient, Vigie sonde le Pi de
    /// son propre chef, sans dépendre d'un réveil de fond opportuniste.
    private func demarrerBoucleDeSondage() {
        boucle?.cancel()
        boucle = Task { @MainActor [weak self] in
            while let self, self.actif, !Task.isCancelled {
                await CentreAlerte.partage.sonder(origine: .veilleAudio)
                try? await Task.sleep(for: .seconds(Self.intervalleSondageS))
            }
        }
    }

    private func observerIncidents() {
        let centre = NotificationCenter.default
        observateurs.append(centre.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            // Extraire la valeur AVANT toute frontière d'isolation : `Notification`
            // n'est pas `Sendable`.
            let brut = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            MainActor.assumeIsolated { self?.gererInterruption(brut: brut) }
        })
        observateurs.append(centre.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.noter("services média réinitialisés")
                self?.lecteur = nil
                if self?.demande == true { self?.engager() }
            }
        })
    }

    private func gererInterruption(brut: UInt?) {
        guard let brut, let type = AVAudioSession.InterruptionType(rawValue: brut) else { return }
        switch type {
        case .began:
            interruptions += 1
            actif = false
            audioInterrompu = true
            statut = "interrompu par une autre app"
            noter("interruption \(interruptions) — une app a pris l'audio")
            // `☠` C'est le passage de relais, et il ne peut PAS attendre
            // `.ended` : une app qui joue un album tient l'audio quarante
            // minutes. Sans cette ligne, le canal d'alerte reste éteint aussi
            // longtemps que dure l'écoute.
            if demande { MaintienVieLocalisation.partage.engager() }
        case .ended:
            reprises += 1
            audioInterrompu = false
            MaintienVieLocalisation.partage.arreter()
            noter("reprise \(reprises)")
            if demande { engager() }
        @unknown default:
            break
        }
    }

    private func noter(_ message: String) {
        dernierIncident = "\(Date().formatted(date: .omitted, time: .standard)) · \(message)"
        rapporter()
    }

    /// L'état du canal 1 est persisté par `CentreAlerte` : les Réglages et
    /// l'écran d'alerte le lisent là, y compris après un redémarrage — un
    /// compteur qui ne vit qu'en mémoire ne dit rien du canal.
    private func rapporter() {
        CentreAlerte.partage.rapporterAudio(
            actif: actif,
            interruptions: interruptions,
            reprises: reprises,
            incident: dernierIncident
        )
    }

    // MARK: - Flux silencieux

    private static func boucleSilencieuse(secondes: Double = 30, tauxEchantillonnage: Int = 8000) -> Data {
        let echantillons = Int(Double(tauxEchantillonnage) * secondes)
        let charge = echantillons * 2
        var donnees = Data()
        donnees.append(contentsOf: Array("RIFF".utf8))
        donnees.append(petitBoutien32(UInt32(36 + charge)))
        donnees.append(contentsOf: Array("WAVEfmt ".utf8))
        donnees.append(petitBoutien32(16))
        donnees.append(petitBoutien16(1))
        donnees.append(petitBoutien16(1))
        donnees.append(petitBoutien32(UInt32(tauxEchantillonnage)))
        donnees.append(petitBoutien32(UInt32(tauxEchantillonnage * 2)))
        donnees.append(petitBoutien16(2))
        donnees.append(petitBoutien16(16))
        donnees.append(contentsOf: Array("data".utf8))
        donnees.append(petitBoutien32(UInt32(charge)))
        donnees.append(Data(count: charge))
        return donnees
    }

    private static func petitBoutien32(_ valeur: UInt32) -> Data {
        withUnsafeBytes(of: valeur.littleEndian) { Data($0) }
    }

    private static func petitBoutien16(_ valeur: UInt16) -> Data {
        withUnsafeBytes(of: valeur.littleEndian) { Data($0) }
    }
}
#endif
