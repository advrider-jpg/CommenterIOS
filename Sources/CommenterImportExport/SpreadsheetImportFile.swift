import CommenterDomain
import CoreXLSX
import Foundation
import OLEKit

public enum SpreadsheetImportFileError: LocalizedError, Equatable {
    case unsupportedFormat(String)
    case emptyFile
    case fileTooLarge(Int)
    case unreadableWorkbook(String)
    case emptyWorkbook(String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedFormat(name):
            return "\(name) import supports CSV, XLSX, and XLS files only."
        case .emptyFile:
            return "The selected file is empty."
        case let .fileTooLarge(maximumKB):
            return "The selected file is too large. The maximum supported size is \(maximumKB) KB."
        case let .unreadableWorkbook(label):
            return "\(label) could not be opened as a workbook."
        case let .emptyWorkbook(label):
            return "The \(label) does not contain a non-empty worksheet."
        }
    }
}

public enum SpreadsheetImportFile {
    public static let maxImportBytes = 8 * 1024 * 1024
    public static let maxWorksheetImportRows = ProjectLimits.results + 1
    public static let maxWorksheetImportColumns = 64
    public static let maxWorkbookEntryBytes = 4 * 1024 * 1024
    public static let maxWorkbookUncompressedBytes = 16 * 1024 * 1024

    public static func parseTabularImportFile(
        url: URL,
        label: String,
        maxRows: Int = CSVParser.maxImportRows
    ) throws -> CSVParseResult {
        let format = try importFormat(for: url, label: label)
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { throw SpreadsheetImportFileError.emptyFile }
        guard data.count <= maxImportBytes else {
            throw SpreadsheetImportFileError.fileTooLarge(maxImportBytes / 1024)
        }

        switch format {
        case .csv:
            guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
                throw CSVParserError.empty(sourceLabel: label)
            }
            return try CSVParser.parseCSV(text, maxRows: maxRows)
        case .xlsx:
            return try parseXLSX(data, label: "\(label) workbook", maxRows: maxRows)
        case .xls:
            return try parseXLS(url, label: "\(label) workbook", maxRows: maxRows)
        case .docx, .backupJSON:
            throw SpreadsheetImportFileError.unsupportedFormat(label)
        }
    }

    public static func importFormat(for url: URL, label: String) throws -> ImportExportFormat {
        let name = url.lastPathComponent.lowercased()
        if name.hasSuffix(".csv") { return .csv }
        if name.hasSuffix(".xlsx") { return .xlsx }
        if name.hasSuffix(".xls") { return .xls }
        if name.range(of: #"\.(xlsm|xlsb|ods|numbers|pdf|docx)$"#, options: .regularExpression) != nil {
            throw SpreadsheetImportFileError.unsupportedFormat(label)
        }
        throw SpreadsheetImportFileError.unsupportedFormat(label)
    }

    public static func parseXLSX(_ data: Data, label: String, maxRows: Int = CSVParser.maxImportRows) throws -> CSVParseResult {
        let file: XLSXFile
        do {
            file = try XLSXFile(data: data)
        } catch {
            return try parseXLSXFallback(data, label: label, maxRows: maxRows)
        }

        do {
            let sharedStrings = try? file.parseSharedStrings()
            for workbook in try file.parseWorkbooks() {
                for (_, path) in try file.parseWorksheetPathsAndNames(workbook: workbook) {
                    let worksheet = try file.parseWorksheet(at: path)
                    let rows = try worksheetRows(worksheet, sharedStrings: sharedStrings, label: label)
                    let normalized = try normalizeWorksheetRows(rows, label: label)
                    if !normalized.isEmpty {
                        return try CSVParser.parseTabularRows(normalized, sourceLabel: label, maxRows: maxRows)
                    }
                }
            }
        } catch {
            return try parseXLSXFallback(data, label: label, maxRows: maxRows)
        }

        throw SpreadsheetImportFileError.emptyWorkbook(label)
    }

    public static func parseXLS(_ url: URL, label: String, maxRows: Int = CSVParser.maxImportRows) throws -> CSVParseResult {
        let stream: Data
        let data = try Data(contentsOf: url)
        let usedFastPath: Bool
        if data.hasOLECompoundFileSignature {
            do {
                stream = try workbookStreamFromCompoundFile(data)
                usedFastPath = true
            } catch {
                usedFastPath = false
                stream = try readOLEWorkbookStream(url, label: label)
            }
        } else {
            usedFastPath = false
            stream = try readOLEWorkbookStream(url, label: label)
        }

        let rows: [[String]]
        do {
            rows = try parseBIFFRows(stream)
        } catch {
            if usedFastPath {
                do {
                    rows = try parseBIFFRows(try readOLEWorkbookStream(url, label: label))
                } catch let fallbackError {
                    if let parserError = error as? CSVParserError {
                        throw parserError
                    }
                    if let parserError = fallbackError as? CSVParserError {
                        throw parserError
                    }
                    throw SpreadsheetImportFileError.unreadableWorkbook(label)
                }
            } else if let parserError = error as? CSVParserError {
                throw parserError
            } else {
                throw SpreadsheetImportFileError.unreadableWorkbook(label)
            }
        }
        let normalized = try normalizeWorksheetRows(rows, label: label)
        guard !normalized.isEmpty else {
            throw SpreadsheetImportFileError.emptyWorkbook(label)
        }
        return try CSVParser.parseTabularRows(normalized, sourceLabel: label, maxRows: maxRows)
    }
}

