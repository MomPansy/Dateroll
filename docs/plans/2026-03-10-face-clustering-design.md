# Face Clustering Service — Design

## Overview

Add a `FaceClusteringService` actor that assigns detected faces to clusters incrementally (per-batch) and supports periodic full re-clustering via HAC to correct drift. Mirrors Apple Photos' proven two-pass architecture.

## Architecture

```
FaceDetectionService (detects faces per batch)
        ↓ [DetectedFace]
FaceClusteringService (assigns to clusters)
        ↓ [FaceCluster]
FaceStore (persists clusters + faces)
```

FaceClusteringService reads faces from FaceStore, performs clustering, and writes updated clusters back. FaceStore remains the single source of truth — the clustering service owns no state.

## Incremental Assignment (Per-Batch)

Called after each batch of 50 photos finishes face detection.

```swift
func assignToClusters(_ newFaces: [DetectedFace]) async
```

For each face:
1. Compute cosine similarity against every existing cluster's `representativeEmbedding`
2. If best match > **0.55** threshold → add to that cluster, update centroid via capped running average (cap N at 50)
3. If no match → create a new single-face cluster

**Capped running average:**
```swift
let effectiveN = min(cluster.faceIDs.count, 50)
newCentroid[i] = (Float(effectiveN) * oldCentroid[i] + newEmbedding[i]) / Float(effectiveN + 1)
```

This bounds drift — once a cluster has 50+ faces, new faces shift the centroid only slightly.

## Full Re-Cluster (Periodic HAC)

```swift
func reclusterAll() async
```

**When it runs:**
- After every 500 new faces processed (~10 batches)
- Or triggered manually (e.g. app backgrounded/idle)

**How it works:**
1. Pull all `DetectedFace` from FaceStore
2. Scope: only faces in clusters with < 5 members + unassigned faces (large confident clusters left alone)
3. Run agglomerative clustering with average linkage — start each face as its own cluster, repeatedly merge closest pair until no pair has similarity > **0.45** threshold
4. Replace clusters in FaceStore via `setClusters(_:)`

## Configuration

```swift
enum ClusteringConfig {
    static let assignmentThreshold: Float = 0.55
    static let reclusterThreshold: Float = 0.45
    static let centroidCap: Int = 50
    static let reclusterInterval: Int = 500  // faces between re-clusters
    static let smallClusterLimit: Int = 5
}
```

Thresholds based on MobileFaceNet 512-dim cosine similarity ranges. Must be validated empirically and may need tuning.

## Protocol

```swift
protocol FaceClusteringServiceProtocol: Sendable {
    func assignToClusters(_ faces: [DetectedFace]) async
    func reclusterAll() async
    func clusterCount() async -> Int
}
```

## Deliverables

| File | Description |
|------|-------------|
| `Core/Services/FaceClusteringService.swift` | Actor with `assignToClusters` + `reclusterAll` |
| `Core/Services/FaceClusteringServiceProtocol.swift` | Protocol for testability |
| `Core/Services/Mocks/MockFaceClusteringService.swift` | Mock for VM testing |
| `DaterollTests/FaceClusteringServiceTests.swift` | Unit tests |
| `DaterollApp.swift` | Wire up DI |
| `EnvironmentValues+Services.swift` | Add environment key |

## Test Cases

- Identical embeddings → same cluster
- Distant embeddings → separate clusters
- Threshold boundary (just above/below 0.55)
- Capped running average doesn't drift beyond bounds
- Re-cluster merges small similar clusters
- Re-cluster leaves large confident clusters untouched
- Empty input → no-op

## Research Context

This design mirrors Apple Photos' two-pass face clustering (per Apple ML Research blog):
- **Pass 1**: Conservative greedy nearest-centroid assignment (our incremental step)
- **Pass 2**: HAC merge with looser threshold (our periodic re-cluster)

Key insights applied:
- Conservative > aggressive — under-merging is fixable, over-merging corrupts centroids
- Capped running average bounds drift over time
- Quality gating on face detection confidence (future enhancement)
- Threshold ~0.55 for assignment, ~0.45 for HAC (empirical tuning needed)
