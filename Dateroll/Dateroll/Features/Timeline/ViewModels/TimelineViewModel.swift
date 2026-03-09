import SwiftUI

enum TimelineState {
    case idle
    case loading
    case loaded([YearEntry])
    case empty
    case error(DaterollError)
}

@Observable
@MainActor
final class TimelineViewModel {
    var state: TimelineState = .idle
    var isRefreshing = false
    private let photoService: any PhotoLibraryServiceProtocol
    private let groupingService: any DateGroupingServiceProtocol

    init(photoService: any PhotoLibraryServiceProtocol, groupingService: any DateGroupingServiceProtocol) {
        self.photoService = photoService
        self.groupingService = groupingService
    }

    func load() async {
        guard case .idle = state else { return }
        state = .loading
        await fetchEntries()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        await fetchEntries()
        isRefreshing = false
    }

    private func fetchEntries() async {
        do {
            let assets = try await photoService.fetchAllPhotoAssets()
            let entries = groupingService.groupIntoDateEntries(
                assets: assets,
                gapThreshold: DateGroupingService.defaultGapThreshold,
                minimumPhotos: DateGroupingService.minimumPhotosPerCluster
            )
            let yearEntries = Dictionary(grouping: entries) {
                Calendar.current.component(.year, from: $0.date)
            }
            .map { year, dateEntries in
                YearEntry(year: year, entries: dateEntries.sorted { $0.date > $1.date })
            }
            .sorted { $0.year > $1.year }
            state = yearEntries.isEmpty ? .empty : .loaded(yearEntries)
        } catch let e as DaterollError {
            state = .error(e)
        } catch {
            state = .error(.loadFailed(underlying: error))
        }
    }
}
