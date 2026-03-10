# Face Clustering Service — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `FaceClusteringService` actor that assigns detected faces to clusters incrementally and supports periodic HAC re-clustering to correct drift.

**Architecture:** New `actor FaceClusteringService` depends on `FaceStoreProtocol`. It reads faces/clusters from FaceStore, performs clustering logic (nearest-centroid for incremental, agglomerative HAC for re-cluster), and writes updated clusters back. FaceStore remains the single source of truth. Protocol + mock follow the existing pattern in the codebase.

**Tech Stack:** Swift 6, Swift Testing (`@Test`, `#expect`), actors for concurrency

**Design doc:** `docs/plans/2026-03-10-face-clustering-design.md`

---

### Task 1: Protocol + Config

**Files:**
- Create: `Dateroll/Dateroll/Core/Services/FaceClusteringServiceProtocol.swift`

**Step 1: Write the protocol and config enum**

```swift
import Foundation

enum ClusteringConfig {
    static let assignmentThreshold: Float = 0.55
    static let reclusterThreshold: Float = 0.45
    static let centroidCap: Int = 50
    static let reclusterInterval: Int = 500
    static let smallClusterLimit: Int = 5
}

protocol FaceClusteringServiceProtocol: Sendable {
    func assignToClusters(_ faces: [DetectedFace]) async
    func reclusterAll() async
    func clusterCount() async -> Int
}
```

**Step 2: Verify it compiles**

Build the project. Expected: SUCCESS (protocol has no dependencies beyond `DetectedFace` which exists in `FaceModels.swift`).

**Step 3: Commit**

```bash
git add Dateroll/Dateroll/Core/Services/FaceClusteringServiceProtocol.swift
git commit -m "feat: add FaceClusteringServiceProtocol and ClusteringConfig"
```

---

### Task 2: Test — identical embeddings cluster together

**Files:**
- Create: `Dateroll/DaterollTests/FaceClusteringServiceTests.swift`

**Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import Dateroll

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
```

**Step 2: Run test to verify it fails**

Build. Expected: FAIL — `FaceClusteringService` does not exist yet.

**Step 3: Commit**

```bash
git add Dateroll/DaterollTests/FaceClusteringServiceTests.swift
git commit -m "test: add failing test for identical embedding clustering"
```

---

### Task 3: Implement `FaceClusteringService.assignToClusters`

**Files:**
- Create: `Dateroll/Dateroll/Core/Services/FaceClusteringService.swift`

**Step 1: Write the implementation**

```swift
import Foundation

