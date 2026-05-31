import DesignSystem
import SwiftUI

struct SupportRootView: View {
    let datasetStatus: AppFeature.DatasetStatus

    var body: some View {
        NavigationStack {
            List {
                Section("Production Dataset") {
                    datasetStatusContent
                }

                Section("Privacy") {
                    Text("CommenterIOS is local-only. Accounts, cloud sync, analytics, telemetry, remote AI, and backend project persistence are outside the MVP product shape.")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .navigationTitle("Support")
        }
    }

    @ViewBuilder
    private var datasetStatusContent: some View {
        switch datasetStatus {
        case .notLoaded, .loading:
            ProgressView("Checking bundled comment engine")
        case let .loaded(snapshot):
            LabeledContent("Status", value: "Bundled dataset loaded")
            LabeledContent("Checks", value: "Basic structural checks passed")
            LabeledContent("Subjects", value: "\(snapshot.subjectCount)")
            LabeledContent("Components", value: "\(snapshot.componentCount)")
            LabeledContent("Recipes", value: "\(snapshot.recipeCount)")
            LabeledContent("Assembled variants", value: "\(snapshot.assembledVariantCount)")
            LabeledContent("Uniqueness rules", value: "\(snapshot.uniquenessGuardCount)")
            if !snapshot.warnings.isEmpty {
                ForEach(snapshot.warnings, id: \.self) { warning in
                    Text(warning)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            LabeledContent("Bundled hash", value: snapshot.hash)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
                .accessibilityLabel("Dataset hash \(snapshot.hash)")
            LabeledContent("Normalized source hash", value: snapshot.normalizedSourceHash)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
                .accessibilityLabel("Normalized source hash \(snapshot.normalizedSourceHash)")
        case let .failed(message):
            UnavailableFeatureNotice(title: "Dataset blocked", message: message)
        }
    }
}
