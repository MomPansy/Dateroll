import SwiftUI

@main
struct DaterollApp: App {
    @State private var router = AppRouter()
    private let photoService = PhotoLibraryService()
    private let imageLoader = ImageLoader()
    private let groupingService = DateGroupingService()
    private let geocodingService = GeocodingService()
    private let faceStore = FaceStore()
    private let faceDetectionService: any FaceDetectionServiceProtocol
    private let faceClusteringService: FaceClusteringService

    init() {
        faceDetectionService = (try? FaceDetectionService(faceStore: faceStore)) ?? MockFaceDetectionService()
        faceClusteringService = FaceClusteringService(faceStore: faceStore)
    }

    #if DEBUG
    @State private var dataSourceManager: DataSourceManager?
    #endif

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let manager = dataSourceManager {
                RootView()
                    .environment(router)
                    .environment(\.photoService, manager.photoService)
                    .environment(\.imageLoader, manager.imageLoader)
                    .environment(\.dateGroupingService, groupingService)
                    .environment(\.geocodingService, geocodingService)
                    .environment(\.faceStore, faceStore)
                    .environment(\.faceDetectionService, faceDetectionService)
                    .environment(\.faceClusteringService, faceClusteringService)
                    .environment(manager)
            } else {
                ProgressView()
                    .onAppear {
                        dataSourceManager = DataSourceManager(
                            photoService: photoService,
                            imageLoader: imageLoader
                        )
                    }
            }
            #else
            RootView()
                .environment(router)
                .environment(\.photoService, photoService)
                .environment(\.imageLoader, imageLoader)
                .environment(\.dateGroupingService, groupingService)
                .environment(\.geocodingService, geocodingService)
                .environment(\.faceStore, faceStore)
                .environment(\.faceDetectionService, faceDetectionService)
                .environment(\.faceClusteringService, faceClusteringService)
            #endif
        }
    }
}