private func parseXLSXFallback(_ data: Data, label: String, maxRows: Int) throws -> CSVParseResult {
    do {
        return try parseOOXMLWorksheetRows(data, label: label, maxRows: maxRows)
    } catch let error as CSVParserError {
        throw error
    } catch let error as SpreadsheetImportFileError {
        throw error
    } catch {
        throw SpreadsheetImportFileError.unreadableWorkbook(label)
    }
}

private func parseOOXMLWorksheetRows(_ data: Data, label: String, maxRows: Int) throws -> CSVParseResult {
    let entries = try OOXMLZipWriter.storedEntries(
        data,
        maximumEntryBytes: SpreadsheetImportFile.maxWorkbookEntryBytes,
        maximumTotalUncompressedBytes: SpreadsheetImportFile.maxWorkbookUncompressedBytes,
        maximumEntryCount: 64,
        allowedPaths: { path in
            path == "[Content_Types].xml" ||
                path == "_rels/.rels" ||
                path == "xl/workbook.xml" ||
                path == "xl/_rels/workbook.xml.rels" ||
                path == "xl/sharedStrings.xml" ||
                (path.hasPrefix("xl/worksheets/") && path.hasSuffix(".xml"))
        }
    )
    let sharedStrings = parseOOXMLSharedStrings(entries["xl/sharedStrings.xml"])
    let worksheetPaths = entries.keys
        .filter { $0.hasPrefix("xl/worksheets/") && $0.hasSuffix(".xml") }
        .sorted()

    for path in worksheetPaths {
        guard let xml = entries[path]?.stringValue else { continue }
        let rows = try parseOOXMLRows(xml, sharedStrings: sharedStrings, label: label)
        let normalized = try normalizeWorksheetRows(rows, label: label)
        if !normalized.isEmpty {
            return try CSVParser.parseTabularRows(normalized, sourceLabel: label, maxRows: maxRows)
        }
    }
    throw SpreadsheetImportFileError.emptyWorkbook(label)
}

