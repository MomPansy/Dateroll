import SwiftUI

private struct PhotoServiceKey: EnvironmentKey {
    static let defaultValue: any PhotoLibraryServiceProtocol = PhotoLibraryService()
}
private struct ImageLoaderKey: EnvironmentKey {
    static let defaultValue: any ImageLoaderProtocol = ImageLoader()
}
private struct DateGroupingServiceKey: EnvironmentKey {
    static let defaultValue: any DateGroupingServiceProtocol = DateGroupingService()
}
private struct GeocodingServiceKey: EnvironmentKey {
    static let defaultValue = GeocodingService()
}
private struct FaceStoreKey: EnvironmentKey {
    static let defaultValue: any FaceStoreProtocol = FaceStore()
}
private struct FaceDetectionServiceKey: EnvironmentKey {
    static let defaultValue: any FaceDetectionServiceProtocol = MockFaceDetectionService()
}

extension EnvironmentValues {
    var photoService: any PhotoLibraryServiceProtocol {
        get { self[PhotoServiceKey.self] }
        set { self[PhotoServiceKey.self] = newValue }
    }
    var imageLoader: any ImageLoaderProtocol {
        get { self[ImageLoaderKey.self] }
        set { self[ImageLoaderKey.self] = newValue }
    }
    var dateGroupingService: any DateGroupingServiceProtocol {
        get { self[DateGroupingServiceKey.self] }
        set { self[DateGroupingServiceKey.self] = newValue }
    }
    var geocodingService: GeocodingService {
        get { self[GeocodingServiceKey.self] }
        set { self[GeocodingServiceKey.self] = newValue }
    }
    var faceStore: any FaceStoreProtocol {
        get { self[FaceStoreKey.self] }
        set { self[FaceStoreKey.self] = newValue }
    }
    var faceDetectionService: any FaceDetectionServiceProtocol {
        get { self[FaceDetectionServiceKey.self] }
        set { self[FaceDetectionServiceKey.self] = newValue }
    }
}
