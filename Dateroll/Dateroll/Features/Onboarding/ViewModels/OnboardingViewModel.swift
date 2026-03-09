import SwiftUI
import Photos

enum OnboardingStep { case welcome, sharedLibraryInstruction, permissionDenied }

@Observable
@MainActor
final class OnboardingViewModel {
    var step: OnboardingStep
    var isRequesting = false
    private let photoService: any PhotoLibraryServiceProtocol

    init(photoService: any PhotoLibraryServiceProtocol, initialStep: OnboardingStep = .welcome) {
        self.photoService = photoService
        self.step = initialStep
    }

    func requestPermission() async {
        isRequesting = true
        let status = await photoService.requestAuthorization()
        isRequesting = false
        switch status {
        case .authorized, .limited: step = .sharedLibraryInstruction
        default: step = .permissionDenied
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
