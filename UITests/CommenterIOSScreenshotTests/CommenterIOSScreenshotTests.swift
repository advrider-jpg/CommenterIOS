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

        captureSection("Roster", fileName: "05-worklist-roster")
        captureSection("Subjects", fileName: "06-worklist-subjects")
        captureSection("Results", fileName: "07-worklist-results")
        captureSection("Draft Comments", fileName: "08-worklist-draft-comments")
        captureSection("Export and Backup", fileName: "09-worklist-export-backup")

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

    private func captureSection(_ section: String, fileName: String) {
        let label = app.staticTexts[section]
        var attempts = 0
        while !label.exists && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(label.exists, "Expected to find the \(section) section before capturing \(fileName).")
        capture(fileName)
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
