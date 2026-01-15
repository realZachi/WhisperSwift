//
//  ContextService.swift
//  whisperswift
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import Cocoa

final class ContextService {
    private enum Constants {
        static let maxFilenameBodyLength = 200
        static let maxExtensionLength = 12
        static let minBaseTokenLength = 3
        static let minUppercaseLetterSequenceLength = 4
        static let minExtensionLetterSequenceLength = 2
    }

    private struct FilenameSignature {
        let baseTokenSequences: [[String]]
        let extensionAlternatives: [String]
    }

    struct Snapshot {
        let appName: String?
        let bundleId: String?
        let windowTitle: String?
        let documentPath: String?
        let documentName: String?
    }

    func captureSnapshot() -> Snapshot? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appName = app.localizedName
        let bundleId = app.bundleIdentifier
        let windowElement = focusedWindowElement()
        let windowTitle = windowElement.flatMap { copyAttributeString($0, kAXTitleAttribute) }
        let documentPath = windowElement.flatMap { copyAttributeString($0, kAXDocumentAttribute) }
        let documentName = documentPath.flatMap { ($0 as NSString).lastPathComponent }

        return Snapshot(
            appName: appName,
            bundleId: bundleId,
            windowTitle: windowTitle,
            documentPath: documentPath,
            documentName: documentName
        )
    }

    func applyContext(to text: String, snapshot: Snapshot?) -> String {
        guard let snapshot else {
            return text
        }

        let candidates = candidateFilenames(snapshot: snapshot)
        guard !candidates.isEmpty else {
            return text
        }

        var updated = text
        for candidate in candidates {
            updated = replaceFileMentions(in: updated, with: candidate)
        }

        return updated
    }

    func candidateFilenames(snapshot: Snapshot) -> [String] {
        extractFileCandidates(snapshot: snapshot)
            .sorted { $0.count > $1.count }
    }

    private func focusedWindowElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success,
              let focusedApp,
              CFGetTypeID(focusedApp) == AXUIElementGetTypeID() else {
            return nil
        }
        let appElement = unsafeBitCast(focusedApp, to: AXUIElement.self)

        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
              let focusedWindow,
              CFGetTypeID(focusedWindow) == AXUIElementGetTypeID() else {
            return nil
        }

        return unsafeBitCast(focusedWindow, to: AXUIElement.self)
    }

    private func copyAttributeString(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else {
            return nil
        }

        return value as? String
    }

    private func extractFileCandidates(snapshot: Snapshot) -> [String] {
        var candidates: [String] = []

        if let documentName = snapshot.documentName {
            let sanitized = sanitizeCandidate(documentName)
            if looksLikeFilename(sanitized) {
                candidates.append(sanitized)
            }
        }

        if let documentPath = snapshot.documentPath {
            let lastComponent = (documentPath as NSString).lastPathComponent
            let sanitized = sanitizeCandidate(lastComponent)
            if looksLikeFilename(sanitized) {
                candidates.append(sanitized)
            }
        }

        if let windowTitle = snapshot.windowTitle {
            candidates.append(contentsOf: candidatesFromWindowTitle(windowTitle))
        }

        return uniqueCandidates(candidates)
    }

    private func candidatesFromWindowTitle(_ title: String) -> [String] {
        var candidates: [String] = []

        candidates.append(contentsOf: extractFilenameLikeSubstrings(from: title))

        if title.contains("/") || title.contains("~") {
            let lastComponent = (title as NSString).lastPathComponent
            let sanitized = sanitizeCandidate(lastComponent)
            if looksLikeFilename(sanitized) {
                candidates.append(sanitized)
            }
        }

        return candidates
    }

    private func extractFilenameLikeSubstrings(from text: String) -> [String] {
        let pattern = "(?<![\\p{L}\\p{N}_])[\\p{L}\\p{N}][\\p{L}\\p{N}._+\\-]{0,\(Constants.maxFilenameBodyLength)}\\.[\\p{L}\\p{N}]{1,\(Constants.maxExtensionLength)}(?![\\p{L}\\p{N}_])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        var results: [String] = []
        results.reserveCapacity(matches.count)

        for match in matches {
            guard let matchRange = Range(match.range, in: text) else { continue }
            let substring = String(text[matchRange])
            let sanitized = sanitizeCandidate(substring)
            if looksLikeFilename(sanitized) {
                results.append(sanitized)
            }
        }

        return results
    }

    private func looksLikeFilename(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let dotIndex = trimmed.lastIndex(of: ".") else {
            return false
        }

        let base = trimmed[..<dotIndex]
        let ext = trimmed[trimmed.index(after: dotIndex)...]
        if base.isEmpty || ext.isEmpty {
            return false
        }

        if ext.contains(" ") || ext.count > Constants.maxExtensionLength {
            return false
        }

        let extString = String(ext)
        let extScalars = extString.unicodeScalars
        guard extScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }) else {
            return false
        }

        return extScalars.contains { CharacterSet.letters.contains($0) }
    }

    private func replaceFileMentions(in text: String, with filename: String) -> String {
        guard let regex = spokenFilenameRegex(for: filename) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let replacement = NSRegularExpression.escapedTemplate(for: filename)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
    }

    private func uniqueCandidates(_ candidates: [String]) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []
        for candidate in candidates {
            let sanitized = sanitizeCandidate(candidate)
            guard looksLikeFilename(sanitized) else { continue }
            if seen.insert(sanitized).inserted {
                unique.append(sanitized)
            }
        }
        return unique
    }

    private func sanitizeCandidate(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return trimmed
        }

        let allowedScalars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-+"))
        var start = trimmed.startIndex
        var end = trimmed.endIndex

        while start < end {
            let character = trimmed[start]
            let scalars = character.unicodeScalars
            if scalars.allSatisfy({ allowedScalars.contains($0) }) {
                break
            }
            start = trimmed.index(after: start)
        }

        while end > start {
            let previousIndex = trimmed.index(before: end)
            let character = trimmed[previousIndex]
            let scalars = character.unicodeScalars
            if scalars.allSatisfy({ allowedScalars.contains($0) }) {
                break
            }
            end = previousIndex
        }

        return String(trimmed[start..<end])
    }

    private func spokenFilenameRegex(for filename: String) -> NSRegularExpression? {
        guard let signature = filenameSignature(for: filename) else {
            return nil
        }

        let wordBoundaryStart = "(?<![\\p{L}\\p{N}_])"
        let wordBoundaryEnd = "(?![\\p{L}\\p{N}_])"
        let softSep = "[^\\p{L}\\p{N}]*"
        let hardSep = "[^\\p{L}\\p{N}]+"

        let fileWord = "(?:datei|file|dokument|document)"
        let dotWord = "(?:punkt|dot|point)"

        let betweenBaseAndExtension = "(?:\(hardSep)|(?:\(softSep)\(dotWord)\(softSep)))"

        let extensionAlternation = signature.extensionAlternatives
            .map { extensionPattern(for: $0, softSeparator: softSep) }
            .joined(separator: "|")

        let extensionGroupPattern = "(?:\(extensionAlternation))"

        let prefixOptional = "(?:(?:\(fileWord))\(hardSep))?"
        let suffixOptional = "(?:\(hardSep)(?:\(fileWord)))?"

        let prefixRequired = "(?:\(fileWord))\(hardSep)"
        let suffixRequired = "\(hardSep)(?:\(fileWord))"

        var patterns: [String] = []
        for baseTokens in signature.baseTokenSequences {
            let base = sequencePattern(for: baseTokens, softSeparator: softSep)

            let full = "\(prefixOptional)\(base)\(betweenBaseAndExtension)\(extensionGroupPattern)\(suffixOptional)"
            patterns.append(full)

            let fileWordBeforeBaseOnly = "\(prefixRequired)\(base)"
            let fileWordAfterBaseOnly = "\(base)\(suffixRequired)"
            patterns.append(fileWordBeforeBaseOnly)
            patterns.append(fileWordAfterBaseOnly)
        }

        let combined = "\(wordBoundaryStart)(?:\(patterns.joined(separator: "|")))\(wordBoundaryEnd)"
        return try? NSRegularExpression(pattern: combined, options: [.caseInsensitive])
    }

    private func filenameSignature(for filename: String) -> FilenameSignature? {
        let sanitized = sanitizeCandidate(filename)
        guard looksLikeFilename(sanitized) else {
            return nil
        }

        let nsFilename = sanitized as NSString
        let ext = nsFilename.pathExtension
        let base = nsFilename.deletingPathExtension
        let baseTokens = tokenizeFileComponent(base)

        guard !baseTokens.isEmpty else {
            return nil
        }

        if baseTokens.count == 1, baseTokens[0].count < Constants.minBaseTokenLength {
            return nil
        }

        var baseTokenSequences: [[String]] = [baseTokens]
        if shouldAddLetterSequenceVariant(for: base) {
            let letters = base.lowercased().map { String($0) }
            if letters.count >= Constants.minUppercaseLetterSequenceLength {
                baseTokenSequences.append(letters)
            }
        }

        let normalizedExt = normalizeToken(ext)
        guard !normalizedExt.isEmpty else {
            return nil
        }

        var extensionAlternatives = [normalizedExt]
        extensionAlternatives.append(contentsOf: extensionAliasTokens(for: normalizedExt))

        if normalizedExt.count <= 3, normalizedExt.unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) }) {
            let letters = normalizedExt.map { String($0) }
            if letters.count >= Constants.minExtensionLetterSequenceLength {
                extensionAlternatives.append(letters.joined(separator: " "))
            }
        }

        extensionAlternatives = Array(Set(extensionAlternatives)).sorted()

        return FilenameSignature(
            baseTokenSequences: baseTokenSequences,
            extensionAlternatives: extensionAlternatives
        )
    }

    private func tokenizeFileComponent(_ value: String) -> [String] {
        let segments = extractAlphanumericSegments(from: value)
        var tokens: [String] = []
        for segment in segments {
            let parts = splitCamelCase(segment)
            for part in parts {
                let normalized = normalizeToken(part)
                if normalized.isEmpty {
                    continue
                }
                tokens.append(normalized)
            }
        }
        return tokens
    }

    private func extractAlphanumericSegments(from value: String) -> [String] {
        var segments: [String] = []
        var current = ""

        for scalar in value.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                segments.append(current)
                current = ""
            }
        }

        if !current.isEmpty {
            segments.append(current)
        }

        return segments
    }

    private func splitCamelCase(_ value: String) -> [String] {
        guard !value.isEmpty else {
            return []
        }

        let scalars = Array(value.unicodeScalars)
        var parts: [String] = []
        var current = ""

        func isUpper(_ scalar: UnicodeScalar) -> Bool {
            CharacterSet.uppercaseLetters.contains(scalar)
        }

        func isLower(_ scalar: UnicodeScalar) -> Bool {
            CharacterSet.lowercaseLetters.contains(scalar)
        }

        func isDigit(_ scalar: UnicodeScalar) -> Bool {
            CharacterSet.decimalDigits.contains(scalar)
        }

        for index in scalars.indices {
            let scalar = scalars[index]
            let char = Character(scalar)

            let prevScalar = index > scalars.startIndex ? scalars[index - 1] : nil
            let nextScalar = index < scalars.index(before: scalars.endIndex) ? scalars[index + 1] : nil

            let shouldSplit: Bool = {
                guard let prevScalar else { return false }

                if isDigit(scalar), !isDigit(prevScalar) {
                    return true
                }

                if !isDigit(scalar), isDigit(prevScalar) {
                    return true
                }

                if isUpper(scalar), isLower(prevScalar) {
                    return true
                }

                if isUpper(scalar), isUpper(prevScalar), let nextScalar, isLower(nextScalar) {
                    return true
                }

                return false
            }()

            if shouldSplit, !current.isEmpty {
                parts.append(current)
                current = ""
            }

            current.append(char)
        }

        if !current.isEmpty {
            parts.append(current)
        }

        return parts
    }

    private func normalizeToken(_ value: String) -> String {
        let lowered = value.lowercased()
        let folded = lowered.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)
        let trimmed = folded.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed
    }

    private func shouldAddLetterSequenceVariant(for value: String) -> Bool {
        guard !value.isEmpty else {
            return false
        }

        let scalars = value.unicodeScalars
        return scalars.allSatisfy { CharacterSet.letters.contains($0) } && value == value.uppercased()
    }

    private func sequencePattern(for tokens: [String], softSeparator: String) -> String {
        let escapedTokens = tokens.map { NSRegularExpression.escapedPattern(for: $0) }
        return escapedTokens.joined(separator: softSeparator)
    }

    private func extensionPattern(for token: String, softSeparator: String) -> String {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains(" ") {
            let parts = trimmed.split(separator: " ").map(String.init)
            if parts.allSatisfy({ $0.count == 1 }) {
                return sequencePattern(for: parts, softSeparator: softSeparator)
            }
        }

        return NSRegularExpression.escapedPattern(for: trimmed)
    }

    private func extensionAliasTokens(for ext: String) -> [String] {
        let aliases: [String: [String]] = [
            "md": ["markdown"],
            "yml": ["yaml"],
            "yaml": ["yml"],
            "js": ["javascript"],
            "ts": ["typescript"],
            "py": ["python"],
            "rb": ["ruby"],
            "rs": ["rust"],
            "kt": ["kotlin"],
            "txt": ["text"]
        ]

        return aliases[ext] ?? []
    }
}
