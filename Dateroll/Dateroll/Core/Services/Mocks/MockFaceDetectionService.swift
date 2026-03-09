import Foundation

actor MockFaceDetectionService: FaceDetectionServiceProtocol {
    var stubbedFaces: [String: [DetectedFace]] = [:]

    init(stubbedFaces: [String: [DetectedFace]] = [:]) {
        self.stubbedFaces = stubbedFaces
    }

    func detectFaces(in assetID: String) async throws -> [DetectedFace] {
        stubbedFaces[assetID] ?? []
    }

    nonisolated func scanAssets(_ assets: [PhotoAsset]) -> AsyncStream<ScanProgress> {
        return AsyncStream { continuation in
            Task {
                var totalFaces = 0
                for (index, asset) in assets.enumerated() {
                    let faces = await self.stubbedFaces[asset.id] ?? []
                    totalFaces += faces.count
                    continuation.yield(ScanProgress(
                        scanned: index + 1,
                        total: assets.count,
                        facesFound: totalFaces
                    ))
                }
                continuation.finish()
            }
        }
    }
}
