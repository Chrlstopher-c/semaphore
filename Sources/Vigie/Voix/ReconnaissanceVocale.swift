// Responsabilité : la reconnaissance continue du mode vocal — Speech en français sur l'appareil, nourri par le micro
// du moteur vocal ; une requête neuve à chaque fin de phrase (Speech la clôt au silence, et au bout d'une minute),
// le texte cumulé jusqu'à `recommencer()` (envoi du message, ou écho jeté après la lecture).
#if canImport(SwiftUI)
@preconcurrency import AVFoundation
import Foundation
import Speech
import VigieNoyau

private enum ResultatReco: Sendable {
    case texte(String, fin: Bool)
    case erreur(String)
}

@MainActor
final class ReconnaissanceVocale {
    private let pont = PontReco()
    private var reconnaissance: SFSpeechRecognizer?
    private var tache: SFSpeechRecognitionTask?
    private var ronde = 0
    private var cumul = CumulDictee(base: "")
    private var surResultat: ((String) -> Void)?

    /// Appelé depuis le fil audio : le tampon part à la requête courante.
    nonisolated func ajouter(_ tampon: AVAudioPCMBuffer) {
        pont.ajouter(tampon)
    }

    static func autoriser() async -> String? {
        guard await AVAudioApplication.requestRecordPermission() else {
            return "Micro non autorisé : autorise Sémaphore dans Réglages iOS."
        }
        return await autoriserReconnaissance() == .authorized
            ? nil : "Reconnaissance vocale non autorisée : autorise-la dans Réglages iOS."
    }

    /// nonisolated : le rappel d'autorisation arrive sur une file quelconque, il ne doit pas hériter du MainActor.
    private nonisolated static func autoriserReconnaissance() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { reprise in
            SFSpeechRecognizer.requestAuthorization { reprise.resume(returning: $0) }
        }
    }

    func demarrer(surResultat: @escaping (String) -> Void) -> String? {
        guard let reco = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR")), reco.supportsOnDeviceRecognition,
              reco.isAvailable else {
            return "Modèle de dictée français absent : télécharge-le dans Réglages iOS."
        }
        reconnaissance = reco
        self.surResultat = surResultat
        recommencer()
        return nil
    }

    func arreter() {
        ronde += 1
        pont.changer(vers: nil)
        tache?.cancel()
        tache = nil
        reconnaissance = nil
        surResultat = nil
    }

    /// Oublie ce qui a été entendu et repart sur une requête neuve.
    func recommencer() {
        cumul = CumulDictee(base: "")
        ouvrirRequete()
    }

    private func ouvrirRequete() {
        guard let reco = reconnaissance else { return }
        ronde += 1
        let requete = SFSpeechAudioBufferRecognitionRequest()
        requete.requiresOnDeviceRecognition = true
        requete.shouldReportPartialResults = true
        requete.addsPunctuation = true
        requete.taskHint = .dictation
        pont.changer(vers: requete)
        tache?.cancel()
        tache = reco.recognitionTask(with: requete, resultHandler: Self.rappel(self, ronde: ronde))
    }

    private func appliquer(_ resultat: ResultatReco, ronde numero: Int) {
        guard numero == ronde, surResultat != nil else { return }
        switch resultat {
        case .texte(let texte, let fin):
            cumul.resultat(texte, fin: fin)
            if fin { ouvrirRequete() }
            if !cumul.texte.isEmpty { surResultat?(cumul.texte) }
        case .erreur(let detail):
            cumul.figer()
            Trace.info("vocal", "reconnaissance relancée : \(detail)")
            ouvrirRequete()
        }
    }

    private nonisolated static func rappel(
        _ reco: ReconnaissanceVocale, ronde numero: Int
    ) -> @Sendable (SFSpeechRecognitionResult?, Error?) -> Void {
        { resultat, erreur in
            let r: ResultatReco
            if let erreur {
                r = .erreur("\((erreur as NSError).code)")
            } else if let resultat {
                r = .texte(resultat.bestTranscription.formattedString, fin: resultat.isFinal)
            } else {
                return
            }
            Task { @MainActor in reco.appliquer(r, ronde: numero) }
        }
    }
}

/// La requête courante, partagée avec le fil audio sous verrou (la requête n'est pas `Sendable`).
private final class PontReco: @unchecked Sendable {
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
#endif
