// Images du fil (vignettes et plein écran, mises en cache) et tâches de fond (SDK, sinon parité du transcript).
#if canImport(SwiftUI)
import Foundation
import ImageIO
import UIKit
import VigieNoyau

/// Cache des images du fil : une vignette réduite (décodée à la taille d'affichage) et l'original pour le plein écran.
@MainActor enum CacheImages {
    static let vignettes = cache(80)
    static let originaux = cache(6)

    private static func cache(_ limite: Int) -> NSCache<NSString, UIImage> {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = limite
        return c
    }
}

extension ModeleRelais {
    /// Vignette d'une image du fil, réduite à `cote` pixels au plus, décodée hors du fil principal.
    public func vignette(_ fichier: String, de session: String, cote: Int = 720) async -> UIImage? {
        let cle = "\(session)/\(fichier)" as NSString
        if let i = CacheImages.vignettes.object(forKey: cle) { return i }
        guard let donnees = await octets(fichier, de: session) else { return nil }
        let image = await Task.detached(priority: .userInitiated) { Self.reduire(donnees, cote: cote) }.value
        if let image { CacheImages.vignettes.setObject(image, forKey: cle) }
        return image
    }

    public func original(_ fichier: String, de session: String) async -> UIImage? {
        let cle = "\(session)/\(fichier)" as NSString
        if let i = CacheImages.originaux.object(forKey: cle) { return i }
        guard let donnees = await octets(fichier, de: session) else { return nil }
        let image = await Task.detached(priority: .userInitiated) { Self.reduire(donnees, cote: 2400) }.value
        if let image { CacheImages.originaux.setObject(image, forKey: cle) }
        return image
    }

    private func octets(_ fichier: String, de session: String) async -> Data? {
        guard let client else { return nil }
        do {
            return try await client.telecharger(Route.fichierSession(sourceLecture(session), fichier))
        } catch {
            Trace.erreur("relais", "image \(fichier) non lue", error)
            return nil
        }
    }

    nonisolated static func reduire(_ donnees: Data, cote: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(donnees as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: cote,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }

    /// Tâches de fond comme Lanterne : celles du SDK si le nœud en donne, sinon celles lues dans le transcript.
    public func tachesFond(de session: String) async -> Result<[TacheFond], ErreurRelais> {
        let id = sourceLecture(session)
        let sdk: [TacheSession]
        switch await taches(de: id) {
        case .success(let t): sdk = t
        case .failure(let e):
            if case .nonConnecte = e { return .failure(e) }
            sdk = []
        }
        guard sdk.isEmpty else { return .success(TachesFond.fusion(sdk: sdk, parite: nil)) }
        let parite: Result<PariteSession, ErreurRelais> = await lire(Route.parite(id))
        switch parite {
        case .success(let p): return .success(TachesFond.fusion(sdk: [], parite: p))
        case .failure(let e): return .failure(e)
        }
    }

    public func detailTacheParite(_ tache: String,
                                  de session: String) async -> Result<DetailTacheParite, ErreurRelais> {
        await lire(Route.tacheParite(sourceLecture(session), tache))
    }
}
#endif
