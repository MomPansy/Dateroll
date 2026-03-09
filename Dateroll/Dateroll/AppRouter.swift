import SwiftUI

enum Route: Hashable {
    case dateDetail(DateEntry)
    case settings
}

@Observable
@MainActor
final class AppRouter {
    var path = NavigationPath()
    func navigate(to route: Route) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path = NavigationPath() }
}
