// La dictée de Vigie : transcription de la parole, strictement sur l'appareil.
//
// `☠` `requiresOnDeviceRecognition` est posé à `true` et il n'y a AUCUN repli
// réseau. Ce qui est dicté ici, ce sont des instructions à un agent qui a la
// main sur le parc : une phrase partie chez Apple parce que le modèle local
// manquait serait une fuite silencieuse. Si la reconnaissance locale n'est pas
// disponible, la sonde refuse de démarrer et le dit.
//
// Matériel : le local exige un A12 Bionic au minimum — l'iPhone XS est
// exactement au seuil — et le modèle de langue doit avoir été téléchargé par le
// système (il l'est dès que le clavier français est installé).
#if canImport(SwiftUI)
import AVFoundation
import Foundation
import Observation
import Speech
import VigieNoyau

@MainActor
@Observable
final class DicteeSonde {
    private(set) var texte = ""
    private(set) var actif = false
    private(set) var empechement: String?

    @ObservationIgnored private let moteur = AVAudioEngine()
    @ObservationIgnored private let recogniseur = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    @ObservationIgnored private let alimentation = Alimentation()
    @ObservationIgnored private var requete: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var tache: SFSpeechRecognitionTask?
    @ObservationIgnored private var assemblage = AssemblageDictee()

    /// Disponibilité réelle, lue sur l'appareil et non déduite de la version du
    /// système : c'est la seule réponse qui vaille.
    var localeDisponible: Bool {
        recogniseur?.supportsOnDeviceRecognition == true
    }

    /// - Parameter brouillon: ce qui est déjà dans le champ. La dictée s'y
    ///   ajoute, elle ne le remplace jamais.
    func demarrer(brouillon: String) async {
        guard !actif else { return }
        guard let recogniseur, recogniseur.isAvailable else {
            empechement = "La reconnaissance vocale française n'est pas disponible sur cet appareil."
            return
        }
        guard recogniseur.supportsOnDeviceRecognition else {
            empechement = "La transcription hors ligne n'est pas installée. "
                + "Ajoute le clavier français dans Réglages pour télécharger le modèle."
            return
        }
        guard await autoriser() else {
            empechement = "Accès au microphone ou à la reconnaissance vocale refusé."
            return
        }
        assemblage = AssemblageDictee(base: brouillon)
        texte = assemblage.texte
        await lancer(recogniseur)
    }

    private func lancer(_ recogniseur: SFSpeechRecognizer) async {
        do {
            try configurerSession()
            try brancherCapture(recogniseur)
            actif = true
            empechement = nil
            Trace.info("dictée", "démarrée, locale fr-FR, sur l'appareil")
        } catch {
            empechement = "La dictée n'a pas pu démarrer : \(error.localizedDescription)"
            Trace.erreur("dictée", "démarrage impossible", error)
            arreter()
        }
    }

    /// Seul Chris arrête une dictée. Un silence, si long soit-il, ne fait que
    /// clore un segment.
    func arreter() {
        guard actif || requete != nil else { return }
        // L'ordre compte : on retient d'abord la dernière phrase, puis on coupe.
        // `actif` passe à faux avant la fermeture pour qu'un résultat tardif
        // n'aille pas rouvrir un segment sur un moteur arrêté.
        actif = false
        assemblage.consolider()
        texte = assemblage.texte

        moteur.inputNode.removeTap(onBus: 0)
        moteur.stop()
        requete?.endAudio()
        tache?.cancel()
        requete = nil
        tache = nil
        rendreSession()
        Trace.info("dictée", "arrêtée")
    }

    /// Le champ a été corrigé au clavier pendant la dictée : l'acquis repart de
    /// ce que Chris voit, sinon le mot suivant écraserait sa correction.
    func reprendreSur(_ texte: String) {
        assemblage.reprendreSur(texte)
        self.texte = texte
    }

    func oublierEmpechement() {
        empechement = nil
    }

    private func autoriser() async -> Bool {
        let micro = await AVAudioApplication.requestRecordPermission()
        guard micro else { return false }
        return await withCheckedContinuation { suite in
            // `@Sendable` obligatoire : sans l'annotation, la closure hérite de
            // l'isolation `@MainActor` de cette classe, Swift y insère une
            // assertion d'exécuteur, et TCC la rappelle depuis sa file XPC.
            // L'assertion tombe et le processus meurt à l'instant exact où
            // l'utilisateur accorde l'autorisation.
            SFSpeechRecognizer.requestAuthorization { @Sendable statut in
                suite.resume(returning: statut == .authorized)
            }
        }
    }

