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

    @Test func distantEmbeddingsCreateSeparateClusters() async {
        let store = MockFaceStore()
        let service = FaceClusteringService(faceStore: store)

        let face1 = makeFace(assetID: "a1", embeddingValue: 1.0)
        let face2 = makeFace(assetID: "a2", embeddingValue: -1.0)

        await store.addFaces([face1])
        await service.assignToClusters([face1])

        await store.addFaces([face2])
        await service.assignToClusters([face2])

        let clusters = await store.allClusters()
        #expect(clusters.count == 2)
    }

    @Test func emptyInputIsNoOp() async {
        let store = MockFaceStore()
        let service = FaceClusteringService(faceStore: store)

        await service.assignToClusters([])

        let clusters = await store.allClusters()
        #expect(clusters.count == 0)
    }

    @Test func thresholdBoundaryBelowCreatesSeparate() async {
        let store = MockFaceStore()
        let service = FaceClusteringService(faceStore: store)

        let values1 = Array(repeating: Float(1.0), count: FaceEmbedding.dimensions)
        var values2 = Array(repeating: Float(1.0), count: FaceEmbedding.dimensions)

        // Flip enough dimensions to push similarity below 0.55 threshold
        // cos = (512 - 2*flipped) / 512; for flipped=118 → ~0.539
        for i in 0..<118 {
            values2[i] = -1.0
        }

        let face1 = DetectedFace(
            assetID: "a1",
            boundingBox: NormalizedRect(cgRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)),
            embedding: FaceEmbedding(values: values1)
        )
        let face2 = DetectedFace(
            assetID: "a2",
            boundingBox: NormalizedRect(cgRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)),
            embedding: FaceEmbedding(values: values2)
        )

        await store.addFaces([face1])
        await service.assignToClusters([face1])

        await store.addFaces([face2])
        await service.assignToClusters([face2])

        let clusters = await store.allClusters()
        #expect(clusters.count == 2)
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
