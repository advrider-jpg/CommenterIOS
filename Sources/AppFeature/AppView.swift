import ComposableArchitecture
import SwiftUI
import UniformTypeIdentifiers

public struct AppView: View {
    private let store: StoreOf<AppFeature>

    @State private var importMode: ImportMode?
    @State private var exportDocument: PreparedExportDocument?
    @State private var isExportingFile = false
    @State private var sharePresentation: SharePresentation?
    @State private var projectDeletionCandidate: ProjectDeletionCandidate?

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            TabView(selection: viewStore.binding(get: \.selectedTab, send: AppFeature.Action.tabSelected)) {
                ProjectsRootView(
                    message: viewStore.projectStorageMessage,
                    status: viewStore.projectStorageStatus,
                    projects: viewStore.projects,
                    operationStatus: viewStore.operationStatus,
                    onCreateProject: { viewStore.send(.createProjectTapped) },
                    onOpenProject: { viewStore.send(.projectTapped($0)) },
                    onImportBackup: { importMode = .backup }
                )
                .tabItem { Label("Projects", systemImage: "folder") }
                .tag(AppFeature.Tab.projects)

                WorklistRootView(
                    project: viewStore.selectedProject,
                    readiness: viewStore.selectedProjectReadiness,
                    status: viewStore.projectStorageStatus,
                    operationStatus: viewStore.operationStatus,
                    preparedFile: viewStore.preparedFile,
                    pendingImport: viewStore.pendingImport,
                    onProjectNameChanged: { viewStore.send(.projectNameChanged($0)) },
                    onProjectTermChanged: { viewStore.send(.projectTermChanged($0)) },
                    onProjectYearLevelChanged: { viewStore.send(.projectYearLevelChanged($0)) },
                    onUseFirstNameOnlyChanged: { viewStore.send(.useFirstNameOnlyChanged($0)) },
                    onSave: { viewStore.send(.saveProjectTapped) },
                    onDeleteProject: {
                        guard let project = viewStore.selectedProject else { return }
                        projectDeletionCandidate = ProjectDeletionCandidate(
                            id: project.metadata.id,
                            name: project.metadata.name
                        )
                    },
                    onAddStudent: { viewStore.send(.addStudentTapped) },
                    onDeleteStudent: { viewStore.send(.deleteStudentTapped($0)) },
                    onStudentFirstNameChanged: { viewStore.send(.studentFirstNameChanged($0, $1)) },
                    onStudentLastNameChanged: { viewStore.send(.studentLastNameChanged($0, $1)) },
                    onStudentYearChanged: { viewStore.send(.studentYearLevelChanged($0, $1)) },
                    onSubjectToggled: { viewStore.send(.subjectToggled($0)) },
                    onAchievementChanged: { viewStore.send(.achievementLevelChanged($0, $1, $2)) },
                    onFocusChanged: { viewStore.send(.focusChanged($0, $1, $2)) },
                    onGenerate: { viewStore.send(.generateReportsTapped) },
                    onManualEditChanged: { viewStore.send(.reportManualEditChanged($0, $1, $2)) },
                    onLockChanged: { viewStore.send(.reportLockChanged($0, $1, $2)) },
                    onImportRoster: { importMode = .roster },
                    onImportResults: { importMode = .results },
                    onPrepareBackup: { viewStore.send(.prepareBackupTapped) },
                    onPrepareExport: { viewStore.send(.prepareReportExportTapped($0)) },
                    onSavePreparedFile: {
                        guard let preparedFile = viewStore.preparedFile else {
                            viewStore.send(.fileExportFailed("No verified prepared file is available."))
                            return
                        }
                        do {
                            exportDocument = try PreparedExportDocument(url: preparedFile.url)
                            isExportingFile = true
                        } catch {
                            viewStore.send(.fileExportFailed(error.localizedDescription))
                        }
                    },
                    onSharePreparedFile: {
                        guard let preparedFile = viewStore.preparedFile else {
                            viewStore.send(.fileShareFailed("No verified prepared file is available."))
                            return
                        }
                        sharePresentation = SharePresentation(url: preparedFile.url)
                        viewStore.send(.fileShareStarted(preparedFile.url))
                    },
                    onDismissPreparedFile: { viewStore.send(.preparedFileDismissed) },
                    onConfirmImport: { viewStore.send(.confirmImportTapped) },
                    onCancelImportPreview: { viewStore.send(.importPreviewCancelled) }
                )
                .tabItem { Label("Worklist", systemImage: "checklist") }
                .tag(AppFeature.Tab.worklist)

                SupportRootView(
                    datasetStatus: viewStore.datasetStatus,
                    projectStorageStatus: viewStore.projectStorageStatus,
                    projectStorageMessage: viewStore.projectStorageMessage,
                    projectCount: viewStore.projects.count,
                    selectedProject: viewStore.selectedProject,
                    readiness: viewStore.selectedProjectReadiness,
                    preparedFile: viewStore.preparedFile
                )
                    .tabItem { Label("Support", systemImage: "questionmark.circle") }
                    .tag(AppFeature.Tab.support)
            }
            .task { await viewStore.send(.task).finish() }
            .fileImporter(
                isPresented: importBinding,
                allowedContentTypes: importMode?.allowedContentTypes ?? [.data],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result, viewStore: viewStore)
            }
            .fileExporter(
                isPresented: $isExportingFile,
                document: exportDocument,
                contentType: exportDocument?.contentType ?? .data,
                defaultFilename: exportDocument?.defaultFilename ?? "CommenterExport"
            ) { result in
                handleExportResult(result, viewStore: viewStore)
            }
            .sheet(item: $sharePresentation) { presentation in
                ActivityShareSheet(url: presentation.url) { result in
                    handleShareResult(result, url: presentation.url, viewStore: viewStore)
                }
            }
            .confirmationDialog(
                "Delete Project?",
                isPresented: Binding(
                    get: { projectDeletionCandidate != nil },
                    set: { isPresented in
                        if !isPresented { projectDeletionCandidate = nil }
                    }
                ),
                titleVisibility: .visible,
                presenting: projectDeletionCandidate
            ) { candidate in
                Button("Delete \(candidate.name)", role: .destructive) {
                    projectDeletionCandidate = nil
                    viewStore.send(.deleteProjectConfirmed(candidate.id))
                }
                Button("Cancel", role: .cancel) {
                    projectDeletionCandidate = nil
                }
            } message: { _ in
                Text("A recovery snapshot of the verified local project will be created before the project file is removed. Save or reopen first if there are unsaved edits.")
            }
        }
    }

    private var importBinding: Binding<Bool> {
        Binding(
            get: { importMode != nil },
            set: { isPresented in
                if !isPresented {
                    importMode = nil
                }
            }
        )
    }

    private func handleImportResult(
        _ result: Result<[URL], Error>,
        viewStore: ViewStore<AppFeature.State, AppFeature.Action>
    ) {
        defer { importMode = nil }
        switch result {
        case let .success(urls):
            guard let url = urls.first, let mode = importMode else {
                viewStore.send(.importCancelled)
                return
            }
            switch mode {
            case .backup:
                viewStore.send(.backupImportPicked(url))
            case .roster:
                viewStore.send(.rosterImportPicked(url))
            case .results:
                viewStore.send(.resultsImportPicked(url))
            }
        case let .failure(error):
            if isCancellation(error) {
                viewStore.send(.importCancelled)
            } else {
                viewStore.send(.importFailed(error.localizedDescription))
            }
        }
    }

    private func handleExportResult(
        _ result: Result<URL, Error>,
        viewStore: ViewStore<AppFeature.State, AppFeature.Action>
    ) {
        switch result {
        case let .success(url):
            viewStore.send(.fileExportSaved(url))
        case let .failure(error):
            if isCancellation(error) {
                viewStore.send(.fileExportCancelled)
            } else {
                viewStore.send(.fileExportFailed(error.localizedDescription))
            }
        }
    }

    private func handleShareResult(
        _ result: Result<Bool, Error>,
        url: URL,
        viewStore: ViewStore<AppFeature.State, AppFeature.Action>
    ) {
        sharePresentation = nil
        switch result {
        case let .success(completed):
            if completed {
                viewStore.send(.fileShareCompleted(url))
            } else {
                viewStore.send(.fileShareCancelled)
            }
        case let .failure(error):
            if isCancellation(error) {
                viewStore.send(.fileShareCancelled)
            } else {
                viewStore.send(.fileShareFailed(error.localizedDescription))
            }
        }
    }
}

private struct ProjectDeletionCandidate: Identifiable, Equatable {
    let id: String
    let name: String
}
