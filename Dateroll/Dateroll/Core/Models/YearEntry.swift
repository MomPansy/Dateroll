import Foundation

struct YearEntry: Identifiable, Hashable, Sendable {
    let year: Int
    let entries: [DateEntry]   // all date clusters for this year, newest-first

    var id: Int { year }
    var heroPhoto: PhotoAsset? { entries.first?.heroPhoto }
    var totalPhotos: Int { entries.reduce(0) { $0 + $1.photoCount } }
    var dateCount: Int { entries.count }

    var carouselPhotos: [PhotoAsset] {
        let limit = 10
        var result: [PhotoAsset] = []
        for entry in entries {
            guard let first = entry.photos.first, result.count < limit else { break }
            result.append(first)
        }
        if result.count < limit {
            let remaining = entries.flatMap { $0.photos.dropFirst() }.prefix(limit - result.count)
            result.append(contentsOf: remaining)
        }
        return result
    }

    var representativeCoordinate: LocationCoordinate? {
        entries.lazy.flatMap(\.photos).first(where: { $0.coordinate != nil })?.coordinate
    }
}
