# Face-Based Photo Filtering — Implementation Plan

## Overview

Replace the "shared library" approach with on-device face detection and clustering. Users select which faces to filter the timeline by, powered by Apple Vision framework + MobileFaceNet CoreML model.

## Completed

- [x] **Model Conversion:** Python script to download MobileFaceNet ONNX model and convert to CoreML (`scripts/convert_mobilefacenet.py`)
- [x] **Model Tests:** Python tests verifying ONNX embeddings and CoreML output (`scripts/test_mobilefacenet.py`)
- [x] **ML Directory:** `Dateroll/Dateroll/Core/ML/MobileFaceNet.mlpackage` (generated, gitignored)

---

## Phase A: iOS Foundation (Models, Storage, Detection)

### Step 1: Face Models

**New file:** `Dateroll/Dateroll/Core/Models/FaceModels.swift`

- `FaceEmbedding` — wrapper around `[Float]` (512-dim vector) with cosine similarity method
- `DetectedFace` — face detected in a photo: asset ID, bounding box, embedding, timestamp
- `FaceCluster` — group of faces belonging to same person: cluster ID, representative embedding, list of `DetectedFace` IDs, user-assigned label (optional)
- All `Codable`, `Identifiable`, `Hashable`

### Step 2: FaceStore Actor

**New file:** `Dateroll/Dateroll/Core/Services/FaceStore.swift`

- `actor FaceStore` — single source of truth for face data
- JSON persistence to app documents directory
- Stores: detected faces, clusters, set of already-scanned asset IDs
- Methods: `addFace(_:)`, `addCluster(_:)`, `markScanned(assetID:)`, `isScanned(assetID:) -> Bool`
- Loads on init, saves on mutation (debounced)

### Step 3: FaceDetectionService

**New file:** `Dateroll/Dateroll/Core/Services/FaceDetectionService.swift`

- `actor FaceDetectionService`
- Dependencies: `FaceStore`, CoreML model (`MobileFaceNet.mlpackage`)
- **Face detection:** Use `VNDetectFaceRectanglesRequest` (Apple Vision) to find face bounding boxes
- **Embedding extraction:** Crop face region, resize to 112x112, run through CoreML model to get 512-dim embedding
- **Batch scanning:** `scanAssets(_ assets: [PhotoAsset])` — skip already-scanned, detect faces, extract embeddings, store results
- **Progress reporting:** expose `@Published` scan progress for UI

### Step 4: Clustering Logic

**Add to:** `FaceDetectionService` or separate `FaceClusteringService`

- Agglomerative clustering using cosine similarity
- Threshold: ~0.5 cosine similarity (tune empirically)
- `clusterFaces()` — reads all detected faces from FaceStore, groups by similarity, writes clusters back
- Merge cluster support for manual corrections

### Step 5: Error Handling

**Edit:** `Dateroll/Dateroll/Core/Models/DaterollError.swift`

- Add cases: `faceScanFailed(underlying: Error)`, `faceModelLoadFailed`
- Integrate with existing error handling patterns

### Step 6: DI Wiring

**Edit:** `Dateroll/Dateroll/DaterollApp.swift`

- Create `FaceStore` and `FaceDetectionService` instances
- Inject via `.environment(...)` keys
- Add `EnvironmentKey` conformances

### Step 7: Unit Tests

**New files in** `Dateroll/DaterollTests/`

- `FaceEmbeddingTests.swift` — cosine similarity math, edge cases (zero vector, identical vectors)
- `FaceStoreTests.swift` — add/retrieve faces, persistence round-trip, scanned tracking
- `FaceClusteringTests.swift` — clustering with known embeddings, threshold behavior

---

## Phase B: Face Filter Service

- `FaceFilterService` — given selected cluster IDs, filter `[PhotoAsset]` to only those containing faces from selected clusters
- Integrate with `TimelineViewModel` to apply face filter alongside date grouping
- Persist selected clusters across sessions

## Phase C: Face Selection UI

- `FaceSelectionView` — grid of detected face clusters with representative thumbnails
- Scan progress indicator (progress bar, count)
- Toggle faces on/off to filter timeline
- Accessible from toolbar or onboarding flow

## Phase D: Integration

- Replace shared library onboarding instructions with face selection flow
- Add face filter toggle to timeline toolbar
- First-launch flow: request photo access → scan → select faces → view timeline

## Phase E: Polish

- Resume interrupted scans
- Delta scanning (only scan new/modified assets)
- Background processing with `BGTaskScheduler`
- Error recovery and retry logic
- Performance optimization for large libraries (10k+ photos)
