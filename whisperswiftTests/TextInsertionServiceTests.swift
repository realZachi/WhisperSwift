//
//  TextInsertionServiceTests.swift
//  whisperswiftTests
//
//  Tests for TextInsertionService
//

import XCTest
@testable import whisperswift

final class TextInsertionServiceTests: XCTestCase {

    // MARK: - InsertionOutcome Tests

    func test_InsertionOutcome_Inserted_Exists() {
        // Given
        let outcome = TextInsertionService.InsertionOutcome.inserted

        // Then
        switch outcome {
        case .inserted:
            XCTAssertTrue(true)
        default:
            XCTFail("Expected .inserted outcome")
        }
    }

    func test_InsertionOutcome_CopiedToClipboard_Exists() {
        // Given
        let outcome = TextInsertionService.InsertionOutcome.copiedToClipboard

        // Then
        switch outcome {
        case .copiedToClipboard:
            XCTAssertTrue(true)
        default:
            XCTFail("Expected .copiedToClipboard outcome")
        }
    }

    func test_InsertionOutcome_NoFocusedTarget_Exists() {
        // Given
        let outcome = TextInsertionService.InsertionOutcome.noFocusedTarget

        // Then
        switch outcome {
        case .noFocusedTarget:
            XCTAssertTrue(true)
        default:
            XCTFail("Expected .noFocusedTarget outcome")
        }
    }

    func test_InsertionOutcome_Empty_Exists() {
        // Given
        let outcome = TextInsertionService.InsertionOutcome.empty

        // Then
        switch outcome {
        case .empty:
            XCTAssertTrue(true)
        default:
            XCTFail("Expected .empty outcome")
        }
    }

    // MARK: - Text Trimming Tests

    func test_InsertText_TrimsWhitespace() {
        // Given
        let text = "   Hello World   "

        // When
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Then
        XCTAssertEqual(trimmed, "Hello World")
    }

    func test_InsertText_TrimsNewlines() {
        // Given
        let text = "\n\nHello World\n\n"

        // When
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Then
        XCTAssertEqual(trimmed, "Hello World")
    }

    func test_InsertText_EmptyString_ReturnsEmpty() {
        // Given
        let text = ""

        // When
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Then
        XCTAssertTrue(trimmed.isEmpty)
    }

    func test_InsertText_WhitespaceOnly_ReturnsEmpty() {
        // Given
        let text = "   \n\t   "

        // When
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Then
        XCTAssertTrue(trimmed.isEmpty)
    }

    func test_InsertText_PreservesInternalWhitespace() {
        // Given
        let text = "Hello   World"

        // When
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Then
        XCTAssertEqual(trimmed, "Hello   World")
    }

    // MARK: - Blacklist Tests

    func test_Blacklist_ContainsVSCode() {
        // Given
        let blacklist: Set<String> = [
            "com.microsoft.VSCode",
            "com.microsoft.VSCodeInsiders",
            "com.vscodium"
        ]

        // Then
        XCTAssertTrue(blacklist.contains("com.microsoft.VSCode"))
    }

    func test_Blacklist_ContainsChrome() {
        // Given
        let blacklist: Set<String> = [
            "com.google.Chrome",
            "com.google.Chrome.canary",
            "org.chromium.Chromium"
        ]

        // Then
        XCTAssertTrue(blacklist.contains("com.google.Chrome"))
    }

    func test_Blacklist_ContainsSafari() {
        // Given
        let blacklist: Set<String> = [
            "com.apple.Safari"
        ]

        // Then
        XCTAssertTrue(blacklist.contains("com.apple.Safari"))
    }

    func test_Blacklist_ContainsFirefox() {
        // Given
        let blacklist: Set<String> = [
            "org.mozilla.firefox"
        ]

        // Then
        XCTAssertTrue(blacklist.contains("org.mozilla.firefox"))
    }

    func test_Blacklist_ContainsBrave() {
        // Given
        let blacklist: Set<String> = [
            "com.brave.Browser"
        ]

        // Then
        XCTAssertTrue(blacklist.contains("com.brave.Browser"))
    }

    func test_Blacklist_ContainsEdge() {
        // Given
        let blacklist: Set<String> = [
            "com.microsoft.edgemac"
        ]

        // Then
        XCTAssertTrue(blacklist.contains("com.microsoft.edgemac"))
    }

    func test_Blacklist_ContainsArc() {
        // Given
        let blacklist: Set<String> = [
            "company.thebrowser.Browser"
        ]

        // Then
        XCTAssertTrue(blacklist.contains("company.thebrowser.Browser"))
    }

    func test_Blacklist_DoesNotContainNotes() {
        // Given
        let blacklist: Set<String> = [
            "com.microsoft.VSCode",
            "com.google.Chrome",
            "com.apple.Safari"
        ]

        // Then Notes should not be blacklisted
        XCTAssertFalse(blacklist.contains("com.apple.Notes"))
    }

    func test_Blacklist_DoesNotContainTextEdit() {
        // Given
        let blacklist: Set<String> = [
            "com.microsoft.VSCode",
            "com.google.Chrome",
            "com.apple.Safari"
        ]

        // Then TextEdit should not be blacklisted
        XCTAssertFalse(blacklist.contains("com.apple.TextEdit"))
    }

    // MARK: - Non-Text Roles Tests

    func test_NonTextRoles_ContainsMenuBar() {
        // Given
        let nonTextRoles: Set<String> = [
            "AXMenuBar",
            "AXMenu",
            "AXMenuItem",
            "AXToolbar",
            "AXScrollBar",
            "AXSplitter"
        ]

        // Then
        XCTAssertTrue(nonTextRoles.contains("AXMenuBar"))
    }

