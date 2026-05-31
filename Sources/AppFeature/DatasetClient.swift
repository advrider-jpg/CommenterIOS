import CommentEngine
import ComposableArchitecture
import Foundation

public struct DatasetSnapshot: Equatable, Sendable {
    public var hash: String
    public var normalizedSourceHash: String
    public var subjectCount: Int
    public var componentCount: Int
    public var recipeCount: Int
    public var assembledVariantCount: Int
    public var uniquenessGuardCount: Int
    public var warnings: [String]
    public var summary: String

    public init(
        hash: String,
        normalizedSourceHash: String,
        subjectCount: Int,
        componentCount: Int,
        recipeCount: Int,
        assembledVariantCount: Int,
        uniquenessGuardCount: Int,
        warnings: [String],
        summary: String
    ) {
        self.hash = hash
        self.normalizedSourceHash = normalizedSourceHash
        self.subjectCount = subjectCount
        self.componentCount = componentCount
        self.recipeCount = recipeCount
        self.assembledVariantCount = assembledVariantCount
        self.uniquenessGuardCount = uniquenessGuardCount
        self.warnings = warnings
        self.summary = summary
    }
}

public struct DatasetClient: Sendable {
    public var load: @Sendable () async throws -> DatasetSnapshot

    public init(load: @escaping @Sendable () async throws -> DatasetSnapshot) {
        self.load = load
    }
}

extension DatasetClient: DependencyKey {
    public static let liveValue = DatasetClient {
        let engine = try ProductionCommentDataset.loadBundled()
        let diagnostics = engine.diagnostics
        return DatasetSnapshot(
            hash: diagnostics.datasetHash,
            normalizedSourceHash: diagnostics.normalizedSourceHash,
            subjectCount: diagnostics.subjects.count,
            componentCount: diagnostics.componentCount,
            recipeCount: diagnostics.recipeCount,
            assembledVariantCount: diagnostics.assembledVariantCount,
            uniquenessGuardCount: diagnostics.uniquenessGuardCount,
            warnings: diagnostics.warnings,
            summary: ProductionCommentDataset.diagnosticSummary(diagnostics)
        )
    }

    public static let testValue = DatasetClient {
        throw ProductionCommentDatasetError.missingBundledDataset
    }
}

public extension DependencyValues {
    var datasetClient: DatasetClient {
        get { self[DatasetClient.self] }
        set { self[DatasetClient.self] = newValue }
    }
}
