// La caméra de l'iPhone : session AVFoundation, objectif, cadence, rotation.
#if canImport(AVFoundation) && canImport(UIKit)
import AVFoundation
import IrisNoyau
import os

enum ErreurCapture: Error {
    case objectifAbsent, entreeRefusee
}

/// `☠` Volontairement PAS `@MainActor` : AVFoundation rappelle le délégué et les
/// observations KVO sur ses propres files ; une closure héritant de l'isolation
/// principale y ferait tomber une assertion d'exécuteur (skill swift-ios).
///
/// `@unchecked Sendable` : tout l'état mutable n'est touché que sur `file`
/// (série) ; `apercu` est créé une fois au lancement puis seulement réglé.
final class CaptureCamera: NSObject, @unchecked Sendable {
    let apercu: AVCaptureVideoPreviewLayer
    private let session = AVCaptureSession()
    private let file = DispatchQueue(label: "iris.capture")
    private let sortie = AVCaptureVideoDataOutput()
    private var entree: AVCaptureDeviceInput?
    private var coordinateur: AVCaptureDevice.RotationCoordinator?
    private var observations: [NSKeyValueObservation] = []
    private let recevoir: @Sendable (CVPixelBuffer, CMTime) -> Void
    private let journal = Logger(subsystem: "com.echo.labs", category: "iris.capture")

    init(recevoir: @escaping @Sendable (CVPixelBuffer, CMTime) -> Void) {
        self.recevoir = recevoir
        apercu = AVCaptureVideoPreviewLayer(session: session)
        apercu.videoGravity = .resizeAspect
        super.init()
        sortie.alwaysDiscardsLateVideoFrames = true
        sortie.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        ]
        sortie.setSampleBufferDelegate(self, queue: file)
    }

    /// Configure (ou reconfigure à chaud) puis lance la session.
    func demarrer(objectif: Objectif, qualite: Qualite) async throws {
        try await surFile {
            try self.configurer(objectif: objectif, qualite: qualite)
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    func arreter() {
        file.async { self.session.stopRunning() }
    }

    private func surFile(_ travail: @escaping @Sendable () throws -> Void) async throws {
        try await withCheckedThrowingContinuation { (suite: CheckedContinuation<Void, Error>) in
            file.async {
                do {
                    try travail()
                    suite.resume()
                } catch {
                    suite.resume(throwing: error)
                }
            }
        }
    }

    private func configurer(objectif: Objectif, qualite: Qualite) throws {
        guard let appareil = Self.appareil(pour: objectif) else { throw ErreurCapture.objectifAbsent }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if let entree { session.removeInput(entree) }
        entree = nil
        let nouvelle = try AVCaptureDeviceInput(device: appareil)
        guard session.canAddInput(nouvelle) else { throw ErreurCapture.entreeRefusee }
        session.addInput(nouvelle)
        entree = nouvelle
        if session.outputs.isEmpty, session.canAddOutput(sortie) { session.addOutput(sortie) }
        let preset: AVCaptureSession.Preset = qualite == .hd720 ? .hd1280x720 : .hd1920x1080
        session.sessionPreset = session.canSetSessionPreset(preset) ? preset : .high
        regler30ImagesParSeconde(appareil)
        orienter(appareil)
        journal.info("caméra : \(objectif.rawValue, privacy: .public) \(qualite.rawValue, privacy: .public)")
    }

    private func regler30ImagesParSeconde(_ appareil: AVCaptureDevice) {
        do {
            try appareil.lockForConfiguration()
            appareil.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
            appareil.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
            appareil.unlockForConfiguration()
        } catch {
            journal.error("cadence non réglée : \(error.localizedDescription, privacy: .public)")
        }
    }

    /// L'image envoyée suit l'horizon : portrait tenu droit → image portrait,
    /// iPhone couché → image 16:9. Le PC range ensuite selon le cadrage.
    private func orienter(_ appareil: AVCaptureDevice) {
        let coordinateur = AVCaptureDevice.RotationCoordinator(device: appareil, previewLayer: apercu)
        self.coordinateur = coordinateur
        tourner(capture: coordinateur.videoRotationAngleForHorizonLevelCapture)
        tournerApercu(coordinateur.videoRotationAngleForHorizonLevelPreview)
        observations = [
            coordinateur.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new]) { [weak self] c, _ in
                let angle = c.videoRotationAngleForHorizonLevelCapture
                guard let self else { return }
                self.file.async { self.tourner(capture: angle) }
            },
            coordinateur.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self] c, _ in
                self?.tournerApercu(c.videoRotationAngleForHorizonLevelPreview)
            },
        ]
    }

    private func tourner(capture angle: CGFloat) {
        guard let connexion = sortie.connection(with: .video),
              connexion.isVideoRotationAngleSupported(angle) else { return }
        connexion.videoRotationAngle = angle
    }

    private func tournerApercu(_ angle: CGFloat) {
        DispatchQueue.main.async { [weak self] in
            guard let connexion = self?.apercu.connection,
                  connexion.isVideoRotationAngleSupported(angle) else { return }
            connexion.videoRotationAngle = angle
        }
    }

    static func appareil(pour objectif: Objectif) -> AVCaptureDevice? {
        switch objectif {
        case .arriere: return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        case .tele: return AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
        case .avant: return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        }
    }
}

extension CaptureCamera: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput, didOutput echantillon: CMSampleBuffer, from connexion: AVCaptureConnection
    ) {
        guard let image = CMSampleBufferGetImageBuffer(echantillon) else { return }
        recevoir(image, CMSampleBufferGetPresentationTimeStamp(echantillon))
    }
}
#endif
