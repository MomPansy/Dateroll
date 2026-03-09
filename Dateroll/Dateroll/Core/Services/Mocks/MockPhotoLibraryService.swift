import Photos

actor MockPhotoLibraryService: PhotoLibraryServiceProtocol {
    private let assets: [PhotoAsset]

    init(assets: [PhotoAsset]) {
        self.assets = assets
    }

    func authorizationStatus() async -> PHAuthorizationStatus {
        .authorized
    }

    func requestAuthorization() async -> PHAuthorizationStatus {
        .authorized
    }

    func fetchAllPhotoAssets() async throws -> [PhotoAsset] {
        assets
    }
}
