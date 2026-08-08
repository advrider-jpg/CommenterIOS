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

public let encryptedBackupFileExtension = "cbackup"
public let encryptedBackupMIMEType = "application/json"

public enum BackupFileWorkflowError: LocalizedError, Equatable {
    case invalidDirectory(String)
    case emptyWrittenFile(URL)
    case verificationFailed(URL)
    case failedOutputCouldNotBeRemoved(URL)

    public var errorDescription: String? {
        switch self {
        case let .invalidDirectory(path):
            return "The backup destination is not a directory: \(path)"
        case let .emptyWrittenFile(url):
            return "The backup file was written but is empty: \(url.lastPathComponent)"
        case let .verificationFailed(url):
            return "The backup file was written but could not be verified: \(url.lastPathComponent)"
        case let .failedOutputCouldNotBeRemoved(url):
            return "Backup preparation failed, and the incomplete or unverified output could not be removed: \(url.lastPathComponent). Do not use this file; remove it manually."
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
    let expectedProject = reconcileProjectForPersistence(project, nowMilliseconds: project.metadata.updatedAt)
    return try prepareSerializedBackupFile(
        serialized: serialized,
        filename: filename,
        expectedProject: expectedProject,
        directory: directory,
        fileManager: fileManager,
        verifyReadBack: verifyReadBack
    )
}

public func prepareEncryptedProjectBackupFile(
    project: Project,
    password: String,
    directory: URL,
    createdAt: Date = Date(),
    fileManager: FileManager = .default
) throws -> PreparedBackupFile {
    try ensureWritableDirectory(directory, fileManager: fileManager)
    let serialized = try serializeEncryptedProjectBackup(
        project: project,
        password: password,
        createdAt: createdAt
    )
    let expectedProject = reconcileProjectForPersistence(project, nowMilliseconds: project.metadata.updatedAt)
    return try prepareSerializedBackupFile(
        serialized: serialized,
        filename: encryptedBackupFilename(project: project),
        expectedProject: expectedProject,
        directory: directory,
        fileManager: fileManager,
        verifyReadBack: { try parseProjectBackup(serialized: $0, password: password) }
    )
}

private func prepareSerializedBackupFile(
    serialized: String,
    filename: String,
    expectedProject: Project,
    directory: URL,
    fileManager: FileManager,
    verifyReadBack: (String) throws -> Project
) throws -> PreparedBackupFile {
    let destination = availableFileDestination(directory: directory, preferredFilename: filename, fileManager: fileManager)
    guard let data = serialized.data(using: .utf8) else {
        throw BackupError.couldNotOpen
    }

    do {
        try writeDataAtomicallyApplyingDefaultProtection(data, to: destination, fileManager: fileManager)
    } catch let writeError {
        do {
            try removeFailedOutputIfPresent(destination, fileManager: fileManager)
        } catch {
            throw BackupFileWorkflowError.failedOutputCouldNotBeRemoved(destination)
        }
        throw writeError
    }
    do {
        let byteCount = try verifiedNonEmptySize(url: destination, fileManager: fileManager)
        let readBack = try String(contentsOf: destination, encoding: .utf8)
        guard readBack == serialized else {
            throw BackupFileWorkflowError.verificationFailed(destination)
        }
        let verifiedProject = try verifyReadBack(readBack)
        guard verifiedProject == expectedProject else {
            throw BackupFileWorkflowError.verificationFailed(destination)
        }
        return PreparedBackupFile(url: destination, byteCount: byteCount, project: verifiedProject)
    } catch let error as BackupFileWorkflowError {
        do {
            try removeFailedOutputIfPresent(destination, fileManager: fileManager)
        } catch {
            throw BackupFileWorkflowError.failedOutputCouldNotBeRemoved(destination)
        }
        throw error
    } catch {
        do {
            try removeFailedOutputIfPresent(destination, fileManager: fileManager)
        } catch {
            throw BackupFileWorkflowError.failedOutputCouldNotBeRemoved(destination)
        }
        throw BackupFileWorkflowError.verificationFailed(destination)
    }
}

public func loadProjectBackupFile(
    from url: URL,
    password: String? = nil,
    fileManager: FileManager = .default
) throws -> PreparedBackupFile {
    let byteCount = try verifiedNonEmptySize(url: url, fileManager: fileManager)
    guard byteCount <= UInt64(encryptedBackupBytes) else {
        throw BackupError.encryptedBackupReadOversized(maximumBytes: encryptedBackupBytes)
    }
    let serialized = try String(contentsOf: url, encoding: .utf8)
    let project = try parseProjectBackup(serialized: serialized, password: password)
    return PreparedBackupFile(url: url, byteCount: byteCount, project: project)
}

public func backupFilename(project: Project, createdAt: Date = Date()) -> String {
    let projectName = safeFilenameComponent(project.metadata.name).nilIfEmpty ?? "report-writer-project"
    let timestamp = backupTimestamp(createdAt)
    return "\(projectName)-\(timestamp).report-writer-backup.json"
}

public func encryptedBackupFilename(project: Project) -> String {
    let sanitized = project.metadata.name.replacingOccurrences(
        of: #"[^a-z0-9_-]+"#,
        with: "_",
        options: [.regularExpression, .caseInsensitive]
    )
    let baseName = sanitized.isEmpty ? "report_comment_writer_backup" : sanitized
    return "\(baseName)_Backup_Copy.\(encryptedBackupFileExtension)"
}

private func ensureWritableDirectory(_ directory: URL, fileManager: FileManager) throws {
    var isDirectory: ObjCBool = false
    if fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
        guard isDirectory.boolValue else {
            throw BackupFileWorkflowError.invalidDirectory(directory.path)
        }
        try applyDefaultProtectionIfAvailable(to: directory, fileManager: fileManager)
        return
    }
    try createDirectoryApplyingDefaultProtection(directory, fileManager: fileManager)
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
    let sanitized = String(filteredScalars)
        .replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
        .replacingOccurrences(of: #"-+"#, with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-_ "))
    var bounded = ""
    var byteCount = 0
    for character in sanitized {
        let characterBytes = String(character).utf8.count
        guard byteCount + characterBytes <= 120 else { break }
        bounded.append(character)
        byteCount += characterBytes
    }
    return bounded.trimmingCharacters(in: CharacterSet(charactersIn: "-_ "))
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
