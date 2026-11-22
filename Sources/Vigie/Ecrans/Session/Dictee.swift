// Responsabilité : dictée vocale du composeur — reconnaissance française sur l'appareil, segments consolidés
// à chaque silence, moteur audio unique, reprise de la veille (MaintienVie) à la fin de chaque dictée.
#if canImport(SwiftUI)
import AVFoundation
import Foundation
import Observation
import Speech
import VigieNoyau

/// Événement de reconnaissance : seules des valeurs `Sendable` traversent les files de rappel.
private enum EvenementReco: Sendable {
    case resultat(texte: String, fin: Bool)
    case erreur(sansParole: Bool, detail: String)
}

/// Porte la requête courante jusqu'au tap audio (file temps réel). `SFSpeechAudioBufferRecognitionRequest`
/// n'est pas `Sendable` : ce pont est le seul objet qui traverse les files, et chaque accès passe par le verrou.
private final class PontAudio: @unchecked Sendable {
    private let verrou = NSLock()
    private var requete: SFSpeechAudioBufferRecognitionRequest?

    func ajouter(_ tampon: AVAudioPCMBuffer) {
        verrou.withLock { requete?.append(tampon) }
    }

    func changer(vers nouvelle: SFSpeechAudioBufferRecognitionRequest?) {
        verrou.withLock {
            requete?.endAudio()
            requete = nouvelle
        }
    }
}

/// Dictée vocale en français, sur l'appareil. `miseAJour` reçoit le texte complet à chaque résultat.
@MainActor
@Observable
final class Dictee {
    static let partage = Dictee()

    private(set) var active = false

    private static let echecsMax = 3
    private static let localeFrancais = Locale(identifier: "fr-FR")

    @ObservationIgnored private var moteur: AVAudioEngine?
    @ObservationIgnored private var reconnaissance: SFSpeechRecognizer?
    @ObservationIgnored private var tache: SFSpeechRecognitionTask?
    @ObservationIgnored private var pont: PontAudio?
    /// Numéro de la requête courante : tout rappel d'une requête antérieure est ignoré.
    @ObservationIgnored private var ronde = 0
    @ObservationIgnored private var texteInitial = ""
    @ObservationIgnored private var consolide = ""
    @ObservationIgnored private var partielle = ""
    @ObservationIgnored private var echecs = 0
    @ObservationIgnored private var miseAJour: (@MainActor (String) -> Void)?

    private init() {}

    func demarrer(texteInitial: String, miseAJour: @escaping @MainActor (String) -> Void) async -> String? {
        guard await Self.autoriserMicro() else {
            return "Micro non autorisé : autorise Sémaphore dans Réglages iOS."
        }
        guard await Self.autoriserReconnaissance() == .authorized else {
            return "Reconnaissance vocale non autorisée : autorise-la dans Réglages iOS."
        }
        if active { arreter() }
        self.texteInitial = texteInitial
        self.miseAJour = miseAJour
        consolide = ""
        partielle = ""
        echecs = 0
        if let erreur = lancerAudio() {
            arreter()
            return erreur
        }
        active = true
        Trace.info("dictee", "dictée démarrée")
        return nil
    }

    func arreter() {
        moteur?.stop()
        moteur?.inputNode.removeTap(onBus: 0)
        moteur = nil
        pont?.changer(vers: nil)
        pont = nil
        tache?.cancel()
        tache = nil
        reconnaissance = nil
        ronde += 1
        consolide = Self.joindre(consolide, partielle)
        partielle = ""
        active = false
        miseAJour?(texteComplet())
        miseAJour = nil
        finirSession()
    }

    // MARK: - Moteur et requêtes

