import CommenterDomain
import CommenterPersistence
import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(Security)
import Security
#endif

public let projectBackupFormat = "commenter-project-backup"
public let projectBackupVersion = 2
public let encryptedProjectBackupFormat = "commenter-project-backup-encrypted"
public let encryptedProjectBackupVersion = 2
public let encryptedBackupKDFIterations = 650_000
public let encryptedBackupMinimumPasswordCharacters = 12
public let encryptedBackupMaximumPasswordCharacters = 1_024
public let encryptedBackupBytes = 8 * 1024 * 1024

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

public struct EncryptedProjectBackupEncryption: Codable, Equatable, Sendable {
    public var algorithm: String
    public var kdf: String
    public var iterations: Int
    public var salt: String
    public var iv: String
    public var plaintextFormat: String
    public var plaintextVersion: Int
    public var aad: String?

    public init(
        algorithm: String = "AES-GCM",
        kdf: String = "PBKDF2-SHA-256",
        iterations: Int = encryptedBackupKDFIterations,
        salt: String,
        iv: String,
        plaintextFormat: String = projectBackupFormat,
        plaintextVersion: Int = projectBackupVersion,
        aad: String? = "backup-envelope-v2"
    ) {
        self.algorithm = algorithm
        self.kdf = kdf
        self.iterations = iterations
        self.salt = salt
        self.iv = iv
        self.plaintextFormat = plaintextFormat
        self.plaintextVersion = plaintextVersion
        self.aad = aad
    }
}

public struct EncryptedProjectBackupChecksum: Codable, Equatable, Sendable {
    public var algorithm: String
    public var ciphertextHash: String

    public init(algorithm: String = "sha256", ciphertextHash: String) {
        self.algorithm = algorithm
        self.ciphertextHash = ciphertextHash
    }
}

public struct EncryptedProjectBackupPayload: Codable, Equatable, Sendable {
    public var format: String
    public var version: Int
    public var createdAt: String
    public var encryption: EncryptedProjectBackupEncryption
    public var checksum: EncryptedProjectBackupChecksum
    public var ciphertext: String

    public init(
        format: String = encryptedProjectBackupFormat,
        version: Int = encryptedProjectBackupVersion,
        createdAt: String,
        encryption: EncryptedProjectBackupEncryption,
        checksum: EncryptedProjectBackupChecksum,
        ciphertext: String
    ) {
        self.format = format
        self.version = version
        self.createdAt = createdAt
        self.encryption = encryption
        self.checksum = checksum
        self.ciphertext = ciphertext
    }
}

public struct BackupPasswordValidation: Equatable, Sendable {
    public var ok: Bool
    public var message: String?

    public init(ok: Bool, message: String? = nil) {
        self.ok = ok
        self.message = message
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
    case encryptedOversized(maxMegabytes: Int)
    case decryptedOversized(maxMegabytes: Int)
    case couldNotOpen
    case couldNotVerify
    case encryptedPasswordRequired
    case encryptedCouldNotDecrypt
    case encryptedUnsupported
    case invalidPassword(String)
    case invalidProject([String])

    public var errorDescription: String? {
        switch self {
        case let .oversized(maxMegabytes):
            return "This backup file is larger than \(maxMegabytes) MB and was not read."
        case let .encryptedOversized(maxMegabytes):
            return "This encrypted backup file is larger than \(maxMegabytes) MB and was not read."
        case let .decryptedOversized(maxMegabytes):
            return "This decrypted backup file is larger than \(maxMegabytes) MB and was not imported."
        case .couldNotOpen:
            return "This backup file could not be opened. Choose a project backup file created by this app."
        case .couldNotVerify:
            return "This backup file could not be verified. It may be incomplete or changed."
        case .encryptedPasswordRequired:
            return "This is an encrypted project backup. Enter the backup password to import it."
        case .encryptedCouldNotDecrypt:
            return "The encrypted backup could not be opened. Check the backup password and try again."
        case .encryptedUnsupported:
            return "Encrypted backups are not available in this build."
        case let .invalidPassword(message):
            return message
        case let .invalidProject(issues):
            return "This backup file contains an invalid project: \(issues.joined(separator: " "))"
        }
    }
}

public func normalizeBackupPassword(_ password: String) -> String {
    (password as NSString).precomposedStringWithCompatibilityMapping
}

public func validateBackupPasswordForEncryption(_ password: String, confirmation: String? = nil) -> BackupPasswordValidation {
    let normalized = normalizeBackupPassword(password)
    if normalized.count < encryptedBackupMinimumPasswordCharacters {
        return BackupPasswordValidation(ok: false, message: "Use at least \(encryptedBackupMinimumPasswordCharacters) characters for an encrypted backup password.")
    }
    if normalized.count > encryptedBackupMaximumPasswordCharacters {
        return BackupPasswordValidation(ok: false, message: "Backup passwords must be \(encryptedBackupMaximumPasswordCharacters) characters or fewer.")
    }
    if normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return BackupPasswordValidation(ok: false, message: "Use a password that is not only spaces.")
    }
    if containsControlCharacter(normalized) {
        return BackupPasswordValidation(ok: false, message: "Backup passwords cannot include control characters.")
    }
    if let confirmation, normalized != normalizeBackupPassword(confirmation) {
        return BackupPasswordValidation(ok: false, message: "The backup passwords do not match.")
    }
    return BackupPasswordValidation(ok: true)
}

