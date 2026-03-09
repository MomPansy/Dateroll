import Photos

actor PhotoLibraryService: PhotoLibraryServiceProtocol {

    func authorizationStatus() async -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func fetchAllPhotoAssets() async throws -> [PhotoAsset] {
        let status = await authorizationStatus()
        guard status == .authorized || status == .limited else {
            throw status == .denied ? DaterollError.photoAccessDenied : DaterollError.photoAccessRestricted
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let result = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PhotoAsset] = []
        assets.reserveCapacity(result.count)

        result.enumerateObjects { asset, _, _ in
            guard let creationDate = asset.creationDate else { return }
            let coord = asset.location.map {
                LocationCoordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
            }
            assets.append(PhotoAsset(id: asset.localIdentifier, creationDate: creationDate, coordinate: coord))
        }

        return assets
    }
}
