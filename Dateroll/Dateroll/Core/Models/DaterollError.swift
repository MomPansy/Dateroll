import Foundation

enum DaterollError: LocalizedError, Sendable {
    case photoAccessDenied
    case photoAccessRestricted
    case loadFailed(underlying: any Error)

    var errorDescription: String? {
        switch self {
        case .photoAccessDenied:
            return "Photo library access was denied. Enable it in Settings to use Dateroll."
        case .photoAccessRestricted:
            return "Photo library access is restricted on this device."
        case .loadFailed(let error):
            return error.localizedDescription
        }
    }
}
