import CommenterDomain
import Foundation

public struct PreparedBackupFile: Equatable, Sendable {
    public var url: URL
    public var byteCount: UInt64
    public var project: Project

    public init(url: URL, byteCount: UInt64, project: Project) {
        self.url = url
        self.byteCount = byteCount
        self.project = project
    }
}

public enum BackupFileWorkflowError: LocalizedError, Equatable {
    case invalidDirectory(String)
    case emptyWrittenFile(URL)
    case verificationFailed(URL)

    public var errorDescription: String? {
        switch self {
        case let .invalidDirectory(path):
            return "The backup destination is not a directory: \(path)"
        case let .emptyWrittenFile(url):
            return "The backup file was written but is empty: \(url.lastPathComponent)"
        case let .verificationFailed(url):
            return "The backup file was written but could not be verified: \(url.lastPathComponent)"
        }
    }
}

public func prepareProjectBackupFile(
    project: Project,
    directory: URL,
    createdAt: Date = Date(),
    fileManager: FileManager = .default
) throws -> PreparedBackupFile {
    try prepareProjectBackupFile(
        project: project,
        directory: directory,
        createdAt: createdAt,
        fileManager: fileManager,
        verifyReadBack: { try parseProjectBackup(serialized: $0) }
    )
}

func prepareProjectBackupFile(
    project: Project,
    directory: URL,
    createdAt: Date = Date(),
    fileManager: FileManager = .default,
    verifyReadBack: (String) throws -> Project
) throws -> PreparedBackupFile {
    try ensureWritableDirectory(directory, fileManager: fileManager)
    let serialized = try serializeProjectBackup(project: project, createdAt: createdAt)
    let filename = backupFilename(project: project, createdAt: createdAt)
    let destination = directory.appendingPathComponent(filename, isDirectory: false)
    guard let data = serialized.data(using: .utf8) else {
        throw BackupError.couldNotOpen
    }

    try data.write(to: destination, options: [.atomic])
    let byteCount = try verifiedNonEmptySize(url: destination, fileManager: fileManager)

    let readBack = try String(contentsOf: destination, encoding: .utf8)
    let verifiedProject: Project
    do {
        verifiedProject = try verifyReadBack(readBack)
    } catch {
        try? fileManager.removeItem(at: destination)
        throw BackupFileWorkflowError.verificationFailed(destination)
    }

    guard verifiedProject.metadata.id == project.metadata.id else {
        try? fileManager.removeItem(at: destination)
        throw BackupFileWorkflowError.verificationFailed(destination)
    }

    return PreparedBackupFile(url: destination, byteCount: byteCount, project: verifiedProject)
}

public func loadProjectBackupFile(
    from url: URL,
    password: String? = nil,
    fileManager: FileManager = .default
) throws -> PreparedBackupFile {
    let byteCount = try verifiedNonEmptySize(url: url, fileManager: fileManager)
    let serialized = try String(contentsOf: url, encoding: .utf8)
    let project = try parseProjectBackup(serialized: serialized, password: password)
    return PreparedBackupFile(url: url, byteCount: byteCount, project: project)
}

public func backupFilename(project: Project, createdAt: Date = Date()) -> String {
    let projectName = safeFilenameComponent(project.metadata.name).nilIfEmpty ?? "report-writer-project"
    let timestamp = backupTimestamp(createdAt)
    return "\(projectName)-\(timestamp).report-writer-backup.json"
}

private func ensureWritableDirectory(_ directory: URL, fileManager: FileManager) throws {
    var isDirectory: ObjCBool = false
    if fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
        guard isDirectory.boolValue else {
            throw BackupFileWorkflowError.invalidDirectory(directory.path)
        }
        return
    }
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
}

private func verifiedNonEmptySize(url: URL, fileManager: FileManager) throws -> UInt64 {
    let attributes = try fileManager.attributesOfItem(atPath: url.path)
    let size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
    guard size > 0 else {
        throw BackupFileWorkflowError.emptyWrittenFile(url)
    }
    return size
}

private func backupTimestamp(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
        .string(from: date)
        .replacingOccurrences(of: ":", with: "-")
}

private func safeFilenameComponent(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
    let filteredScalars = value.unicodeScalars.map { scalar -> Character in
        allowed.contains(scalar) ? Character(scalar) : "-"
    }
    return String(filteredScalars)
        .replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
        .replacingOccurrences(of: #"-+"#, with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-_ "))
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
