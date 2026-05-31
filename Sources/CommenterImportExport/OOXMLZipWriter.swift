import Foundation
import ZIPFoundation

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
        var seen: Set<String> = []
        let archive = try Archive(data: Data(), accessMode: .create)

        for entry in entries {
            guard seen.insert(entry.path).inserted else {
                throw OOXMLZipWriterError.duplicateEntry(entry.path)
            }
            let pathBytes = Data(entry.path.utf8)
            guard entry.data.count <= Int(UInt32.max), pathBytes.count <= Int(UInt16.max) else {
                throw OOXMLZipWriterError.entryTooLarge(entry.path)
            }

            try archive.addEntry(
                with: entry.path,
                type: .file,
                uncompressedSize: Int64(entry.data.count),
                bufferSize: 32_768,
                provider: { position, size in
                    let start = Int(position)
                    guard start <= entry.data.count else { return Data() }
                    let end = min(start + size, entry.data.count)
                    return entry.data.subdata(in: start..<end)
                }
            )
        }

        guard let data = archive.data, data.count <= Int(UInt32.max), entries.count <= Int(UInt16.max) else {
            throw OOXMLZipWriterError.archiveTooLarge
        }

        return data
    }

    static func validateArchive(_ data: Data, requiredEntries: Set<String>) throws {
        let entries = try storedEntries(data)
        let missing = requiredEntries.subtracting(entries.keys)
        if let missing = missing.sorted().first {
            throw OOXMLZipWriterError.missingRequiredEntry(missing)
        }
    }

    static func storedEntries(_ data: Data) throws -> [String: Data] {
        do {
            let archive = try Archive(data: data, accessMode: .read)
            var entries: [String: Data] = [:]
            for entry in archive {
                var extracted = Data()
                _ = try archive.extract(entry, consumer: { chunk in
                    extracted.append(chunk)
                })
                entries[entry.path] = extracted
            }

            return entries
        } catch {
            throw OOXMLZipWriterError.invalidArchive
        }
    }
}
