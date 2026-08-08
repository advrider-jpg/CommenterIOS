import Foundation

/// Serializes the app's JSON value model with the same observable string,
/// number, and object-key rules as JavaScript JSON.stringify. CommenterV3 uses
/// that representation for persistence fingerprints and byte limits.
public func javaScriptJSONString(_ value: JSONValue) -> String {
    switch value {
    case let .string(string):
        return javaScriptEscapedJSONString(string)
    case let .number(number):
        return ecmaScriptNumberString(number)
    case let .bool(bool):
        return bool ? "true" : "false"
    case let .array(array):
        return "[" + array.map(javaScriptJSONString).joined(separator: ",") + "]"
    case let .object(object):
        return "{" + object.keys.sorted(by: utf16CodeUnitLess).map { key in
            javaScriptEscapedJSONString(key) + ":" + javaScriptJSONString(object[key] ?? .null)
        }.joined(separator: ",") + "}"
    case .null:
        return "null"
    }
}

/// Mirrors the decimal form produced by JavaScript's JSON.stringify for a
/// finite IEEE-754 Number. Swift and JavaScript both begin with the shortest
/// round-trippable decimal digits, but choose different fixed/scientific
/// thresholds and exponent spelling.
private func ecmaScriptNumberString(_ value: Double) -> String {
    guard value.isFinite else { return "null" }
    guard value != 0 else { return "0" }

    var rendered = String(value).lowercased()
    let sign: String
    if rendered.first == "-" {
        sign = "-"
        rendered.removeFirst()
    } else {
        sign = ""
    }

    let exponentParts = rendered.split(separator: "e", maxSplits: 1, omittingEmptySubsequences: false)
    let mantissa = String(exponentParts[0])
    let exponent = exponentParts.count == 2 ? (Int(exponentParts[1]) ?? 0) : 0
    let mantissaCharacters = Array(mantissa)
    let decimalPosition = mantissaCharacters.firstIndex(of: ".") ?? mantissaCharacters.count
    var digits = mantissaCharacters.filter { $0 != "." }
    var leadingZeroCount = 0
    while digits.first == "0" {
        digits.removeFirst()
        leadingZeroCount += 1
    }
    while digits.last == "0" {
        digits.removeLast()
    }
    guard !digits.isEmpty else { return "0" }

    let decimalExponent = decimalPosition + exponent - leadingZeroCount
    let digitString = String(digits)
    let digitCount = digits.count
    let body: String
    if digitCount <= decimalExponent, decimalExponent <= 21 {
        body = digitString + String(repeating: "0", count: decimalExponent - digitCount)
    } else if decimalExponent > 0, decimalExponent <= 21 {
        let split = digitString.index(digitString.startIndex, offsetBy: decimalExponent)
        body = String(digitString[..<split]) + "." + String(digitString[split...])
    } else if decimalExponent > -6, decimalExponent <= 0 {
        body = "0." + String(repeating: "0", count: -decimalExponent) + digitString
    } else {
        let scientificExponent = decimalExponent - 1
        let fraction = digitCount > 1 ? "." + String(digitString.dropFirst()) : ""
        let exponentSign = scientificExponent >= 0 ? "+" : ""
        body = String(digitString.prefix(1)) + fraction + "e" + exponentSign + String(scientificExponent)
    }
    return sign + body
}

private func utf16CodeUnitLess(_ left: String, _ right: String) -> Bool {
    left.utf16.lexicographicallyPrecedes(right.utf16)
}

private func javaScriptEscapedJSONString(_ value: String) -> String {
    var output = "\""
    for scalar in value.unicodeScalars {
        switch scalar.value {
        case 0x08:
            output += "\\b"
        case 0x09:
            output += "\\t"
        case 0x0A:
            output += "\\n"
        case 0x0C:
            output += "\\f"
        case 0x0D:
            output += "\\r"
        case 0x22:
            output += "\\\""
        case 0x5C:
            output += "\\\\"
        case 0x00..<0x20:
            output += "\\u" + String(format: "%04x", scalar.value)
        default:
            output.append(String(scalar))
        }
    }
    output += "\""
    return output
}