    private func lancerAudio() -> String? {
        guard preparerSession() else { return "Micro indisponible." }
        let moteur = AVAudioEngine()
        let format = moteur.inputNode.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            Trace.erreur("dictee", "entrée micro sans format exploitable")
            return "Micro indisponible."
        }
        guard let reco = Self.reconnaissanceFrancaise() else {
            return "Modèle de dictée français absent : télécharge-le dans Réglages iOS."
        }
        let pont = PontAudio()
        moteur.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.blocAudio(pont))
        do {
            moteur.prepare()
            try moteur.start()
        } catch {
            moteur.inputNode.removeTap(onBus: 0)
            Trace.erreur("dictee", "moteur audio impossible à démarrer", error)
            return "Micro indisponible."
        }
        self.moteur = moteur
        self.pont = pont
        reconnaissance = reco
        ouvrirRequete()
        return nil
    }

    private func preparerSession() -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default, options: [])
            try session.setActive(true)
            return true
        } catch {
            Trace.erreur("dictee", "session audio de capture refusée", error)
            return false
        }
    }

    /// Ouvre une requête neuve sur le MÊME moteur audio : Speech clôt une phrase à chaque silence.
    private func ouvrirRequete() {
        guard let reco = reconnaissance, let pont else { return }
        ronde += 1
        let requete = SFSpeechAudioBufferRecognitionRequest()
        requete.requiresOnDeviceRecognition = true
        requete.shouldReportPartialResults = true
        requete.addsPunctuation = true
        pont.changer(vers: requete)
        tache?.cancel()
        tache = reco.recognitionTask(with: requete, resultHandler: Self.rappelReconnaissance(self, ronde: ronde))
    }

    private func finirSession() {
        if MaintienVie.partage.reprendreApresCapture() { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            Trace.erreur("dictee", "désactivation de la session audio", error)
        }
    }

    // MARK: - Résultats (MainActor)

    private func appliquer(_ evenement: EvenementReco, ronde numero: Int) {
        guard active, numero == ronde else { return }
        switch evenement {
        case .resultat(let texte, let fin): traiterResultat(texte, fin: fin)
        case .erreur(let sansParole, let detail): traiterErreur(sansParole: sansParole, detail: detail)
        }
    }

    private func traiterResultat(_ texte: String, fin: Bool) {
        echecs = 0
        if fin {
            consolide = Self.joindre(consolide, texte)
            partielle = ""
            ouvrirRequete()
        } else {
            partielle = texte
        }
        miseAJour?(texteComplet())
    }

    private func traiterErreur(sansParole: Bool, detail: String) {
        consolide = Self.joindre(consolide, partielle)
        partielle = ""
        if !sansParole { echecs += 1 }
        guard echecs < Self.echecsMax else {
            Trace.erreur("dictee", "reconnaissance abandonnée après \(echecs) échecs : \(detail)")
            arreter()
            return
        }
        ouvrirRequete()
    }

    private func texteComplet() -> String {
        Self.joindre(texteInitial, Self.joindre(consolide, partielle))
    }

    /// Accole `suite` à `avant`, avec une espace si besoin. Rend `avant` seul si `suite` est vide.
    private nonisolated static func joindre(_ avant: String, _ suite: String) -> String {
        let segment = suite.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !segment.isEmpty else { return avant }
        guard let dernier = avant.last, !dernier.isWhitespace else { return avant + segment }
        return avant + " " + segment
    }

    // MARK: - Autorisations et fabriques (nonisolated : les rappels ne doivent pas hériter du MainActor)

    private static func autoriserMicro() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    private nonisolated static func autoriserReconnaissance() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { reprise in
            SFSpeechRecognizer.requestAuthorization { statut in reprise.resume(returning: statut) }
        }
    }

    private static func reconnaissanceFrancaise() -> SFSpeechRecognizer? {
        guard let reco = SFSpeechRecognizer(locale: localeFrancais), reco.supportsOnDeviceRecognition,
              reco.isAvailable else { return nil }
        return reco
    }

    private nonisolated static func blocAudio(_ pont: PontAudio) -> @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void {
        { tampon, _ in pont.ajouter(tampon) }
    }

    private nonisolated static func rappelReconnaissance(
        _ dictee: Dictee, ronde numero: Int
    ) -> @Sendable (SFSpeechRecognitionResult?, Error?) -> Void {
        { resultat, erreurReco in
            if let erreurReco {
                let code = (erreurReco as NSError).code
                let sansParole = code == SFSpeechRecognitionErrorCode.noSpeechDetected.rawValue
                let detail = "\(code) \(erreurReco.localizedDescription)"
                dictee.transmettre(.erreur(sansParole: sansParole, detail: detail), ronde: numero)
            } else if let resultat {
                let texte = resultat.bestTranscription.formattedString
                dictee.transmettre(.resultat(texte: texte, fin: resultat.isFinal), ronde: numero)
            }
        }
    }

    /// Le rappel arrive sur une file non principale : on ne fait que repasser au MainActor avec des valeurs `Sendable`.
    private nonisolated func transmettre(_ evenement: EvenementReco, ronde numero: Int) {
        Task { @MainActor in self.appliquer(evenement, ronde: numero) }
    }
}
#endif
