import XCTest

final class CommenterIOSScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testCoreAppPages() throws {
        app.launch()

        waitForPage(named: "Projects")
        capture("01-projects")

        openTab("Worklist")
        waitForPage(named: "Worklist")
        capture("02-worklist-no-project")

        openTab("Support")
        waitForPage(named: "Support")
        capture("03-support")

        openTab("Projects")
        let createProject = app.buttons["Create Project"]
        waitForEnabledElement(createProject, named: "Create Project")
        createProject.tap()

        waitForPage(named: "Untitled Project")
        capture("04-worklist-project")

        captureArea(anchor: "Import Roster CSV, XLSX, or XLS", fileName: "05-worklist-roster")
        captureArea(anchor: "English", fileName: "06-worklist-subjects")
        captureArea(anchor: "Import Results CSV, XLSX, or XLS", fileName: "07-worklist-results")
        captureArea(anchor: "Generate and Save Reports", fileName: "08-worklist-draft-comments")
        captureArea(anchor: "Prepare Backup JSON", fileName: "09-worklist-export-backup")

        openTab("Support")
        waitForPage(named: "Support")
        capture("10-support-with-project")
    }

    private func openTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        waitForEnabledElement(tab, named: "\(name) tab")
        tab.tap()
    }

    private func waitForPage(named name: String) {
        let navigationBar = app.navigationBars[name]
        XCTAssertTrue(
            navigationBar.waitForExistence(timeout: 30),
            "Expected \(name) page to be visible before capturing a screenshot."
        )
    }

    private func waitForEnabledElement(_ element: XCUIElement, named name: String) {
        let predicate = NSPredicate(format: "exists == true AND enabled == true")
        let readyExpectation = expectation(for: predicate, evaluatedWith: element)
        let result = XCTWaiter().wait(for: [readyExpectation], timeout: 30)
        XCTAssertEqual(result, .completed, "Expected \(name) to become available.")
    }

    private func captureArea(anchor: String, fileName: String) {
        var attempts = 0
        while !visibleElement(named: anchor) && attempts < 10 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(visibleElement(named: anchor), "Expected to find \(anchor) before capturing \(fileName).")
        capture(fileName)
    }

    private func visibleElement(named name: String) -> Bool {
        app.buttons[name].exists ||
            app.staticTexts[name].exists ||
            app.switches[name].exists ||
            app.textFields[name].exists
    }

    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let directory = ProcessInfo.processInfo.environment["COMMENTER_SCREENSHOT_DIR"] else {
            return
        }

        do {
            let outputDirectory = URL(fileURLWithPath: directory, isDirectory: true)
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            let outputURL = outputDirectory.appendingPathComponent("\(name).png")
            try screenshot.pngRepresentation.write(to: outputURL, options: [.atomic])
        } catch {
            XCTFail("Could not write screenshot \(name): \(error.localizedDescription)")
        }
    }
}
