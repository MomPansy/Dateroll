import Photos

protocol PhotoLibraryServiceProtocol: Sendable {
    func authorizationStatus() async -> PHAuthorizationStatus
    func requestAuthorization() async -> PHAuthorizationStatus
    func fetchAllPhotoAssets() async throws -> [PhotoAsset]
}
