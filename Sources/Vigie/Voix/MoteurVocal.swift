// Responsabilité : la chaîne audio du mode vocal — UN moteur pour le micro et la voix, avec le traitement de la voix
// d'iOS (annulation d'écho : la voix lue n'est pas reprise par le micro, on peut couper la parole sans casque).
// Activer ce traitement fait reconfigurer la puce peu après le démarrage : le moteur est alors rebranché,
// patiemment (format micro valide attendu, 5 essais), comme Reflet l'a éprouvé sur l'iPhone.
// Session, traitement de la voix et démarrage du moteur bloquent (de dizaines de ms à plus d'une seconde) : ils se
// font dans une file dédiée, jamais sur le fil principal, sinon l'écran se fige à l'ouverture du mode vocal.
#if canImport(SwiftUI)
@preconcurrency import AVFoundation
import Foundation
import VigieNoyau

@MainActor
final class MoteurVocal {
    /// Format de lecture : celui de la voix de la tour (24 kHz mono) ; tout le reste y est converti.
    /// Lu aussi par les tâches de décodage, hors du MainActor.
    nonisolated static let formatLecture = AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1)!

    /// Toutes les opérations audio bloquantes, dans l'ordre des demandes (démarrer, arrêter, rebrancher).
    private nonisolated static let fileAudio = DispatchQueue(label: "fr.vigie.vocal.audio", qos: .userInitiated)

    private(set) var moteur: AVAudioEngine?
    private(set) var lecteur = AVAudioPlayerNode()
    private let surMicro: @Sendable (AVAudioPCMBuffer) -> Void
    private var observateur: NSObjectProtocol?
    private var reconstruction: Task<Void, Never>?
    /// Incrémenté à chaque démarrage et arrêt : un démarrage dépassé par un arrêt jette son montage.
    private var generation = 0
    /// Après une reconstruction, la lecture en cours est perdue : le mode vocal relance la file.
    var surReconstruit: (() -> Void)?

    init(surMicro: @escaping @Sendable (AVAudioPCMBuffer) -> Void) {
        self.surMicro = surMicro
    }

    func demarrer() async throws {
        generation += 1
        let jeton = generation
        let surMicro = self.surMicro
        let chaine = try await Self.surFile { try Self.ouvrirChaine(surMicro: surMicro) }
        guard jeton == generation else {
            Self.fileSansAttente { Self.arreterChaine(chaine, desactiverSession: false) }
            throw ErreurVocale("démarrage interrompu")
        }
        moteur = chaine.moteur
        lecteur = chaine.lecteur
        observateur = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reconstruire() }
        }
    }

    func arreter() {
        generation += 1
        if let observateur { NotificationCenter.default.removeObserver(observateur) }
        observateur = nil
        reconstruction?.cancel()
        let chaine = ChaineAudio(moteur: moteur, lecteur: lecteur)
        moteur = nil
        Self.fileSansAttente { Self.arreterChaine(chaine, desactiverSession: true) }
    }

    /// Joue un tampon au format de lecture ; `fin` est rappelé quand il a été entendu.
    func jouer(_ tampon: AVAudioPCMBuffer, fin: @escaping @Sendable () -> Void) {
        guard moteur?.isRunning == true else { return fin() }
        lecteur.scheduleBuffer(tampon, completionCallbackType: .dataPlayedBack) { _ in fin() }
        if !lecteur.isPlaying { lecteur.play() }
    }

    /// Coupe net la voix (barge-in, passer) : tout ce qui était programmé est jeté.
    func taire() {
        lecteur.stop()
    }

    /// Changement de configuration : on attend que la puce se stabilise (les notifications arrivent en rafale),
    /// puis on rebranche le même moteur. Plusieurs changements pendant l'attente n'en font qu'un.
    private func reconstruire() {
        guard observateur != nil else { return }
        reconstruction?.cancel()
        reconstruction = Task { @MainActor in
            for essai in 1...5 {
                try? await Task.sleep(for: .milliseconds(250 * essai))
                guard !Task.isCancelled else { return }
                if moteur?.isRunning == true { reconstruction = nil; return }
                do {
                    try await rebrancher()
                    Trace.info("vocal", "moteur rebranché (essai \(essai))")
                    reconstruction = nil
                    surReconstruit?()
                    return
                } catch {
                    Trace.erreur("vocal", "rebranchement du moteur, essai \(essai)", error)
                }
            }
            reconstruction = nil
        }
    }

    /// Le traitement de la voix n'est activé qu'UNE fois, sur un moteur unique : l'activer sur un moteur neuf fait
    /// reconfigurer la puce, qui reposte un changement de configuration — reconstruire à chaque fois bouclait sans fin
    /// (journal iPhone du 22/11 : le micro ne tournait jamais). Sur changement, on rebranche le même moteur.
    private func rebrancher() async throws {
        guard let moteur else { throw ErreurVocale("moteur absent") }
        let chaine = ChaineAudio(moteur: moteur, lecteur: lecteur)
        let surMicro = self.surMicro
        try await Self.surFile { try Self.brancher(chaine, surMicro: surMicro) }
    }

    // MARK: - Hors du fil principal (file audio)

    /// Session, traitement de la voix, moteur démarré : rien ici ne touche l'interface.
    private nonisolated static func ouvrirChaine(
        surMicro: @escaping @Sendable (AVAudioPCMBuffer) -> Void
    ) throws -> ChaineAudio {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat,
                                options: [.defaultToSpeaker, .allowBluetoothHFP, .duckOthers])
        try session.setActive(true)
        let moteur = AVAudioEngine()
        do {
            try moteur.inputNode.setVoiceProcessingEnabled(true)
        } catch {
            Trace.erreur("vocal", "traitement de la voix indisponible (écho possible)", error)
        }
        let lecteur = AVAudioPlayerNode()
        moteur.attach(lecteur)
        let chaine = ChaineAudio(moteur: moteur, lecteur: lecteur)
        try brancher(chaine, surMicro: surMicro)
        return chaine
    }

    /// Branche le micro et la voix sur le moteur puis le démarre.
    private nonisolated static func brancher(
        _ chaine: ChaineAudio, surMicro: @escaping @Sendable (AVAudioPCMBuffer) -> Void
    ) throws {
        guard let moteur = chaine.moteur else { throw ErreurVocale("moteur absent") }
        let entree = moteur.inputNode
        entree.removeTap(onBus: 0)
        let format = entree.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw ErreurVocale("micro sans format exploitable")
        }
        moteur.disconnectNodeOutput(chaine.lecteur)
        moteur.connect(chaine.lecteur, to: moteur.mainMixerNode, format: formatLecture)
        entree.installTap(onBus: 0, bufferSize: 1024, format: format, block: bloc(surMicro))
        moteur.prepare()
        try moteur.start()
    }

    /// Arrête le moteur ; la session n'est désactivée que par un arrêt voulu (pas par un démarrage abandonné, dont
    /// la session peut déjà servir au démarrage suivant).
    private nonisolated static func arreterChaine(_ chaine: ChaineAudio, desactiverSession: Bool) {
        chaine.lecteur.stop()
        chaine.moteur?.inputNode.removeTap(onBus: 0)
        chaine.moteur?.stop()
        guard desactiverSession else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            Trace.erreur("vocal", "désactivation de la session audio", error)
        }
    }

    /// Exécute `travail` sur la file audio et rend son résultat au fil appelant.
    private nonisolated static func surFile<T: Sendable>(_ travail: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { reprise in
            fileAudio.async {
                do {
                    reprise.resume(returning: try travail())
                } catch {
                    reprise.resume(throwing: error)
                }
            }
        }
    }

    private nonisolated static func fileSansAttente(_ travail: @escaping @Sendable () -> Void) {
        fileAudio.async(execute: travail)
    }

    private nonisolated static func bloc(
        _ rappel: @escaping @Sendable (AVAudioPCMBuffer) -> Void
    ) -> @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void {
        { tampon, _ in rappel(tampon) }
    }
}

/// Moteur et lecteur, passés de la file audio au fil principal ; ils ne sont touchés qu'à travers la file audio.
private struct ChaineAudio: @unchecked Sendable {
    let moteur: AVAudioEngine?
    let lecteur: AVAudioPlayerNode
}

struct ErreurVocale: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
#endif
