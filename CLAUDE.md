# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dateroll is an iOS 17+ couples photo timeline app (Swift 6, SwiftUI) that groups a shared photo library by calendar day into "date" entries. Core docs: `docs/PRD.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`.

**Current state**: Xcode project scaffolded at `Dateroll/Dateroll.xcodeproj`. The app files still contain the default SwiftData template — the planned MVVM+Services architecture has not been implemented yet.

## XcodeBuildMCP

This project uses XcodeBuildMCP for all Xcode operations. Always call `mcp__XcodeBuildMCP__session_show_defaults` at the start of a session, then set defaults pointing to `Dateroll/Dateroll.xcodeproj`.

| Task | Tool |
|------|------|
| Build | `mcp__xcodebuildmcp__build_sim_name_proj` |
| Test | `mcp__xcodebuildmcp__test_sim_name_proj` |
| Run tests (SwiftPM) | `mcp__xcodebuildmcp__swift_package_test` |
| Clean | `mcp__xcodebuildmcp__clean` |
| Screenshot | `mcp__XcodeBuildMCP__screenshot` |

## Architecture

**Pattern**: MVVM + Services. See `docs/ARCHITECTURE.md` for full detail.

```
View ←→ ViewModel (@Observable, @MainActor) ←→ Service (actor) ←→ PhotoKit
```

- **Services** are `actor` types — all PhotoKit work happens off MainActor
- **ViewModels** are `@Observable` `@MainActor` classes
- **Models** (`DateEntry`, `PhotoAsset`) are structs passed between layers
- **Navigation**: single `AppRouter` (`@Observable`) injected via `@Environment`
- **DI**: services created once in `DaterollApp`, injected via `.environment(...)`

### Key Types

```swift
struct DateEntry: Identifiable, Hashable {
    let id: String           // ISO date string "2025-02-14"
    let date: Date           // Midnight local tz
    let photos: [PhotoAsset]
}

struct PhotoAsset: Identifiable, Hashable {
    let id: String           // PHAsset.localIdentifier
    let creationDate: Date
    let location: CLLocation?
}
```

### Services

- `PhotoLibraryService` (actor) — authorization, `PHAsset` fetching, `PHPhotoLibraryChangeObserver`
- `DateGroupingService` (actor) — groups assets by calendar day, returns `[DateEntry]` newest-first
- `ImageLoader` (actor) — wraps `PHImageManager` in async/await, NSCache for thumbnails

`PhotoLibraryService` hides behind `PhotoLibraryServiceProtocol` for testability.

## Coding Standards

### Swift Style
- Use Swift 6 strict concurrency; never access PhotoKit assets on the MainActor
- Prefer `@Observable` over `ObservableObject`
- Use `async/await` for all async operations
- Use `guard` for early exits
- Prefer value types (structs) over reference types (classes)

### SwiftUI Patterns
- Extract views when they exceed 100 lines
- Use `@State` for local view state only
- Use `@Environment` for dependency injection
- Prefer `NavigationStack` over deprecated `NavigationView`
- Use `@Bindable` for bindings to `@Observable` objects

### Navigation Pattern
```swift
enum Route: Hashable {
    case detail(Item)
    case settings
}

NavigationStack(path: $router.path) {
    ContentView()
        .navigationDestination(for: Route.self) { route in
            // Handle routing
        }
}
```

### Error Handling
```swift
enum AppError: LocalizedError {
    case networkError(underlying: Error)
    case validationError(message: String)

    var errorDescription: String? {
        switch self {
        case .networkError(let error): return error.localizedDescription
        case .validationError(let msg): return msg
        }
    }
}
```

### DO NOT
- Write UITests during scaffolding phase
- Use deprecated APIs (UIKit when SwiftUI suffices)
- Create massive monolithic views
- Use force unwrapping (`!`) without justification
- Ignore Swift 6 concurrency warnings

## Testing

- Run tests: `mcp__xcodebuildmcp__swift_package_test`
- Framework: Swift Testing (`@Test`, `#expect`) — not XCTest
- Target: `DaterollTests/` for unit tests
- `DateGroupingService` is pure logic — fully unit-testable without PhotoKit
- ViewModels tested with mock services via `PhotoLibraryServiceProtocol`
- 80% coverage target for business logic

## Permissions

`NSPhotoLibraryUsageDescription` required in Info.plist. Request `.readWrite` via `PHPhotoLibrary.requestAuthorization`. Handle all states: `notDetermined`, `authorized`, `denied`, `restricted`, `limited`.