actor FaceClusteringService: FaceClusteringServiceProtocol {
    private let faceStore: any FaceStoreProtocol

    init(faceStore: any FaceStoreProtocol) {
        self.faceStore = faceStore
    }

    func assignToClusters(_ faces: [DetectedFace]) async {
        guard !faces.isEmpty else { return }

        var clusters = await faceStore.allClusters()

        for face in faces {
            let bestMatch = findBestCluster(for: face, in: clusters)

            if let (index, similarity) = bestMatch,
               similarity > ClusteringConfig.assignmentThreshold {
                clusters[index].faceIDs.append(face.id)
                clusters[index].representativeEmbedding = updatedCentroid(
                    current: clusters[index].representativeEmbedding,
                    newEmbedding: face.embedding,
                    clusterSize: clusters[index].faceIDs.count - 1
                )
            } else {
                let newCluster = FaceCluster(
                    faceIDs: [face.id],
                    representativeEmbedding: face.embedding
                )
                clusters.append(newCluster)
            }
        }

        await faceStore.setClusters(clusters)
    }

    func reclusterAll() async {
        // Implemented in Task 6
    }

    func clusterCount() async -> Int {
        let clusters = await faceStore.allClusters()
        return clusters.count
    }

    // MARK: - Private

    private func findBestCluster(
        for face: DetectedFace,
        in clusters: [FaceCluster]
    ) -> (index: Int, similarity: Float)? {
        var bestIndex: Int?
        var bestSimilarity: Float = -1

        for (index, cluster) in clusters.enumerated() {
            let similarity = face.embedding.cosineSimilarity(to: cluster.representativeEmbedding)
            if similarity > bestSimilarity {
                bestSimilarity = similarity
                bestIndex = index
            }
        }

        guard let index = bestIndex else { return nil }
        return (index, bestSimilarity)
    }

    private func updatedCentroid(
        current: FaceEmbedding,
        newEmbedding: FaceEmbedding,
        clusterSize: Int
    ) -> FaceEmbedding {
        let effectiveN = min(clusterSize, ClusteringConfig.centroidCap)
        let n = Float(effectiveN)
        var updated = [Float](repeating: 0, count: FaceEmbedding.dimensions)

        for i in 0..<FaceEmbedding.dimensions {
            updated[i] = (n * current.values[i] + newEmbedding.values[i]) / (n + 1)
        }

        return FaceEmbedding(values: updated)
    }
}
```

**Step 2: Run test to verify it passes**

Run tests. Expected: `identicalEmbeddingsClusterTogether` PASSES.

**Step 3: Commit**

```bash
git add Dateroll/Dateroll/Core/Services/FaceClusteringService.swift
git commit -m "feat: implement FaceClusteringService.assignToClusters with nearest-centroid"
```

---

### Task 4: Tests — distant embeddings, threshold boundary, empty input

**Files:**
- Modify: `Dateroll/DaterollTests/FaceClusteringServiceTests.swift`

**Step 1: Add three more tests to the existing suite**

```swift
    @Test func distantEmbeddingsCreateSeparateClusters() async {
        let store = MockFaceStore()
        let service = FaceClusteringService(faceStore: store)

        // Embedding [1,1,...] and [-1,-1,...] have cosine similarity -1.0
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

        // Create two embeddings with cosine similarity just below 0.55
        // Use orthogonal-ish vectors: one mostly 1s, one with some different values
        var values1 = Array(repeating: Float(1.0), count: FaceEmbedding.dimensions)
        var values2 = Array(repeating: Float(1.0), count: FaceEmbedding.dimensions)

        // Flip enough dimensions to push similarity below threshold
        // For 512-dim unit-ish vectors, flipping ~115 dims gives ~0.55 similarity
        // cos = (512 - 2*flipped) / 512; for 0.54 → flipped ≈ 118
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

        // Similarity = (512 - 236) / 512 = 276/512 ≈ 0.539 < 0.55
        let clusters = await store.allClusters()
        #expect(clusters.count == 2)
    }
```

**Step 2: Run tests to verify they pass**

Run tests. Expected: all 4 tests PASS.

**Step 3: Commit**

```bash
git add Dateroll/DaterollTests/FaceClusteringServiceTests.swift
git commit -m "test: add distant embeddings, threshold boundary, and empty input tests"
```

---

### Task 5: Test — capped running average bounds drift

**Files:**
- Modify: `Dateroll/DaterollTests/FaceClusteringServiceTests.swift`

**Step 1: Add a new test suite for centroid drift**

```swift
@Suite("FaceClusteringService - centroid capping")
struct FaceClusteringCentroidTests {

    @Test func centroidDoesNotDriftBeyondCap() async {
        let store = MockFaceStore()
        let service = FaceClusteringService(faceStore: store)

        // Add 60 faces with embedding [1,1,...] to build a large cluster
        var faces: [DetectedFace] = []
        for i in 0..<60 {
            let face = DetectedFace(
                assetID: "a\(i)",
                boundingBox: NormalizedRect(cgRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)),
                embedding: FaceEmbedding(values: Array(repeating: Float(1.0), count: FaceEmbedding.dimensions))
            )
            faces.append(face)
        }
        await store.addFaces(faces)
        await service.assignToClusters(faces)

