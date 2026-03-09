import SwiftUI

struct OnboardingView: View {
    @Environment(\.photoService) private var photoService
    @State private var vm: OnboardingViewModel?
    let initialStep: OnboardingStep

    init(initialStep: OnboardingStep = .welcome) {
        self.initialStep = initialStep
    }

    var body: some View {
        Group {
            if let vm {
                OnboardingStepsView(vm: vm)
            } else {
                ProgressView()
            }
        }
        .task {
            if vm == nil {
                vm = OnboardingViewModel(photoService: photoService, initialStep: initialStep)
            }
        }
    }
}

private struct OnboardingStepsView: View {
    var vm: OnboardingViewModel

    var body: some View {
        switch vm.step {
        case .welcome:
            welcomeStep
        case .sharedLibraryInstruction:
            sharedLibraryStep
        case .permissionDenied:
            permissionDeniedStep
        }
    }

    @ViewBuilder
    private var welcomeStep: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "heart.fill")
                .font(.system(size: 72))
                .foregroundStyle(.pink)
            VStack(spacing: 12) {
                Text("Welcome to Dateroll")
                    .font(.largeTitle.bold())
                Text("Relive every day you've spent together, organized beautifully by date.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await vm.requestPermission() }
            } label: {
                Label("Allow Photo Access", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.pink)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(vm.isRequesting)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding()
    }

    @ViewBuilder
    private var sharedLibraryStep: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "person.2.fill")
                .font(.system(size: 56))
                .foregroundStyle(.pink)

            Text("iCloud Shared Library")
                .font(.title.bold())

            Text("To see photos from your shared library, follow these steps:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 16) {
                onboardingStepRow(number: 1, icon: "gear", text: "Open the **Settings** app")
                onboardingStepRow(number: 2, icon: "photo.on.rectangle", text: "Tap **Photos**")
                onboardingStepRow(number: 3, icon: "person.2", text: "Under **Library**, tap **Shared Library**")
                onboardingStepRow(number: 4, icon: "checkmark.circle", text: "Set it as your **Default Library**")
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            Text("Dateroll will then show photos from your shared library.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
            VStack(spacing: 12) {
                Button {
                    vm.openSettings()
                } label: {
                    Label("Open Settings", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.pink)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button("Continue to Timeline") {
                    vm.step = .welcome
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding()
    }

    private func onboardingStepRow(number: Int, icon: String, text: LocalizedStringKey) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.pink.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.pink)
            }

            Text(text)
                .font(.subheadline)
        }
    }

    @ViewBuilder
    private var permissionDeniedStep: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "photo.slash")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)
            VStack(spacing: 12) {
                Text("Photo Access Required")
                    .font(.largeTitle.bold())
                Text("Dateroll needs access to your photo library to show your dates together. Enable it in Settings.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open Settings") {
                vm.openSettings()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.pink)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding()
    }
}
