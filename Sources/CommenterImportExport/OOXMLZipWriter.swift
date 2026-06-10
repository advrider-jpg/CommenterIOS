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
    static let defaultMaximumEntryBytes = 2 * 1024 * 1024
    static let defaultMaximumTotalUncompressedBytes = 8 * 1024 * 1024
    static let defaultMaximumEntryCount = 128

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
        let entries = try storedEntries(
            data,
            maximumEntryBytes: 64 * 1024 * 1024,
            maximumTotalUncompressedBytes: 128 * 1024 * 1024,
            maximumEntryCount: max(requiredEntries.count, 1),
            allowedPaths: { requiredEntries.contains($0) }
        )
        let missing = requiredEntries.subtracting(entries.keys)
        if let missing = missing.sorted().first {
            throw OOXMLZipWriterError.missingRequiredEntry(missing)
        }
    }

    static func storedEntries(
        _ data: Data,
        maximumEntryBytes: Int = defaultMaximumEntryBytes,
        maximumTotalUncompressedBytes: Int = defaultMaximumTotalUncompressedBytes,
        maximumEntryCount: Int = defaultMaximumEntryCount,
        allowedPaths: ((String) -> Bool)? = nil
    ) throws -> [String: Data] {
        guard maximumEntryBytes > 0, maximumTotalUncompressedBytes > 0, maximumEntryCount > 0 else {
            throw OOXMLZipWriterError.archiveTooLarge
        }

        do {
            let archive = try Archive(data: data, accessMode: .read)
            var entries: [String: Data] = [:]
            var extractedTotalBytes = 0
            var acceptedEntryCount = 0

            for entry in archive {
                guard allowedPaths?(entry.path) ?? true else { continue }
                acceptedEntryCount += 1
                guard acceptedEntryCount <= maximumEntryCount else {
                    throw OOXMLZipWriterError.archiveTooLarge
                }
                guard entries[entry.path] == nil else {
                    throw OOXMLZipWriterError.duplicateEntry(entry.path)
                }

                let declaredSize = Int(clamping: entry.uncompressedSize)
                guard declaredSize <= maximumEntryBytes else {
                    throw OOXMLZipWriterError.entryTooLarge(entry.path)
                }
                guard declaredSize <= maximumTotalUncompressedBytes - extractedTotalBytes else {
                    throw OOXMLZipWriterError.archiveTooLarge
                }

                var extracted = Data()
                extracted.reserveCapacity(declaredSize)
                _ = try archive.extract(entry, consumer: { chunk in
                    guard chunk.count <= maximumEntryBytes - extracted.count else {
                        throw OOXMLZipWriterError.entryTooLarge(entry.path)
                    }
                    guard chunk.count <= maximumTotalUncompressedBytes - extractedTotalBytes else {
                        throw OOXMLZipWriterError.archiveTooLarge
                    }
                    extracted.append(chunk)
                    extractedTotalBytes += chunk.count
                })
                entries[entry.path] = extracted
            }

            return entries
        } catch let error as OOXMLZipWriterError {
            throw error
        } catch {
            throw OOXMLZipWriterError.invalidArchive
        }
    }
}
