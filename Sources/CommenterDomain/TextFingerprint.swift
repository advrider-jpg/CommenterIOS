import Foundation

public func stableTextFingerprint(_ text: String) -> String {
    let bytes = Array(text.utf8)
    let hash = bytes.reduce(UInt64(0xcbf29ce484222325)) { partial, byte in
        (partial ^ UInt64(byte)) &* 0x100000001b3
    }
    return String(format: "%016llx", hash)
}