    /// `☠` `.playAndRecord` et non `.record` : Vigie garde une session audio
    /// vivante en permanence pour survivre en arrière-plan (`MaintienVie`).
    /// `.record` coupe toute lecture, donc tue le maintien en vie sans un mot.
    /// `mixWithOthers` par la même raison : cette session ne réclame jamais
    /// l'exclusivité.
    ///
    /// Le mode reste `.default` — c'est lui qui laisse le système appliquer à la
    /// voix son traitement habituel. `.spokenAudio` n'est PAS valide en capture
    /// (il appartient à `.playback`) et donne `OSStatus -50`.
    private func configurerSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker]
        )
        try session.setActive(true)
    }

    /// Rend la session à qui de droit : au maintien en vie s'il la réclamait,
    /// sinon au système. Désactiver une session que `MaintienVie` croit tenir
    /// ferait mourir le canal d'alerte à la première dictée.
    private func rendreSession() {
        guard !MaintienVie.partage.reprendreApresCapture() else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            Trace.erreur("dictée", "désactivation de la session audio", error)
        }
    }

    private func brancherCapture(_ recogniseur: SFSpeechRecognizer) throws {
        let entree = moteur.inputNode
        // `inputFormat` et non `outputFormat` : c'est le format réel imposé par
        // le matériel. Un tap dont le format ne correspond pas à celui du bus
        // est la seconde cause classique d'`OSStatus -50`.
        let format = entree.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw DicteeErreur.entreeIndisponible
        }

        // Closure explicitement `@Sendable` : sans l'annotation elle hériterait
        // de l'isolation `@MainActor` de cette méthode, puisque
        // `AVAudioNodeTapBlock` n'est pas marqué `Sendable`. Swift y insérerait
        // une assertion d'exécuteur, que CoreAudio ferait tomber en appelant le
        // bloc depuis sa file temps réel — le processus meurt au premier tampon.
        let alimentation = self.alimentation
        entree.installTap(onBus: 0, bufferSize: 2048, format: format) { @Sendable tampon, _ in
            alimentation.alimenter(tampon)
        }
        ouvrirSegment(recogniseur)
        moteur.prepare()
        try moteur.start()
    }

    /// Ouvre une requête de reconnaissance neuve sur le moteur audio déjà en
    /// marche.
    ///
    /// `☠` Speech clôt une phrase dès qu'il entend un silence : il envoie un
    /// résultat final et cesse de transcrire, et le résultat suivant repart de
    /// zéro — c'est ce qui fait disparaître tout ce qui précède la pause. La
    /// parade est de consolider chaque phrase et de rouvrir immédiatement une
    /// requête sans jamais toucher à la capture audio. Chris ne voit qu'une
    /// dictée continue, et la limite de durée d'une tâche Speech tombe avec.
    private func ouvrirSegment(_ recogniseur: SFSpeechRecognizer) {
        let requete = SFSpeechAudioBufferRecognitionRequest()
        requete.requiresOnDeviceRecognition = true
        requete.shouldReportPartialResults = true
        self.requete = requete
        alimentation.rediriger(vers: requete)
        tache = recogniseur.recognitionTask(with: requete, resultHandler: recevoir)
    }

    /// `nonisolated` : le gestionnaire est appelé depuis une file interne au
    /// framework Speech, jamais depuis l'acteur principal. Seuls des scalaires
    /// traversent — `SFSpeechRecognitionResult` n'est pas `Sendable`.
    private nonisolated func recevoir(_ resultat: SFSpeechRecognitionResult?, _ erreur: Error?) {
        let transcription = resultat?.bestTranscription.formattedString
        let clos = resultat?.isFinal == true
        let message = erreur?.localizedDescription
        Task { @MainActor [weak self] in
            self?.appliquer(transcription, clos: clos, erreur: message)
        }
    }

    /// - Parameter clos: Speech considère la phrase terminée. Ce n'est **pas**
    ///   la fin de la dictée.
    private func appliquer(_ transcription: String?, clos: Bool, erreur: String?) {
        guard actif else { return }
        if let transcription { assemblage.poser(transcription) }
        texte = assemblage.texte
        guard clos || erreur != nil else { return }
        if let erreur { Trace.detail("dictée", "segment clos : \(erreur)") }
        consolider()
    }

    /// Verse le segment courant dans l'acquis et rouvre une requête.
    private func consolider() {
        assemblage.consolider()
        texte = assemblage.texte
        guard let recogniseur, actif else { return }
        tache?.cancel()
        requete?.endAudio()
        ouvrirSegment(recogniseur)
    }
}

/// Passe-plat vers la requête de reconnaissance depuis le rappel de capture.
///
/// `SFSpeechAudioBufferRecognitionRequest` n'est pas marqué `Sendable`, mais
/// `append(_:)` est précisément prévu pour être appelé depuis le tap audio :
/// c'est l'usage documenté par Apple. Cette boîte assume explicitement un
/// contrat que le compilateur n'a aucun moyen de vérifier, plutôt que de
/// désactiver la vérification sur tout le module avec `@preconcurrency`.
/// La requête change à chaque phrase close pendant que la capture, elle, ne
/// s'arrête jamais : le verrou protège le passage de l'une à l'autre.
private final class Alimentation: @unchecked Sendable {
    private let verrou = NSLock()
    private var requete: SFSpeechAudioBufferRecognitionRequest?

    func rediriger(vers requete: SFSpeechAudioBufferRecognitionRequest) {
        verrou.lock()
        defer { verrou.unlock() }
        self.requete = requete
    }

    func alimenter(_ tampon: AVAudioPCMBuffer) {
        verrou.lock()
        defer { verrou.unlock() }
        requete?.append(tampon)
    }
}

enum DicteeErreur: LocalizedError {
    case entreeIndisponible

    var errorDescription: String? {
        switch self {
        case .entreeIndisponible: return "aucune entrée audio exploitable"
        }
    }
}
#endif
