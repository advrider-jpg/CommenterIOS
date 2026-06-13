import Foundation

func userVisibleErrorMessage(_ error: Error) -> String {
    sanitizedUserVisibleMessage(error.localizedDescription)
}

func sanitizedUserVisibleMessage(_ message: String) -> String {
    let tokens = message.split(separator: " ", omittingEmptySubsequences: false)
    let sanitized = tokens.map { token -> String in
        let value = String(token)
        guard let candidate = localPathCandidate(in: value) else { return value }
        return value.replacingOccurrences(of: candidate, with: "[local file]")
    }
    return sanitized.joined(separator: " ")
}

private func localPathCandidate(in value: String) -> String? {
    var start = value.startIndex
    var end = value.endIndex

    while start < end, isWrapperPunctuation(value[start]) {
        start = value.index(after: start)
    }
    while start < end {
        let previous = value.index(before: end)
        guard isWrapperPunctuation(value[previous]) else { break }
        end = previous
    }

    let candidate = String(value[start..<end])
    return looksLikeLocalPath(candidate) ? candidate : nil
}

private func isWrapperPunctuation(_ character: Character) -> Bool {
    guard character != "/", character != "\\" else { return false }
    return character.unicodeScalars.allSatisfy { CharacterSet.punctuationCharacters.contains($0) }
}

private func looksLikeLocalPath(_ value: String) -> Bool {
    if value.hasPrefix("file://") || value.hasPrefix("/") || value.hasPrefix("\\\\") {
        return true
    }
    guard value.count >= 3 else { return false }
    let scalars = Array(value.unicodeScalars)
    return CharacterSet.letters.contains(scalars[0]) &&
        scalars[1] == ":" &&
        (scalars[2] == "\\" || scalars[2] == "/")
}
