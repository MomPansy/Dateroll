import SwiftUI

struct TimelineView: View {
    @Environment(\.photoService) private var photoService
    @Environment(\.dateGroupingService) private var dateGroupingService
    @State private var vm: TimelineViewModel?
    @State private var showingSharedLibrary = false

    #if DEBUG
    @Environment(DataSourceManager.self) private var dataSourceManager
    @State private var showingDatasetChooser = false
    #endif

    var body: some View {
        Group {
            if let vm {
                TimelineContentView(vm: vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Memories")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingSharedLibrary = true
                } label: {
                    Image(systemName: "person.2")
                }
            }
        }
        .sheet(isPresented: $showingSharedLibrary) {
            SharedLibraryInfoSheet()
        }
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingDatasetChooser = true
                } label: {
                    Image(systemName: "flask")
                }
            }
        }
        .sheet(isPresented: $showingDatasetChooser) {
            DatasetChooserView(manager: dataSourceManager)
        }
        .onChange(of: dataSourceManager.mode) {
            vm = nil
        }
        #endif
        .task(id: vm == nil) {
            if vm == nil {
                let newVM = TimelineViewModel(photoService: photoService, groupingService: dateGroupingService)
                vm = newVM
                await newVM.load()
            }
        }
    }
}

private struct TimelineContentView: View {
    var vm: TimelineViewModel

    var body: some View {
        switch vm.state {
        case .idle:
            ProgressView()
        case .loading:
            ProgressView("Loading your dates...")
        case .loaded(let yearEntries):
            let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(yearEntries) { entry in
                        YearCardView(entry: entry)
                    }
                }
                .padding(16)
            }
            .refreshable {
                await vm.refresh()
            }
        case .empty:
            ContentUnavailableView(
                "No Dates Yet",
                systemImage: "photo.on.rectangle.angled",
                description: Text("Take some photos together and they'll appear here, grouped by day.")
            )
        case .error(let error):
            ContentUnavailableView(
                "Something Went Wrong",
                systemImage: "exclamationmark.triangle",
                description: Text(error.errorDescription ?? "An unknown error occurred.")
            )
        }
    }
}

private struct SharedLibraryInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.pink)
                        .padding(.top, 24)

                    Text("iCloud Shared Library")
                        .font(.title.bold())

                    Text("To see photos from your shared library, follow these steps:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    SharedLibraryStepsView()

                    Text("Dateroll will then show photos from your shared library.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("Open Settings", systemImage: "gear")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.pink)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button("Done") {
                            dismiss()
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct SharedLibraryStepsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SharedLibraryStepRow(number: 1, icon: "gear", text: "Open the **Settings** app")
            SharedLibraryStepRow(number: 2, icon: "photo.on.rectangle", text: "Tap **Photos**")
            SharedLibraryStepRow(number: 3, icon: "person.2", text: "Under **Library**, tap **Shared Library**")
            SharedLibraryStepRow(number: 4, icon: "checkmark.circle", text: "Set it as your **Default Library**")
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

private struct SharedLibraryStepRow: View {
    let number: Int
    let icon: String
    let text: LocalizedStringKey

    var body: some View {
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
}
