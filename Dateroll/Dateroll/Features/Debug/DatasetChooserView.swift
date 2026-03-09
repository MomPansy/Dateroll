#if DEBUG
import SwiftUI

struct DatasetChooserView: View {
    let manager: DataSourceManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Data Source") {
                    Button {
                        manager.mode = .live
                        dismiss()
                    } label: {
                        HStack {
                            Label("Live Photo Library", systemImage: "photo.on.rectangle")
                            Spacer()
                            if manager.mode == .live {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }

                Section("Sample Datasets") {
                    ForEach(SampleDataset.allCases) { dataset in
                        Button {
                            manager.mode = .mock(dataset)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(dataset.rawValue)
                                    Text(dataset.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if manager.mode == .mock(dataset) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Choose Dataset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
#endif
