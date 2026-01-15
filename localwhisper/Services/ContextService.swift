//
//  ContextService.swift
//  localwhisper
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import Cocoa

final class ContextService {
    struct Snapshot {
        let appName: String?
        let bundleId: String?
        let windowTitle: String?
        let documentPath: String?
        let documentName: String?
        let capturedAt: Date
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
            documentName: documentName,
            capturedAt: Date()
        )
    }

    func applyContext(to text: String, snapshot: Snapshot?) -> String {
        guard let snapshot else {
            return text
        }

        let candidates = extractFileCandidates(snapshot: snapshot)
        guard !candidates.isEmpty else {
            return text
        }

        var updated = text
        for candidate in candidates {
            let variants = filenameVariants(for: candidate)
            for variant in variants {
                updated = replacePhrase(in: updated, phrase: variant, replacement: candidate)
            }
        }

        return updated
    }

    private func focusedWindowElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success,
              let appElement = focusedApp else {
            return nil
        }

        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement as! AXUIElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
              let windowElement = focusedWindow else {
            return nil
        }

        return windowElement as! AXUIElement
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

        if let documentName = snapshot.documentName, looksLikeFilename(documentName) {
            candidates.append(documentName)
        }

        if let documentPath = snapshot.documentPath {
            let lastComponent = (documentPath as NSString).lastPathComponent
            if looksLikeFilename(lastComponent) {
                candidates.append(lastComponent)
            }
        }

        if let windowTitle = snapshot.windowTitle {
            candidates.append(contentsOf: candidatesFromWindowTitle(windowTitle))
        }

        return uniqueCandidates(candidates)
    }

    private func candidatesFromWindowTitle(_ title: String) -> [String] {
        let separators = [
            " - ",
            " | ",
            " :: ",
            " \(String(UnicodeScalar(0x2014)!)) ",
            " \(String(UnicodeScalar(0x2013)!)) ",
            " \(String(UnicodeScalar(0x2022)!)) "
        ]

        var segments = [title]
        for separator in separators {
            segments = segments.flatMap { $0.components(separatedBy: separator) }
        }

        var candidates: [String] = []
        for segment in segments {
            let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.contains("://") { continue }

            if trimmed.contains("/") || trimmed.contains("~") {
                let lastComponent = (trimmed as NSString).lastPathComponent
                if looksLikeFilename(lastComponent) {
                    candidates.append(lastComponent)
                }
                continue
            }

            if looksLikeFilename(trimmed) {
                candidates.append(trimmed)
            }
        }

        return candidates
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

        if ext.contains(" ") || ext.count > 6 {
            return false
        }

        return true
    }

    private func filenameVariants(for filename: String) -> [String] {
        var variants: [String] = []
        let normalized = normalizeFilenamePhrase(filename)
        if !normalized.isEmpty {
            variants.append(normalized)
        }

        if let dotIndex = filename.lastIndex(of: ".") {
            let base = String(filename[..<dotIndex])
            let ext = String(filename[filename.index(after: dotIndex)...])
            let basePhrase = normalizeFilenamePhrase(base)
            let extPhrase = normalizeFilenamePhrase(ext)
            if !basePhrase.isEmpty && !extPhrase.isEmpty {
                variants.append("\(basePhrase) dot \(extPhrase)")
                variants.append("\(basePhrase) punkt \(extPhrase)")
            }
        }

        return uniqueVariants(variants)
    }

    private func normalizeFilenamePhrase(_ value: String) -> String {
        let lowered = value.lowercased()
        let replaced = lowered
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: ".", with: " ")
        return collapseWhitespace(replaced)
    }

    private func collapseWhitespace(_ value: String) -> String {
        let parts = value.split { $0.isWhitespace }
        return parts.joined(separator: " ")
    }

    private func replacePhrase(in text: String, phrase: String, replacement: String) -> String {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else {
            return text
        }

        let escaped = NSRegularExpression.escapedPattern(for: trimmed)
        let pattern = "(?i)\\b\(escaped)\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
    }

    private func uniqueCandidates(_ candidates: [String]) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []
        for candidate in candidates {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard looksLikeFilename(trimmed) else { continue }
            if seen.insert(trimmed).inserted {
                unique.append(trimmed)
            }
        }
        return unique
    }

    private func uniqueVariants(_ variants: [String]) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []
        for variant in variants {
            let trimmed = variant.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 4 else { continue }
            if seen.insert(trimmed).inserted {
                unique.append(trimmed)
            }
        }
        return unique
    }
}
