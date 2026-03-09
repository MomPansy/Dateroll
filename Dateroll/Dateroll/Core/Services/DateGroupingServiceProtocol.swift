import Foundation

protocol DateGroupingServiceProtocol: Sendable {
    func groupIntoDateEntries(
        assets: [PhotoAsset],
        gapThreshold: TimeInterval,
        minimumPhotos: Int
    ) -> [DateEntry]
}
