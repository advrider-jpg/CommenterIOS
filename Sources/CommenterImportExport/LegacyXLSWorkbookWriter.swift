import Foundation

enum LegacyXLSWorkbookError: LocalizedError, Equatable {
    case tooManyRows(Int)
    case tooManyColumns(Int)
    case cellTextTooLarge
    case workbookTooLarge
    case invalidCompoundFile
    case missingWorkbookStream
    case invalidWorkbookStream

    var errorDescription: String? {
        switch self {
        case let .tooManyRows(count):
            return "Legacy XLS supports at most 65,536 rows; this workbook has \(count)."
        case let .tooManyColumns(count):
            return "Legacy XLS supports at most 256 columns; this workbook has \(count)."
        case .cellTextTooLarge:
            return "One cell is too large for the legacy XLS BIFF record limit."
        case .workbookTooLarge:
            return "The legacy XLS workbook is too large to write safely."
        case .invalidCompoundFile:
            return "The generated file is not a valid OLE compound file."
        case .missingWorkbookStream:
            return "The generated OLE compound file does not contain a Workbook stream."
        case .invalidWorkbookStream:
            return "The generated Workbook stream is not valid BIFF data."
        }
    }
}

enum LegacyXLSWorkbookWriter {
    private static let sectorSize = 512
    private static let maxBIFFRecordPayload = 8_224
    private static let freeSector: UInt32 = 0xffffffff
    private static let endOfChain: UInt32 = 0xfffffffe
    private static let fatSector: UInt32 = 0xfffffffd
    private static let noStream: UInt32 = 0xffffffff

    static func workbook(rows: [[String]], sheetName: String) throws -> Data {
        guard rows.count <= 65_536 else { throw LegacyXLSWorkbookError.tooManyRows(rows.count) }
        let maxColumns = rows.map(\.count).max() ?? 0
        guard maxColumns <= 256 else { throw LegacyXLSWorkbookError.tooManyColumns(maxColumns) }

        let workbookStream = try biffWorkbookStream(rows: rows, sheetName: sheetName)
        return try compoundFile(workbookStream: workbookStream)
    }

    static func validateWorkbook(_ data: Data, requiredSheetName: String, requiredStrings: [String]) throws {
        let stream = try workbookStream(from: data)
        guard stream.count >= 4, stream.uint16LE(at: 0) == 0x0809 else {
            throw LegacyXLSWorkbookError.invalidWorkbookStream
        }

        let records = try biffRecords(stream)
        guard records.contains(where: { $0.id == 0x0085 && decodeBoundSheetName($0.payload) == requiredSheetName }) else {
            throw LegacyXLSWorkbookError.invalidWorkbookStream
        }
        let sheetOffsets = records.compactMap { record -> Int? in
            guard record.id == 0x0085, record.payload.count >= 4 else { return nil }
            return Int(record.payload.uint32LE(at: 0))
        }
        guard sheetOffsets.contains(where: { offset in
            offset + 4 <= stream.count && stream.uint16LE(at: offset) == 0x0809
        }) else {
            throw LegacyXLSWorkbookError.invalidWorkbookStream
        }

        let labels = records.compactMap { record -> String? in
            guard record.id == 0x0204, record.payload.count >= 9 else { return nil }
            return decodeXLUnicodeString(record.payload, offset: 6)
        }
        for required in requiredStrings {
            guard labels.contains(required) else {
                throw LegacyXLSWorkbookError.invalidWorkbookStream
            }
        }
    }

    private static func biffWorkbookStream(rows: [[String]], sheetName: String) throws -> Data {
        let sheet = try worksheetStream(rows: rows)
        let globalsWithoutOffset = try globalsStream(sheetOffset: 0, sheetName: sheetName)
        let globals = try globalsStream(sheetOffset: UInt32(globalsWithoutOffset.count), sheetName: sheetName)
        var stream = Data()
        stream.append(globals)
        stream.append(sheet)
        return stream
    }

    private static func globalsStream(sheetOffset: UInt32, sheetName: String) throws -> Data {
        var globals = Data()
        globals.append(try biffRecord(0x0809, payload: bofPayload(documentType: 0x0005)))
        globals.append(try biffRecord(0x0042, payload: uint16Data(0x04b0)))
        globals.append(try biffRecord(0x003d, payload: window1Payload()))
        globals.append(try biffRecord(0x0085, payload: boundsheetPayload(sheetOffset: sheetOffset, sheetName: sheetName)))
        globals.append(try biffRecord(0x000a, payload: Data()))
        return globals
    }

