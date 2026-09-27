// L'analyse d'une photo par Vision, sur l'appareil : son empreinte (pour les
// similaires) et son jugement esthétique (ratée, utilitaire). Aucun octet ne
// quitte le téléphone.
//
// Les deux requêtes sont jouées séparément : si l'une échoue (l'esthétique est
// récente, iOS 18), l'autre garde sa valeur.
#if canImport(Vision) && canImport(UIKit)
import TamisNoyau
import UIKit
import Vision

struct Lecture: Sendable {
    let qualite: Qualite?
    let vecteur: [Float]?
}

enum Analyseur {
    /// 360 px suffisent aux deux modèles, qui réduisent eux-mêmes bien en dessous.
    private static let cote: CGFloat = 360

    static func analyser(_ id: String) async -> Lecture? {
        guard let image = await Images.image(id, cote: cote, reseau: false), let cg = image.cgImage else {
            return nil
        }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return Lecture(qualite: qualite(cg, orientation, id), vecteur: empreinte(cg, orientation, id))
    }

    private static func qualite(_ cg: CGImage, _ orientation: CGImagePropertyOrientation, _ id: String) -> Qualite? {
        let requete = VNCalculateImageAestheticsScoresRequest()
        do {
            try VNImageRequestHandler(cgImage: cg, orientation: orientation).perform([requete])
            guard let resultat = requete.results?.first else { return nil }
            return Qualite(score: resultat.overallScore, utilitaire: resultat.isUtility)
        } catch {
            Journal.echec("esthétique \(id) : \(error.localizedDescription)")
            return nil
        }
    }

    private static func empreinte(_ cg: CGImage, _ orientation: CGImagePropertyOrientation, _ id: String) -> [Float]? {
        let requete = VNGenerateImageFeaturePrintRequest()
        do {
            try VNImageRequestHandler(cgImage: cg, orientation: orientation).perform([requete])
            guard let resultat = requete.results?.first else { return nil }
            return vecteur(resultat)
        } catch {
            Journal.echec("empreinte \(id) : \(error.localizedDescription)")
            return nil
        }
    }

    private static func vecteur(_ observation: VNFeaturePrintObservation) -> [Float] {
        let data = observation.data
        switch observation.elementType {
        case .float:
            return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        case .double:
            return data.withUnsafeBytes { $0.bindMemory(to: Double.self).map { Float($0) } }
        default:
            return []
        }
    }
}
#endif
