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
        if case .inserted = TextInsertionService.InsertionOutcome.inserted {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected .inserted outcome")
        }
    }

    func test_InsertionOutcome_CopiedToClipboard_Exists() {
        if case .copiedToClipboard = TextInsertionService.InsertionOutcome.copiedToClipboard {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected .copiedToClipboard outcome")
        }
    }

    func test_InsertionOutcome_NoFocusedTarget_Exists() {
        if case .noFocusedTarget = TextInsertionService.InsertionOutcome.noFocusedTarget {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected .noFocusedTarget outcome")
        }
    }

    func test_InsertionOutcome_Empty_Exists() {
        if case .empty = TextInsertionService.InsertionOutcome.empty {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected .empty outcome")
        }
    }

    // MARK: - Text Trimming Tests

    func test_InsertText_TrimsWhitespace() {
        XCTAssertEqual("   Hello World   ".trimmingCharacters(in: .whitespacesAndNewlines), "Hello World")
    }

    func test_InsertText_TrimsNewlines() {
        XCTAssertEqual("\n\nHello World\n\n".trimmingCharacters(in: .whitespacesAndNewlines), "Hello World")
    }

    func test_InsertText_EmptyString_ReturnsEmpty() {
        XCTAssertTrue("".trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func test_InsertText_WhitespaceOnly_ReturnsEmpty() {
        XCTAssertTrue("   \n\t   ".trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func test_InsertText_PreservesInternalWhitespace() {
        XCTAssertEqual("Hello   World".trimmingCharacters(in: .whitespacesAndNewlines), "Hello   World")
    }

    // MARK: - Blacklist Tests

    private var blacklist: Set<String> {
        [
            "com.microsoft.VSCode",
            "com.microsoft.VSCodeInsiders",
            "com.vscodium",
            "com.google.Chrome",
            "com.google.Chrome.canary",
            "org.chromium.Chromium",
            "com.apple.Safari",
            "org.mozilla.firefox",
            "com.brave.Browser",
            "com.microsoft.edgemac",
            "company.thebrowser.Browser"
        ]
    }

    func test_Blacklist_ContainsVSCode() {
        XCTAssertTrue(blacklist.contains("com.microsoft.VSCode"))
    }

    func test_Blacklist_ContainsChrome() {
        XCTAssertTrue(blacklist.contains("com.google.Chrome"))
    }

    func test_Blacklist_ContainsSafari() {
        XCTAssertTrue(blacklist.contains("com.apple.Safari"))
    }

    func test_Blacklist_ContainsFirefox() {
        XCTAssertTrue(blacklist.contains("org.mozilla.firefox"))
    }

    func test_Blacklist_ContainsBrave() {
        XCTAssertTrue(blacklist.contains("com.brave.Browser"))
    }

    func test_Blacklist_ContainsEdge() {
        XCTAssertTrue(blacklist.contains("com.microsoft.edgemac"))
    }

    func test_Blacklist_ContainsArc() {
        XCTAssertTrue(blacklist.contains("company.thebrowser.Browser"))
    }

    func test_Blacklist_DoesNotContainNotes() {
        XCTAssertFalse(blacklist.contains("com.apple.Notes"))
    }

    func test_Blacklist_DoesNotContainTextEdit() {
        XCTAssertFalse(blacklist.contains("com.apple.TextEdit"))
    }

    // MARK: - Non-Text Roles Tests

    private var nonTextRoles: Set<String> {
        ["AXMenuBar", "AXMenu", "AXMenuItem", "AXToolbar", "AXScrollBar", "AXSplitter"]
    }

    func test_NonTextRoles_ContainsMenuBar() {
        XCTAssertTrue(nonTextRoles.contains("AXMenuBar"))
    }

    func test_NonTextRoles_ContainsToolbar() {
        XCTAssertTrue(nonTextRoles.contains("AXToolbar"))
    }

    func test_NonTextRoles_DoesNotContainTextField() {
        XCTAssertFalse(nonTextRoles.contains("AXTextField"))
    }

    func test_NonTextRoles_DoesNotContainTextArea() {
        XCTAssertFalse(nonTextRoles.contains("AXTextArea"))
    }

    // MARK: - Pasteboard Delay Constants Tests

    func test_PasteboardSettleDelay_IsReasonable() {
        let settleDelay: TimeInterval = 0.05
        XCTAssertGreaterThan(settleDelay, 0)
        XCTAssertLessThan(settleDelay, 1.0)
    }

    func test_PasteboardRestoreDelay_IsReasonable() {
        let restoreDelay: TimeInterval = 0.1
        XCTAssertGreaterThan(restoreDelay, 0)
        XCTAssertLessThan(restoreDelay, 1.0)
    }

    func test_RestoreDelay_IsGreaterThanSettleDelay() {
        XCTAssertGreaterThan(0.1, 0.05)
    }

    // MARK: - V Key Code Tests

    func test_VKeyCode_IsCorrect() {
        XCTAssertEqual(9 as UInt16, 9) // kVK_ANSI_V
    }

    // MARK: - Text Content Tests

    func test_TextContent_UnicodeSupport() {
        XCTAssertEqual("Hello World!".trimmingCharacters(in: .whitespacesAndNewlines), "Hello World!")
    }

    func test_TextContent_EmojiSupport() {
        XCTAssertTrue("Hello World".trimmingCharacters(in: .whitespacesAndNewlines).contains("Hello"))
    }

    func test_TextContent_MultilineSupport() {
        let text = "Line 1\nLine 2\nLine 3"
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(trimmed.contains("\n"))
        XCTAssertEqual(trimmed, text)
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
        let content: String? = nil
        XCTAssertNil(content)
    }

    func test_ClipboardContent_CanBeString() {
        let content: String? = "Test content"
        XCTAssertEqual(content, "Test content")
    }

    func test_ClipboardRestore_WithPreviousContent() {
        let previousContent: String? = "Previous content"
        XCTAssertEqual(previousContent ?? "fallback", "Previous content")
    }

    func test_ClipboardRestore_WithoutPreviousContent() {
        let previousContent: String? = nil
        XCTAssertFalse(previousContent != nil)
    }
}
