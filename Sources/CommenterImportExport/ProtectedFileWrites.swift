import Foundation

func createDirectoryApplyingDefaultProtection(_ directory: URL, fileManager: FileManager) throws {
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    try applyDefaultProtectionIfAvailable(to: directory, fileManager: fileManager)
}

func writeDataAtomicallyApplyingDefaultProtection(_ data: Data, to destination: URL, fileManager: FileManager) throws {
    try data.write(to: destination, options: [.atomic])
    try applyDefaultProtectionIfAvailable(to: destination, fileManager: fileManager)
}

func availableFileDestination(directory: URL, preferredFilename: String, fileManager: FileManager) -> URL {
    let preferred = directory.appendingPathComponent(preferredFilename, isDirectory: false)
    guard fileManager.fileExists(atPath: preferred.path) else { return preferred }

    let preferredURL = URL(fileURLWithPath: preferredFilename)
    let fileExtension = preferredURL.pathExtension
    let stem = preferredURL.deletingPathExtension().lastPathComponent
    for copyNumber in 2...9_999 {
        let extensionSuffix = fileExtension.isEmpty ? "" : ".\(fileExtension)"
        let candidate = directory.appendingPathComponent("\(stem)-\(copyNumber)\(extensionSuffix)", isDirectory: false)
        if !fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }
    }
    let extensionSuffix = fileExtension.isEmpty ? "" : ".\(fileExtension)"
    return directory.appendingPathComponent("\(stem)-\(UUID().uuidString)\(extensionSuffix)", isDirectory: false)
}

enum FailedOutputCleanupError: Error, Equatable {
    case fileStillExists(URL)
}

func removeFailedOutputIfPresent(
    _ url: URL,
    fileManager: FileManager,
    removeItem: ((URL) throws -> Void)? = nil
) throws {
    guard fileManager.fileExists(atPath: url.path) else { return }
    do {
        if let removeItem {
            try removeItem(url)
        } else {
            try fileManager.removeItem(at: url)
        }
    } catch {
        guard !fileManager.fileExists(atPath: url.path) else {
            throw FailedOutputCleanupError.fileStillExists(url)
        }
    }
    guard !fileManager.fileExists(atPath: url.path) else {
        throw FailedOutputCleanupError.fileStillExists(url)
    }
}

func applyDefaultProtectionIfAvailable(to url: URL, fileManager: FileManager) throws {
    #if os(iOS)
    guard fileManager.fileExists(atPath: url.path) else { return }
    try fileManager.setAttributes(
        [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
        ofItemAtPath: url.path
    )
    #else
    _ = url
    _ = fileManager
    #endif
}