public func validateBackupPasswordForImport(_ password: String) -> BackupPasswordValidation {
    let normalized = normalizeBackupPassword(password)
    if normalized.isEmpty {
        return BackupPasswordValidation(ok: false, message: "Enter the backup password.")
    }
    if normalized.count > encryptedBackupMaximumPasswordCharacters {
        return BackupPasswordValidation(ok: false, message: "Backup passwords must be \(encryptedBackupMaximumPasswordCharacters) characters or fewer.")
    }
    if containsControlCharacter(normalized) {
        return BackupPasswordValidation(ok: false, message: "Backup passwords cannot include control characters.")
    }
    return BackupPasswordValidation(ok: true)
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

public func serializeEncryptedProjectBackup(project: Project, password: String, createdAt: Date = Date()) throws -> String {
    let salt = try secureRandomData(byteCount: 16)
    let iv = try secureRandomData(byteCount: 12)
    return try serializeEncryptedProjectBackup(
        project: project,
        password: password,
        createdAt: createdAt,
        iterations: encryptedBackupKDFIterations,
        salt: salt,
        iv: iv
    )
}

func serializeEncryptedProjectBackup(
    project: Project,
    password: String,
    createdAt: Date = Date(),
    iterations: Int,
    salt: Data,
    iv: Data
) throws -> String {
    let passwordValidation = validateBackupPasswordForEncryption(password)
    guard passwordValidation.ok else {
        throw BackupError.invalidPassword(passwordValidation.message ?? "Choose a stronger backup password.")
    }

    let plaintext = try serializeProjectBackup(project: project, createdAt: createdAt)
    guard plaintext.lengthOfBytes(using: .utf8) <= ProjectLimits.backupBytes else {
        throw BackupError.oversized(maxMegabytes: ProjectLimits.backupBytes / (1024 * 1024))
    }
    guard let plaintextData = plaintext.data(using: .utf8) else {
        throw BackupError.couldNotOpen
    }

    let envelope = EncryptedProjectBackupPayload(
        createdAt: iso8601String(createdAt),
        encryption: EncryptedProjectBackupEncryption(
            iterations: iterations,
            salt: salt.base64EncodedString(),
            iv: iv.base64EncodedString()
        ),
        checksum: EncryptedProjectBackupChecksum(ciphertextHash: ""),
        ciphertext: ""
    )
    let aad = encryptedBackupAssociatedData(payload: envelope)
    let ciphertext = try encryptAESGCM(plaintext: plaintextData, password: password, salt: salt, iterations: iterations, iv: iv, aad: aad)
        .base64EncodedString()
    let payload = EncryptedProjectBackupPayload(
        createdAt: envelope.createdAt,
        encryption: envelope.encryption,
        checksum: EncryptedProjectBackupChecksum(ciphertextHash: try sha256Hex(ciphertext)),
        ciphertext: ciphertext
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(payload)
    guard let serialized = String(data: data, encoding: .utf8) else {
        throw BackupError.couldNotOpen
    }
    guard serialized.lengthOfBytes(using: .utf8) <= encryptedBackupBytes else {
        throw BackupError.encryptedOversized(maxMegabytes: encryptedBackupBytes / (1024 * 1024))
    }
    return serialized
}

public func looksLikeEncryptedProjectBackup(serialized: String) -> Bool {
    guard let data = serialized.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
        return false
    }
    return object["format"] as? String == encryptedProjectBackupFormat
}

public func parseProjectBackup(serialized: String, password: String? = nil) throws -> Project {
    let byteCount = serialized.lengthOfBytes(using: .utf8)
    if byteCount > encryptedBackupBytes {
        throw BackupError.encryptedOversized(maxMegabytes: encryptedBackupBytes / (1024 * 1024))
    }

    let data: Data
    guard let encoded = serialized.data(using: .utf8) else { throw BackupError.couldNotOpen }
    data = encoded

    let parsedObject: Any
    do {
        parsedObject = try JSONSerialization.jsonObject(with: data)
    } catch let error as BackupError {
        throw error
    } catch {
        if byteCount > ProjectLimits.backupBytes {
            throw BackupError.oversized(maxMegabytes: ProjectLimits.backupBytes / (1024 * 1024))
        }
        throw BackupError.couldNotOpen
    }

    if let object = parsedObject as? [String: Any],
       object["format"] as? String == encryptedProjectBackupFormat {
        let plaintext = try decryptEncryptedBackupPayload(data: data, password: password)
        guard plaintext.lengthOfBytes(using: .utf8) <= ProjectLimits.backupBytes else {
            throw BackupError.decryptedOversized(maxMegabytes: ProjectLimits.backupBytes / (1024 * 1024))
        }
        return try parsePlainProjectBackup(serialized: plaintext)
    }

    if byteCount > ProjectLimits.backupBytes {
        throw BackupError.oversized(maxMegabytes: ProjectLimits.backupBytes / (1024 * 1024))
    }

    return try parsePlainProjectBackup(serialized: serialized)
}

private func parsePlainProjectBackup(serialized: String) throws -> Project {
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

private func decryptEncryptedBackupPayload(data: Data, password: String?) throws -> String {
    let payload = try decodeEncryptedPayload(data: data)
    guard let password, !password.isEmpty else {
        throw BackupError.encryptedPasswordRequired
    }
    guard try sha256Hex(payload.ciphertext) == payload.checksum.ciphertextHash else {
        throw BackupError.couldNotVerify
    }
    guard let salt = Data(base64Encoded: payload.encryption.salt),
          let iv = Data(base64Encoded: payload.encryption.iv),
          let ciphertext = Data(base64Encoded: payload.ciphertext)
    else {
        throw BackupError.encryptedCouldNotDecrypt
    }

    let aad = payload.version == encryptedProjectBackupVersion
        ? encryptedBackupAssociatedData(payload: payload)
        : Data()
    let plaintextData = try decryptAESGCM(
        ciphertextAndTag: ciphertext,
        password: password,
        salt: salt,
        iterations: payload.encryption.iterations,
        iv: iv,
        aad: aad
    )
    guard let plaintext = String(data: plaintextData, encoding: .utf8) else {
        throw BackupError.encryptedCouldNotDecrypt
    }
    return plaintext
}

private func decodeEncryptedPayload(data: Data) throws -> EncryptedProjectBackupPayload {
    let payload: EncryptedProjectBackupPayload
    do {
        payload = try JSONDecoder().decode(EncryptedProjectBackupPayload.self, from: data)
    } catch {
        throw BackupError.couldNotOpen
    }
    guard payload.format == encryptedProjectBackupFormat,
          payload.version == 1 || payload.version == encryptedProjectBackupVersion,
          payload.encryption.algorithm == "AES-GCM",
          payload.encryption.kdf == "PBKDF2-SHA-256",
          payload.encryption.iterations > 0,
          payload.encryption.plaintextFormat == projectBackupFormat,
          payload.encryption.plaintextVersion == projectBackupVersion,
          payload.checksum.algorithm == "sha256",
          !payload.checksum.ciphertextHash.isEmpty,
          !payload.encryption.salt.isEmpty,
          !payload.encryption.iv.isEmpty,
          !payload.ciphertext.isEmpty
    else {
        throw BackupError.couldNotOpen
    }
    return payload
}

private func encryptAESGCM(plaintext: Data, password: String, salt: Data, iterations: Int, iv: Data, aad: Data) throws -> Data {
    #if canImport(CryptoKit)
    let key = try deriveAESGCMKey(password: password, salt: salt, iterations: iterations)
    let nonce = try AES.GCM.Nonce(data: iv)
    let sealed = try AES.GCM.seal(plaintext, using: key, nonce: nonce, authenticating: aad)
    var ciphertextAndTag = sealed.ciphertext
    ciphertextAndTag.append(sealed.tag)
    return ciphertextAndTag
    #else
    throw BackupError.encryptedUnsupported
    #endif
}

private func decryptAESGCM(ciphertextAndTag: Data, password: String, salt: Data, iterations: Int, iv: Data, aad: Data) throws -> Data {
    #if canImport(CryptoKit)
    guard ciphertextAndTag.count > 16 else {
        throw BackupError.encryptedCouldNotDecrypt
    }
    do {
        let key = try deriveAESGCMKey(password: password, salt: salt, iterations: iterations)
        let nonce = try AES.GCM.Nonce(data: iv)
        let ciphertext = Data(ciphertextAndTag.prefix(ciphertextAndTag.count - 16))
        let tag = Data(ciphertextAndTag.suffix(16))
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        return try AES.GCM.open(sealedBox, using: key, authenticating: aad)
    } catch let error as BackupError {
        throw error
    } catch {
        throw BackupError.encryptedCouldNotDecrypt
    }
    #else
    throw BackupError.encryptedUnsupported
    #endif
}

#if canImport(CryptoKit)
private func deriveAESGCMKey(password: String, salt: Data, iterations: Int) throws -> SymmetricKey {
    let normalized = normalizeBackupPassword(password)
    guard normalized.count >= 10,
          let passwordData = normalized.data(using: .utf8)
    else {
        throw BackupError.encryptedCouldNotDecrypt
    }
    return SymmetricKey(data: try pbkdf2SHA256(password: passwordData, salt: salt, iterations: iterations, keyByteCount: 32))
}

private func pbkdf2SHA256(password: Data, salt: Data, iterations: Int, keyByteCount: Int) throws -> Data {
    guard iterations > 0, keyByteCount > 0 else {
        throw BackupError.encryptedCouldNotDecrypt
    }
    let key = SymmetricKey(data: password)
    let hashByteCount = 32
    let blockCount = Int(ceil(Double(keyByteCount) / Double(hashByteCount)))
    var derived = [UInt8]()
    derived.reserveCapacity(blockCount * hashByteCount)

    for blockIndex in 1...blockCount {
        var saltBlock = [UInt8](salt)
        saltBlock.append(contentsOf: UInt32(blockIndex).bigEndianBytes)
        var u = Data(HMAC<SHA256>.authenticationCode(for: Data(saltBlock), using: key))
        var block = [UInt8](u)
        if iterations > 1 {
            for _ in 2...iterations {
                u = Data(HMAC<SHA256>.authenticationCode(for: u, using: key))
                let uBytes = [UInt8](u)
                for index in block.indices {
                    block[index] ^= uBytes[index]
                }
            }
        }
        derived.append(contentsOf: block)
    }

    return Data(derived.prefix(keyByteCount))
}
#endif

private func encryptedBackupAssociatedData(payload: EncryptedProjectBackupPayload) -> Data {
    let encryption = payload.encryption
    var encryptionFields = [
        "\"algorithm\":\(jsonStringLiteral(encryption.algorithm))",
        "\"kdf\":\(jsonStringLiteral(encryption.kdf))",
        "\"iterations\":\(encryption.iterations)",
        "\"salt\":\(jsonStringLiteral(encryption.salt))",
        "\"iv\":\(jsonStringLiteral(encryption.iv))",
        "\"plaintextFormat\":\(jsonStringLiteral(encryption.plaintextFormat))",
        "\"plaintextVersion\":\(encryption.plaintextVersion)"
    ]
    if let aad = encryption.aad {
        encryptionFields.append("\"aad\":\(jsonStringLiteral(aad))")
    }
    let json = "{"
        + "\"format\":\(jsonStringLiteral(payload.format)),"
        + "\"version\":\(payload.version),"
        + "\"createdAt\":\(jsonStringLiteral(payload.createdAt)),"
        + "\"encryption\":{\(encryptionFields.joined(separator: ","))}"
        + "}"
    return Data(json.utf8)
}

private func secureRandomData(byteCount: Int) throws -> Data {
    #if canImport(Security)
    var bytes = [UInt8](repeating: 0, count: byteCount)
    let status = bytes.withUnsafeMutableBytes { buffer in
        SecRandomCopyBytes(kSecRandomDefault, byteCount, buffer.baseAddress!)
    }
    guard status == errSecSuccess else {
        throw BackupError.encryptedUnsupported
    }
    return Data(bytes)
    #else
    throw BackupError.encryptedUnsupported
    #endif
}

private func containsControlCharacter(_ value: String) -> Bool {
    value.unicodeScalars.contains { scalar in
        scalar.value <= 0x1f || scalar.value == 0x7f
    }
}

private func jsonStringLiteral(_ value: String) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: [value]),
          let rendered = String(data: data, encoding: .utf8),
          rendered.count >= 2
    else {
        return "\"\""
    }
    return String(rendered.dropFirst().dropLast())
}

private func iso8601String(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}

private extension UInt32 {
    var bigEndianBytes: [UInt8] {
        [
            UInt8((self >> 24) & 0xff),
            UInt8((self >> 16) & 0xff),
            UInt8((self >> 8) & 0xff),
            UInt8(self & 0xff)
        ]
    }
}
