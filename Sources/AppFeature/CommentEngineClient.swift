import CommentEngine
import CommenterDomain
import ComposableArchitecture
import Foundation

public struct CommentEngineClient: Sendable {
    public var generateReports: @Sendable (_ project: Project) async throws -> CommentGenerationResult

    public init(generateReports: @escaping @Sendable (_ project: Project) async throws -> CommentGenerationResult) {
        self.generateReports = generateReports
    }
}

public struct CommentGenerationResult: Equatable, Sendable {
    public var project: Project
    public var generatedCount: Int
    public var skippedLockedCount: Int

    public init(project: Project, generatedCount: Int, skippedLockedCount: Int) {
        self.project = project
        self.generatedCount = generatedCount
        self.skippedLockedCount = skippedLockedCount
    }
}

extension CommentEngineClient: DependencyKey {
    public static let liveValue = CommentEngineClient { project in
        let engine = try await productionDatasetCache.load()
        var generator = try ReportGenerator(
            data: engine.data,
            projectMetadata: project.metadata,
            usedVariantIds: Set(reportVariantIds(project))
        )
        let now = milliseconds(Date())
        var next = project
        var generatedCount = 0
        var skippedLockedCount = 0

        let expected = getExpectedReportKeys(project: project)
        guard !expected.isEmpty else {
            throw ReportGenerationError.noEligibleComment(studentName: "Project", subject: "No selected subjects")
        }

        for key in expected {
            if key.report?.isLocked == true {
                skippedLockedCount += 1
                continue
            }
            let readiness = getResultReadiness(project: project, studentId: key.student.id, subject: key.subject)
            guard readiness.status == .ready, let result = readiness.result else {
                throw ReportGenerationError.unavailableSubject(readiness.message)
            }
            let report = try generator.generateReport(
                student: key.student,
                subject: key.subject,
                result: result,
                generatedAt: now
            )
            next.reports = replaceReport(next.reports, with: report)
            generatedCount += 1
        }

        guard generatedCount > 0 else {
            throw ReportGenerationError.unavailableSubject("No reports were generated because all eligible reports are locked.")
        }

        return CommentGenerationResult(project: next, generatedCount: generatedCount, skippedLockedCount: skippedLockedCount)
    }

    public static let testValue = CommentEngineClient { _ in
        throw ReportGenerationError.invalidDataset(["Comment engine test dependency was not provided."])
    }
}

public extension DependencyValues {
    var commentEngineClient: CommentEngineClient {
        get { self[CommentEngineClient.self] }
        set { self[CommentEngineClient.self] = newValue }
    }
}

private let productionDatasetCache = ProductionDatasetCache()

private actor ProductionDatasetCache {
    private var cached: ValidatedCommentEngine?

    func load() throws -> ValidatedCommentEngine {
        if let cached { return cached }
        let loaded = try ProductionCommentDataset.loadBundled()
        cached = loaded
        return loaded
    }
}

private func milliseconds(_ date: Date) -> Int64 {
    Int64((date.timeIntervalSince1970 * 1000).rounded())
}
