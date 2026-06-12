import CoreGraphics
import Foundation
import XCTest

final class CommenterIOSScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private let screenshotProjectName = "Room 5"
    private let screenshotStudentId = "student-1"
    private let screenshotSubjectKey = "english"
    private let screenshotReportTitle = "Ava Ng - English"

    private var screenshotReportEditorIdentifier: String {
        "report-editor-\(screenshotStudentId)-\(screenshotSubjectKey)"
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UITestMode"]
        app.launchEnvironment["UITEST_DISABLE_ANIMATIONS"] = "1"
    }

    func testCoreReportFlowScreenshots() throws {
        app.launch()

        waitForPage(named: "Projects")
        capture("01-projects-empty")

        openTab("Work list")
        waitForPage(named: "Work list")
        waitForElement(element("worklist-page"), named: "empty Work list page")
        capture("02-worklist-no-project")

        openTab("Support")
        waitForPage(named: "Support")
        waitForElement(element("support-page"), named: "Support page")
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

        ensureWorklistOpen()
        let addStudent = scrollToAnyInWorklist(buttons(identifier: "add-student-button", label: "Add Student"), name: "Add Student")
        capture("05-roster-before-student")
        addStudent.tap()

        let newRow = element("student-row-\(screenshotStudentId)")
        waitForElement(newRow, named: "new student row")
        openStudentEditor(studentId: screenshotStudentId)

        let firstName = waitForAny(textFields(identifier: "student-first-name-\(screenshotStudentId)", label: "First name"), timeout: 10)
            ?? textField(identifier: "student-first-name-\(screenshotStudentId)", label: "First name")
        waitForElement(firstName, named: "student first name field")
        enterText("Ava", in: firstName, named: "student first name")
        let lastName = waitForAny(textFields(identifier: "student-last-name-\(screenshotStudentId)", label: "Last name"), timeout: 10)
            ?? textField(identifier: "student-last-name-\(screenshotStudentId)", label: "Last name")
        waitForElement(lastName, named: "student last name field")
        enterText("Ng", in: lastName, named: "student last name")
        capture("06-roster-student-entered")
        guard tapBack(to: screenshotProjectName) else { return }
        ensureWorklistOpen()

        let deselectAll = scrollToAnyInWorklist(
            buttons(identifier: "subject-deselect-all-button", label: "Deselect all"),
            name: "Deselect all",
            requireHittable: true
        )
        tapElement(deselectAll, named: "Deselect all")
        ensureWorklistOpen()

        let englishToggle = scrollToAnyInWorklist(
            switches(identifier: "subject-toggle-\(screenshotSubjectKey)", label: "English"),
            name: "English subject toggle",
            requireHittable: true
        )
        tapSwitch(englishToggle, named: "English subject toggle")
        capture("07-subject-selected-english")

        let achievementOption = scrollToAnyInWorklist(
            buttons(identifier: "achievement-picker-\(screenshotStudentId)-\(screenshotSubjectKey)-atstandard", label: "At Standard"),
            name: "Ava English At Standard achievement option"
        )
        capture("08-result-before-achievement")
        tapElement(achievementOption, named: "Ava English At Standard achievement option")

        let focusField = scrollToAnyInWorklist(
            textFields(identifier: "focus-field-\(screenshotStudentId)-\(screenshotSubjectKey)", label: "Focus"),
            name: "Ava English focus field"
        )
        enterText("reading comprehension", in: focusField, named: "Ava English focus")
        capture("09-result-ready-for-generation")

        let saveProject = scrollToAnyInWorklist(
            buttons(identifier: "save-project-button", label: "Save Project"),
            name: "Save Project",
            directions: [false, true]
        )
        saveProject.tap()
        ensureWorklistOpen()
        _ = scrollToAnyInWorklist(
            [element("operation-status-saved")],
            name: "verified project save status",
            requireHittable: false,
            directions: [false, true]
        )
        capture("10-project-saved-before-generation")

        let generateReports = scrollToAnyInWorklist(
            buttons(identifier: "generate-reports-button", label: "Generate and Save Reports"),
            name: "Generate and Save Reports"
        )
        generateReports.tap()
        waitForOperationToSettle(action: "report generation")
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))
        ensureWorklistOpen()

        let reportRow = scrollToAnyInWorklist(
            reportRows(identifier: "report-row-\(screenshotStudentId)-\(screenshotSubjectKey)"),
            name: "generated Ava English report row",
            requireHittable: false
        )
        scrollElementIntoSafeTapZone(reportRow, named: "generated Ava English report row", container: worklistScrollContainer())
        tapElement(reportRow, named: "generated Ava English report row")
        guard waitForGeneratedReportEditor(timeout: 12) else {
            captureFailureContext("missing-generated-report-editor")
            XCTFail("Expected generated Ava English report editor to open after tapping the report row.")
            return
        }
        capture("11-generated-report-comment")
        guard tapBack(to: screenshotProjectName) else { return }
        ensureWorklistOpen()

        let prepareDocx = scrollToAnyInWorklist(
            buttons(identifier: "prepare-docx-reports-button", label: "Prepare DOCX Reports"),
            name: "Prepare DOCX Reports"
        )
        waitForEnabledElement(prepareDocx, named: "Prepare DOCX Reports")
        capture("12-export-ready")
        tapElement(prepareDocx, named: "Prepare DOCX Reports")

        ensureWorklistOpen()
        let preparedFile = scrollToAnyInWorklist(
            [element("prepared-file-ready")],
            name: "verified prepared DOCX file",
            requireHittable: false
        )
        _ = preparedFile
        capture("13-docx-prepared")

        openTab("Support")
        waitForPage(named: "Support")
        waitForElement(element("support-page"), named: "Support page")
        _ = scrollToAnyInSupport([element("support-ready-file")], name: "support ready file status", requireHittable: false)
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

    private func waitForStudentEditorIfPresent(studentId: String, timeout: TimeInterval) -> Bool {
        let editor = element("student-editor-\(studentId)")
        let firstName = app.textFields["student-first-name-\(studentId)"]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if editor.exists || firstName.exists {
                return true
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }
        return editor.exists || firstName.exists
    }

    private func openStudentEditor(studentId: String) {
        let rowIdentifier = "student-row-\(studentId)"
        let row = scrollToAnyInWorklist(
            [app.buttons[rowIdentifier], element(rowIdentifier)],
            name: "new student row",
            requireHittable: false
        )

        scrollElementIntoSafeTapZone(row, named: "new student row", container: worklistScrollContainer())
        guard row.isHittable else {
            captureFailureContext("student-row-\(studentId)-not-hittable")
            XCTFail("Expected new student row to be hittable after scrolling it away from the footer.")
            return
        }
        row.tap()
        if waitForStudentEditorIfPresent(studentId: studentId, timeout: 5) {
            return
        }

        captureFailureContext("student-editor-\(studentId)")
        XCTFail("Expected student editor for \(studentId) to open after tapping the roster row.")
    }

    private func scrollElementIntoSafeTapZone(_ element: XCUIElement, named name: String, container: XCUIElement) {
        waitForElement(element, named: name)
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            let frame = element.frame
            let safeRange = safeVerticalTapRange()
            if frame.midY >= safeRange.lowerBound && frame.midY <= safeRange.upperBound && isVisibleOnScreen(element) {
                return
            }
            if frame.midY > safeRange.upperBound {
                scrollWithin(container, up: true)
            } else {
                scrollWithin(container, up: false)
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.15))
        }

        let frame = element.frame
        let safeRange = safeVerticalTapRange()
        if !(frame.midY >= safeRange.lowerBound && frame.midY <= safeRange.upperBound) {
            captureFailureContext("\(name)-safe-zone")
            XCTFail("Expected \(name) to be away from the footer before tapping. frame=\(frame), safeY=\(safeRange)")
        }
    }

    private func safeVerticalTapRange() -> ClosedRange<CGFloat> {
        let appFrame = app.frame
        let tabTop = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY : appFrame.maxY
        let lower = appFrame.minY + 140
        let upper = min(tabTop, appFrame.maxY) - 120
        if upper > lower {
            return lower...upper
        }
        return (appFrame.midY - 40)...(appFrame.midY + 40)
    }

    private func waitForEnabledElement(_ element: XCUIElement, named name: String) {
        let predicate = NSPredicate(format: "exists == true AND enabled == true")
        let readyExpectation = expectation(for: predicate, evaluatedWith: element)
        let result = XCTWaiter().wait(for: [readyExpectation], timeout: 30)
        XCTAssertEqual(result, .completed, "Expected \(name) to become available.")
    }

    private func element(_ identifier: String) -> XCUIElement {
        let predicate = NSPredicate(format: "identifier == %@", identifier)
        return app.descendants(matching: .any).matching(predicate).firstMatch
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
        [app.buttons[identifier], app.cells[identifier], app.otherElements[identifier], element(identifier)]
    }

    private func reportRows(identifier: String) -> [XCUIElement] {
        [app.cells[identifier], app.buttons[identifier], app.otherElements[identifier], element(identifier)]
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

    private func waitForGeneratedReportEditor(timeout: TimeInterval) -> Bool {
        let editorCandidates = [
            app.textViews[screenshotReportEditorIdentifier],
            app.otherElements[screenshotReportEditorIdentifier],
            element(screenshotReportEditorIdentifier)
        ]
        let expectedNavigationBar = app.navigationBars[screenshotReportTitle]
        let expectedTitle = app.staticTexts[screenshotReportTitle]
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if expectedNavigationBar.exists || expectedTitle.exists || editorCandidates.contains(where: { $0.exists }) {
                return true
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.15))
        }

        return expectedNavigationBar.exists || expectedTitle.exists || editorCandidates.contains(where: { $0.exists })
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
        directions: [Bool] = [true, false],
        container: XCUIElement? = nil
    ) -> XCUIElement {
        precondition(!elements.isEmpty, "scrollToAny requires at least one candidate element.")
        if let visible = visibleElement(in: elements, requireHittable: requireHittable) {
            return visible
        }

        for direction in directions {
            for _ in 0..<24 {
                if let container {
                    scrollWithin(container, up: direction)
                } else {
                    scrollBySmallStep(up: direction)
                }
                if let visible = visibleElement(in: elements, requireHittable: requireHittable) {
                    return visible
                }
            }
        }

        captureFailureContext(name)
        let failureStatus = element("operation-status-failed")
        let candidatesSummary = elements.map { element in
            let identifier = element.identifier.isEmpty ? "<no-id>" : element.identifier
            return "\(identifier): exists=\(element.exists) hittable=\(element.isHittable) label=\(element.label)"
        }.joined(separator: "; ")
        if failureStatus.exists {
            XCTFail("Expected \(name), but the app reported failure: \(failureStatus.label). Candidates: \(candidatesSummary)")
        } else {
            XCTFail("Expected \(name) to be visible\(requireHittable ? " and hittable" : ""). Candidates: \(candidatesSummary)")
        }
        return elements[0]
    }

    private func scrollToAnyInWorklist(
        _ elements: [XCUIElement],
        name: String,
        requireHittable: Bool = true,
        directions: [Bool] = [true, false],
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        ensureWorklistOpen(file: file, line: line)
        return scrollToAny(
            elements,
            name: name,
            requireHittable: requireHittable,
            directions: directions,
            container: worklistScrollContainer()
        )
    }

    private func scrollToAnyInSupport(
        _ elements: [XCUIElement],
        name: String,
        requireHittable: Bool = true,
        directions: [Bool] = [true, false]
    ) -> XCUIElement {
        waitForElement(element("support-page"), named: "Support page")
        return scrollToAny(
            elements,
            name: name,
            requireHittable: requireHittable,
            directions: directions,
            container: supportScrollContainer()
        )
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

    private func worklistScrollContainer() -> XCUIElement {
        let list = element("worklist-list")
        if list.exists {
            return list
        }
        if app.scrollViews.firstMatch.exists {
            return app.scrollViews.firstMatch
        }
        if app.collectionViews.firstMatch.exists {
            return app.collectionViews.firstMatch
        }
        if app.tables.firstMatch.exists {
            return app.tables.firstMatch
        }
        return list
    }

    private func supportScrollContainer() -> XCUIElement {
        let list = element("support-list")
        if list.exists {
            return list
        }
        if app.scrollViews.firstMatch.exists {
            return app.scrollViews.firstMatch
        }
        if app.collectionViews.firstMatch.exists {
            return app.collectionViews.firstMatch
        }
        if app.tables.firstMatch.exists {
            return app.tables.firstMatch
        }
        return list
    }

    private func scrollWithin(_ container: XCUIElement, up: Bool) {
        if !container.waitForExistence(timeout: 5) {
            captureFailureContext("missing-scroll-container")
            XCTFail("Expected scroll container to exist before scrolling.")
            return
        }

        let startY: CGFloat = up ? 0.75 : 0.30
        let endY: CGFloat = up ? 0.35 : 0.65
        let start = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
        let end = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY))
        start.press(forDuration: 0.01, thenDragTo: end)
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

    private func ensureWorklistOpen(file: StaticString = #filePath, line: UInt = #line) {
        openTab("Work list")
        waitForPage(named: screenshotProjectName)
        let worklistPage = element("worklist-page")
        if element("support-page").exists && !worklistPage.exists {
            captureFailureContext("unexpected-support-tab")
            XCTFail("Expected Work list, but Support is visible.", file: file, line: line)
            return
        }
        if !worklistPage.waitForExistence(timeout: 5) {
            captureFailureContext("missing-worklist-page")
            XCTFail("Expected Work list page to be visible.", file: file, line: line)
            return
        }
        let worklistList = worklistScrollContainer()
        if !worklistList.waitForExistence(timeout: 5) {
            captureFailureContext("missing-worklist-list")
            XCTFail("Expected Work list scroll container to exist.", file: file, line: line)
        }
    }

    @discardableResult private func tapBack(to pageName: String) -> Bool {
        let backCandidates = [
            app.navigationBars.buttons[pageName],
            app.navigationBars.buttons["Back"],
            app.buttons[pageName],
            app.buttons["Back"],
            app.navigationBars.buttons.firstMatch
        ]
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if let backButton = backCandidates.first(where: { $0.exists && $0.isEnabled }) {
                if backButton.isHittable {
                    backButton.tap()
                } else {
                    backButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                }
                waitForPage(named: pageName)
                return true
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }

        captureFailureContext("\(pageName)-back-button")
        XCTFail("Expected a back button to \(pageName) to become available.")
        return false
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

    private func waitForOperationToSettle(action: String, timeout: TimeInterval = 45) {
        let busy = element("operation-status-busy")
        let failed = element("operation-status-failed")
        let observationGrace = Date().addingTimeInterval(5)
        let deadline = Date().addingTimeInterval(timeout)
        var observedBusy = false
        while Date() < deadline {
            if failed.exists {
                captureFailureContext("\(action)-failed")
                XCTFail("\(action) failed: \(failed.label)")
                return
            }
            if busy.exists {
                observedBusy = true
            } else if observedBusy || Date() >= observationGrace {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.5))
                return
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.25))
        }
        captureFailureContext("\(action)-timeout")
        XCTFail("\(action) timed out (still busy): \(busy.label)")
    }

    private func waitForDocxPreparation() {
        let prepared = element("operation-status-prepared")
        let failed = element("operation-status-failed")
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            if prepared.exists { return }
            if failed.exists {
                captureFailureContext("docx-preparation-failed")
                XCTFail("DOCX preparation failed: \(failed.label)")
                return
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.5))
        }
        captureFailureContext("docx-preparation-timeout")
        let busy = element("operation-status-busy")
        if busy.exists {
            XCTFail("DOCX preparation timed out (still busy): \(busy.label)")
        } else {
            XCTFail("DOCX preparation timed out with no recognised operation status.")
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

        let context = XCTAttachment(string: failureDiagnosticSummary())
        context.name = "failure-\(safeName)-context"
        context.lifetime = .keepAlways
        add(context)
    }

    private func failureDiagnosticSummary() -> String {
        let rootIdentifiers = [
            "projects-page",
            "projects-list",
            "worklist-page",
            "worklist-list",
            "support-page",
            "support-list",
            "student-row-\(screenshotStudentId)",
            "student-editor-\(screenshotStudentId)",
            "student-first-name-\(screenshotStudentId)",
            "student-last-name-\(screenshotStudentId)",
            "report-row-\(screenshotStudentId)-\(screenshotSubjectKey)",
            screenshotReportEditorIdentifier,
            "operation-status-busy",
            "operation-status-failed",
            "operation-status-saved",
            "prepared-file-ready"
        ]
        let roots = rootIdentifiers.map { identifier -> String in
            let candidate = element(identifier)
            if candidate.exists {
                return "\(identifier): exists=true hittable=\(candidate.isHittable) frame=\(String(describing: candidate.frame)) label=\(candidate.label)"
            }
            return "\(identifier): exists=false"
        }
        let navigationBars = app.navigationBars.allElementsBoundByIndex.map { bar -> String in
            "identifier=\(bar.identifier) label=\(bar.label) exists=\(bar.exists)"
        }
        let tabButtons = app.tabBars.buttons.allElementsBoundByIndex.map { button -> String in
            let value = button.value.map { String(describing: $0) } ?? "nil"
            return "identifier=\(button.identifier) label=\(button.label) exists=\(button.exists) hittable=\(button.isHittable) value=\(value)"
        }
        let appDebug = app.debugDescription
        return """
        Root identifiers:
        \(roots.joined(separator: "\n"))

        Navigation bars:
        \(navigationBars.joined(separator: "\n"))

        Tab buttons:
        \(tabButtons.joined(separator: "\n"))

        App debugDescription:
        \(appDebug)
        """
    }
}
