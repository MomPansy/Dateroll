import Foundation

struct DateEntry: Identifiable, Hashable, Sendable {
    let id: String           // e.g. "2025-02-14T22:00:00Z-cluster-0"
    let date: Date           // Start of cluster (first photo's creation date)
    let photos: [PhotoAsset]

    var heroPhoto: PhotoAsset? { photos.first }
    var photoCount: Int { photos.count }
}
