import CommenterDomain
import Foundation

public struct PreparedReportDocumentFile: Equatable, Sendable {
    public var url: URL
    public var byteCount: UInt64
    public var format: ImportExportFormat
    public var studentCount: Int

    public init(url: URL, byteCount: UInt64, format: ImportExportFormat, studentCount: Int) {
        self.url = url
        self.byteCount = byteCount
        self.format = format
        self.studentCount = studentCount
    }
}

public enum ReportDocumentFileError: LocalizedError, Equatable {
    case unsupportedFormat(ImportExportFormat)
    case invalidDirectory(String)
    case emptyWrittenFile(URL)
    case verificationFailed(URL)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedFormat(format):
            return "\(format.rawValue.uppercased()) report document writing is not implemented in this helper."
        case let .invalidDirectory(path):
            return "The report document destination is not a directory: \(path)"
        case let .emptyWrittenFile(url):
            return "The report document was written but is empty: \(url.lastPathComponent)"
        case let .verificationFailed(url):
            return "The report document was written but could not be verified: \(url.lastPathComponent)"
        }
    }
}

public func prepareReportDocumentFile(
    project: Project,
    format: ImportExportFormat,
    directory: URL,
    studentId: String? = nil,
    fileManager: FileManager = .default
) throws -> PreparedReportDocumentFile {
    guard format == .docx else {
        throw ReportDocumentFileError.unsupportedFormat(format)
    }

    try ensureDocumentDirectory(directory, fileManager: fileManager)
    let packet = try prepareReportPacket(project: project, studentId: studentId)
    let filename = try reportExportFilename(project: project, format: format, studentId: studentId)
    let destination = directory.appendingPathComponent(filename, isDirectory: false)
    let headerText = "\(project.metadata.name) \(bullet) \(project.metadata.term)"
    let forbiddenStrings = forbiddenReportExportStrings(project: project)
    let data = try buildReportDocumentDOCX(packet: packet, headerText: headerText)

    try data.write(to: destination, options: [.atomic])
    do {
        let byteCount = try verifiedDocumentSize(url: destination, fileManager: fileManager)
        let readBack = try Data(contentsOf: destination)
        try verifyReportDocumentPackage(readBack, packet: packet, headerText: headerText, forbiddenStrings: forbiddenStrings)
        return PreparedReportDocumentFile(url: destination, byteCount: byteCount, format: format, studentCount: packet.students.count)
    } catch let error as ReportDocumentFileError {
        try? fileManager.removeItem(at: destination)
        throw error
    } catch {
        try? fileManager.removeItem(at: destination)
        throw ReportDocumentFileError.verificationFailed(destination)
    }
}

private let requiredDOCXEntries: Set<String> = [
    "[Content_Types].xml",
    "_rels/.rels",
    "docProps/app.xml",
    "docProps/core.xml",
    "word/document.xml",
    "word/_rels/document.xml.rels",
    "word/footer1.xml",
    "word/header1.xml",
    "word/styles.xml"
]

private let bullet = "\u{2022}"

private func buildReportDocumentDOCX(packet: PreparedReportPacket, headerText: String) throws -> Data {
    let documentXML = reportDocumentXML(packet: packet)
    return try OOXMLZipWriter.archive(entries: [
        OOXMLZipEntry(path: "[Content_Types].xml", data: documentData(documentContentTypesXML)),
        OOXMLZipEntry(path: "_rels/.rels", data: documentData(documentRootRelationshipsXML)),
        OOXMLZipEntry(path: "docProps/app.xml", data: documentData(documentAppPropertiesXML)),
        OOXMLZipEntry(path: "docProps/core.xml", data: documentData(corePropertiesXML(title: packet.title))),
        OOXMLZipEntry(path: "word/document.xml", data: documentData(documentXML)),
        OOXMLZipEntry(path: "word/_rels/document.xml.rels", data: documentData(documentRelationshipsXML)),
        OOXMLZipEntry(path: "word/footer1.xml", data: documentData(footerXML)),
        OOXMLZipEntry(path: "word/header1.xml", data: documentData(headerXML(text: headerText))),
        OOXMLZipEntry(path: "word/styles.xml", data: documentData(documentStylesXML))
    ])
}

private func ensureDocumentDirectory(_ directory: URL, fileManager: FileManager) throws {
    var isDirectory: ObjCBool = false
    if fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
        guard isDirectory.boolValue else {
            throw ReportDocumentFileError.invalidDirectory(directory.path)
        }
        return
    }
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
}

