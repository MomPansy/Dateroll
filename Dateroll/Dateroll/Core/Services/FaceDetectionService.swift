@preconcurrency import CoreML
import Photos
import UIKit
import Vision

actor FaceDetectionService: FaceDetectionServiceProtocol {
    nonisolated let faceStore: any FaceStoreProtocol
    nonisolated(unsafe) let model: MLModel

    init(faceStore: any FaceStoreProtocol) throws {
        self.faceStore = faceStore

        guard let modelURL = Bundle.main.url(forResource: "MobileFaceNet", withExtension: "mlmodelc") else {
            throw DaterollError.faceModelLoadFailed
        }

        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine
        self.model = try MLModel(contentsOf: modelURL, configuration: config)
    }

    // MARK: - FaceDetectionServiceProtocol

    func detectFaces(in assetID: String) async throws -> [DetectedFace] {
        guard let image = await fetchImage(assetID: assetID) else { return [] }
        guard let cgImage = image.cgImage else { return [] }

        let observations = try detectFaceRectangles(in: cgImage)
        var faces: [DetectedFace] = []

        for observation in observations {
            let imageWidth = CGFloat(cgImage.width)
            let imageHeight = CGFloat(cgImage.height)

            let faceRect = VNImageRectForNormalizedRect(
                observation.boundingBox,
                Int(imageWidth),
                Int(imageHeight)
            )

            let margin: CGFloat = 0.2
            let expandedRect = faceRect.insetBy(
                dx: -faceRect.width * margin,
                dy: -faceRect.height * margin
            )
            let clampedRect = expandedRect.intersection(
                CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)
            )

            guard !clampedRect.isEmpty,
                  let croppedFace = cgImage.cropping(to: clampedRect) else { continue }

            guard let pixelBuffer = resizeTo112x112(cgImage: croppedFace) else { continue }

            guard let embedding = try extractEmbedding(from: pixelBuffer) else { continue }

            let face = await DetectedFace(
                assetID: assetID,
                boundingBox: NormalizedRect(cgRect: observation.boundingBox),
                embedding: embedding
            )
            faces.append(face)
        }

        return faces
    }

    nonisolated func scanAssets(_ assets: [PhotoAsset]) -> AsyncStream<ScanProgress> {
        return AsyncStream { continuation in
            let task = Task {
                let alreadyScanned = await self.faceStore.scannedAssetIDs()
                let toScan = assets.filter { !alreadyScanned.contains($0.id) }

                if toScan.isEmpty {
                    continuation.yield(ScanProgress(scanned: 0, total: 0, facesFound: 0))
                    continuation.finish()
                    return
                }

                var totalFacesFound = 0
                let batchSize = 10

                for (index, asset) in toScan.enumerated() {
                    if Task.isCancelled { break }

                    do {
                        let faces = try await self.detectFaces(in: asset.id)
                        if !faces.isEmpty {
                            await self.faceStore.addFaces(faces)
                            totalFacesFound += faces.count
                        }
                        await self.faceStore.markScanned(assetIDs: [asset.id])
                    } catch {
                        // Continue on error — one failed asset shouldn't stop scan
                        await self.faceStore.markScanned(assetIDs: [asset.id])
                    }

                    continuation.yield(ScanProgress(
                        scanned: index + 1,
                        total: toScan.count,
                        facesFound: totalFacesFound
                    ))

                    // Yield between batches to avoid blocking
                    if (index + 1) % batchSize == 0 {
                        await Task.yield()
                    }
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Private Helpers

    private func fetchImage(assetID: String) async -> UIImage? {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard let asset = result.firstObject else { return nil }

        let targetSize = CGSize(width: 1024, height: 1024)
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset, targetSize: targetSize,
                contentMode: .aspectFit, options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    private func detectFaceRectangles(in cgImage: CGImage) throws -> [VNFaceObservation] {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        return request.results ?? []
    }

    private func resizeTo112x112(cgImage: CGImage) -> CVPixelBuffer? {
        let width = 112
        let height = 112

        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, width, height,
            kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }

    private func extractEmbedding(from pixelBuffer: CVPixelBuffer) throws -> FaceEmbedding? {
        let featureProvider = try MLDictionaryFeatureProvider(
            dictionary: ["img_inputs": MLFeatureValue(pixelBuffer: pixelBuffer)]
        )
        let prediction = try model.prediction(from: featureProvider)

        guard let outputKey = model.modelDescription.outputDescriptionsByName.keys.first,
              let multiArray = prediction.featureValue(for: outputKey)?.multiArrayValue else {
            return nil
        }

        let count = multiArray.count
        var values = [Float](repeating: 0, count: count)
        let pointer = multiArray.dataPointer.bindMemory(to: Float.self, capacity: count)
        for i in 0..<count {
            values[i] = pointer[i]
        }

        return FaceEmbedding(values: values)
    }
}
