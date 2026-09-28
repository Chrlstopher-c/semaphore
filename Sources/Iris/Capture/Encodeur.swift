// L'encodeur H.264 matériel : une seule compression, quel que soit le nombre de PC.
#if canImport(VideoToolbox)
import Foundation
import IrisNoyau
import os
import VideoToolbox

/// `@unchecked Sendable` : `session` et ses dimensions ne sont touchées que
/// depuis la file de capture (série), qui seule appelle `encoder` ; les
/// demandes venues d'ailleurs (clé forcée, débit) passent par `demandes`, verrouillé.
final class Encodeur: @unchecked Sendable {
    private struct Demandes {
        var cle = false
        var debit: Int
    }

    private var session: VTCompressionSession?
    private var largeur: Int32 = 0
    private var hauteur: Int32 = 0
    private var debitApplique = 0
    private let demandes: OSAllocatedUnfairLock<Demandes>
    private let sortie = OSAllocatedUnfairLock<(@Sendable (Data, Bool) -> Void)?>(initialState: nil)
    private let journal = Logger(subsystem: "com.echo.labs", category: "iris.encodeur")

    init(debit: Int) {
        demandes = OSAllocatedUnfairLock(initialState: Demandes(debit: debit))
    }

    /// Où partent les unités compressées : branché une fois, après construction
    /// (la diffusion et l'encodeur se connaissent mutuellement).
    func brancher(_ livrer: @escaping @Sendable (Data, Bool) -> Void) {
        sortie.withLock { $0 = livrer }
    }

    /// Un PC vient de se joindre : il ne décode rien avant une image clé.
    func forcerCle() {
        demandes.withLock { $0.cle = true }
    }

    func changerDebit(_ debit: Int) {
        demandes.withLock { $0.debit = debit }
    }

    func encoder(_ image: CVPixelBuffer, instant: CMTime) {
        let l = Int32(CVPixelBufferGetWidth(image)), h = Int32(CVPixelBufferGetHeight(image))
        let voulu = demandes.withLock { etat -> Demandes in
            let copie = etat
            etat.cle = false
            return copie
        }
        if session == nil || l != largeur || h != hauteur { creer(largeur: l, hauteur: h, debit: voulu.debit) }
        guard let session else { return }
        if voulu.debit != debitApplique { appliquerDebit(voulu.debit, a: session) }
        let proprietes = voulu.cle ? [kVTEncodeFrameOptionKey_ForceKeyFrame: kCFBooleanTrue!] as CFDictionary : nil
        guard let livrer = sortie.withLock({ $0 }) else { return }
        let statut = VTCompressionSessionEncodeFrame(
            session, imageBuffer: image, presentationTimeStamp: instant, duration: .invalid,
            frameProperties: proprietes, infoFlagsOut: nil
        ) { @Sendable statut, _, echantillon in
            guard statut == noErr, let echantillon, let (unite, cle) = Encodeur.extraire(echantillon) else { return }
            livrer(unite, cle)
        }
        if statut != noErr { journal.error("encodage refusé : \(statut)") }
    }

    private func creer(largeur l: Int32, hauteur h: Int32, debit: Int) {
        if let session { VTCompressionSessionInvalidate(session) }
        session = nil
        var nouvelle: VTCompressionSession?
        let statut = VTCompressionSessionCreate(
            allocator: nil, width: l, height: h, codecType: kCMVideoCodecType_H264, encoderSpecification: nil,
            imageBufferAttributes: nil, compressedDataAllocator: nil, outputCallback: nil, refcon: nil,
            compressionSessionOut: &nouvelle
        )
        guard statut == noErr, let nouvelle else {
            journal.error("session d'encodage impossible : \(statut)")
            return
        }
        let reglages: [CFString: Any] = [
            kVTCompressionPropertyKey_RealTime: kCFBooleanTrue!,
            kVTCompressionPropertyKey_ProfileLevel: kVTProfileLevel_H264_High_AutoLevel,
            kVTCompressionPropertyKey_AllowFrameReordering: kCFBooleanFalse!,
            kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration: 2,
            kVTCompressionPropertyKey_ExpectedFrameRate: 30,
        ]
        VTSessionSetProperties(nouvelle, propertyDictionary: reglages as CFDictionary)
        appliquerDebit(debit, a: nouvelle)
        VTCompressionSessionPrepareToEncodeFrames(nouvelle)
        session = nouvelle
        largeur = l
        hauteur = h
        journal.info("encodeur \(l)×\(h)")
    }

    /// Débit moyen visé, plafonné à 1,5× sur une seconde : une scène qui bouge
    /// ne doit pas noyer la liaison d'un coup.
    private func appliquerDebit(_ debit: Int, a session: VTCompressionSession) {
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: debit as CFNumber)
        let limites = [debit / 8 * 3 / 2, 1] as CFArray
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_DataRateLimits, value: limites)
        debitApplique = debit
    }

    /// L'échantillon compressé en unité Annex-B, jeux de paramètres en tête sur une clé.
    static func extraire(_ echantillon: CMSampleBuffer) -> (Data, Bool)? {
        guard let bloc = CMSampleBufferGetDataBuffer(echantillon),
              let format = CMSampleBufferGetFormatDescription(echantillon) else { return nil }
        let longueur = CMBlockBufferGetDataLength(bloc)
        var avcc = Data(count: longueur)
        let copie = avcc.withUnsafeMutableBytes { tampon -> OSStatus in
            guard let base = tampon.baseAddress else { return -1 }
            return CMBlockBufferCopyDataBytes(bloc, atOffset: 0, dataLength: longueur, destination: base)
        }
        guard copie == noErr else { return nil }
        let cle = estCle(echantillon)
        let (jeux, tailleLongueur) = parametres(format)
        let unite = AnnexeB.uniteAcces(parametres: cle ? jeux : [], avcc: avcc, tailleLongueur: tailleLongueur)
        return unite.map { ($0, cle) }
    }

    private static func estCle(_ echantillon: CMSampleBuffer) -> Bool {
        guard let pieces = CMSampleBufferGetSampleAttachmentsArray(echantillon, createIfNecessary: false)
                as? [[CFString: Any]], let premiere = pieces.first else { return true }
        return !(premiere[kCMSampleAttachmentKey_NotSync] as? Bool ?? false)
    }

    private static func parametres(_ format: CMFormatDescription) -> ([Data], Int) {
        var nombre = 0
        var tailleNAL: Int32 = 4
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            format, parameterSetIndex: 0, parameterSetPointerOut: nil, parameterSetSizeOut: nil,
            parameterSetCountOut: &nombre, nalUnitHeaderLengthOut: &tailleNAL
        )
        var jeux: [Data] = []
        for rang in 0..<nombre {
            var pointeur: UnsafePointer<UInt8>?
            var taille = 0
            let statut = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                format, parameterSetIndex: rang, parameterSetPointerOut: &pointeur, parameterSetSizeOut: &taille,
                parameterSetCountOut: nil, nalUnitHeaderLengthOut: nil
            )
            if statut == noErr, let pointeur { jeux.append(Data(bytes: pointeur, count: taille)) }
        }
        return (jeux, Int(tailleNAL))
    }
}
#endif