    private static func worksheetStream(rows: [[String]]) throws -> Data {
        var sheet = Data()
        sheet.append(try biffRecord(0x0809, payload: bofPayload(documentType: 0x0010)))
        sheet.append(try biffRecord(0x0200, payload: dimensionsPayload(rowCount: rows.count, columnCount: rows.map(\.count).max() ?? 0)))
        for (rowIndex, row) in rows.enumerated() {
            for (columnIndex, value) in row.enumerated() {
                sheet.append(try biffRecord(0x0204, payload: labelPayload(row: rowIndex, column: columnIndex, value: value)))
            }
        }
        sheet.append(try biffRecord(0x000a, payload: Data()))
        return sheet
    }

    private static func bofPayload(documentType: UInt16) -> Data {
        var payload = Data()
        payload.appendUInt16LE(0x0600)
        payload.appendUInt16LE(documentType)
        payload.appendUInt16LE(0x0dbb)
        payload.appendUInt16LE(0x07cc)
        payload.appendUInt32LE(0)
        payload.appendUInt32LE(0x00000600)
        return payload
    }

    private static func window1Payload() -> Data {
        var payload = Data()
        [UInt16(0), 0, 16_000, 9_000, 0x0038, 0, 0, 1, 500].forEach { payload.appendUInt16LE($0) }
        return payload
    }

    private static func boundsheetPayload(sheetOffset: UInt32, sheetName: String) -> Data {
        let safeName = safeSheetName(sheetName)
        var payload = Data()
        payload.appendUInt32LE(sheetOffset)
        payload.appendUInt8(0)
        payload.appendUInt8(0)
        payload.appendUInt8(UInt8(safeName.count))
        payload.appendUInt8(0)
        payload.append(Data(safeName.utf8))
        return payload
    }

    private static func dimensionsPayload(rowCount: Int, columnCount: Int) -> Data {
        var payload = Data()
        payload.appendUInt32LE(0)
        payload.appendUInt32LE(UInt32(rowCount))
        payload.appendUInt16LE(0)
        payload.appendUInt16LE(UInt16(columnCount))
        payload.appendUInt16LE(0)
        return payload
    }

    private static func labelPayload(row: Int, column: Int, value: String) throws -> Data {
        var payload = Data()
        payload.appendUInt16LE(UInt16(row))
        payload.appendUInt16LE(UInt16(column))
        payload.appendUInt16LE(0)
        payload.append(try xlUnicodeString(value))
        return payload
    }

    private static func xlUnicodeString(_ value: String) throws -> Data {
        let utf16 = Array(value.utf16)
        guard utf16.count <= Int(UInt16.max) else { throw LegacyXLSWorkbookError.cellTextTooLarge }
        var payload = Data()
        payload.appendUInt16LE(UInt16(utf16.count))
        if utf16.allSatisfy({ $0 <= 0x00ff }) {
            payload.appendUInt8(0)
            payload.append(contentsOf: utf16.map { UInt8($0 & 0x00ff) })
        } else {
            payload.appendUInt8(1)
            utf16.forEach { payload.appendUInt16LE($0) }
        }
        return payload
    }

    private static func biffRecord(_ id: UInt16, payload: Data) throws -> Data {
        guard payload.count <= maxBIFFRecordPayload else { throw LegacyXLSWorkbookError.cellTextTooLarge }
        var record = Data()
        record.appendUInt16LE(id)
        record.appendUInt16LE(UInt16(payload.count))
        record.append(payload)
        return record
    }

    private static func compoundFile(workbookStream: Data) throws -> Data {
        guard workbookStream.count <= Int(UInt32.max) else { throw LegacyXLSWorkbookError.workbookTooLarge }
        let workbookSectorCount = max(1, sectorCount(for: workbookStream.count))
        var fatSectorCount = 1
        while true {
            let totalSectors = workbookSectorCount + fatSectorCount + 1
            let requiredFATSectors = sectorCount(for: totalSectors * 4)
            if requiredFATSectors == fatSectorCount { break }
            fatSectorCount = requiredFATSectors
            guard fatSectorCount <= 109 else { throw LegacyXLSWorkbookError.workbookTooLarge }
        }

        let fatStart = workbookSectorCount
        let directorySector = workbookSectorCount + fatSectorCount
        let totalSectors = directorySector + 1
        guard totalSectors <= Int(UInt32.max) else { throw LegacyXLSWorkbookError.workbookTooLarge }

        var data = compoundHeader(fatSectors: (0..<fatSectorCount).map { UInt32(fatStart + $0) }, directorySector: UInt32(directorySector))
        data.append(paddedSectorData(workbookStream))
        data.append(fatData(workbookSectorCount: workbookSectorCount, fatSectorCount: fatSectorCount, totalSectors: totalSectors))
        data.append(directoryData(workbookStartSector: 0, workbookSize: workbookStream.count))
        return data
    }

