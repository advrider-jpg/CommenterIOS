import Foundation

func createDirectoryApplyingDefaultProtection(_ directory: URL, fileManager: FileManager) throws {
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    try applyDefaultProtectionIfAvailable(to: directory, fileManager: fileManager)
}

func writeDataAtomicallyApplyingDefaultProtection(_ data: Data, to destination: URL, fileManager: FileManager) throws {
    try data.write(to: destination, options: [.atomic])
    try applyDefaultProtectionIfAvailable(to: destination, fileManager: fileManager)
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