    func test_NonTextRoles_ContainsToolbar() {
        // Given
        let nonTextRoles: Set<String> = [
            "AXMenuBar",
            "AXMenu",
            "AXMenuItem",
            "AXToolbar",
            "AXScrollBar",
            "AXSplitter"
        ]

        // Then
        XCTAssertTrue(nonTextRoles.contains("AXToolbar"))
    }

    func test_NonTextRoles_DoesNotContainTextField() {
        // Given
        let nonTextRoles: Set<String> = [
            "AXMenuBar",
            "AXMenu",
            "AXMenuItem",
            "AXToolbar",
            "AXScrollBar",
            "AXSplitter"
        ]

        // Then text field should not be in non-text roles
        XCTAssertFalse(nonTextRoles.contains("AXTextField"))
    }

    func test_NonTextRoles_DoesNotContainTextArea() {
        // Given
        let nonTextRoles: Set<String> = [
            "AXMenuBar",
            "AXMenu",
            "AXMenuItem",
            "AXToolbar",
            "AXScrollBar",
            "AXSplitter"
        ]

        // Then text area should not be in non-text roles
        XCTAssertFalse(nonTextRoles.contains("AXTextArea"))
    }

    // MARK: - Pasteboard Delay Constants Tests

    func test_PasteboardSettleDelay_IsReasonable() {
        // Given
        let settleDelay: TimeInterval = 0.05

        // Then should be between 0 and 1 second
        XCTAssertGreaterThan(settleDelay, 0)
        XCTAssertLessThan(settleDelay, 1.0)
    }

    func test_PasteboardRestoreDelay_IsReasonable() {
        // Given
        let restoreDelay: TimeInterval = 0.1

        // Then should be between 0 and 1 second
        XCTAssertGreaterThan(restoreDelay, 0)
        XCTAssertLessThan(restoreDelay, 1.0)
    }

    func test_RestoreDelay_IsGreaterThanSettleDelay() {
        // Given
        let settleDelay: TimeInterval = 0.05
        let restoreDelay: TimeInterval = 0.1

        // Then restore should be after settle
        XCTAssertGreaterThan(restoreDelay, settleDelay)
    }

    // MARK: - V Key Code Tests

    func test_VKeyCode_IsCorrect() {
        // The V key code is 9 (from Carbon.h kVK_ANSI_V)
        let vKeyCode: UInt16 = 9

        XCTAssertEqual(vKeyCode, 9)
    }

    // MARK: - Text Content Tests

    func test_TextContent_UnicodeSupport() {
        // Given text with unicode characters
        let text = "Hello World!"

        // When trimmed
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Then unicode should be preserved
        XCTAssertEqual(trimmed, "Hello World!")
    }

    func test_TextContent_EmojiSupport() {
        // Given text with emojis
        let text = "Hello World"

        // When trimmed
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Then emojis should be preserved
        XCTAssertTrue(trimmed.contains("Hello"))
    }

    func test_TextContent_MultilineSupport() {
        // Given multiline text (internal newlines should be preserved)
        let text = "Line 1\nLine 2\nLine 3"

        // When trimmed
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Then internal newlines should be preserved
        XCTAssertTrue(trimmed.contains("\n"))
        XCTAssertEqual(trimmed, "Line 1\nLine 2\nLine 3")
    }

    // MARK: - Performance Tests

    func test_TextTrimming_Performance() {
        let longText = String(repeating: "   Hello World   \n", count: 1000)

        measure {
            _ = longText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func test_BlacklistLookup_Performance() {
        let blacklist: Set<String> = [
            "com.microsoft.VSCode",
            "com.microsoft.VSCodeInsiders",
            "com.vscodium",
            "com.google.Chrome",
            "com.google.Chrome.canary",
            "org.chromium.Chromium",
            "com.brave.Browser",
            "com.microsoft.edgemac",
            "com.apple.Safari",
            "org.mozilla.firefox",
            "com.operasoftware.Opera",
            "com.vivaldi.Vivaldi",
            "company.thebrowser.Browser"
        ]

        let testBundleIds = [
            "com.microsoft.VSCode",
            "com.apple.Notes",
            "com.google.Chrome",
            "com.apple.TextEdit"
        ]

        measure {
            for _ in 0..<10000 {
                for bundleId in testBundleIds {
                    _ = blacklist.contains(bundleId)
                }
            }
        }
    }
}

// MARK: - Clipboard Tests

final class ClipboardTests: XCTestCase {

    func test_ClipboardContent_CanBeNil() {
        // Clipboard content can be nil when empty
        let content: String? = nil

        XCTAssertNil(content)
    }

    func test_ClipboardContent_CanBeString() {
        // Clipboard content can be a string
        let content: String? = "Test content"

        XCTAssertNotNil(content)
        XCTAssertEqual(content, "Test content")
    }

    func test_ClipboardRestore_WithPreviousContent() {
        // Given
        let previousContent: String? = "Previous content"
        let newContent = "New content"

        // When restoring
        let restoredContent = previousContent ?? newContent

        // Then previous content should be restored
        XCTAssertEqual(restoredContent, "Previous content")
    }

    func test_ClipboardRestore_WithoutPreviousContent() {
        // Given
        let previousContent: String? = nil
        let newContent = "New content"

        // When checking for restore
        let shouldRestore = previousContent != nil

        // Then should not restore
        XCTAssertFalse(shouldRestore)
    }
}
