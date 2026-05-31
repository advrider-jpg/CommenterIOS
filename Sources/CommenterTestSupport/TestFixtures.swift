import CommentEngine
import Foundation

public enum TestFixtures {
    public static func loadProductionDatasetForTests() throws -> ValidatedCommentEngine {
        try ProductionCommentDataset.loadBundled()
    }
}