private func verifiedDocumentSize(url: URL, fileManager: FileManager) throws -> UInt64 {
    let attributes = try fileManager.attributesOfItem(atPath: url.path)
    let size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
    guard size > 0 else {
        throw ReportDocumentFileError.emptyWrittenFile(url)
    }
    return size
}

private func verifyReportDocumentPackage(
    _ data: Data,
    packet: PreparedReportPacket,
    headerText: String,
    forbiddenStrings: [String]
) throws {
    try OOXMLZipWriter.validateArchive(data, requiredEntries: requiredDOCXEntries)
    let entries = try OOXMLZipWriter.storedEntries(data)
    guard let document = entries["word/document.xml"].flatMap({ String(data: $0, encoding: .utf8) }),
          let header = entries["word/header1.xml"].flatMap({ String(data: $0, encoding: .utf8) }),
          let footer = entries["word/footer1.xml"].flatMap({ String(data: $0, encoding: .utf8) }),
          document.contains("<w:document"),
          document.contains("<w:body>"),
          document.contains("<w:sectPr>"),
          document.contains("w:headerReference"),
          document.contains("w:footerReference"),
          header.contains("<w:hdr"),
          header.contains(documentEscape(headerText)),
          footer.contains("<w:ftr"),
          footer.contains("PAGE")
    else {
        throw OOXMLZipWriterError.invalidArchive
    }
    if let summary = packet.summary, !document.contains(documentEscape(summary)) {
        throw OOXMLZipWriterError.invalidArchive
    }
    if packet.summary != nil {
        guard document.contains(documentEscape(packet.title)),
              document.contains(documentEscape(packet.subtitle))
        else {
            throw OOXMLZipWriterError.invalidArchive
        }
    }
    for student in packet.students {
        guard document.contains(documentEscape(student.displayName)),
              document.contains(documentEscape(student.detail))
        else {
            throw OOXMLZipWriterError.invalidArchive
        }
        for section in student.sections {
            guard document.contains(documentEscape(section.subject)),
                  document.contains(documentEscape("Achievement: \(section.achievement)"))
            else {
                throw OOXMLZipWriterError.invalidArchive
            }
            if let focus = section.focus,
               !document.contains(documentEscape("Focus: \(focus)")) {
                throw OOXMLZipWriterError.invalidArchive
            }
            for paragraph in section.paragraphs where !document.contains(documentEscape(paragraph)) {
                throw OOXMLZipWriterError.invalidArchive
            }
        }
    }
    try assertXMLPackageOmitsForbiddenStrings(entries: entries, forbiddenStrings: forbiddenStrings)
}

private func documentData(_ xml: String) -> Data {
    Data(xml.utf8)
}

private func forbiddenReportExportStrings(project: Project) -> [String] {
    var values: [String?] = []
    values.append(contentsOf: project.roster.map(\.internalTeacherNote))
    values.append(contentsOf: project.results.map(\.internalTeacherNote))
    for report in project.reports {
        values.append(contentsOf: report.variantIds.map(Optional.some))
        values.append(report.trace)
        values.append(report.resultFingerprint)
        if let manualEdit = report.manualEdit,
           !manualEdit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           manualEdit != report.text {
            values.append(report.text)
        }
    }
    return uniqueForbiddenStrings(values)
}

private func assertXMLPackageOmitsForbiddenStrings(entries: [String: Data], forbiddenStrings: [String]) throws {
    let xmlValues = entries.values.compactMap { String(data: $0, encoding: .utf8) }
    for forbidden in forbiddenStrings {
        let escaped = documentEscape(forbidden)
        if xmlValues.contains(where: { $0.contains(forbidden) || $0.contains(escaped) }) {
            throw OOXMLZipWriterError.invalidArchive
        }
    }
}

private func uniqueForbiddenStrings(_ values: [String?]) -> [String] {
    var seen: Set<String> = []
    return values.compactMap { value in
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard trimmed.count >= 4, seen.insert(trimmed).inserted else { return nil }
        return trimmed
    }
}

