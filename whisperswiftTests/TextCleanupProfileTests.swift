//
//  TextCleanupProfileTests.swift
//  whisperswiftTests
//
//  Tests for TextCleanupProfile and TextCleanupPrompts
//

import XCTest
@testable import whisperswift

final class TextCleanupProfileTests: XCTestCase {

    // MARK: - Profile Enum Tests

    func test_TextCleanupProfile_AllCases_Count() {
        XCTAssertEqual(TextCleanupProfile.allCases.count, 5)
    }

    func test_TextCleanupProfile_Contains_Default() {
        XCTAssertTrue(TextCleanupProfile.allCases.contains(.default))
    }

    func test_TextCleanupProfile_Contains_Email() {
        XCTAssertTrue(TextCleanupProfile.allCases.contains(.email))
    }

    func test_TextCleanupProfile_Contains_Chat() {
        XCTAssertTrue(TextCleanupProfile.allCases.contains(.chat))
    }

    func test_TextCleanupProfile_Contains_Markdown() {
        XCTAssertTrue(TextCleanupProfile.allCases.contains(.markdown))
    }

    func test_TextCleanupProfile_Contains_Document() {
        XCTAssertTrue(TextCleanupProfile.allCases.contains(.document))
    }

    // MARK: - Raw Value Tests

    func test_TextCleanupProfile_Default_RawValue() {
        XCTAssertEqual(TextCleanupProfile.default.rawValue, "default")
    }

    func test_TextCleanupProfile_Email_RawValue() {
        XCTAssertEqual(TextCleanupProfile.email.rawValue, "email")
    }

    func test_TextCleanupProfile_Chat_RawValue() {
        XCTAssertEqual(TextCleanupProfile.chat.rawValue, "chat")
    }

    func test_TextCleanupProfile_Markdown_RawValue() {
        XCTAssertEqual(TextCleanupProfile.markdown.rawValue, "markdown")
    }

    func test_TextCleanupProfile_Document_RawValue() {
        XCTAssertEqual(TextCleanupProfile.document.rawValue, "document")
    }

    // MARK: - Base System Prompt Tests

    func test_BaseSystemPrompt_IsNotEmpty() {
        XCTAssertFalse(TextCleanupPrompts.baseSystemPrompt.isEmpty)
    }

    func test_BaseSystemPrompt_ContainsDisfluencyMention() {
        XCTAssertTrue(TextCleanupPrompts.baseSystemPrompt.contains("disfluenc"))
    }

    func test_BaseSystemPrompt_ContainsPreserveInstruction() {
        XCTAssertTrue(TextCleanupPrompts.baseSystemPrompt.contains("Preserve"))
    }

    func test_BaseSystemPrompt_MentionsFillerWords() {
        XCTAssertTrue(TextCleanupPrompts.baseSystemPrompt.contains("filler"))
    }

    func test_BaseSystemPrompt_MentionsListFormatting() {
        XCTAssertTrue(TextCleanupPrompts.baseSystemPrompt.lowercased().contains("list"))
    }

    // MARK: - Formatting Prompt Tests

    func test_FormattingPrompt_Default_ReturnsNil() {
        XCTAssertNil(TextCleanupPrompts.formattingSystemPrompt(for: .default))
    }

    func test_FormattingPrompt_Email_ReturnsContent() {
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: .email)
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt!.contains("email"))
    }

    func test_FormattingPrompt_Chat_ReturnsContent() {
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: .chat)
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt!.contains("chat"))
    }

    func test_FormattingPrompt_Markdown_ReturnsContent() {
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: .markdown)
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt!.contains("Markdown"))
    }

    func test_FormattingPrompt_Document_ReturnsContent() {
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: .document)
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt!.contains("prose"))
    }

    // MARK: - Email Prompt Content Tests

    func test_EmailPrompt_MentionsParagraphStructure() {
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: .email)!
        XCTAssertTrue(prompt.contains("Paragraph") || prompt.contains("paragraph"))
    }

    func test_EmailPrompt_MentionsGreeting() {
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: .email)!
        XCTAssertTrue(prompt.contains("greeting"))
    }

    func test_EmailPrompt_MentionsSignature() {
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: .email)!
        XCTAssertTrue(prompt.lowercased().contains("signature") || prompt.lowercased().contains("name"))
    }

    // MARK: - Chat Prompt Content Tests

    func test_ChatPrompt_MentionsCompact() {
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: .chat)!
        XCTAssertTrue(prompt.contains("compact"))
    }

    func test_ChatPrompt_MentionsNoBlankLines() {
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: .chat)!
        XCTAssertTrue(prompt.lowercased().contains("no blank lines") || prompt.lowercased().contains("no multi-paragraph"))
    }

    // MARK: - Markdown Prompt Content Tests

    func test_MarkdownPrompt_MentionsBulletLists() {
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: .markdown)!
        XCTAssertTrue(prompt.contains("bullet") || prompt.contains("-"))
    }

    func test_MarkdownPrompt_MentionsNumberedLists() {
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: .markdown)!
        XCTAssertTrue(prompt.contains("numbered") || prompt.contains("1."))
    }

    // MARK: - Document Prompt Content Tests

    func test_DocumentPrompt_MentionsProse() {
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: .document)!
        XCTAssertTrue(prompt.contains("prose"))
    }

    func test_DocumentPrompt_MentionsParagraphs() {
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: .document)!
        XCTAssertTrue(prompt.contains("paragraph"))
    }

    // MARK: - Profile From Raw Value Tests

    func test_ProfileFromRawValue_Default() {
        XCTAssertEqual(TextCleanupProfile(rawValue: "default"), .default)
    }

    func test_ProfileFromRawValue_Email() {
        XCTAssertEqual(TextCleanupProfile(rawValue: "email"), .email)
    }

    func test_ProfileFromRawValue_Invalid() {
        XCTAssertNil(TextCleanupProfile(rawValue: "invalid"))
    }

    // MARK: - Performance Tests

    func test_FormattingPromptLookup_Performance() {
        let profiles = TextCleanupProfile.allCases

        measure {
            for _ in 0..<1000 {
                for profile in profiles {
                    _ = TextCleanupPrompts.formattingSystemPrompt(for: profile)
                }
            }
        }
    }

    func test_ProfileRawValueAccess_Performance() {
        let profiles = TextCleanupProfile.allCases

        measure {
            for _ in 0..<10000 {
                for profile in profiles {
                    _ = profile.rawValue
                }
            }
        }
    }
}