        // Now add a face with embedding [0.9, 0.9, ...] — similar enough to match
        let outlier = DetectedFace(
            assetID: "outlier",
            boundingBox: NormalizedRect(cgRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)),
            embedding: FaceEmbedding(values: Array(repeating: Float(0.9), count: FaceEmbedding.dimensions))
        )
        await store.addFaces([outlier])
        await service.assignToClusters([outlier])

        let clusters = await store.allClusters()
        #expect(clusters.count == 1)
        #expect(clusters[0].faceIDs.count == 61)

        // Centroid should barely move because cap is 50
        // New centroid = (50 * 1.0 + 0.9) / 51 ≈ 0.998
        let centroid = clusters[0].representativeEmbedding.values[0]
        #expect(centroid > 0.99)
    }
}
```

**Step 2: Run tests to verify it passes**

Run tests. Expected: PASS.

**Step 3: Commit**

```bash
git add Dateroll/DaterollTests/FaceClusteringServiceTests.swift
git commit -m "test: verify capped running average bounds centroid drift"
```

---

### Task 6: Implement `reclusterAll` (HAC)

**Files:**
- Modify: `Dateroll/Dateroll/Core/Services/FaceClusteringService.swift`

**Step 1: Write the failing test first**

Add to `FaceClusteringServiceTests.swift`:

```swift
@Suite("FaceClusteringService - reclusterAll")
struct FaceClusteringReclusterTests {

    private func makeEmbedding(_ value: Float) -> FaceEmbedding {
        FaceEmbedding(values: Array(repeating: value, count: FaceEmbedding.dimensions))
    }

