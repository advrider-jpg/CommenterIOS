import Foundation

enum OOXMLZipWriterError: LocalizedError, Equatable {
    case duplicateEntry(String)
    case entryTooLarge(String)
    case archiveTooLarge
    case invalidArchive
    case missingRequiredEntry(String)

    var errorDescription: String? {
        switch self {
        case let .duplicateEntry(path):
            return "The OOXML package contains a duplicate entry: \(path)"
        case let .entryTooLarge(path):
            return "The OOXML package entry is too large: \(path)"
        case .archiveTooLarge:
            return "The OOXML package is too large."
        case .invalidArchive:
            return "The OOXML package is not a readable ZIP archive."
        case let .missingRequiredEntry(path):
            return "The OOXML package is missing a required entry: \(path)"
        }
    }
}

struct OOXMLZipEntry: Equatable {
    var path: String
    var data: Data
}

enum OOXMLZipWriter {
    static func archive(entries: [OOXMLZipEntry]) throws -> Data {
        var archive = Data()
        var centralDirectory = Data()
        var seen: Set<String> = []
        let dosTime: UInt16 = 0
        let dosDate: UInt16 = 33

        for entry in entries {
            guard seen.insert(entry.path).inserted else {
                throw OOXMLZipWriterError.duplicateEntry(entry.path)
            }
            let pathBytes = Data(entry.path.utf8)
            guard entry.data.count <= Int(UInt32.max), pathBytes.count <= Int(UInt16.max) else {
                throw OOXMLZipWriterError.entryTooLarge(entry.path)
            }
            guard archive.count <= Int(UInt32.max) else {
                throw OOXMLZipWriterError.archiveTooLarge
            }

            let offset = UInt32(archive.count)
            let crc = CRC32.checksum(entry.data)
            let size = UInt32(entry.data.count)
            let pathLength = UInt16(pathBytes.count)

            archive.appendUInt32LE(0x04034b50)
            archive.appendUInt16LE(20)
            archive.appendUInt16LE(0)
            archive.appendUInt16LE(0)
            archive.appendUInt16LE(dosTime)
            archive.appendUInt16LE(dosDate)
            archive.appendUInt32LE(crc)
            archive.appendUInt32LE(size)
            archive.appendUInt32LE(size)
            archive.appendUInt16LE(pathLength)
            archive.appendUInt16LE(0)
            archive.append(pathBytes)
            archive.append(entry.data)

            centralDirectory.appendUInt32LE(0x02014b50)
            centralDirectory.appendUInt16LE(20)
            centralDirectory.appendUInt16LE(20)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(dosTime)
            centralDirectory.appendUInt16LE(dosDate)
            centralDirectory.appendUInt32LE(crc)
            centralDirectory.appendUInt32LE(size)
            centralDirectory.appendUInt32LE(size)
            centralDirectory.appendUInt16LE(pathLength)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt32LE(0)
            centralDirectory.appendUInt32LE(offset)
            centralDirectory.append(pathBytes)
        }

        guard centralDirectory.count <= Int(UInt32.max), archive.count <= Int(UInt32.max), entries.count <= Int(UInt16.max) else {
            throw OOXMLZipWriterError.archiveTooLarge
        }

        let centralDirectoryOffset = UInt32(archive.count)
        archive.append(centralDirectory)
        archive.appendUInt32LE(0x06054b50)
        archive.appendUInt16LE(0)
        archive.appendUInt16LE(0)
        archive.appendUInt16LE(UInt16(entries.count))
        archive.appendUInt16LE(UInt16(entries.count))
        archive.appendUInt32LE(UInt32(centralDirectory.count))
        archive.appendUInt32LE(centralDirectoryOffset)
        archive.appendUInt16LE(0)
        return archive
    }

    static func validateArchive(_ data: Data, requiredEntries: Set<String>) throws {
        let entries = try storedEntries(data)
        let missing = requiredEntries.subtracting(entries.keys)
        if let missing = missing.sorted().first {
            throw OOXMLZipWriterError.missingRequiredEntry(missing)
        }
    }

    static func storedEntries(_ data: Data) throws -> [String: Data] {
        try validateEndOfCentralDirectory(data)
        var entries: [String: Data] = [:]
        var offset = 0
        while offset + 30 <= data.count {
            guard data.uint32LE(at: offset) == 0x04034b50 else { break }
            let compressionMethod = data.uint16LE(at: offset + 8)
            let compressedSize = Int(data.uint32LE(at: offset + 18))
            let uncompressedSize = Int(data.uint32LE(at: offset + 22))
            let nameLength = Int(data.uint16LE(at: offset + 26))
            let extraLength = Int(data.uint16LE(at: offset + 28))
            let nameStart = offset + 30
            let nameEnd = nameStart + nameLength
            let dataStart = nameEnd + extraLength
            let dataEnd = dataStart + compressedSize
            guard compressionMethod == 0,
                  compressedSize == uncompressedSize,
                  nameEnd <= data.count,
                  dataEnd <= data.count
            else {
                throw OOXMLZipWriterError.invalidArchive
            }
            let path = String(decoding: data[nameStart..<nameEnd], as: UTF8.self)
            entries[path] = Data(data[dataStart..<dataEnd])
            offset = dataEnd
        }

        return entries
    }

    private static func validateEndOfCentralDirectory(_ data: Data) throws {
        guard data.count >= 22 else {
            throw OOXMLZipWriterError.invalidArchive
        }
        let eocdOffset = data.count - 22
        guard data.uint32LE(at: eocdOffset) == 0x06054b50 else {
            throw OOXMLZipWriterError.invalidArchive
        }
        let centralDirectorySize = Int(data.uint32LE(at: eocdOffset + 12))
        let centralDirectoryOffset = Int(data.uint32LE(at: eocdOffset + 16))
        guard centralDirectoryOffset >= 0,
              centralDirectorySize >= 0,
              centralDirectoryOffset + centralDirectorySize <= eocdOffset,
              centralDirectorySize == 0 || (centralDirectorySize >= 4 && data.uint32LE(at: centralDirectoryOffset) == 0x02014b50)
        else {
            throw OOXMLZipWriterError.invalidArchive
        }
    }
}

private enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { index in
        var crc = UInt32(index)
        for _ in 0..<8 {
            if crc & 1 == 1 {
                crc = (crc >> 1) ^ 0xedb88320
            } else {
                crc >>= 1
            }
        }
        return crc
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xff)] ^ (crc >> 8)
        }
        return crc ^ 0xffffffff
    }
}

private extension Data {
    mutating func appendUInt16LE(_ value: UInt16) {
        var littleEndian = value.littleEndian
        let bytes = Swift.withUnsafeBytes(of: &littleEndian) { Data($0) }
        append(bytes)
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        var littleEndian = value.littleEndian
        let bytes = Swift.withUnsafeBytes(of: &littleEndian) { Data($0) }
        append(bytes)
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
}
