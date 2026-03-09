import Foundation

enum DaterollError: LocalizedError, Sendable {
    case photoAccessDenied
    case photoAccessRestricted
    case loadFailed(underlying: any Error)
    case faceModelLoadFailed
    case faceScanFailed(underlying: any Error)

    var errorDescription: String? {
        switch self {
        case .photoAccessDenied:
            return "Photo library access was denied. Enable it in Settings to use Dateroll."
        case .photoAccessRestricted:
            return "Photo library access is restricted on this device."
        case .loadFailed(let error):
            return error.localizedDescription
        case .faceModelLoadFailed:
            return "Failed to load the face detection model."
        case .faceScanFailed(let error):
            return "Face scan failed: \(error.localizedDescription)"
        }
    }
}