    @Test func reclusterMergesSmallSimilarClusters() async {
        let store = MockFaceStore()
        let service = FaceClusteringService(faceStore: store)

        // Create two small clusters with identical embeddings (should merge)
        let face1 = DetectedFace(
            assetID: "a1",
            boundingBox: NormalizedRect(cgRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)),
            embedding: makeEmbedding(1.0)
        )
        let face2 = DetectedFace(
            assetID: "a2",
            boundingBox: NormalizedRect(cgRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)),
            embedding: makeEmbedding(1.0)
        )

        await store.addFaces([face1, face2])

        // Manually set up two separate small clusters
        let cluster1 = FaceCluster(faceIDs: [face1.id], representativeEmbedding: face1.embedding)
        let cluster2 = FaceCluster(faceIDs: [face2.id], representativeEmbedding: face2.embedding)
        await store.setClusters([cluster1, cluster2])

        await service.reclusterAll()

        let clusters = await store.allClusters()
        #expect(clusters.count == 1)
        #expect(clusters[0].faceIDs.count == 2)
    }

    @Test func reclusterLeavesLargeClustersAlone() async {
        let store = MockFaceStore()
        let service = FaceClusteringService(faceStore: store)

        // Build one large cluster (6 faces, above smallClusterLimit of 5)
        var largeFaces: [DetectedFace] = []
        var largeFaceIDs: [String] = []
        for i in 0..<6 {
            let face = DetectedFace(
                assetID: "large-\(i)",
                boundingBox: NormalizedRect(cgRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)),
                embedding: makeEmbedding(1.0)
            )
            largeFaces.append(face)
            largeFaceIDs.append(face.id)
        }

        // Build one small cluster with similar embedding
        let smallFace = DetectedFace(
            assetID: "small-0",
            boundingBox: NormalizedRect(cgRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)),
            embedding: makeEmbedding(1.0)
        )

        await store.addFaces(largeFaces + [smallFace])

        let largeCluster = FaceCluster(
            faceIDs: largeFaceIDs,
            representativeEmbedding: makeEmbedding(1.0)
        )
        let smallCluster = FaceCluster(
            faceIDs: [smallFace.id],
            representativeEmbedding: smallFace.embedding
        )
        await store.setClusters([largeCluster, smallCluster])

        await service.reclusterAll()

        let clusters = await store.allClusters()
        // Large cluster should be preserved as-is
        // Small cluster gets re-clustered but stays separate (only 1 face to cluster)
        let large = clusters.first { $0.faceIDs.count == 6 }
        #expect(large != nil)
        #expect(large?.id == largeCluster.id)
    }

    @Test func reclusterWithDistantEmbeddingsKeepsSeparate() async {
        let store = MockFaceStore()
        let service = FaceClusteringService(faceStore: store)

        let face1 = DetectedFace(
            assetID: "a1",
            boundingBox: NormalizedRect(cgRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)),
            embedding: makeEmbedding(1.0)
        )
        let face2 = DetectedFace(
            assetID: "a2",
            boundingBox: NormalizedRect(cgRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)),
            embedding: makeEmbedding(-1.0)
        )

        await store.addFaces([face1, face2])

        let cluster1 = FaceCluster(faceIDs: [face1.id], representativeEmbedding: face1.embedding)
        let cluster2 = FaceCluster(faceIDs: [face2.id], representativeEmbedding: face2.embedding)
        await store.setClusters([cluster1, cluster2])

        await service.reclusterAll()

        let clusters = await store.allClusters()
        #expect(clusters.count == 2)
    }
}
```

**Step 2: Run tests — `reclusterMergesSmallSimilarClusters` should FAIL**

Expected: FAIL because `reclusterAll()` is empty.

**Step 3: Implement `reclusterAll`**

Replace the stub `reclusterAll` in `FaceClusteringService.swift`:

```swift
    func reclusterAll() async {
        var clusters = await faceStore.allClusters()
        let allFaces = await faceStore.allFaces()

        guard !clusters.isEmpty else { return }

        // Separate large (confident) clusters from small ones
        let largeClusters = clusters.filter { $0.faceIDs.count >= ClusteringConfig.smallClusterLimit }
        let smallClusters = clusters.filter { $0.faceIDs.count < ClusteringConfig.smallClusterLimit }

        guard !smallClusters.isEmpty else { return }

        // Build face lookup
        let faceLookup = Dictionary(uniqueKeysWithValues: allFaces.map { ($0.id, $0) })

        // Collect all faces from small clusters for re-clustering
        let facesToRecluster: [DetectedFace] = smallClusters.flatMap { cluster in
            cluster.faceIDs.compactMap { faceLookup[$0] }
        }

        guard !facesToRecluster.isEmpty else { return }

        // HAC: start with each face as its own cluster
        var hacClusters: [(faceIDs: [String], embedding: FaceEmbedding)] = facesToRecluster.map {
            (faceIDs: [$0.id], embedding: $0.embedding)
        }

        // Repeatedly merge closest pair until no pair exceeds threshold
        while hacClusters.count > 1 {
            var bestI = 0
            var bestJ = 1
            var bestSimilarity: Float = -1

            for i in 0..<hacClusters.count {
                for j in (i + 1)..<hacClusters.count {
                    let similarity = hacClusters[i].embedding.cosineSimilarity(
                        to: hacClusters[j].embedding
                    )
                    if similarity > bestSimilarity {
                        bestSimilarity = similarity
                        bestI = i
                        bestJ = j
                    }
                }
            }

            guard bestSimilarity > ClusteringConfig.reclusterThreshold else { break }

            // Merge bestJ into bestI
            let mergedFaceIDs = hacClusters[bestI].faceIDs + hacClusters[bestJ].faceIDs
            let mergedEmbedding = averageEmbedding(
                hacClusters[bestI].embedding, count: hacClusters[bestI].faceIDs.count,
                hacClusters[bestJ].embedding, count: hacClusters[bestJ].faceIDs.count
            )
            hacClusters[bestI] = (faceIDs: mergedFaceIDs, embedding: mergedEmbedding)
            hacClusters.remove(at: bestJ)
        }

        // Convert HAC results back to FaceCluster structs
        let newSmallClusters = hacClusters.map { item in
            FaceCluster(
                faceIDs: item.faceIDs,
                representativeEmbedding: item.embedding
            )
        }

        await faceStore.setClusters(largeClusters + newSmallClusters)
    }

    private func averageEmbedding(
        _ a: FaceEmbedding, count countA: Int,
        _ b: FaceEmbedding, count countB: Int
    ) -> FaceEmbedding {
        let totalCount = Float(countA + countB)
        var values = [Float](repeating: 0, count: FaceEmbedding.dimensions)
        for i in 0..<FaceEmbedding.dimensions {
            values[i] = (Float(countA) * a.values[i] + Float(countB) * b.values[i]) / totalCount
        }
        return FaceEmbedding(values: values)
    }
