import CoreGraphics
import Foundation

// MARK: - FaceEmbedding

struct FaceEmbedding: Codable, Hashable, Sendable {
    let values: [Float]  // 512-dim vector from MobileFaceNet

    static let dimensions = 512

    func cosineSimilarity(to other: FaceEmbedding) -> Float {
        guard values.count == other.values.count, !values.isEmpty else { return 0 }

        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in values.indices {
            dot += values[i] * other.values[i]
            normA += values[i] * values[i]
            normB += other.values[i] * other.values[i]
        }

        let denominator = (normA * normB).squareRoot()
        guard denominator > 0 else { return 0 }
        return dot / denominator
    }
}

// MARK: - DetectedFace

struct DetectedFace: Identifiable, Codable, Hashable, Sendable {
    let id: String              // UUID string
    let assetID: String         // PHAsset.localIdentifier
    let boundingBox: NormalizedRect  // Face region in normalized image coordinates
    let embedding: FaceEmbedding
    let detectedAt: Date

    init(assetID: String, boundingBox: NormalizedRect, embedding: FaceEmbedding) {
        self.id = UUID().uuidString
        self.assetID = assetID
        self.boundingBox = boundingBox
        self.embedding = embedding
        self.detectedAt = Date()
    }
}

// MARK: - NormalizedRect

/// A rectangle in normalized coordinates (0...1), matching Vision framework's output.
struct NormalizedRect: Codable, Hashable, Sendable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    init(cgRect: CGRect) {
        self.x = cgRect.origin.x
        self.y = cgRect.origin.y
        self.width = cgRect.size.width
        self.height = cgRect.size.height
    }
}

// MARK: - FaceCluster

struct FaceCluster: Identifiable, Codable, Hashable, Sendable {
    let id: String              // UUID string
    var label: String?          // User-assigned name (e.g. "Sarah")
    var faceIDs: [String]       // IDs of DetectedFace instances in this cluster
    var representativeEmbedding: FaceEmbedding  // Average or centroid embedding

    init(faceIDs: [String], representativeEmbedding: FaceEmbedding, label: String? = nil) {
        self.id = UUID().uuidString
        self.faceIDs = faceIDs
        self.representativeEmbedding = representativeEmbedding
        self.label = label
    }
}
