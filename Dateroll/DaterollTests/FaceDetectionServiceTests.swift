import CoreGraphics
import Testing
import Foundation
@testable import Dateroll

@MainActor
@Suite("FaceDetectionService - scanAssets")
struct FaceDetectionScanTests {

    @Test func scanAssetsSkipsAlreadyScannedAssets() async {
        let service = MockFaceDetectionService()

        let assets = [
            PhotoAsset(id: "asset-1", creationDate: Date(), coordinate: nil),
            PhotoAsset(id: "asset-2", creationDate: Date(), coordinate: nil),
            PhotoAsset(id: "asset-3", creationDate: Date(), coordinate: nil),
        ]

        var progressValues: [ScanProgress] = []
        for await progress in service.scanAssets(assets) {
            progressValues.append(progress)
        }

        // MockFaceDetectionService processes all assets (no store filtering)
        #expect(progressValues.last?.scanned == 3)
        #expect(progressValues.last?.total == 3)
    }

    @Test func scanAssetsYieldsCorrectProgress() async {
        let face1 = DetectedFace(
            assetID: "a1",
            boundingBox: NormalizedRect(cgRect: CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.3)),
            embedding: FaceEmbedding(values: Array(repeating: Float(0.1), count: 512))
        )
        let face2 = DetectedFace(
            assetID: "a2",
            boundingBox: NormalizedRect(cgRect: CGRect(x: 0.2, y: 0.2, width: 0.3, height: 0.3)),
            embedding: FaceEmbedding(values: Array(repeating: Float(0.2), count: 512))
        )

        let service = MockFaceDetectionService(stubbedFaces: [
            "a1": [face1],
            "a2": [face2],
        ])

        let assets = [
            PhotoAsset(id: "a1", creationDate: Date(), coordinate: nil),
            PhotoAsset(id: "a2", creationDate: Date(), coordinate: nil),
            PhotoAsset(id: "a3", creationDate: Date(), coordinate: nil),
        ]

        var progressValues: [ScanProgress] = []
        for await progress in service.scanAssets(assets) {
            progressValues.append(progress)
        }

        #expect(progressValues.count == 3)
        #expect(progressValues[0].scanned == 1)
        #expect(progressValues[0].facesFound == 1)
        #expect(progressValues[1].scanned == 2)
        #expect(progressValues[1].facesFound == 2)
        #expect(progressValues[2].scanned == 3)
        #expect(progressValues[2].facesFound == 2) // a3 has no faces
    }

    @Test func scanAssetsHandlesEmptyInput() async {
        let service = MockFaceDetectionService()
        var progressValues: [ScanProgress] = []

        for await progress in service.scanAssets([]) {
            progressValues.append(progress)
        }

        #expect(progressValues.isEmpty)
    }
}

@MainActor
@Suite("MockFaceDetectionService")
struct MockFaceDetectionServiceTests {

    @Test func detectFacesReturnsStubbedFaces() async throws {
        let face = DetectedFace(
            assetID: "asset-1",
            boundingBox: NormalizedRect(cgRect: CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.3)),
            embedding: FaceEmbedding(values: Array(repeating: Float(0.5), count: 512))
        )

        let service = MockFaceDetectionService(stubbedFaces: ["asset-1": [face]])
        let result = try await service.detectFaces(in: "asset-1")

        #expect(result.count == 1)
        #expect(result[0].assetID == "asset-1")
    }

    @Test func detectFacesReturnsEmptyForUnknownAsset() async throws {
        let service = MockFaceDetectionService()
        let result = try await service.detectFaces(in: "unknown-id")

        #expect(result.isEmpty)
    }

    @Test func scanAssetsCompletesWithCorrectFinalProgress() async {
        let face = DetectedFace(
            assetID: "a1",
            boundingBox: NormalizedRect(cgRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)),
            embedding: FaceEmbedding(values: Array(repeating: Float(1.0), count: 512))
        )
        let service = MockFaceDetectionService(stubbedFaces: ["a1": [face]])

        let assets = [
            PhotoAsset(id: "a1", creationDate: Date(), coordinate: nil),
            PhotoAsset(id: "a2", creationDate: Date(), coordinate: nil),
        ]

        var lastProgress: ScanProgress?
        for await progress in service.scanAssets(assets) {
            lastProgress = progress
        }

        #expect(lastProgress?.scanned == 2)
        #expect(lastProgress?.total == 2)
        #expect(lastProgress?.facesFound == 1)
    }
}