```

**Step 4: Run tests to verify they all pass**

Run tests. Expected: all recluster tests PASS.

**Step 5: Commit**

```bash
git add Dateroll/Dateroll/Core/Services/FaceClusteringService.swift \
    Dateroll/DaterollTests/FaceClusteringServiceTests.swift
git commit -m "feat: implement reclusterAll with agglomerative HAC for small clusters"
```

---

### Task 7: Mock + Protocol wiring

**Files:**
- Create: `Dateroll/Dateroll/Core/Services/Mocks/MockFaceClusteringService.swift`

**Step 1: Write the mock**

```swift
import Foundation

actor MockFaceClusteringService: FaceClusteringServiceProtocol {
    private(set) var assignCallCount = 0
    private(set) var reclusterCallCount = 0
    private(set) var lastAssignedFaces: [DetectedFace] = []
    private var _clusterCount: Int = 0

    init(clusterCount: Int = 0) {
        self._clusterCount = clusterCount
    }

    func assignToClusters(_ faces: [DetectedFace]) async {
        assignCallCount += 1
        lastAssignedFaces = faces
    }

    func reclusterAll() async {
        reclusterCallCount += 1
    }

    func clusterCount() async -> Int {
        _clusterCount
    }
}
```

**Step 2: Verify it compiles**

Build. Expected: SUCCESS.

**Step 3: Commit**

```bash
git add Dateroll/Dateroll/Core/Services/Mocks/MockFaceClusteringService.swift
git commit -m "feat: add MockFaceClusteringService for testing"
```

---

### Task 8: DI wiring

**Files:**
- Modify: `Dateroll/Dateroll/Core/Extensions/EnvironmentValues+Services.swift`
- Modify: `Dateroll/Dateroll/DaterollApp.swift`

**Step 1: Add environment key**

In `EnvironmentValues+Services.swift`, add after the `FaceDetectionServiceKey`:

```swift
private struct FaceClusteringServiceKey: EnvironmentKey {
    static let defaultValue: any FaceClusteringServiceProtocol = MockFaceClusteringService()
}
```

And in the `EnvironmentValues` extension, add:

```swift
    var faceClusteringService: any FaceClusteringServiceProtocol {
        get { self[FaceClusteringServiceKey.self] }
        set { self[FaceClusteringServiceKey.self] = newValue }
    }
```

**Step 2: Wire up in DaterollApp**

In `DaterollApp.swift`, add the service property:

```swift
    private let faceClusteringService: FaceClusteringService
```

Update `init()`:

```swift
    init() {
        faceDetectionService = (try? FaceDetectionService(faceStore: faceStore)) ?? MockFaceDetectionService()
        faceClusteringService = FaceClusteringService(faceStore: faceStore)
    }
```

Add `.environment(\.faceClusteringService, faceClusteringService)` to both the `#if DEBUG` and `#else` branches of the body, after `.environment(\.faceDetectionService, faceDetectionService)`.

**Step 3: Verify it compiles**

Build. Expected: SUCCESS.

**Step 4: Commit**

```bash
git add Dateroll/Dateroll/Core/Extensions/EnvironmentValues+Services.swift \
    Dateroll/Dateroll/DaterollApp.swift
git commit -m "feat: wire FaceClusteringService into DI via Environment"
```

---

### Task 9: Final verification

**Step 1: Run all tests**

Run full test suite. Expected: ALL PASS — existing `DaterollTests`, `FaceDetectionServiceTests`, and new `FaceClusteringServiceTests`.

**Step 2: Build for simulator**

Build. Expected: SUCCESS with no warnings related to clustering code.

**Step 3: Review file list**

Verify these files exist:
- `Dateroll/Dateroll/Core/Services/FaceClusteringService.swift`
- `Dateroll/Dateroll/Core/Services/FaceClusteringServiceProtocol.swift`
- `Dateroll/Dateroll/Core/Services/Mocks/MockFaceClusteringService.swift`
- `Dateroll/DaterollTests/FaceClusteringServiceTests.swift`

Verify these files were modified:
- `Dateroll/Dateroll/Core/Extensions/EnvironmentValues+Services.swift`
- `Dateroll/Dateroll/DaterollApp.swift`
