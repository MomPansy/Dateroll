import Foundation

struct ScanProgress: Sendable {
    let scanned: Int
    let total: Int
    let facesFound: Int
}

protocol FaceDetectionServiceProtocol: Sendable {
    nonisolated func scanAssets(_ assets: [PhotoAsset]) -> AsyncStream<ScanProgress>
    func detectFaces(in assetID: String) async throws -> [DetectedFace]
}
