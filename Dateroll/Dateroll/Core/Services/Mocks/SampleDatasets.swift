import Foundation

enum SampleDataset: String, CaseIterable, Identifiable {
    case couplesTrips = "Couple's Trips"
    case dailyLife = "Daily Life"
    case longDistance = "Long Distance"
    case newCouple = "New Couple"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .couplesTrips: "4 years of international travel"
        case .dailyLife: "3 years in San Francisco"
        case .longDistance: "5 years, Singapore & Melbourne"
        case .newCouple: "1 year, just getting started"
        }
    }

    var assets: [PhotoAsset] {
        switch self {
        case .couplesTrips: Self.couplesTripsAssets
        case .dailyLife: Self.dailyLifeAssets
        case .longDistance: Self.longDistanceAssets
        case .newCouple: Self.newCoupleAssets
        }
    }

    // MARK: - Couple's Trips (~200 photos, 2022-2025)

    private static let couplesTripsAssets: [PhotoAsset] = {
        let tokyo = LocationCoordinate(latitude: 35.6762, longitude: 139.6503)
        let paris = LocationCoordinate(latitude: 48.8566, longitude: 2.3522)
        let nyc = LocationCoordinate(latitude: 40.7128, longitude: -74.0060)
        let bali = LocationCoordinate(latitude: -8.3405, longitude: 115.0920)
        let rome = LocationCoordinate(latitude: 41.9028, longitude: 12.4964)
        let london = LocationCoordinate(latitude: 51.5074, longitude: -0.1278)
        let barcelona = LocationCoordinate(latitude: 41.3874, longitude: 2.1686)
        let kyoto = LocationCoordinate(latitude: 35.0116, longitude: 135.7681)

        var all: [PhotoAsset] = []
        // 2022: Tokyo spring, Rome summer
        all += cluster(baseDate: date(2022, 3, 20), count: 25, coordinate: tokyo, idPrefix: "ct-tokyo22")
        all += cluster(baseDate: date(2022, 7, 10), count: 20, coordinate: rome, idPrefix: "ct-rome22")
        // 2023: Paris valentine's, Bali summer, NYC fall, London NYE
        all += cluster(baseDate: date(2023, 2, 14), count: 30, coordinate: paris, idPrefix: "ct-paris23")
        all += cluster(baseDate: date(2023, 6, 15), count: 25, coordinate: bali, idPrefix: "ct-bali23")
        all += cluster(baseDate: date(2023, 10, 5), count: 20, coordinate: nyc, idPrefix: "ct-nyc23")
        all += cluster(baseDate: date(2023, 12, 30), count: 15, coordinate: london, idPrefix: "ct-london23")
        // 2024: Barcelona spring, Kyoto fall
        all += cluster(baseDate: date(2024, 4, 1), count: 25, coordinate: barcelona, idPrefix: "ct-bcn24")
        all += cluster(baseDate: date(2024, 10, 15), count: 20, coordinate: kyoto, idPrefix: "ct-kyoto24")
        // 2025: Tokyo anniversary
        all += cluster(baseDate: date(2025, 3, 20), count: 20, coordinate: tokyo, idPrefix: "ct-tokyo25")
        return all
    }()

    // MARK: - Daily Life (~300 photos, 2023-2025, SF)

    private static let dailyLifeAssets: [PhotoAsset] = {
        let sf = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        var all: [PhotoAsset] = []
        for year in 2023...2025 {
            for month in 1...12 {
                guard year < 2025 || month <= 6 else { break }
                let count = Int.random(in: 3...8)
                let day = Int.random(in: 1...28)
                all += cluster(
                    baseDate: date(year, month, day),
                    count: count,
                    coordinate: sf,
                    idPrefix: "dl-\(year)\(month)"
                )
            }
        }
        return all
    }()

    // MARK: - Long Distance (~80 photos, 2021-2025)

    private static let longDistanceAssets: [PhotoAsset] = {
        let singapore = LocationCoordinate(latitude: 1.3521, longitude: 103.8198)
        let melbourne = LocationCoordinate(latitude: -37.8136, longitude: 144.9631)
        var all: [PhotoAsset] = []
        for year in 2021...2025 {
            // Alternate visits: SG in spring, Melbourne in winter
            all += cluster(
                baseDate: date(year, 4, Int.random(in: 10...20)),
                count: Int.random(in: 8...12),
                coordinate: singapore,
                idPrefix: "ld-sg\(year)"
            )
            all += cluster(
                baseDate: date(year, 12, Int.random(in: 15...25)),
                count: Int.random(in: 6...10),
                coordinate: melbourne,
                idPrefix: "ld-mel\(year)"
            )
        }
        return all
    }()

    // MARK: - New Couple (~30 photos, 2025 only)

    private static let newCoupleAssets: [PhotoAsset] = {
        let cafe = LocationCoordinate(latitude: 34.0522, longitude: -118.2437) // LA
        let beach = LocationCoordinate(latitude: 33.7701, longitude: -118.1937) // Long Beach
        var all: [PhotoAsset] = []
        all += cluster(baseDate: date(2025, 1, 15), count: 5, coordinate: cafe, idPrefix: "nc-jan")
        all += cluster(baseDate: date(2025, 2, 14), count: 6, coordinate: cafe, idPrefix: "nc-feb")
        all += cluster(baseDate: date(2025, 3, 8), count: 4, coordinate: beach, idPrefix: "nc-mar")
        all += cluster(baseDate: date(2025, 4, 20), count: 5, coordinate: beach, idPrefix: "nc-apr")
        all += cluster(baseDate: date(2025, 5, 10), count: 5, coordinate: cafe, idPrefix: "nc-may")
        all += cluster(baseDate: date(2025, 6, 1), count: 5, coordinate: beach, idPrefix: "nc-jun")
        return all
    }()

    // MARK: - Helpers

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 10
        return Calendar.current.date(from: comps)!
    }

    static func cluster(
        baseDate: Date,
        count: Int,
        coordinate: LocationCoordinate?,
        idPrefix: String
    ) -> [PhotoAsset] {
        (0..<count).map { i in
            PhotoAsset(
                id: "\(idPrefix)-\(i)",
                creationDate: baseDate.addingTimeInterval(Double(i) * 600), // 10 min apart
                coordinate: coordinate
            )
        }
    }
}
