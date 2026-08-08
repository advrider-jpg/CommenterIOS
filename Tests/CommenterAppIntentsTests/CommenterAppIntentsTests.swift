import XCTest
@testable import CommenterAppIntents

@MainActor
final class CommenterAppIntentsTests: XCTestCase {
    func testRouterPublishesAndConsumesRequestedDestination() async {
        let router = CommenterAppIntentRouter.shared
        if let pending = router.pendingDestination {
            router.consume(pending)
        }

        await CommenterAppIntentRouter.request(.aiReviewQueue)

        XCTAssertEqual(router.pendingDestination, .aiReviewQueue)
        router.consume(.reportPreparation)
        XCTAssertEqual(router.pendingDestination, .aiReviewQueue)
        router.consume(.aiReviewQueue)
        XCTAssertNil(router.pendingDestination)
    }
}