private func reportDocumentXML(packet: PreparedReportPacket) -> String {
    var paragraphs: [String] = []
    if let summary = packet.summary {
        paragraphs.append(paragraph(packet.title, style: "Title", alignment: "center"))
        paragraphs.append(paragraph(packet.subtitle, alignment: "center", color: "666666"))
        paragraphs.append(paragraph(summary, alignment: "center"))
    }

    for (studentIndex, student) in packet.students.enumerated() {
        if studentIndex > 0 || packet.summary != nil {
            paragraphs.append(pageBreakParagraph())
        }
        let studentStyle = packet.summary == nil ? "Title" : "Heading1"
        paragraphs.append(paragraph(student.displayName, style: studentStyle))
        paragraphs.append(paragraph(student.detail, color: "666666"))

        student.sections.forEach { section in
            let subjectStyle = packet.summary == nil ? "Heading1" : "Heading2"
            paragraphs.append(paragraph(section.subject, style: subjectStyle))
            let focus = section.focus.map { " \(bullet) Focus: \($0)" } ?? ""
            paragraphs.append(paragraph("Achievement: \(section.achievement)\(focus)", italic: true, color: "666666"))
            section.paragraphs.forEach { text in
                paragraphs.append(paragraph(text))
            }
        }
    }

    return documentXMLPrefix
        + paragraphs.joined()
        + #"<w:sectPr><w:headerReference w:type="default" r:id="rId1"/><w:footerReference w:type="default" r:id="rId2"/><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720" w:header="360" w:footer="360" w:gutter="0"/></w:sectPr>"#
        + documentXMLSuffix
}

private func paragraph(
    _ text: String,
    style: String? = nil,
    alignment: String? = nil,
    italic: Bool = false,
    color: String? = nil
) -> String {
    var properties = ""
    if let style {
        properties += #"<w:pStyle w:val="\#(style)"/>"#
    }
    if let alignment {
        properties += #"<w:jc w:val="\#(alignment)"/>"#
    }
    let paragraphProperties = properties.isEmpty ? "" : "<w:pPr>\(properties)</w:pPr>"
    var runProperties = ""
    if italic {
        runProperties += "<w:i/>"
    }
    if let color {
        runProperties += #"<w:color w:val="\#(color)"/>"#
    }
    let runPropertiesXML = runProperties.isEmpty ? "" : "<w:rPr>\(runProperties)</w:rPr>"
    return #"<w:p>\#(paragraphProperties)<w:r>\#(runPropertiesXML)<w:t xml:space="preserve">\#(documentEscape(text))</w:t></w:r></w:p>"#
}

private func pageBreakParagraph() -> String {
    #"<w:p><w:r><w:br w:type="page"/></w:r></w:p>"#
}

private func headerXML(text: String) -> String {
    documentXMLDeclaration
        + #"<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:rPr><w:color w:val="666666"/><w:sz w:val="18"/></w:rPr><w:t xml:space="preserve">\#(documentEscape(text))</w:t></w:r></w:p></w:hdr>"#
}

private let footerXML = documentXMLDeclaration
    + #"<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:color w:val="666666"/><w:sz w:val="18"/></w:rPr><w:t>Page </w:t></w:r><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText xml:space="preserve">PAGE</w:instrText></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:ftr>"#

private func corePropertiesXML(title: String) -> String {
    documentXMLDeclaration
        + #"<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>\#(documentEscape(title))</dc:title><dc:creator>Commenter</dc:creator><dc:description>Student reports</dc:description></cp:coreProperties>"#
}

private func documentEscape(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&apos;")
}

private let documentXMLDeclaration = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"#

private let documentXMLPrefix = documentXMLDeclaration
    + #"<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:body>"#

private let documentXMLSuffix = "</w:body></w:document>"

private let documentContentTypesXML = documentXMLDeclaration + #"""
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/><Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/></Types>
"""#

private let documentRootRelationshipsXML = documentXMLDeclaration + #"""
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/></Relationships>
"""#

private let documentRelationshipsXML = documentXMLDeclaration + #"""
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>
"""#

private let documentAppPropertiesXML = documentXMLDeclaration + #"""
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"><Application>Commenter</Application></Properties>
"""#

private let documentStylesXML = documentXMLDeclaration + #"""
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:qFormat/><w:pPr><w:jc w:val="center"/><w:spacing w:after="300"/></w:pPr><w:rPr><w:b/><w:sz w:val="36"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:qFormat/><w:pPr><w:spacing w:before="240" w:after="120"/></w:pPr><w:rPr><w:b/><w:sz w:val="28"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:qFormat/><w:pPr><w:spacing w:before="260" w:after="80"/></w:pPr><w:rPr><w:b/><w:sz w:val="24"/></w:rPr></w:style></w:styles>
"""#
