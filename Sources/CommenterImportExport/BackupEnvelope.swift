import CommenterDomain
import CommenterPersistence
import Foundation

public let projectBackupFormat = "commenter-project-backup"
public let projectBackupVersion = 2

public struct ProjectBackupChecksum: Codable, Equatable, Sendable {
    public var algorithm: String
    public var projectFingerprint: String

    public init(algorithm: String = "sha256", projectFingerprint: String) {
        self.algorithm = algorithm
        self.projectFingerprint = projectFingerprint
    }
}

public struct ProjectBackupPayload: Codable, Equatable, Sendable {
    public var format: String
    public var version: Int
    public var createdAt: String
    public var checksum: ProjectBackupChecksum?
    public var project: Project

    public init(format: String, version: Int, createdAt: String, checksum: ProjectBackupChecksum?, project: Project) {
        self.format = format
        self.version = version
        self.createdAt = createdAt
        self.checksum = checksum
        self.project = project
    }
}

public enum BackupImportChoice: String, Equatable, Sendable {
    case replace = "REPLACE"
    case copy = "COPY"
    case cancel = "CANCEL"
}

public enum BackupCollisionKind: String, Equatable, Sendable {
    case none
    case valid
    case invalid
}

public enum BackupError: LocalizedError, Equatable {
    case oversized(maxMegabytes: Int)
    case couldNotOpen
    case couldNotVerify
    case invalidProject([String])

    public var errorDescription: String? {
        switch self {
        case let .oversized(maxMegabytes):
            return "This backup file is larger than \(maxMegabytes) MB and was not read."
        case .couldNotOpen:
            return "This backup file could not be opened. Choose a project backup file created by this app."
        case .couldNotVerify:
            return "This backup file could not be verified. It may be incomplete or changed."
        case let .invalidProject(issues):
            return "This backup file contains an invalid project: \(issues.joined(separator: " "))"
        }
    }
}

public func getBackupCollisionKind(
    projectId: String,
    projects: [Project],
    invalidProjects: [(id: String, reason: String)]
) -> BackupCollisionKind {
    if projects.contains(where: { $0.metadata.id == projectId }) { return .valid }
    if invalidProjects.contains(where: { $0.id == projectId }) { return .invalid }
    return .none
}

public func normalizeBackupImportChoice(_ value: String?) -> BackupImportChoice? {
    let normalized = (value ?? "CANCEL").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    if normalized.isEmpty || normalized == "CANCEL" { return .cancel }
    return BackupImportChoice(rawValue: normalized)
}

public func serializeProjectBackup(project: Project, createdAt: Date = Date()) throws -> String {
    let normalizedProject = normalizeProjectForPersistence(project)
    let validation = validateStoredProjectShape(normalizedProject)
    guard validation.ok else {
        throw BackupError.invalidProject(validation.issues)
    }

    let payload = ProjectBackupPayload(
        format: projectBackupFormat,
        version: projectBackupVersion,
        createdAt: iso8601String(createdAt),
        checksum: ProjectBackupChecksum(projectFingerprint: try projectFingerprint(normalizedProject)),
        project: normalizedProject
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(payload)
    guard let serialized = String(data: data, encoding: .utf8) else {
        throw BackupError.couldNotOpen
    }
    return serialized
}

public func parseProjectBackup(serialized: String) throws -> Project {
    let byteCount = serialized.lengthOfBytes(using: .utf8)
    if byteCount > ProjectLimits.backupBytes {
        throw BackupError.oversized(maxMegabytes: ProjectLimits.backupBytes / (1024 * 1024))
    }

    let payload: ProjectBackupPayload
    do {
        guard let data = serialized.data(using: .utf8) else { throw BackupError.couldNotOpen }
        payload = try JSONDecoder().decode(ProjectBackupPayload.self, from: data)
    } catch let error as BackupError {
        throw error
    } catch {
        throw BackupError.couldNotOpen
    }

    guard payload.format == projectBackupFormat, payload.version == 1 || payload.version == 2 else {
        throw BackupError.couldNotOpen
    }

    let validation = validateStoredProjectShape(payload.project)
    guard validation.ok else {
        throw BackupError.couldNotOpen
    }

    let normalizedProject = normalizeProjectForPersistence(payload.project)
    if payload.version == 2 {
        guard let checksum = payload.checksum,
              checksum.algorithm == "sha256",
              !checksum.projectFingerprint.isEmpty
        else {
            throw BackupError.couldNotOpen
        }
        guard try projectFingerprint(normalizedProject) == checksum.projectFingerprint else {
            throw BackupError.couldNotVerify
        }
    }

    return normalizedProject
}

private func normalizeProjectForPersistence(_ project: Project) -> Project {
    reconcileProjectForPersistence(project, nowMilliseconds: project.metadata.updatedAt)
}

private func iso8601String(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}
