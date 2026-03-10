import CoreGraphics
import Testing
import Foundation
@testable import Dateroll

@MainActor
@Suite("FaceClusteringService - assignToClusters")
struct FaceClusteringAssignTests {

    private func makeEmbedding(_ value: Float) -> FaceEmbedding {
        FaceEmbedding(values: Array(repeating: value, count: FaceEmbedding.dimensions))
    }

    private func makeFace(assetID: String, embeddingValue: Float) -> DetectedFace {
        DetectedFace(
            assetID: assetID,
            boundingBox: NormalizedRect(cgRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)),
            embedding: makeEmbedding(embeddingValue)
        )
    }

    @Test func identicalEmbeddingsClusterTogether() async {
        let store = MockFaceStore()
        let service = FaceClusteringService(faceStore: store)

        let face1 = makeFace(assetID: "a1", embeddingValue: 1.0)
        let face2 = makeFace(assetID: "a2", embeddingValue: 1.0)

        await store.addFaces([face1])
        await service.assignToClusters([face1])

        await store.addFaces([face2])
        await service.assignToClusters([face2])

        let clusters = await store.allClusters()
        #expect(clusters.count == 1)
        #expect(clusters[0].faceIDs.count == 2)
    }
}
