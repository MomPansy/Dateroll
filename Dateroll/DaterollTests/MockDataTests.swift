import Testing
import Foundation
import Photos
@testable import Dateroll

@MainActor
@Suite("Mock Data System")
struct MockDataTests {

    @Test func allDatasetsNonEmpty() {
        for dataset in SampleDataset.allCases {
            #expect(!dataset.assets.isEmpty, "Dataset \(dataset.rawValue) should not be empty")
        }
    }

    @Test func couplesTripsProducesFourYears() {
        let service = DateGroupingService()
        let entries = service.groupIntoDateEntries(assets: SampleDataset.couplesTrips.assets)
        let years = Set(entries.map { Calendar.current.component(.year, from: $0.date) })
        #expect(years.count == 4, "Couple's Trips should span 4 years")
    }

    @Test func dailyLifeProducesThreeYears() {
        let service = DateGroupingService()
        let entries = service.groupIntoDateEntries(assets: SampleDataset.dailyLife.assets)
        let years = Set(entries.map { Calendar.current.component(.year, from: $0.date) })
        #expect(years.count == 3, "Daily Life should span 3 years")
    }

    @Test func longDistanceProducesFiveYears() {
        let service = DateGroupingService()
        let entries = service.groupIntoDateEntries(assets: SampleDataset.longDistance.assets)
        let years = Set(entries.map { Calendar.current.component(.year, from: $0.date) })
        #expect(years.count == 5, "Long Distance should span 5 years")
    }

    @Test func newCoupleProducesOneYear() {
        let service = DateGroupingService()
        let entries = service.groupIntoDateEntries(assets: SampleDataset.newCouple.assets)
        let years = Set(entries.map { Calendar.current.component(.year, from: $0.date) })
        #expect(years.count == 1, "New Couple should span 1 year")
    }

    @Test func mockPhotoLibraryServiceReturnsAuthorized() async {
        let service = MockPhotoLibraryService(assets: [])
        let status = await service.authorizationStatus()
        #expect(status == .authorized)
    }

    @Test func mockImageLoaderReturnsImage() async {
        let loader = MockImageLoader()
        let image = await loader.thumbnail(for: "test-id", targetSize: CGSize(width: 100, height: 100))
        #expect(image != nil)
    }

    @Test func representativeCoordinateFromYearEntry() {
        let coordinated = PhotoAsset(
            id: "p1",
            creationDate: Date(),
            coordinate: LocationCoordinate(latitude: 35.0, longitude: 139.0)
        )
        let entry = DateEntry(id: "d1", date: Date(), photos: [coordinated])
        let yearEntry = YearEntry(year: 2025, entries: [entry])
        #expect(yearEntry.representativeCoordinate != nil)
        #expect(yearEntry.representativeCoordinate?.latitude == 35.0)
    }

    @Test func representativeCoordinateNilWhenNoLocations() {
        let noCoord = PhotoAsset(id: "p1", creationDate: Date(), coordinate: nil)
        let entry = DateEntry(id: "d1", date: Date(), photos: [noCoord])
        let yearEntry = YearEntry(year: 2025, entries: [entry])
        #expect(yearEntry.representativeCoordinate == nil)
    }
}
