import XCTest

final class CommenterIOSScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testCoreReportFlowScreenshots() throws {
        app.launch()

        waitForPage(named: "Projects")
        capture("01-projects-empty")

        openTab("Worklist")
        waitForPage(named: "Worklist")
        capture("02-worklist-no-project")

        openTab("Support")
        waitForPage(named: "Support")
        capture("03-support-diagnostics")

        openTab("Projects")
        let createProject = app.buttons["Create Project"]
        waitForEnabledElement(createProject, named: "Create Project")
        createProject.tap()

        waitForPage(named: "Untitled Project")
        capture("04-project-created")

        let addStudent = element("add-student-button")
        scrollTo(addStudent, name: "Add Student")
        capture("05-roster-before-student")
        addStudent.tap()

        let firstName = element("student-first-name-student-1")
        waitForElement(firstName, named: "student first name field")
        enterText("Ava", in: firstName, named: "student first name")
        enterText("Ng", in: element("student-last-name-student-1"), named: "student last name")
        capture("06-roster-student-entered")

        let englishToggle = element("subject-toggle-english")
        scrollTo(englishToggle, name: "English subject toggle")
        englishToggle.tap()
        capture("07-subject-selected-english")

        let achievementPicker = element("achievement-picker-student-1-english")
        scrollTo(achievementPicker, name: "Ava English achievement picker")
        capture("08-result-before-achievement")
        chooseAchievement("At Standard", picker: achievementPicker)

        let focusField = element("focus-field-student-1-english")
        waitForElement(focusField, named: "Ava English focus field")
        enterText("reading comprehension", in: focusField, named: "Ava English focus")
        capture("09-result-ready-for-generation")

        let generateReports = element("generate-reports-button")
        scrollTo(generateReports, name: "Generate and Save Reports")
        generateReports.tap()

        let reportEditor = element("report-editor-student-1-english")
        waitForElement(reportEditor, named: "generated Ava English report")
        capture("10-generated-report-comment")

        let prepareDocx = element("prepare-docx-reports-button")
        scrollTo(prepareDocx, name: "Prepare DOCX Reports")
        capture("11-export-ready")
        prepareDocx.tap()

        let preparedFile = element("prepared-file-ready")
        waitForElement(preparedFile, named: "verified prepared DOCX file")
        capture("12-docx-prepared")

        openTab("Support")
        waitForPage(named: "Support")
        capture("13-support-after-report")
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

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func waitForElement(_ element: XCUIElement, named name: String, timeout: TimeInterval = 30) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Expected \(name) to exist.")
    }

    private func scrollTo(_ element: XCUIElement, name: String) {
        var attempts = 0
        while (!element.exists || !element.isHittable) && attempts < 12 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(element.exists, "Expected \(name) to exist.")
        XCTAssertTrue(element.isHittable, "Expected \(name) to be visible and hittable.")
    }

    private func enterText(_ text: String, in element: XCUIElement, named name: String) {
        waitForElement(element, named: name)
        element.tap()
        element.typeText(text)
        dismissKeyboardIfNeeded()
    }

    private func chooseAchievement(_ value: String, picker: XCUIElement) {
        picker.tap()

        let button = app.buttons[value]
        if button.waitForExistence(timeout: 3) {
            button.tap()
            return
        }

        let option = app.descendants(matching: .any)[value]
        if option.waitForExistence(timeout: 3), option.isHittable {
            option.tap()
            return
        }

        let wheel = app.pickerWheels.firstMatch
        if wheel.waitForExistence(timeout: 3) {
            wheel.adjust(toPickerWheelValue: value)
            if app.buttons["Done"].exists {
                app.buttons["Done"].tap()
            }
            return
        }

        XCTFail("Expected to choose achievement value \(value).")
    }

    private func dismissKeyboardIfNeeded() {
        guard app.keyboards.firstMatch.exists else { return }
        if app.keyboards.buttons["Return"].exists {
            app.keyboards.buttons["Return"].tap()
        } else if app.keyboards.buttons["Done"].exists {
            app.keyboards.buttons["Done"].tap()
        }
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
