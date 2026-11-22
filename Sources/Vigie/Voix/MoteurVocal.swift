// Responsabilité : la chaîne audio du mode vocal — UN moteur pour le micro et la voix, avec le traitement de la voix
// d'iOS (annulation d'écho : la voix lue n'est pas reprise par le micro, on peut couper la parole sans casque).
// Activer ce traitement fait reconfigurer la puce peu après le démarrage : le moteur est alors reconstruit,
// patiemment (format micro valide attendu, 5 essais), comme Reflet l'a éprouvé sur l'iPhone.
#if canImport(SwiftUI)
@preconcurrency import AVFoundation
import Foundation
import VigieNoyau

@MainActor
final class MoteurVocal {
    /// Format de lecture : celui de la voix de la tour (24 kHz mono) ; tout le reste y est converti.
    /// Lu aussi par les tâches de décodage, hors du MainActor.
    nonisolated static let formatLecture = AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1)!

    private(set) var moteur: AVAudioEngine?
    private(set) var lecteur = AVAudioPlayerNode()
    private let surMicro: @Sendable (AVAudioPCMBuffer) -> Void
    private var observateur: NSObjectProtocol?
    private var reconstruction: Task<Void, Never>?
    /// Après une reconstruction, la lecture en cours est perdue : le mode vocal relance la file.
    var surReconstruit: (() -> Void)?

    init(surMicro: @escaping @Sendable (AVAudioPCMBuffer) -> Void) {
        self.surMicro = surMicro
    }

    func demarrer() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat,
                                options: [.defaultToSpeaker, .allowBluetoothHFP, .duckOthers])
        try session.setActive(true)
        try construire()
        observateur = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reconstruire() }
        }
    }

    func arreter() {
        if let observateur { NotificationCenter.default.removeObserver(observateur) }
        observateur = nil
        reconstruction?.cancel()
        demonter()
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            Trace.erreur("vocal", "désactivation de la session audio", error)
        }
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

    private func construire() throws {
        let moteur = AVAudioEngine()
        let entree = moteur.inputNode
        do {
            try entree.setVoiceProcessingEnabled(true)
        } catch {
            Trace.erreur("vocal", "traitement de la voix indisponible (écho possible)", error)
        }
        let format = entree.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw ErreurVocale("micro sans format exploitable")
        }
        let lecteur = AVAudioPlayerNode()
        moteur.attach(lecteur)
        moteur.connect(lecteur, to: moteur.mainMixerNode, format: Self.formatLecture)
        entree.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.bloc(surMicro))
        moteur.prepare()
        try moteur.start()
        self.moteur = moteur
        self.lecteur = lecteur
    }

    private func demonter() {
        lecteur.stop()
        moteur?.inputNode.removeTap(onBus: 0)
        moteur?.stop()
        moteur = nil
    }

    private func reconstruire() {
        // La puce change de configuration en arrêtant le moteur ; s'il tourne encore, rien à reconstruire.
        guard reconstruction == nil, observateur != nil, moteur?.isRunning != true else { return }
        reconstruction = Task { @MainActor in
            defer { reconstruction = nil }
            for essai in 1...5 {
                demonter()
                try? await Task.sleep(for: .milliseconds(150 * essai))
                guard !Task.isCancelled else { return }
                do {
                    try construire()
                    Trace.info("vocal", "moteur reconstruit (essai \(essai))")
                    surReconstruit?()
                    return
                } catch {
                    Trace.erreur("vocal", "reconstruction du moteur, essai \(essai)", error)
                }
            }
        }
    }

    private nonisolated static func bloc(
        _ rappel: @escaping @Sendable (AVAudioPCMBuffer) -> Void
    ) -> @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void {
        { tampon, _ in rappel(tampon) }
    }
}

struct ErreurVocale: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
#endif