    private static func compoundHeader(fatSectors: [UInt32], directorySector: UInt32) -> Data {
        var header = Data()
        header.append(Data([0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1]))
        header.append(Data(repeating: 0, count: 16))
        header.appendUInt16LE(0x003e)
        header.appendUInt16LE(0x0003)
        header.appendUInt16LE(0xfffe)
        header.appendUInt16LE(9)
        header.appendUInt16LE(6)
        header.append(Data(repeating: 0, count: 6))
        header.appendUInt32LE(0)
        header.appendUInt32LE(UInt32(fatSectors.count))
        header.appendUInt32LE(directorySector)
        header.appendUInt32LE(0)
        header.appendUInt32LE(4096)
        header.appendUInt32LE(endOfChain)
        header.appendUInt32LE(0)
        header.appendUInt32LE(endOfChain)
        header.appendUInt32LE(0)
        fatSectors.forEach { header.appendUInt32LE($0) }
        for _ in fatSectors.count..<109 { header.appendUInt32LE(freeSector) }
        return header
    }

    private static func fatData(workbookSectorCount: Int, fatSectorCount: Int, totalSectors: Int) -> Data {
        var entries: [UInt32] = []
        for index in 0..<workbookSectorCount {
            entries.append(index == workbookSectorCount - 1 ? endOfChain : UInt32(index + 1))
        }
        for _ in 0..<fatSectorCount { entries.append(fatSector) }
        entries.append(endOfChain)
        while entries.count < totalSectors { entries.append(freeSector) }

        let paddedCount = sectorCount(for: entries.count * 4) * sectorSize / 4
        while entries.count < paddedCount { entries.append(freeSector) }
        var data = Data()
        entries.forEach { data.appendUInt32LE($0) }
        return data
    }

    private static func directoryData(workbookStartSector: UInt32, workbookSize: Int) -> Data {
        var directory = Data()
        directory.append(directoryEntry(name: "Root Entry", objectType: 5, childId: 1, startSector: endOfChain, streamSize: 0))
        directory.append(directoryEntry(name: "Workbook", objectType: 2, childId: noStream, startSector: workbookStartSector, streamSize: UInt64(workbookSize)))
        while directory.count < sectorSize { directory.append(Data(repeating: 0, count: 128)) }
        return Data(directory.prefix(sectorSize))
    }

    private static func directoryEntry(name: String, objectType: UInt8, childId: UInt32, startSector: UInt32, streamSize: UInt64) -> Data {
        var entry = Data()
        let nameBytes = compoundDirectoryName(name)
        entry.append(nameBytes)
        entry.append(Data(repeating: 0, count: 64 - nameBytes.count))
        entry.appendUInt16LE(UInt16(nameBytes.count))
        entry.appendUInt8(objectType)
        entry.appendUInt8(1)
        entry.appendUInt32LE(noStream)
        entry.appendUInt32LE(noStream)
        entry.appendUInt32LE(childId)
        entry.append(Data(repeating: 0, count: 16))
        entry.appendUInt32LE(0)
        entry.appendUInt64LE(0)
        entry.appendUInt64LE(0)
        entry.appendUInt32LE(startSector)
        entry.appendUInt64LE(streamSize)
        return entry
    }

    private static func workbookStream(from data: Data) throws -> Data {
        guard data.count >= sectorSize,
              data.prefix(8) == Data([0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1]),
              data.uint16LE(at: 30) == 9
        else {
            throw LegacyXLSWorkbookError.invalidCompoundFile
        }
        let firstDirectorySector = Int(data.uint32LE(at: 48))
        let directoryOffset = sectorOffset(firstDirectorySector)
        guard directoryOffset + sectorSize <= data.count else {
            throw LegacyXLSWorkbookError.invalidCompoundFile
        }
        let directory = data[directoryOffset..<directoryOffset + sectorSize]
        for entryOffset in stride(from: 0, to: directory.count, by: 128) {
            let entry = Data(directory[entryOffset..<entryOffset + 128])
            if directoryEntryName(entry) == "Workbook" {
                let startSector = Int(entry.uint32LE(at: 116))
                let streamSize = Int(entry.uint64LE(at: 120))
                let streamOffset = sectorOffset(startSector)
                guard streamSize > 0, streamOffset + streamSize <= data.count else {
                    throw LegacyXLSWorkbookError.invalidCompoundFile
                }
                return Data(data[streamOffset..<streamOffset + streamSize])
            }
        }
        throw LegacyXLSWorkbookError.missingWorkbookStream
    }

