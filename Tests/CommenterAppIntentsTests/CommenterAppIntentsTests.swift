import XCTest
@testable import CommenterAppIntents

@MainActor
final class CommenterAppIntentsTests: XCTestCase {
    func testRouterPublishesAndConsumesRequestedDestination() async {
        let router = CommenterAppIntentRouter.shared
        if let pending = router.pendingDestination {
            router.consume(pending)
        }

        await CommenterAppIntentRouter.request(.reportPreparation)

        XCTAssertEqual(router.pendingDestination, .reportPreparation)
        router.consume(.reportPreparation)
        XCTAssertNil(router.pendingDestination)
    }
}