private func parseOOXMLSharedStrings(_ data: Data?) -> [String] {
    guard let xml = data?.stringValue else { return [] }
    return xml.matches(pattern: #"<si\b[^>]*>(.*?)</si>"#).map { item in
        item.matches(pattern: #"<t\b[^>]*>(.*?)</t>"#)
            .map(xmlUnescape)
            .joined()
    }
}

private func parseOOXMLRows(_ xml: String, sharedStrings: [String], label: String) throws -> [[String]] {
    let rawRows = xml.matches(pattern: #"<row\b[^>]*>(.*?)</row>"#)
    guard rawRows.count <= SpreadsheetImportFile.maxWorksheetImportRows else {
        throw CSVParserError.tooManyRows(
            sourceLabel: label,
            count: max(0, rawRows.count - 1),
            maximum: ProjectLimits.results
        )
    }

    return try rawRows.map { rowXML in
        var cellsByIndex: [Int: String] = [:]
        for cellXML in rowXML.matches(pattern: #"<c\b[^>]*>.*?</c>"#) {
            let attributes = cellXML.captured(pattern: #"^<c\b([^>]*)>"#) ?? ""
            let body = cellXML.captured(pattern: #"^<c\b[^>]*>(.*?)</c>$"#) ?? ""
            guard let reference = attributes.captured(pattern: #"\br="([^"]+)""#) else { continue }
            let column = reference.prefix { $0.isLetter }
            let index = try columnIndex(from: String(column), label: label)
            let type = attributes.captured(pattern: #"\bt="([^"]+)""#)
            if type == "inlineStr" {
                cellsByIndex[index] = body.matches(pattern: #"<t\b[^>]*>(.*?)</t>"#).map(xmlUnescape).joined()
            } else if type == "s",
                      let rawIndex = body.captured(pattern: #"<v\b[^>]*>(.*?)</v>"#),
                      let sharedIndex = Int(rawIndex.trimmingCharacters(in: .whitespacesAndNewlines)) {
                guard sharedStrings.indices.contains(sharedIndex) else {
                    throw SpreadsheetImportFileError.unreadableWorkbook(label)
                }
                cellsByIndex[index] = sharedStrings[sharedIndex]
            } else {
                cellsByIndex[index] = xmlUnescape(body.captured(pattern: #"<v\b[^>]*>(.*?)</v>"#) ?? "")
            }
        }
        guard let maxColumn = cellsByIndex.keys.max() else { return [] }
        guard maxColumn < SpreadsheetImportFile.maxWorksheetImportColumns else {
            throw SpreadsheetImportFileError.unreadableWorkbook(label)
        }
        return (0...maxColumn).map { cellsByIndex[$0] ?? "" }
    }
}

private func workbookStreamFromCompoundFile(_ data: Data) throws -> Data {
    let sectorSize = 512

    guard data.count >= sectorSize,
          data.prefix(8) == Data([0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1]),
          data.uint16LE(at: 30) == 9
    else {
        throw LegacyXLSWorkbookError.invalidCompoundFile
    }

    let headerMiniSectorShift = Int(data.uint16LE(at: 32))
    guard headerMiniSectorShift > 0,
          headerMiniSectorShift < 16
    else {
        throw LegacyXLSWorkbookError.invalidCompoundFile
    }

    let miniSectorSize = 1 << headerMiniSectorShift
    let maxFATSectorCount = Int(data.uint32LE(at: 44))
    guard maxFATSectorCount > 0 else {
        throw LegacyXLSWorkbookError.invalidCompoundFile
    }
    let fatTable = try readOLEFatTable(
        data: data,
        sectorSize: sectorSize,
        expectedFATSectorCount: maxFATSectorCount
    )

    let directory = try readOLESectorChain(
        in: data,
        startSector: Int(data.uint32LE(at: 48)),
        sectorSize: sectorSize,
        fat: fatTable
    )
    let directoryEntries = parseOLEDirectoryEntries(Data(directory))

    guard
        let rootEntry = directoryEntries.first(where: { $0.objectType == 5 }),
        let workbookEntry = directoryEntries.first(where: {
            $0.name == "Workbook" || $0.name == "Book"
        })
    else {
        throw LegacyXLSWorkbookError.missingWorkbookStream
    }

    guard workbookEntry.streamSize > 0,
          workbookEntry.streamSize <= SpreadsheetImportFile.maxWorkbookUncompressedBytes,
          workbookEntry.streamSize <= Int.max
    else {
        throw LegacyXLSWorkbookError.invalidCompoundFile
    }

    let miniStreamCutoff = Int(data.uint32LE(at: 56))
    let firstMiniFATSector = Int(data.uint32LE(at: 60))
    let miniFATSectorCount = Int(data.uint32LE(at: 64))
    if workbookEntry.streamSize <= miniStreamCutoff,
       firstMiniFATSector != 0xffffffff,
       miniFATSectorCount > 0,
       rootEntry.streamSize > 0 {
        let miniFAT = try readOLEMiniFAT(
            in: data,
            sectorSize: sectorSize,
            fat: fatTable,
            firstMiniFATSector: firstMiniFATSector,
            miniFATSectorCount: miniFATSectorCount
        )
        let miniStream = try readOLEStream(
            in: data,
            sectorSize: sectorSize,
            startSector: rootEntry.startSector,
            streamSize: rootEntry.streamSize,
            fat: fatTable
        )
        return try readOLEMiniStream(
            miniStream: miniStream,
            miniSectorSize: miniSectorSize,
            miniFAT: miniFAT,
            startSector: workbookEntry.startSector,
            streamSize: workbookEntry.streamSize
        )
    }

    return try readOLEStream(
        in: data,
        sectorSize: sectorSize,
        startSector: workbookEntry.startSector,
        streamSize: workbookEntry.streamSize,
        fat: fatTable
    )
}

private struct OLEDirectoryEntry {
    let name: String
    let objectType: UInt8
    let startSector: Int
    let streamSize: Int
}

private func readOLEFatTable(
    data: Data,
    sectorSize: Int,
    expectedFATSectorCount: Int
) throws -> [UInt32] {
    let startDIFATSector = Int(data.uint32LE(at: 68))
    let extraDIFATSectors = Int(data.uint32LE(at: 72))
    let freeSector: UInt32 = 0xffffffff
    let endOfChain: UInt32 = 0xfffffffe
    let noStream: UInt32 = 0xffffffff

    var fatSectorIndices = Array((0..<109).compactMap { index in
        let sector = data.uint32LE(at: 76 + (index * 4))
        return sector == freeSector ? nil : sector
    })

    var nextDIFAT = startDIFATSector
    var visitedDIFATSectors = Set<Int>()
    var remainingDIFATSectors = extraDIFATSectors
    while remainingDIFATSectors > 0 && nextDIFAT != Int(endOfChain) {
        guard !visitedDIFATSectors.contains(nextDIFAT) else {
            throw LegacyXLSWorkbookError.invalidCompoundFile
        }
        visitedDIFATSectors.insert(nextDIFAT)
        guard nextDIFAT != Int(noStream) else {
            throw LegacyXLSWorkbookError.invalidCompoundFile
        }

        let base = sectorOffset(nextDIFAT, sectorSize: sectorSize)
        let nextBase = base + sectorSize
        guard base >= sectorSize, nextBase <= data.count else {
            throw LegacyXLSWorkbookError.invalidCompoundFile
        }
        for entryOffset in stride(from: base, to: nextBase - 4, by: 4) {
            fatSectorIndices.append(data.uint32LE(at: entryOffset))
        }
        let nextSector = Int(data.uint32LE(at: nextBase - 4))
        remainingDIFATSectors -= 1
        nextDIFAT = nextSector
        if nextSector == Int(endOfChain) {
            break
        }
    }
    if remainingDIFATSectors > 0 && nextDIFAT != Int(endOfChain) {
        throw LegacyXLSWorkbookError.invalidCompoundFile
    }

    guard expectedFATSectorCount <= fatSectorIndices.count else {
        throw LegacyXLSWorkbookError.invalidCompoundFile
    }

    var fat: [UInt32] = []
    for fatSector in fatSectorIndices.prefix(expectedFATSectorCount) {
        if fatSector == freeSector { continue }
        let sector = Int(fatSector)
        guard sector >= 0 && sector != Int(freeSector) else {
            throw LegacyXLSWorkbookError.invalidCompoundFile
        }
        let base = sectorOffset(sector, sectorSize: sectorSize)
        let nextBase = base + sectorSize
        guard base >= sectorSize, nextBase <= data.count else {
            throw LegacyXLSWorkbookError.invalidCompoundFile
        }
        for entryOffset in stride(from: base, to: nextBase, by: 4) {
            fat.append(data.uint32LE(at: entryOffset))
        }
    }
    return fat
}

private func readOLESectorChain(
    in data: Data,
    startSector: Int,
    sectorSize: Int,
    fat: [UInt32]
) throws -> Data {
    let chain = try readOLESectorIndices(startSector: startSector, sectorCountLimit: nil, sectorSize: sectorSize, fat: fat)
    var output = Data()
    for sector in chain {
        let start = sectorOffset(sector, sectorSize: sectorSize)
        let end = start + sectorSize
        guard start >= sectorSize, end <= data.count else {
            throw LegacyXLSWorkbookError.invalidCompoundFile
        }
        output.append(contentsOf: data[start..<end])
    }
    return output
}

private func readOLEStream(
    in data: Data,
    sectorSize: Int,
    startSector: Int,
    streamSize: Int,
    fat: [UInt32]
) throws -> Data {
    let chain = try readOLESectorIndices(startSector: startSector, sectorCountLimit: nil, sectorSize: sectorSize, fat: fat)
    let neededBytes = (chain.count * sectorSize)
    guard streamSize > 0, streamSize <= neededBytes else {
        throw LegacyXLSWorkbookError.invalidCompoundFile
    }

    var stream = Data()
    stream.reserveCapacity(min(neededBytes, SpreadsheetImportFile.maxWorkbookUncompressedBytes))
    for sector in chain {
        let start = sectorOffset(sector, sectorSize: sectorSize)
        let end = start + sectorSize
        guard start >= sectorSize, end <= data.count else {
            throw LegacyXLSWorkbookError.invalidCompoundFile
        }
        stream.append(contentsOf: data[start..<end])
    }
    return Data(stream.prefix(streamSize))
}

private func readOLEMiniFAT(
    in data: Data,
    sectorSize: Int,
    fat: [UInt32],
    firstMiniFATSector: Int,
    miniFATSectorCount: Int
) throws -> [UInt32] {
    guard miniFATSectorCount > 0 else { throw LegacyXLSWorkbookError.invalidCompoundFile }
    let chain = try readOLESectorIndices(
        startSector: firstMiniFATSector,
        sectorCountLimit: miniFATSectorCount,
        sectorSize: sectorSize,
        fat: fat
    )
    guard chain.count == miniFATSectorCount else {
        throw LegacyXLSWorkbookError.invalidCompoundFile
    }
    var entries: [UInt32] = []
    for sector in chain {
        let base = sectorOffset(sector, sectorSize: sectorSize)
        let nextBase = base + sectorSize
        for offset in stride(from: base, to: nextBase, by: 4) {
            entries.append(data.uint32LE(at: offset))
        }
    }
    return entries
}

private func readOLEMiniStream(
    miniStream: Data,
    miniSectorSize: Int,
    miniFAT: [UInt32],
    startSector: Int,
    streamSize: Int
) throws -> Data {
    let chain = try readOLEMiniFATSectorIndices(
        startSector: startSector,
        streamSize: streamSize,
        sectorSize: miniSectorSize,
        miniFAT: miniFAT
    )
    var output = Data()
    output.reserveCapacity(min(streamSize, SpreadsheetImportFile.maxWorkbookUncompressedBytes))
    let maxSectorOffset = miniStream.count - miniSectorSize
    for miniSector in chain {
        let start = miniSector * miniSectorSize
        let end = start + miniSectorSize
        guard start >= 0, end <= miniStream.count, start <= maxSectorOffset else {
            throw LegacyXLSWorkbookError.invalidCompoundFile
        }
        output.append(contentsOf: miniStream[start..<end])
    }
    guard output.count >= streamSize else {
        throw LegacyXLSWorkbookError.invalidCompoundFile
    }
    return Data(output.prefix(streamSize))
}

private func readOLESectorIndices(
    startSector: Int,
    sectorCountLimit: Int?,
    sectorSize: Int,
    fat: [UInt32]
) throws -> [Int] {
    let endOfChain: UInt32 = 0xfffffffe
    let freeSector: UInt32 = 0xffffffff
    let noStream: UInt32 = 0xffffffff
    let fatSector: UInt32 = 0xfffffffd
    let miniFatSector: UInt32 = 0xfffffffc

    guard startSector != 0xfffffffe else { return [] }
    if startSector < 0 || startSector == Int(noStream) {
        throw LegacyXLSWorkbookError.invalidCompoundFile
    }

    var chain: [Int] = []
    var current = UInt32(startSector)
    var visited = Set<UInt32>()
    while current != endOfChain {
        if current == noStream || current == freeSector || current == fatSector || current == miniFatSector {
            throw LegacyXLSWorkbookError.invalidCompoundFile
        }
        if current >= UInt32(fat.count) {
            throw LegacyXLSWorkbookError.invalidCompoundFile
        }
        if !visited.insert(current).inserted {
            throw LegacyXLSWorkbookError.invalidCompoundFile
        }
        chain.append(Int(current))

        if let limit = sectorCountLimit, chain.count > limit {
            throw LegacyXLSWorkbookError.invalidCompoundFile
        }
        current = fat[Int(current)]
    }
    return chain
}

private func readOLEMiniFATSectorIndices(
    startSector: Int,
    streamSize: Int,
    sectorSize: Int,
    miniFAT: [UInt32]
) throws -> [Int] {
    let endOfChain: UInt32 = 0xfffffffe
    let freeSector: UInt32 = 0xffffffff
    let noStream: UInt32 = 0xffffffff

    if streamSize == 0 { return [] }
    if startSector < 0 { throw LegacyXLSWorkbookError.invalidCompoundFile }

    var chain: [Int] = []
    var current = UInt32(startSector)
    var visited = Set<UInt32>()
    let maxNeededSectors = (streamSize + sectorSize - 1) / sectorSize
    while current != endOfChain {
        if current == freeSector || current == noStream { throw LegacyXLSWorkbookError.invalidCompoundFile }
        if current >= UInt32(miniFAT.count) {
            throw LegacyXLSWorkbookError.invalidCompoundFile
        }
        if !visited.insert(current).inserted {
            throw LegacyXLSWorkbookError.invalidCompoundFile
        }
        chain.append(Int(current))
        if chain.count >= maxNeededSectors { break }
        current = miniFAT[Int(current)]
    }
    return chain
}

private func parseOLEDirectoryEntries(_ data: Data) -> [OLEDirectoryEntry] {
    var entries: [OLEDirectoryEntry] = []
    for entryOffset in stride(from: 0, to: data.count, by: 128) {
        let entryEnd = entryOffset + 128
        guard entryEnd <= data.count else { break }
        let entry = Data(data[entryOffset..<entryEnd])
        let name = directoryEntryName(entry)
        if name.isEmpty { continue }
        let streamSizeRaw = entry.uint64LE(at: 120)
        guard streamSizeRaw <= UInt64(Int.max) else { continue }
        entries.append(OLEDirectoryEntry(
            name: name,
            objectType: entry[66],
            startSector: Int(entry.uint32LE(at: 116)),
            streamSize: Int(streamSizeRaw)
        ))
    }
    return entries
}

private func sectorOffset(_ sector: Int, sectorSize: Int) -> Int {
    sectorSize + (sector * sectorSize)
}

private func readOLEWorkbookStream(_ url: URL, label: String) throws -> Data {
    do {
        let ole = try OLEFile(url.path)
        guard let workbook = findOLEEntry(named: "Workbook", in: ole.root) ?? findOLEEntry(named: "Book", in: ole.root) else {
            throw LegacyXLSWorkbookError.missingWorkbookStream
        }
        let stream = try ole.stream(workbook).readDataToEnd()
        guard stream.count <= SpreadsheetImportFile.maxWorkbookUncompressedBytes else {
            throw LegacyXLSWorkbookError.invalidWorkbookStream
        }
        return stream
    } catch let error as LegacyXLSWorkbookError {
        throw error
    } catch {
        throw SpreadsheetImportFileError.unreadableWorkbook(label)
    }
}

private func directoryEntryName(_ entry: Data) -> String {
    let byteCount = Int(entry.uint16LE(at: 64))
    guard byteCount >= 2, byteCount <= 64 else { return "" }
    let units = stride(from: 0, to: byteCount - 2, by: 2).map { entry.uint16LE(at: $0) }
    return String(decoding: units, as: UTF16.self)
}

private func xmlUnescape(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&apos;", with: "'")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&amp;", with: "&")
}

private func normalizeWorksheetRows(_ rawRows: [[String]], label: String) throws -> [[String]] {
    guard rawRows.count <= SpreadsheetImportFile.maxWorksheetImportRows else {
        throw CSVParserError.tooManyRows(
            sourceLabel: label,
            count: max(0, rawRows.count - 1),
            maximum: ProjectLimits.results
        )
    }

    let rows = rawRows.map { row -> [String] in
        var cells = Array(row.prefix(SpreadsheetImportFile.maxWorksheetImportColumns)).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        while cells.last == "" {
            cells.removeLast()
        }
        return cells
    }
    let nonEmpty = rows.filter { row in row.contains { !$0.isEmpty } }
    guard let headerLength = nonEmpty.first?.count, headerLength > 0 else { return [] }
    guard headerLength <= SpreadsheetImportFile.maxWorksheetImportColumns else {
        throw SpreadsheetImportFileError.unreadableWorkbook(label)
    }
    return nonEmpty.map { row in
        row.count < headerLength ? row + Array(repeating: "", count: headerLength - row.count) : Array(row.prefix(headerLength))
    }
}

private func worksheetRows(_ worksheet: Worksheet, sharedStrings: SharedStrings?, label: String) throws -> [[String]] {
    let sourceRows = worksheet.data?.rows ?? []
    guard sourceRows.count <= SpreadsheetImportFile.maxWorksheetImportRows else {
        throw CSVParserError.tooManyRows(
            sourceLabel: label,
            count: max(0, sourceRows.count - 1),
            maximum: ProjectLimits.results
        )
    }

    return try sourceRows.map { row in
        var cellsByIndex: [Int: String] = [:]
        for cell in row.cells {
            let column = try columnIndex(from: cell.reference.column.description, label: label)
            cellsByIndex[column] = try worksheetCellValue(cell, sharedStrings: sharedStrings, label: label)
        }
        guard let maxColumn = cellsByIndex.keys.max() else { return [] }
        guard maxColumn < SpreadsheetImportFile.maxWorksheetImportColumns else {
            throw SpreadsheetImportFileError.unreadableWorkbook(label)
        }
        return (0...maxColumn).map { cellsByIndex[$0] ?? "" }
    }
}

private func worksheetCellValue(_ cell: Cell, sharedStrings: SharedStrings?, label: String) throws -> String {
    switch cell.type {
    case .some(.sharedString):
        guard let sharedStrings, let value = cell.stringValue(sharedStrings) else {
            throw SpreadsheetImportFileError.unreadableWorkbook(label)
        }
        return value
    case .some(.inlineStr):
        return cell.inlineString?.text ?? ""
    default:
        if let sharedStrings, let value = cell.stringValue(sharedStrings) {
            return value
        }
        return cell.value ?? ""
    }
}

private func columnIndex(from column: String, label: String) throws -> Int {
    let normalized = column.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard !normalized.isEmpty, normalized.count <= 3 else {
        throw SpreadsheetImportFileError.unreadableWorkbook(label)
    }

    var value = 0
    for scalar in normalized.unicodeScalars {
        guard (65...90).contains(scalar.value) else {
            throw SpreadsheetImportFileError.unreadableWorkbook(label)
        }
        value = value * 26 + Int(scalar.value - 64)
        guard value <= SpreadsheetImportFile.maxWorksheetImportColumns else {
            throw SpreadsheetImportFileError.unreadableWorkbook(label)
        }
    }
    return value - 1
}

private func findOLEEntry(named name: String, in entry: DirectoryEntry) -> DirectoryEntry? {
    if entry.name == name {
        return entry
    }
    for child in entry.children {
        if let match = findOLEEntry(named: name, in: child) {
            return match
        }
    }
    return nil
}

private func parseBIFFRows(_ stream: Data) throws -> [[String]] {
    var sharedStrings: [String] = []
    var cells: [Int: [Int: String]] = [:]
    var offset = 0
    while offset + 4 <= stream.count {
        let id = stream.uint16LE(at: offset)
        let length = Int(stream.uint16LE(at: offset + 2))
        let payloadStart = offset + 4
        let payloadEnd = payloadStart + length
        guard payloadEnd <= stream.count else { throw LegacyXLSWorkbookError.invalidWorkbookStream }
        let payload = Data(stream[payloadStart..<payloadEnd])

        switch id {
        case 0x00fc:
            sharedStrings = decodeSST(payload)
        case 0x0204:
            if payload.count >= 9, let value = decodeXLUnicodeString(payload, offset: 6) {
                try storeBIFFCell(value, rowIndex: Int(payload.uint16LE(at: 0)), columnIndex: Int(payload.uint16LE(at: 2)), cells: &cells)
            }
        case 0x00fd:
            if payload.count >= 10 {
                let index = Int(payload.uint32LE(at: 6))
                if sharedStrings.indices.contains(index) {
                    try storeBIFFCell(sharedStrings[index], rowIndex: Int(payload.uint16LE(at: 0)), columnIndex: Int(payload.uint16LE(at: 2)), cells: &cells)
                }
            }
        case 0x0203:
            if payload.count >= 14 {
                let value = payload.doubleLE(at: 6)
                try storeBIFFCell(numberString(value), rowIndex: Int(payload.uint16LE(at: 0)), columnIndex: Int(payload.uint16LE(at: 2)), cells: &cells)
            }
        case 0x000a:
            break
        default:
            break
        }
        offset = payloadEnd
    }

    guard let maxRow = cells.keys.max() else { return [] }
    guard maxRow < SpreadsheetImportFile.maxWorksheetImportRows else {
        throw CSVParserError.tooManyRows(
            sourceLabel: "workbook",
            count: maxRow,
            maximum: ProjectLimits.results
        )
    }
    return try (0...maxRow).map { rowIndex in
        let row = cells[rowIndex] ?? [:]
        guard let maxColumn = row.keys.max() else { return [] }
        guard maxColumn < SpreadsheetImportFile.maxWorksheetImportColumns else {
            throw LegacyXLSWorkbookError.invalidWorkbookStream
        }
        return (0...maxColumn).map { row[$0] ?? "" }
    }
}

private func storeBIFFCell(
    _ value: String,
    rowIndex: Int,
    columnIndex: Int,
    cells: inout [Int: [Int: String]]
) throws {
    guard rowIndex >= 0, rowIndex < SpreadsheetImportFile.maxWorksheetImportRows,
          columnIndex >= 0, columnIndex < SpreadsheetImportFile.maxWorksheetImportColumns
    else {
        throw LegacyXLSWorkbookError.invalidWorkbookStream
    }
    cells[rowIndex, default: [:]][columnIndex] = value
}

private func decodeSST(_ payload: Data) -> [String] {
    guard payload.count >= 8 else { return [] }
    let count = min(Int(payload.uint32LE(at: 4)), ProjectLimits.results * SpreadsheetImportFile.maxWorksheetImportColumns)
    var strings: [String] = []
    var offset = 8
    while offset < payload.count, strings.count < count {
        guard let decoded = decodeXLUnicodeStringWithLength(payload, offset: offset) else { break }
        strings.append(decoded.value)
        offset = decoded.nextOffset
    }
    return strings
}

private func decodeXLUnicodeString(_ payload: Data, offset: Int) -> String? {
    decodeXLUnicodeStringWithLength(payload, offset: offset)?.value
}

private func decodeXLUnicodeStringWithLength(_ payload: Data, offset: Int) -> (value: String, nextOffset: Int)? {
    guard offset + 3 <= payload.count else { return nil }
    let length = Int(payload.uint16LE(at: offset))
    let flags = payload[offset + 2]
    let start = offset + 3
    if flags & 0x01 == 0 {
        guard length <= ProjectLimits.resultFreeTextCharacters,
              start + length <= payload.count
        else { return nil }
        return (String(bytes: payload[start..<start + length], encoding: .utf8) ?? "", start + length)
    }
    guard length <= ProjectLimits.resultFreeTextCharacters,
          start + (length * 2) <= payload.count
    else { return nil }
    let units = stride(from: start, to: start + (length * 2), by: 2).map { payload.uint16LE(at: $0) }
    return (String(decoding: units, as: UTF16.self), start + (length * 2))
}

private func numberString(_ value: Double) -> String {
    guard value.isFinite else { return "" }
    if value.rounded() == value,
       value >= Double(Int64.min),
       value <= Double(Int64.max) {
        return String(Int64(value))
    }
    return String(value)
}

private extension Data {
    var stringValue: String? {
        String(data: self, encoding: .utf8) ?? String(data: self, encoding: .utf16)
    }

    var hasOLECompoundFileSignature: Bool {
        count >= 8 && prefix(8) == Data([0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1])
    }

    func uint16LE(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func uint32LE(at offset: Int) -> UInt32 {
        UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }

    func uint64LE(at offset: Int) -> UInt64 {
        UInt64(uint32LE(at: offset)) | (UInt64(uint32LE(at: offset + 4)) << 32)
    }

    func doubleLE(at offset: Int) -> Double {
        let byte0 = UInt64(self[offset])
        let byte1 = UInt64(self[offset + 1]) << 8
        let byte2 = UInt64(self[offset + 2]) << 16
        let byte3 = UInt64(self[offset + 3]) << 24
        let byte4 = UInt64(self[offset + 4]) << 32
        let byte5 = UInt64(self[offset + 5]) << 40
        let byte6 = UInt64(self[offset + 6]) << 48
        let byte7 = UInt64(self[offset + 7]) << 56
        let bits = byte0 | byte1 | byte2 | byte3 | byte4 | byte5 | byte6 | byte7
        return Double(bitPattern: bits)
    }
}

private extension String {
    func matches(pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }
        let nsRange = NSRange(startIndex..<endIndex, in: self)
        return regex.matches(in: self, range: nsRange).compactMap { match in
            let range = match.numberOfRanges > 1 ? match.range(at: 1) : match.range(at: 0)
            guard range.location != NSNotFound, let swiftRange = Range(range, in: self) else { return nil }
            return String(self[swiftRange])
        }
    }

    func captured(pattern: String) -> String? {
        matches(pattern: pattern).first
    }
}