    private static func biffRecords(_ stream: Data) throws -> [(id: UInt16, payload: Data)] {
        var records: [(id: UInt16, payload: Data)] = []
        var offset = 0
        while offset + 4 <= stream.count {
            let id = stream.uint16LE(at: offset)
            let length = Int(stream.uint16LE(at: offset + 2))
            let payloadStart = offset + 4
            let payloadEnd = payloadStart + length
            guard payloadEnd <= stream.count else { throw LegacyXLSWorkbookError.invalidWorkbookStream }
            records.append((id: id, payload: Data(stream[payloadStart..<payloadEnd])))
            offset = payloadEnd
        }
        guard records.contains(where: { $0.id == 0x000a }) else {
            throw LegacyXLSWorkbookError.invalidWorkbookStream
        }
        return records
    }

    private static func decodeBoundSheetName(_ payload: Data) -> String? {
        guard payload.count >= 8 else { return nil }
        let length = Int(payload[6])
        let flags = payload[7]
        let start = 8
        if flags & 0x01 == 0 {
            guard start + length <= payload.count else { return nil }
            return String(bytes: payload[start..<start + length], encoding: .utf8)
        }
        guard start + (length * 2) <= payload.count else { return nil }
        return String(decoding: stride(from: start, to: start + (length * 2), by: 2).map { payload.uint16LE(at: $0) }, as: UTF16.self)
    }

    private static func decodeXLUnicodeString(_ payload: Data, offset: Int) -> String? {
        guard offset + 3 <= payload.count else { return nil }
        let length = Int(payload.uint16LE(at: offset))
        let flags = payload[offset + 2]
        let start = offset + 3
        if flags & 0x01 == 0 {
            guard start + length <= payload.count else { return nil }
            return String(bytes: payload[start..<start + length], encoding: .utf8)
        }
        guard start + (length * 2) <= payload.count else { return nil }
        return String(decoding: stride(from: start, to: start + (length * 2), by: 2).map { payload.uint16LE(at: $0) }, as: UTF16.self)
    }

    private static func safeSheetName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: #"\/?*[]:"#)
        let cleaned = String(name.unicodeScalars.map { invalid.contains($0) ? " " : Character($0) })
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String((cleaned.isEmpty ? "Sheet" : cleaned).prefix(31))
    }

    private static func compoundDirectoryName(_ name: String) -> Data {
        var data = Data()
        Array((name + "\0").utf16).forEach { data.appendUInt16LE($0) }
        return data
    }

    private static func directoryEntryName(_ entry: Data) -> String {
        let byteCount = Int(entry.uint16LE(at: 64))
        guard byteCount >= 2, byteCount <= 64 else { return "" }
        let units = stride(from: 0, to: byteCount - 2, by: 2).map { entry.uint16LE(at: $0) }
        return String(decoding: units, as: UTF16.self)
    }

    private static func sectorCount(for byteCount: Int) -> Int {
        max(1, (byteCount + sectorSize - 1) / sectorSize)
    }

    private static func sectorOffset(_ sector: Int) -> Int {
        sectorSize + (sector * sectorSize)
    }

    private static func paddedSectorData(_ data: Data) -> Data {
        var padded = data
        let remainder = padded.count % sectorSize
        if remainder != 0 {
            padded.append(Data(repeating: 0, count: sectorSize - remainder))
        }
        return padded
    }

    private static func uint16Data(_ value: UInt16) -> Data {
        var data = Data()
        data.appendUInt16LE(value)
        return data
    }
}

private extension Data {
    mutating func appendUInt8(_ value: UInt8) {
        append(value)
    }

    mutating func appendUInt16LE(_ value: UInt16) {
        var littleEndian = value.littleEndian
        append(Swift.withUnsafeBytes(of: &littleEndian) { Data($0) })
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        var littleEndian = value.littleEndian
        append(Swift.withUnsafeBytes(of: &littleEndian) { Data($0) })
    }

    mutating func appendUInt64LE(_ value: UInt64) {
        var littleEndian = value.littleEndian
        append(Swift.withUnsafeBytes(of: &littleEndian) { Data($0) })
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
}
