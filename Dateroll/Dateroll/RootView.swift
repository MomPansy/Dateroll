import SwiftUI
import Photos

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.photoService) private var photoService
    @State private var authStatus: PHAuthorizationStatus = .notDetermined

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            Group {
                switch authStatus {
                case .authorized, .limited:
                    TimelineView()
                default:
                    OnboardingView(initialStep: authStatus == .denied || authStatus == .restricted ? .permissionDenied : .welcome)
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .dateDetail(let entry): Text("Detail: \(entry.id)") // Phase 4
                case .settings: Text("Settings")                          // Phase 5
                }
            }
        }
        .task {
            authStatus = await photoService.authorizationStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { authStatus = await photoService.authorizationStatus() }
        }
    }
}
