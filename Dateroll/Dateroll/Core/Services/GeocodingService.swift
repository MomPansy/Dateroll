import CoreLocation

actor GeocodingService {
    private var cache: [String: String] = [:]
    private let geocoder = CLGeocoder()

    func placeName(for coordinate: LocationCoordinate) async -> String? {
        let key = String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
        if let cached = cache[key] { return cached }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemarks = try? await geocoder.reverseGeocodeLocation(location),
              let placemark = placemarks.first else { return nil }

        let name = placemark.locality ?? placemark.administrativeArea ?? placemark.country
        if let name { cache[key] = name }
        return name
    }
}
