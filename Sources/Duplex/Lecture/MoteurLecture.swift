// La lecture : la session audio, le moteur, et le nœud source qui tire du tampon.
#if canImport(SwiftUI)
import AVFoundation
import DuplexNoyau
import Foundation

/// L'état que le fil de rendu est SEUL à toucher : la correction de dérive et la
/// phase de lecture. Les garder ensemble, dans un objet alloué une fois, évite
/// tout partage entre fils — donc tout verrou dans le rappel de rendu.
///
/// `☠` La correction est calculée DANS le rappel, à partir du remplissage lu au
/// même instant. La faire calculer ailleurs obligerait à publier un `Double`
/// entre deux fils, et à comparer deux mesures prises à des moments différents.
final class EtatRendu: @unchecked Sendable {
    var correction = CorrectionDerive()
    var lecteur = LectureEtiree()

    func reinitialiser() {
        correction.reinitialiser()
        lecteur.reinitialiser()
    }
}

/// Le moteur de lecture. Ouvre la session, monte le graphe, et rend la main.
public final class MoteurLecture: @unchecked Sendable {
    private let tampon: TamponAudio
    private let etat = EtatRendu()
    private let moteur = AVAudioEngine()
    private var source: AVAudioSourceNode?
    public private(set) var enMarche = false

    public init(tampon: TamponAudio) {
        self.tampon = tampon
    }

    /// Le format du flux, imposé par le protocole : 48 kHz, stéréo, 16 bits
    /// signés, entrelacés. Aucune négociation — toute source du PC est
    /// reconvertie à ce format avant émission.
    private static var format: AVAudioFormat? {
        AVAudioFormat(
            commonFormat: .pcmFormatInt16, sampleRate: EnTetePaquet.frequence,
            channels: AVAudioChannelCount(EnTetePaquet.canaux), interleaved: true
        )
    }

    public func demarrer() throws {
        guard !enMarche else { return }
        try ouvrirSession()
        try monterGraphe()
        do {
            try moteur.start()
        } catch {
            Journal.echec("moteur audio refusé : \(error.localizedDescription)")
            throw ErreurDuplex.injoignable("moteur audio : \(error.localizedDescription)")
        }
        enMarche = true
        Journal.note("lecture démarrée")
    }

    public func arreter() {
        guard enMarche else { return }
        moteur.stop()
        if let source {
            moteur.detach(source)
            self.source = nil
        }
        etat.reinitialiser()
        tampon.vider()
        enMarche = false
        fermerSession()
        Journal.note("lecture arrêtée")
    }

    // MARK: - La session

    /// `☠` `.playback` + `.mixWithOthers`, et RIEN d'autre. Les deux
    /// conséquences sont voulues, et la seconde est la plus importante : avec
    /// `.mixWithOthers`, Duplex ne devient jamais l'app « qui joue » aux yeux du
    /// système, donc il ne prend PAS les contrôles de l'écran verrouillé. Sillon
    /// en a besoin, et une collision là-dessus serait un défaut grave. C'est
    /// aussi ce qui laisse le son du PC se mêler à ce que le téléphone joue
    /// déjà, au lieu de l'interrompre.
    private func ouvrirSession() throws {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            Journal.echec("session audio refusée : \(error.localizedDescription)")
            throw ErreurDuplex.injoignable("session audio : \(error.localizedDescription)")
        }
        #endif
    }

    /// `☠` On désactive la session en prévenant les autres apps (`.notifyOthersOnDeactivation`) :
    /// sans ça, une app mise en sourdine pendant l'écoute ne reprend pas toute seule.
    private func fermerSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance()
                .setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            Journal.echec("session audio non refermée : \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - Le graphe

    private func monterGraphe() throws {
        guard let format = Self.format else {
            throw ErreurDuplex.injoignable("format audio 48 kHz stéréo 16 bits indisponible")
        }
        let source = AVAudioSourceNode(format: format) { [tampon, etat] _, _, trames, bacs in
            Self.rendre(trames: trames, bacs: bacs, tampon: tampon, etat: etat)
        }
        moteur.attach(source)
        moteur.connect(source, to: moteur.mainMixerNode, format: format)
        self.source = source
    }

    /// Le rappel de rendu. Tourne sur un fil TEMPS RÉEL : aucune allocation,
    /// aucun verrou, aucun `print`, aucun appel système. Tout ce qu'il touche
    /// est soit atomique (`TamponAudio`), soit à lui seul (`EtatRendu`).
    private static func rendre(
        trames: AVAudioFrameCount, bacs: UnsafeMutablePointer<AudioBufferList>,
        tampon: TamponAudio, etat: EtatRendu
    ) -> OSStatus {
        let liste = UnsafeMutableAudioBufferListPointer(bacs)
        guard let premier = liste.first, let brut = premier.mData else { return noErr }
        let destination = brut.assumingMemoryBound(to: Int16.self)
        let facteur = etat.correction.observer(remplissageMs: tampon.remplissageMs)
        tampon.lire(
            dans: destination, trames: Int(trames), facteur: facteur, lecteur: &etat.lecteur
        )
        return noErr
    }
}
#endif
