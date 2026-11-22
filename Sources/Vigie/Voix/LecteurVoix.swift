// Responsabilité : la file de lecture du mode vocal — chaque phrase de la réponse est demandée à la voix de la tour dès
// qu'elle est complète (la suivante pendant que la précédente est dite), et jouée dès que son premier morceau arrive
// (flux PCM de la tour), dans l'ordre. Si la tour ne répond pas, la voix de l'iPhone prend le relais (30 s avant de
// réessayer la tour) : le mode parle toujours.
#if canImport(SwiftUI)
@preconcurrency import AVFoundation
import Foundation
import VigieNoyau

/// Un tampon audio qui traverse les tâches ; il n'est plus modifié une fois rempli.
struct TamponAudio: @unchecked Sendable {
    let tampon: AVAudioPCMBuffer
}

/// Une phrase en train d'arriver : ses tampons passent au fil de la synthèse (un seul pour la voix de l'iPhone).
struct PhraseAudio: Sendable {
    let tampons: AsyncStream<TamponAudio>
    /// Vrai : voix de la tour ; faux : voix de l'iPhone (repli).
    let duTour: Bool
}

@MainActor
final class LecteurVoix {
    /// Deux synthèses vers la tour à la fois : la suivante est prête quand la précédente finit d'être dite.
    private static let synthesesEnVol = 2
    typealias Synthese = @Sendable (String) async throws -> AsyncThrowingStream<MorceauSynthese, Error>

    private let moteur: MoteurVocal
    private let synthese: Synthese
    private let file = FileVocale<PhraseAudio>(enVol: LecteurVoix.synthesesEnVol)
    private var lecture: Task<Void, Never>?
    private var generation = 0
    private var tourEnPanneJusqua: ContinuousClock.Instant?
    private var debutTour: ContinuousClock.Instant?
    /// Tampons de la phrase en cours pas encore entendus, et fin de la phrase arrivée.
    private var enVol = 0
    private var phraseArrivee = false
    /// La phrase dite en ce moment (nil : silence) et la voix qui la dit.
    var surPhrase: ((String?, Bool) -> Void)?
    var surSilence: (() -> Void)?
    private(set) var parle = false

    init(moteur: MoteurVocal, synthese: @escaping Synthese) {
        self.moteur = moteur
        self.synthese = synthese
    }

    func ajouter(_ texte: String) {
        if !parle && file.vide { debutTour = .now }
        let panne = tourEnPanne
        let synthese = self.synthese
        file.ajouter(texte) { phrase in
            await LecteurVoix.preparer(phrase, tour: panne ? nil : synthese)
        }
        if lecture == nil { lireSuivant() }
    }

    /// Coupe la voix et jette tout ce qui attendait (passer un message, ou Chris qui parle).
    func taire() {
        generation += 1
        file.annuler()
        lecture?.cancel()
        lecture = nil
        moteur.taire()
        if parle {
            parle = false
            surPhrase?(nil, true)
        }
    }

    /// Le moteur a été reconstruit : la phrase en cours est perdue, on passe à la suivante.
    func reprendre() {
        lecture = nil
        lireSuivant()
    }

    private var tourEnPanne: Bool {
        guard let fin = tourEnPanneJusqua else { return false }
        return ContinuousClock.now < fin
    }

    private func lireSuivant() {
        guard let morceau = file.prochain() else {
            lecture = nil
            if parle { parle = false; surPhrase?(nil, true); surSilence?() }
            return
        }
        let numero = generation
        lecture = Task { [weak self] in
            let phrase = await morceau.audio.value
            guard let self, numero == self.generation else { return }
            await self.jouer(morceau.texte, phrase, numero: numero)
        }
    }

    /// Joue les tampons de la phrase au fur et à mesure qu'ils arrivent ; la suivante part quand le dernier est entendu.
    private func jouer(_ texte: String, _ phrase: PhraseAudio?, numero: Int) async {
        guard let phrase else { return lireSuivant() }
        if let debut = debutTour {
            Trace.info("vocal", "premier son après \(debut.duration(to: .now)) — « \(texte.prefix(40)) »")
            debutTour = nil
        }
        parle = true
        surPhrase?(texte, phrase.duTour)
        enVol = 0
        phraseArrivee = false
        for await morceau in phrase.tampons {
            guard numero == generation else { return }
            enVol += 1
            moteur.jouer(morceau.tampon) { [weak self] in
                Task { @MainActor in self?.tamponJoue(numero) }
            }
        }
        guard numero == generation else { return }
        phraseArrivee = true
        terminerSiJoue(numero)
    }

    private func tamponJoue(_ numero: Int) {
        guard numero == generation else { return }
        enVol -= 1
        terminerSiJoue(numero)
    }

    private func terminerSiJoue(_ numero: Int) {
        guard phraseArrivee, enVol == 0, numero == generation else { return }
        lireSuivant()
    }

    nonisolated private static func preparer(_ texte: String, tour: Synthese?) async -> PhraseAudio? {
        if let tour {
            do {
                return phraseTour(try await tour(texte))
            } catch {
                if Task.isCancelled { return nil }
                Trace.erreur("vocal", "voix de la tour indisponible, voix de l'iPhone", error)
                await signalerPanne()
            }
        }
        if Task.isCancelled { return nil }
        guard let tampon = await VoixIPhone.dire(texte) else { return nil }
        let tampons: AsyncStream<TamponAudio> = AsyncStream { suite in
            suite.yield(TamponAudio(tampon: tampon))
            suite.finish()
        }
        return PhraseAudio(tampons: tampons, duTour: false)
    }

    /// Les morceaux de la tour passent dans le flux de la phrase, décodés au fur et à mesure (PCM) ou d'un bloc (MP3).
    nonisolated private static func phraseTour(_ morceaux: AsyncThrowingStream<MorceauSynthese, Error>) -> PhraseAudio {
        let tampons: AsyncStream<TamponAudio> = AsyncStream { suite in
            let tache = Task {
                var decodeur = DecodeurPCM()
                do {
                    for try await morceau in morceaux {
                        let tampon: AVAudioPCMBuffer?
                        switch morceau {
                        case .pcm(let octets): tampon = DecodageAudio.pcm(decodeur.ajouter(octets))
                        case .mp3(let donnees): tampon = DecodageAudio.mp3(donnees)
                        }
                        if let tampon { suite.yield(TamponAudio(tampon: tampon)) }
                    }
                } catch {
                    Trace.erreur("vocal", "flux de la tour interrompu", error)
                }
                suite.finish()
            }
            suite.onTermination = { _ in tache.cancel() }
        }
        return PhraseAudio(tampons: tampons, duTour: true)
    }

    nonisolated private static func signalerPanne() async {
        await MainActor.run { ModeVocal.partage.lecteur?.marquerPanne() }
    }

    func marquerPanne() {
        tourEnPanneJusqua = .now.advanced(by: .seconds(30))
    }
}
#endif
