import CoreGraphics
import Foundation
import XCTest

final class CommenterIOSScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private let screenshotProjectName = "Room 5"
    private let screenshotStudentId = "student-1"
    private let screenshotSubjectKey = "english"

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testCoreReportFlowScreenshots() throws {
        app.launch()

        waitForPage(named: "Projects")
        capture("01-projects-empty")

        openTab("Work list")
        waitForPage(named: "Work list")
        capture("02-worklist-no-project")

        openTab("Support")
        waitForPage(named: "Support")
        waitForElement(element("dataset-loaded-status"), named: "bundled production dataset loaded status")
        capture("03-support-diagnostics")

        openTab("Projects")
        let createProject = button(identifier: "create-project-button", label: "Create Project")
        waitForEnabledElement(createProject, named: "Create Project")
        createProject.tap()

        waitForPage(named: "Create project")
        let projectName = textField(identifier: "project-creation-name-field", label: "Class name")
        enterText(screenshotProjectName, in: projectName, named: "project creation class name")
        let confirmCreate = button(identifier: "project-creation-create-button", label: "Create")
        waitForEnabledElement(confirmCreate, named: "Create project confirmation")
        confirmCreate.tap()

        waitForPage(named: screenshotProjectName)
        capture("04-project-created")

        let addStudent = scrollToAny(buttons(identifier: "add-student-button", label: "Add Student"), name: "Add Student")
        capture("05-roster-before-student")
        addStudent.tap()

        let studentRow = scrollToAny(cells(identifier: "student-row-\(screenshotStudentId)", label: "Student"), name: "new student row")
        studentRow.tap()

        let firstName = scrollToAny(textFields(identifier: "student-first-name-\(screenshotStudentId)", label: "First name"), name: "student first name field")
        enterText("Ava", in: firstName, named: "student first name")
        let lastName = scrollToAny(textFields(identifier: "student-last-name-\(screenshotStudentId)", label: "Last name"), name: "student last name field")
        enterText("Ng", in: lastName, named: "student last name")
        capture("06-roster-student-entered")
        tapBack(to: screenshotProjectName)

        let deselectAll = scrollToAny(buttons(identifier: "subject-deselect-all-button", label: "Deselect all"), name: "Deselect all", requireHittable: false)
        tapElement(deselectAll, named: "Deselect all")
        let englishToggle = scrollToAny(switches(identifier: "subject-toggle-\(screenshotSubjectKey)", label: "English"), name: "English subject toggle", requireHittable: false)
        tapSwitch(englishToggle, named: "English subject toggle")
        capture("07-subject-selected-english")

        let achievementOption = scrollToAny(buttons(identifier: "achievement-picker-\(screenshotStudentId)-\(screenshotSubjectKey)-atstandard", label: "At Standard"), name: "Ava English At Standard achievement option")
        capture("08-result-before-achievement")
        tapElement(achievementOption, named: "Ava English At Standard achievement option")

        let focusField = scrollToAny(textFields(identifier: "focus-field-\(screenshotStudentId)-\(screenshotSubjectKey)", label: "Focus"), name: "Ava English focus field")
        enterText("reading comprehension", in: focusField, named: "Ava English focus")
        capture("09-result-ready-for-generation")

        let saveProject = scrollToAny(buttons(identifier: "save-project-button", label: "Save Project"), name: "Save Project", directions: [false, true])
        saveProject.tap()
        _ = scrollToAny([element("operation-status-saved")], name: "verified project save status", requireHittable: false, directions: [false, true])
        capture("10-project-saved-before-generation")

        let generateReports = scrollToAny(buttons(identifier: "generate-reports-button", label: "Generate and Save Reports"), name: "Generate and Save Reports")
        generateReports.tap()

        let reportRow = scrollToAny(cells(identifier: "report-row-\(screenshotStudentId)-\(screenshotSubjectKey)", label: "Ava Ng - English"), name: "generated Ava English report row")
        reportRow.tap()
        let reportEditor = scrollToAny(textViews(identifier: "report-editor-\(screenshotStudentId)-\(screenshotSubjectKey)", label: "Ava English report"), name: "generated Ava English report", requireHittable: false)
        waitForElement(reportEditor, named: "generated Ava English report")
        capture("11-generated-report-comment")
        tapBack(to: screenshotProjectName)

        let prepareDocx = scrollToAny(buttons(identifier: "prepare-docx-reports-button", label: "Prepare DOCX Reports"), name: "Prepare DOCX Reports")
        waitForEnabledElement(prepareDocx, named: "Prepare DOCX Reports")
        capture("12-export-ready")
        prepareDocx.tap()

        let preparedFile = element("prepared-file-ready")
        waitForElement(preparedFile, named: "verified prepared DOCX file")
        _ = scrollToAny([preparedFile], name: "verified prepared DOCX file", requireHittable: false)
        capture("13-docx-prepared")

        openTab("Support")
        waitForPage(named: "Support")
        _ = scrollToAny([element("support-ready-file")], name: "support ready file status", requireHittable: false)
        capture("14-support-after-report")
    }

    private func openTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        waitForEnabledElement(tab, named: "\(name) tab")
        tab.tap()
    }

    private func waitForPage(named name: String) {
        let navigationBar = app.navigationBars[name]
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            if navigationBar.exists {
                return
            }
            if let pageIdentifier = pageAccessibilityIdentifier(for: name), element(pageIdentifier).exists {
                return
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }
        let pageExists = pageAccessibilityIdentifier(for: name).map { element($0).exists } ?? false
        XCTAssertTrue(navigationBar.exists || pageExists, "Expected \(name) page to be visible before capturing a screenshot.")
    }

    private func pageAccessibilityIdentifier(for name: String) -> String? {
        switch name {
        case "Projects":
            return "projects-page"
        case "Work list":
            return "worklist-page"
        case "Support":
            return "support-page"
        default:
            return nil
        }
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

    private func button(identifier: String, label: String) -> XCUIElement {
        let identified = app.buttons[identifier]
        return identified.exists ? identified : app.buttons[label]
    }

    private func textField(identifier: String, label: String) -> XCUIElement {
        let identified = app.textFields[identifier]
        return identified.exists ? identified : app.textFields[label]
    }

    private func buttons(identifier: String, label: String) -> [XCUIElement] {
        [app.buttons[identifier], app.buttons[label], element(identifier)]
    }

    private func cells(identifier: String, label: String) -> [XCUIElement] {
        [app.cells[identifier], app.buttons[identifier], app.staticTexts[label], element(identifier)]
    }

    private func textFields(identifier: String, label: String) -> [XCUIElement] {
        [app.textFields[identifier], app.textFields[label], element(identifier)]
    }

    private func switches(identifier: String, label: String) -> [XCUIElement] {
        [
            app.switches[identifier],
            app.switches[label],
            app.buttons[identifier],
            app.buttons[label],
            app.cells[identifier],
            app.cells[label],
            app.staticTexts[label],
            element(identifier)
        ]
    }

    private func pickers(identifier: String, label: String) -> [XCUIElement] {
        [
            app.buttons[identifier],
            app.buttons[label],
            app.pickers[identifier],
            app.pickers[label],
            app.cells[identifier],
            app.cells[label],
            app.otherElements[identifier],
            element(identifier)
        ]
    }

    private func textViews(identifier: String, label: String) -> [XCUIElement] {
        [app.textViews[identifier], app.textViews[label], element(identifier)]
    }

    private func waitForElement(_ element: XCUIElement, named name: String, timeout: TimeInterval = 30) {
        if !element.waitForExistence(timeout: timeout) {
            captureFailureContext(name)
            XCTFail("Expected \(name) to exist.")
        }
    }

    private func scrollToAny(
        _ elements: [XCUIElement],
        name: String,
        requireHittable: Bool = true,
        directions: [Bool] = [true, false]
    ) -> XCUIElement {
        precondition(!elements.isEmpty, "scrollToAny requires at least one candidate element.")
        if let visible = visibleElement(in: elements, requireHittable: requireHittable) {
            return visible
        }

        for direction in directions {
            for _ in 0..<24 {
                scrollBySmallStep(up: direction)
                if let visible = visibleElement(in: elements, requireHittable: requireHittable) {
                    return visible
                }
            }
        }

        captureFailureContext(name)
        let failureStatus = element("operation-status-failed")
        if failureStatus.exists {
            XCTFail("Expected \(name), but the app reported failure: \(failureStatus.label)")
        } else {
            XCTFail("Expected \(name) to be visible\(requireHittable ? " and hittable" : "").")
        }
        return elements[0]
    }

    private func visibleElement(in elements: [XCUIElement], requireHittable: Bool) -> XCUIElement? {
        elements.first { element in
            guard element.exists else { return false }
            return requireHittable ? element.isHittable : isVisibleOnScreen(element)
        }
    }

    private func isVisibleOnScreen(_ element: XCUIElement) -> Bool {
        let frame = element.frame
        return !frame.isEmpty && app.frame.intersects(frame)
    }

    private func scrollBySmallStep(up: Bool) {
        let startY: CGFloat = up ? 0.68 : 0.32
        let endY: CGFloat = up ? 0.44 : 0.56
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY))
        start.press(forDuration: 0.01, thenDragTo: end)
    }

    private func enterText(_ text: String, in element: XCUIElement, named name: String) {
        waitForElement(element, named: name)
        XCTAssertTrue(element.isHittable, "Expected \(name) to be visible before entering text.")
        element.tap()
        element.typeText(text)
        dismissKeyboardIfNeeded()
    }

    private func tapElement(_ element: XCUIElement, named name: String) {
        waitForElement(element, named: name)
        if element.isHittable {
            element.tap()
            return
        }
        XCTAssertTrue(isVisibleOnScreen(element), "Expected \(name) to be visible before tapping.")
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func tapSwitch(_ element: XCUIElement, named name: String) {
        waitForElement(element, named: name)
        if element.elementType == .switch || element.elementType == .button {
            if element.isHittable {
                element.tap()
            } else {
                XCTAssertTrue(isVisibleOnScreen(element), "Expected \(name) to be visible before tapping.")
                element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
        } else {
            XCTAssertTrue(isVisibleOnScreen(element), "Expected \(name) to be visible before tapping.")
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
    }

    private func chooseAchievement(_ value: String, picker: XCUIElement) {
        picker.tap()

        let optionCandidates = [app.buttons[value], app.cells[value], app.staticTexts[value], app.descendants(matching: .any)[value]]
        if let option = waitForAny(optionCandidates, timeout: 5), option.exists {
            if option.isHittable {
                option.tap()
            } else {
                option.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            returnToWorklistIfNeeded()
            return
        }

        let wheel = app.pickerWheels.firstMatch
        if wheel.waitForExistence(timeout: 5) {
            wheel.adjust(toPickerWheelValue: value)
            if app.buttons["Done"].exists {
                app.buttons["Done"].tap()
            }
            returnToWorklistIfNeeded()
            return
        }

        XCTFail("Expected to choose achievement value \(value).")
    }

    private func waitForAny(_ elements: [XCUIElement], timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let element = elements.first(where: { $0.exists }) {
                return element
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }
        return elements.first(where: { $0.exists })
    }

    private func returnToWorklistIfNeeded() {
        if app.navigationBars[screenshotProjectName].exists {
            return
        }

        let backButton = app.navigationBars.buttons[screenshotProjectName]
        if backButton.waitForExistence(timeout: 3) {
            backButton.tap()
        }
        waitForPage(named: screenshotProjectName)
    }

    private func tapBack(to pageName: String) {
        let backButton = app.navigationBars.buttons[pageName]
        waitForEnabledElement(backButton, named: "\(pageName) back button")
        backButton.tap()
        waitForPage(named: pageName)
    }

    private func dismissKeyboardIfNeeded() {
        guard app.keyboards.firstMatch.exists else { return }
        if tapKeyboardButton("Done") {
            return
        }
        if tapKeyboardButton("Return") {
            return
        }
        if tapKeyboardButton("return") {
            return
        }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
    }

    private func tapKeyboardButton(_ label: String) -> Bool {
        let button = app.keyboards.buttons[label]
        guard button.exists else { return false }
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        return true
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

    private func captureFailureContext(_ name: String) {
        let safeName = name
            .lowercased()
            .map { character in
                character.isLetter || character.isNumber ? character : "-"
            }
            .reduce(into: "") { partial, character in
                if character != "-" || partial.last != "-" {
                    partial.append(character)
                }
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        capture("failure-\(safeName)")
    }
}
