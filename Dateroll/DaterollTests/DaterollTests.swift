import Testing
import Foundation
@testable import Dateroll

@MainActor
@Suite("DateGroupingService")
struct DateGroupingServiceTests {
    private static let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func asset(offsetHours: Double, id: String = UUID().uuidString) -> PhotoAsset {
        PhotoAsset(id: id, creationDate: Self.base.addingTimeInterval(offsetHours * 3600), coordinate: nil)
    }

    @Test func singleCluster() {
        let service = DateGroupingService()
        let assets = [asset(offsetHours: 0), asset(offsetHours: 1), asset(offsetHours: 2)]
        let entries = service.groupIntoDateEntries(assets: assets)
        #expect(entries.count == 1)
        #expect(entries[0].photoCount == 3)
    }

    @Test func twoClusters() {
        let service = DateGroupingService()
        // 3 photos in cluster 1, then 10h gap, then 2 photos in cluster 2
        let assets = [
            asset(offsetHours: 0),
            asset(offsetHours: 1),
            asset(offsetHours: 2),
            asset(offsetHours: 12),
            asset(offsetHours: 13)
        ]
        let entries = service.groupIntoDateEntries(assets: assets)
        #expect(entries.count == 2)
        // newest first
        #expect(entries[0].date > entries[1].date)
    }

    @Test func filterSinglePhotoCluster() {
        let service = DateGroupingService()
        // lone photo separated by 10h gap from another lone photo; both filtered (< minimumPhotos)
        let assets = [
            asset(offsetHours: 0),
            asset(offsetHours: 10)
        ]
        let entries = service.groupIntoDateEntries(assets: assets)
        #expect(entries.isEmpty)
    }

    @Test func emptyInput() {
        let service = DateGroupingService()
        let entries = service.groupIntoDateEntries(assets: [])
        #expect(entries.isEmpty)
    }

    @Test func spansMiddnight() {
        let service = DateGroupingService()
        // Photos across midnight but within 8h gap: should be one cluster
        let midnight = Calendar.current.startOfDay(for: Self.base)
        let p1 = PhotoAsset(id: "1", creationDate: midnight.addingTimeInterval(-2 * 3600), coordinate: nil) // 10 PM
        let p2 = PhotoAsset(id: "2", creationDate: midnight.addingTimeInterval(2 * 3600), coordinate: nil)  // 2 AM
        let entries = service.groupIntoDateEntries(assets: [p1, p2])
        #expect(entries.count == 1)
        #expect(entries[0].photoCount == 2)
    }

    @Test func customGapThreshold() {
        let service = DateGroupingService()
        // 3h gap: over 2h custom threshold, under 8h default
        let assets = [
            asset(offsetHours: 0),
            asset(offsetHours: 1),
            asset(offsetHours: 4),  // 3h gap from previous
            asset(offsetHours: 5)
        ]
        // With 2h threshold: splits into two clusters
        let splitEntries = service.groupIntoDateEntries(assets: assets, gapThreshold: 2 * 3600)
        #expect(splitEntries.count == 2)
        // With default 8h threshold: stays as one cluster
        let mergedEntries = service.groupIntoDateEntries(assets: assets)
        #expect(mergedEntries.count == 1)
    }

    @Test func newestFirst() {
        let service = DateGroupingService()
        let assets = [
            asset(offsetHours: 0),
            asset(offsetHours: 1),
            asset(offsetHours: 10),  // 9h gap → new cluster
            asset(offsetHours: 11)
        ]
        let entries = service.groupIntoDateEntries(assets: assets)
        #expect(entries.count == 2)
        #expect(entries[0].date > entries[1].date)
    }
}
