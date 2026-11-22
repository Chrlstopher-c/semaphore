// Responsabilité : ramener tout son du mode vocal au format de lecture (24 kHz mono) — le MP3 de la voix de la tour,
// et la voix française de l'iPhone (repli), rendue en tampons par AVSpeechSynthesizer au lieu d'être jouée à part :
// elle passe ainsi par le même moteur, donc par l'annulation d'écho.
#if canImport(SwiftUI)
@preconcurrency import AVFoundation
import Foundation
import VigieNoyau

enum DecodageAudio {
    /// MP3 → tampon au format de lecture ; nil si illisible.
    nonisolated static func mp3(_ donnees: Data) -> AVAudioPCMBuffer? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("voix-\(UUID().uuidString).mp3")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            try donnees.write(to: url)
            let fichier = try AVAudioFile(forReading: url)
            let capacite = AVAudioFrameCount(max(fichier.length, 1))
            guard let brut = AVAudioPCMBuffer(pcmFormat: fichier.processingFormat, frameCapacity: capacite) else {
                return nil
            }
            try fichier.read(into: brut)
            return convertir(brut)
        } catch {
            Trace.erreur("vocal", "décodage MP3", error)
            return nil
        }
    }

    /// Un tampon quelconque → format de lecture (rééchantillonné, mono, flottant).
    nonisolated static func convertir(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let cible = MoteurVocal.formatLecture
        if source.format == cible { return source }
        guard let convertisseur = AVAudioConverter(from: source.format, to: cible) else { return nil }
        let ratio = cible.sampleRate / source.format.sampleRate
        let capacite = AVAudioFrameCount(Double(source.frameLength) * ratio) + 1024
        guard let sortie = AVAudioPCMBuffer(pcmFormat: cible, frameCapacity: capacite) else { return nil }
        let fourni = Fourni()
        var erreur: NSError?
        convertisseur.convert(to: sortie, error: &erreur) { _, statut in
            if fourni.fait {
                statut.pointee = .endOfStream
                return nil
            }
            fourni.fait = true
            statut.pointee = .haveData
            return source
        }
        if let erreur { Trace.erreur("vocal", "conversion audio", erreur) }
        return erreur == nil ? sortie : nil
    }

    /// Tampons successifs (même format) → un seul.
    nonisolated static func concatener(_ tampons: [AVAudioPCMBuffer]) -> AVAudioPCMBuffer? {
        let total = tampons.reduce(0) { $0 + $1.frameLength }
        guard total > 0, let format = tampons.first?.format,
              let sortie = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: total),
              let destination = sortie.floatChannelData?[0] else { return nil }
        var position = 0
        for tampon in tampons {
            guard let source = tampon.floatChannelData?[0] else { continue }
            destination.advanced(by: position).update(from: source, count: Int(tampon.frameLength))
            position += Int(tampon.frameLength)
        }
        sortie.frameLength = AVAudioFrameCount(position)
        return sortie
    }
}

private final class Fourni: @unchecked Sendable {
    var fait = false
}

/// Voix française de l'iPhone, quand la tour ne répond pas.
enum VoixIPhone {
    nonisolated static func dire(_ texte: String) async -> AVAudioPCMBuffer? {
        let synthe = AVSpeechSynthesizer()
        let enonce = AVSpeechUtterance(string: texte)
        enonce.voice = AVSpeechSynthesisVoice(language: "fr-FR")
        enonce.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
        let collecte = Collecte(synthe)
        return await withCheckedContinuation { (reprise: CheckedContinuation<AVAudioPCMBuffer?, Never>) in
            collecte.reprise = reprise
            synthe.write(enonce) { tampon in collecte.recevoir(tampon) }
        }
    }
}

/// Rassemble les tampons de la voix de l'iPhone ; un tampon vide marque la fin. Garde le synthétiseur en vie.
private final class Collecte: @unchecked Sendable {
    private let verrou = NSLock()
    private var tampons: [AVAudioPCMBuffer] = []
    private var synthe: AVSpeechSynthesizer?
    var reprise: CheckedContinuation<AVAudioPCMBuffer?, Never>?

    init(_ synthe: AVSpeechSynthesizer) {
        self.synthe = synthe
    }

    func recevoir(_ tampon: AVAudioBuffer) {
        let fini: CheckedContinuation<AVAudioPCMBuffer?, Never>? = verrou.withLock {
            guard let pcm = tampon as? AVAudioPCMBuffer else { return nil }
            if pcm.frameLength > 0 {
                if let converti = DecodageAudio.convertir(pcm) { tampons.append(converti) }
                return nil
            }
            defer { reprise = nil; synthe = nil }
            return reprise
        }
        fini?.resume(returning: DecodageAudio.concatener(verrou.withLock { tampons }))
    }
}
#endif
