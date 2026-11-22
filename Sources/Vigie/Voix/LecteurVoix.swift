// Responsabilité : la file de lecture du mode vocal — chaque morceau de la réponse est demandé à la voix de la tour
// dès qu'il est complet (le suivant pendant que le précédent est dit), puis joué dans l'ordre. Si la tour ne répond
// pas, la voix de l'iPhone prend le relais (30 s avant de réessayer la tour) : le mode parle toujours.
#if canImport(SwiftUI)
@preconcurrency import AVFoundation
import Foundation
import VigieNoyau

/// Un tampon audio qui traverse les tâches ; il n'est plus modifié une fois rempli.
struct TamponAudio: @unchecked Sendable {
    let tampon: AVAudioPCMBuffer
    /// Vrai : voix de la tour ; faux : voix de l'iPhone (repli).
    let duTour: Bool
}

@MainActor
final class LecteurVoix {
    /// Deux synthèses vers la tour à la fois : la suivante est prête quand la précédente finit d'être dite.
    private static let synthesesEnVol = 2

    private let moteur: MoteurVocal
    private let synthese: @Sendable (String) async throws -> Data
    private let file = FileVocale<TamponAudio>(enVol: LecteurVoix.synthesesEnVol)
    private var lecture: Task<Void, Never>?
    private var generation = 0
    private var tourEnPanneJusqua: ContinuousClock.Instant?
    private var debutTour: ContinuousClock.Instant?
    /// La phrase dite en ce moment (nil : silence) et la voix qui la dit.
    var surPhrase: ((String?, Bool) -> Void)?
    var surSilence: (() -> Void)?
    private(set) var parle = false

    init(moteur: MoteurVocal, synthese: @escaping @Sendable (String) async throws -> Data) {
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
            let audio = await morceau.audio.value
            guard let self, numero == self.generation else { return }
            self.jouer(morceau.texte, audio, numero: numero)
        }
    }

    private func jouer(_ texte: String, _ audio: TamponAudio?, numero: Int) {
        guard let audio else { return lireSuivant() }
        if let debut = debutTour {
            Trace.info("vocal", "premier son après \(debut.duration(to: .now)) — « \(texte.prefix(40)) »")
            debutTour = nil
        }
        parle = true
        surPhrase?(texte, audio.duTour)
        moteur.jouer(audio.tampon) { [weak self] in
            Task { @MainActor in
                guard let self, numero == self.generation else { return }
                self.lireSuivant()
            }
        }
    }

    nonisolated private static func preparer(
        _ texte: String, tour: (@Sendable (String) async throws -> Data)?
    ) async -> TamponAudio? {
        if let tour {
            do {
                let donnees = try await tour(texte)
                if let tampon = DecodageAudio.mp3(donnees) { return TamponAudio(tampon: tampon, duTour: true) }
                Trace.erreur("vocal", "audio de la tour illisible (\(donnees.count) o)")
            } catch {
                if Task.isCancelled { return nil }
                Trace.erreur("vocal", "voix de la tour indisponible, voix de l'iPhone", error)
                await signalerPanne()
            }
        }
        if Task.isCancelled { return nil }
        return await VoixIPhone.dire(texte).map { TamponAudio(tampon: $0, duTour: false) }
    }

    nonisolated private static func signalerPanne() async {
        await MainActor.run { ModeVocal.partage.lecteur?.marquerPanne() }
    }

    func marquerPanne() {
        tourEnPanneJusqua = .now.advanced(by: .seconds(30))
    }
}
#endif
