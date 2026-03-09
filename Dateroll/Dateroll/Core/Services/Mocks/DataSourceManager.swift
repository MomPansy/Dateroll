#if DEBUG
import Foundation

enum DataSourceMode: Equatable {
    case live
    case mock(SampleDataset)
}

@Observable
@MainActor
final class DataSourceManager {
    var mode: DataSourceMode = .live {
        didSet { rebuildServices() }
    }

    private(set) var photoService: any PhotoLibraryServiceProtocol
    private(set) var imageLoader: any ImageLoaderProtocol

    private let livePhotoService: any PhotoLibraryServiceProtocol
    private let liveImageLoader: any ImageLoaderProtocol

    init(photoService: any PhotoLibraryServiceProtocol, imageLoader: any ImageLoaderProtocol) {
        self.livePhotoService = photoService
        self.liveImageLoader = imageLoader
        self.photoService = photoService
        self.imageLoader = imageLoader
    }

    private func rebuildServices() {
        switch mode {
        case .live:
            photoService = livePhotoService
            imageLoader = liveImageLoader
        case .mock(let dataset):
            photoService = MockPhotoLibraryService(assets: dataset.assets)
            imageLoader = MockImageLoader()
        }
    }
}
#endif
