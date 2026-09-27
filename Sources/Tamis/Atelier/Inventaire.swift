// La lecture de la photothèque : autorisation, fiches, poids. Tout ici est
// `nonisolated` et ne rend que des valeurs `Sendable` — `PHAsset` ne franchit
// jamais une frontière d'acteur, on le refait à partir de son identifiant.
#if canImport(Photos)
import Photos
import TamisNoyau

enum Inventaire {
    enum Acces: Sendable { case complet, limite, refuse }

    static func autoriser() async -> Acces {
        switch await PHPhotoLibrary.requestAuthorization(for: .readWrite) {
        case .authorized: return .complet
        case .limited: return .limite
        default: return .refuse
        }
    }

    /// Toutes les photos et vidéos visibles, y compris chaque image des rafales
    /// (Photos n'en montre qu'une, mais les autres pèsent aussi dans iCloud).
    static func lister() -> [Cliche] {
        let options = PHFetchOptions()
        options.includeAllBurstAssets = true
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let resultat = PHAsset.fetchAssets(with: options)
        var fiches: [Cliche] = []
        fiches.reserveCapacity(resultat.count)
        for rang in 0..<resultat.count {
            fiches.append(fiche(resultat.object(at: rang)))
        }
        Journal.note("inventaire : \(fiches.count) éléments")
        return fiches
    }

    private static func fiche(_ asset: PHAsset) -> Cliche {
        var traits = Set<Trait>()
        let sous = asset.mediaSubtypes
        if sous.contains(.photoScreenshot) { traits.insert(.capture) }
        if sous.contains(.photoLive) { traits.insert(.live) }
        if sous.contains(.photoPanorama) { traits.insert(.panorama) }
        if asset.isFavorite { traits.insert(.favori) }
        if asset.burstIdentifier != nil { traits.insert(.rafale) }
        if asset.representsBurst || asset.burstSelectionTypes.contains(.userPick) { traits.insert(.choixRafale) }
        return Cliche(
            id: asset.localIdentifier, date: asset.creationDate,
            media: asset.mediaType == .video ? .video : .photo, traits: traits,
            largeur: asset.pixelWidth, hauteur: asset.pixelHeight, duree: asset.duration,
            rafale: asset.burstIdentifier
        )
    }

    /// Le poids de chaque élément : la somme de toutes ses ressources — original,
    /// version retouchée, vidéo d'une Live Photo. C'est ce qu'iCloud stocke.
    ///
    /// `☠` `fileSize` n'est pas une propriété publique de `PHAssetResource` : lue
    /// par KVC, elle existe depuis iOS 10 et toutes les apps de nettoyage s'en
    /// servent. Si elle disparaît, le poids reste inconnu — jamais zéro.
    static func peser(_ ids: [String]) -> [String: Int64] {
        let resultat = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var poids: [String: Int64] = [:]
        for rang in 0..<resultat.count {
            let asset = resultat.object(at: rang)
            let tailles = PHAssetResource.assetResources(for: asset).compactMap {
                ($0.value(forKey: "fileSize") as? NSNumber)?.int64Value
            }
            if !tailles.isEmpty { poids[asset.localIdentifier] = tailles.reduce(0, +) }
        }
        return poids
    }

    /// Envoie les éléments dans « Supprimés récemment ». iOS demande lui-même
    /// confirmation : aucune app ne peut supprimer une photo en silence.
    static func supprimer(_ ids: [String]) async throws {
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
            PHAssetChangeRequest.deleteAssets(assets)
        }
    }
}
#endif
