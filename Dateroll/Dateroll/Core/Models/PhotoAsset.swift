import Foundation

// CLLocation is not Sendable in Swift 6 — store coordinate values instead
struct LocationCoordinate: Hashable, Sendable {
    let latitude: Double
    let longitude: Double
}

struct PhotoAsset: Identifiable, Hashable, Sendable {
    let id: String           // PHAsset.localIdentifier
    let creationDate: Date
    let coordinate: LocationCoordinate?
}
