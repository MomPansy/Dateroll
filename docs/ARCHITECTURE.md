# Architecture: Dateroll

## Pattern: MVVM + Services

```
View  ←→  ViewModel  ←→  Service  ←→  PhotoKit / System
```

- **Views** are pure SwiftUI, stateless beyond local `@State`
- **ViewModels** are `@Observable` classes; own business logic and drive UI state
- **Services** are actors (for concurrency safety) that abstract PhotoKit and data processing
- **Models** are value types (structs) passed between layers

## Concurrency Model

All PhotoKit operations run off the MainActor:

```swift
@MainActor
final class TimelineViewModel: Observable {
    var dateEntries: [DateEntry] = []
    var isLoading = false

    func load() async {
        isLoading = true
        dateEntries = await photoService.fetchDateEntries()
        isLoading = false
    }
}

actor PhotoLibraryService {
    func fetchDateEntries() async -> [DateEntry] { ... }
}
```

## Core Models

```swift
struct DateEntry: Identifiable, Hashable {
    let id: String           // ISO date string "2025-02-14"
    let date: Date           // Midnight of the day (local tz)
    let photos: [PhotoAsset]
    var heroPhoto: PhotoAsset? { photos.first }
}

struct PhotoAsset: Identifiable, Hashable {
    let id: String           // PHAsset.localIdentifier
    let creationDate: Date
    let location: CLLocation?
    // Resolved images fetched lazily via PHImageManager
}
```

## Service Layer

### `PhotoLibraryService` (actor)
Responsibilities:
- Check and request `PHAuthorizationStatus`
- Fetch all `PHAsset` objects (images only)
- Observe `PHPhotoLibraryChangeObserver` and publish changes

### `DateGroupingService` (actor)
Responsibilities:
- Accept `[PHAsset]` and group by calendar day (user's local timezone)
- Return `[DateEntry]` sorted newest-first
- Filter out days with 0 photos

### `ImageLoader` (actor)
Responsibilities:
- Wrap `PHImageManager.requestImage` in async/await
- Cache thumbnails in memory (NSCache)
- Cancel inflight requests on deinit

## Navigation

Single `AppRouter` (`@Observable`) holds the `NavigationPath`:

```swift
@Observable
final class AppRouter {
    var path = NavigationPath()

    func navigate(to route: Route) { path.append(route) }
    func pop() { path.removeLast() }
    func popToRoot() { path = NavigationPath() }
}
```

Injected via `@Environment(\.router)`.

## Dependency Injection

Services are created once in `DaterollApp` and injected via `@Environment`:

```swift
@main
struct DaterollApp: App {
    @State private var router = AppRouter()
    @State private var photoService = PhotoLibraryService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(photoService)
        }
    }
}
```

## Photo Access States

```
notDetermined → [request] → authorized | denied | restricted | limited
```

The app handles all states in `OnboardingViewModel` and gracefully degrades for `limited`.

## Testing Strategy

- `PhotoLibraryService` hides behind a `PhotoLibraryServiceProtocol`
- Mock implementations injected in unit tests
- ViewModels tested with mock services, no PhotoKit dependency
- `DateGroupingService` fully unit-testable (pure logic, no PhotoKit)
