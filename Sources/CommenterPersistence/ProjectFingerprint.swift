import CommenterDomain
import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

public enum ProjectFingerprintError: LocalizedError, Equatable {
    case unsupportedPlatform
    case encodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedPlatform:
            return "SHA-256 is not available in this build."
        case let .encodingFailed(message):
            return message
        }
    }
}

public func projectFingerprintPayload(_ project: Project) -> Project {
    var copy = project
    copy.metadata.persistence = nil
    return copy
}

public func stableProjectString(_ project: Project) throws -> String {
    let encoder = JSONEncoder()
    let data = try encoder.encode(projectFingerprintPayload(project))
    let value = try JSONDecoder().decode(JSONValue.self, from: data)
    return stableJSONString(value)
}

public func projectFingerprint(_ project: Project) throws -> String {
    try sha256Hex(stableProjectString(project))
}

public func sha256Hex(_ value: String) throws -> String {
    guard let data = value.data(using: .utf8) else {
        throw ProjectFingerprintError.encodingFailed("Project fingerprint payload could not be encoded as UTF-8.")
    }
    return try sha256Hex(data)
}

public func sha256Hex(_ data: Data) throws -> String {
    #if canImport(CryptoKit)
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
    #else
    throw ProjectFingerprintError.unsupportedPlatform
    #endif
}

public func stableJSONString(_ value: JSONValue) -> String {
    switch value {
    case let .string(string):
        return jsonEscapedString(string)
    case let .number(number):
        if number.rounded(.towardZero) == number {
            return String(Int64(number))
        }
        return String(number)
    case let .bool(bool):
        return bool ? "true" : "false"
    case let .array(array):
        return "[" + array.map(stableJSONString).joined(separator: ",") + "]"
    case let .object(object):
        return "{" + object.keys.sorted().map { key in
            jsonEscapedString(key) + ":" + stableJSONString(object[key] ?? .null)
        }.joined(separator: ",") + "}"
    case .null:
        return "null"
    }
}

private func jsonEscapedString(_ value: String) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: [value], options: []),
          let rendered = String(data: data, encoding: .utf8),
          rendered.count >= 2
    else {
        return "\"\""
    }
    return String(rendered.dropFirst().dropLast())
}
