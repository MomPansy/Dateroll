import SwiftUI

@main
struct DaterollApp: App {
    @State private var router = AppRouter()
    private let photoService = PhotoLibraryService()
    private let imageLoader = ImageLoader()
    private let groupingService = DateGroupingService()
    private let geocodingService = GeocodingService()

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
            #endif
        }
    }
}
