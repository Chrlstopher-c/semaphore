// Le chargement d'images depuis la photothèque, pour les vignettes, la carte de
// tri et l'analyse.
//
// `☠` Le rappel de `requestImage` arrive sur une file de Photos : sa closure est
// marquée `@Sendable` pour ne pas hériter d'une isolation `@MainActor` — le
// piège qui fait tomber le processus au premier rappel, sans avertissement.
#if canImport(UIKit) && canImport(Photos)
import Photos
import TamisNoyau
import UIKit

enum Images {
    /// `cote` en pixels. `reseau` autorise le téléchargement depuis iCloud :
    /// jamais pour une vignette (elle existe toujours en local), oui pour la
    /// carte de tri.
    static func image(_ id: String, cote: CGFloat, reseau: Bool) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else {
            return nil
        }
        let options = PHImageRequestOptions()
        // Un seul rappel garanti : la continuation ne reprend qu'une fois.
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = reseau
        let taille = CGSize(width: cote, height: cote)
        return await withCheckedContinuation { suite in
            PHImageManager.default().requestImage(
                for: asset, targetSize: taille, contentMode: .aspectFit, options: options
            ) { @Sendable image, _ in
                suite.resume(returning: image)
            }
        }
    }
}

extension CGImagePropertyOrientation {
    /// L'orientation d'une `UIImage` traduite pour Vision, qui analyse les
    /// pixels bruts et ignore la métadonnée.
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
#endif
