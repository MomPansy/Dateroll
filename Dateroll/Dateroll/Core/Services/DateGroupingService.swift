import Foundation

actor DateGroupingService: DateGroupingServiceProtocol {

    nonisolated static let defaultGapThreshold: TimeInterval = 8 * 3600  // 8 hours
    nonisolated static let minimumPhotosPerCluster = 2

    nonisolated func groupIntoDateEntries(
        assets: [PhotoAsset],
        gapThreshold: TimeInterval = defaultGapThreshold,
        minimumPhotos: Int = minimumPhotosPerCluster
    ) -> [DateEntry] {
        guard !assets.isEmpty else { return [] }

        let sorted = assets.sorted { $0.creationDate < $1.creationDate }
        var clusters: [[PhotoAsset]] = []
        var current: [PhotoAsset] = [sorted[0]]

        for i in 1..<sorted.count {
            let gap = sorted[i].creationDate.timeIntervalSince(sorted[i - 1].creationDate)
            if gap > gapThreshold {
                clusters.append(current)
                current = [sorted[i]]
            } else {
                current.append(sorted[i])
            }
        }
        clusters.append(current)

        let formatter = ISO8601DateFormatter()
        return clusters
            .filter { $0.count >= minimumPhotos }
            .enumerated()
            .map { index, cluster in
                DateEntry(
                    id: "\(formatter.string(from: cluster[0].creationDate))-cluster-\(index)",
                    date: cluster[0].creationDate,
                    photos: cluster
                )
            }
            .sorted { $0.date > $1.date }
    }
}
