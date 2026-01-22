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
        // Given
        let allCases = TextCleanupProfile.allCases

        // Then should have 5 profiles
        XCTAssertEqual(allCases.count, 5)
    }

    func test_TextCleanupProfile_Contains_Default() {
        // Given
        let allCases = TextCleanupProfile.allCases

        // Then
        XCTAssertTrue(allCases.contains(.default))
    }

    func test_TextCleanupProfile_Contains_Email() {
        // Given
        let allCases = TextCleanupProfile.allCases

        // Then
        XCTAssertTrue(allCases.contains(.email))
    }

    func test_TextCleanupProfile_Contains_Chat() {
        // Given
        let allCases = TextCleanupProfile.allCases

        // Then
        XCTAssertTrue(allCases.contains(.chat))
    }

    func test_TextCleanupProfile_Contains_Markdown() {
        // Given
        let allCases = TextCleanupProfile.allCases

        // Then
        XCTAssertTrue(allCases.contains(.markdown))
    }

    func test_TextCleanupProfile_Contains_Document() {
        // Given
        let allCases = TextCleanupProfile.allCases

        // Then
        XCTAssertTrue(allCases.contains(.document))
    }

    // MARK: - Raw Value Tests

    func test_TextCleanupProfile_Default_RawValue() {
        // Given
        let profile = TextCleanupProfile.default

        // Then
        XCTAssertEqual(profile.rawValue, "default")
    }

    func test_TextCleanupProfile_Email_RawValue() {
        // Given
        let profile = TextCleanupProfile.email

        // Then
        XCTAssertEqual(profile.rawValue, "email")
    }

    func test_TextCleanupProfile_Chat_RawValue() {
        // Given
        let profile = TextCleanupProfile.chat

        // Then
        XCTAssertEqual(profile.rawValue, "chat")
    }

    func test_TextCleanupProfile_Markdown_RawValue() {
        // Given
        let profile = TextCleanupProfile.markdown

        // Then
        XCTAssertEqual(profile.rawValue, "markdown")
    }

    func test_TextCleanupProfile_Document_RawValue() {
        // Given
        let profile = TextCleanupProfile.document

        // Then
        XCTAssertEqual(profile.rawValue, "document")
    }

    // MARK: - Base System Prompt Tests

    func test_BaseSystemPrompt_IsNotEmpty() {
        // Given
        let prompt = TextCleanupPrompts.baseSystemPrompt

        // Then
        XCTAssertFalse(prompt.isEmpty)
    }

    func test_BaseSystemPrompt_ContainsDisfluencyMention() {
        // Given
        let prompt = TextCleanupPrompts.baseSystemPrompt

        // Then
        XCTAssertTrue(prompt.contains("disfluenc"))
    }

    func test_BaseSystemPrompt_ContainsPreserveInstruction() {
        // Given
        let prompt = TextCleanupPrompts.baseSystemPrompt

        // Then
        XCTAssertTrue(prompt.contains("Preserve"))
    }

    func test_BaseSystemPrompt_MentionsFillerWords() {
        // Given
        let prompt = TextCleanupPrompts.baseSystemPrompt

        // Then
        XCTAssertTrue(prompt.contains("filler"))
    }

    func test_BaseSystemPrompt_MentionsListFormatting() {
        // Given
        let prompt = TextCleanupPrompts.baseSystemPrompt

        // Then
        XCTAssertTrue(prompt.lowercased().contains("list"))
    }

    // MARK: - Formatting Prompt Tests

    func test_FormattingPrompt_Default_ReturnsNil() {
        // Given
        let profile = TextCleanupProfile.default

        // When
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: profile)

        // Then
        XCTAssertNil(prompt)
    }

    func test_FormattingPrompt_Email_ReturnsContent() {
        // Given
        let profile = TextCleanupProfile.email

        // When
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: profile)

        // Then
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt!.contains("email"))
    }

    func test_FormattingPrompt_Chat_ReturnsContent() {
        // Given
        let profile = TextCleanupProfile.chat

        // When
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: profile)

        // Then
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt!.contains("chat"))
    }

    func test_FormattingPrompt_Markdown_ReturnsContent() {
        // Given
        let profile = TextCleanupProfile.markdown

        // When
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: profile)

        // Then
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt!.contains("Markdown"))
    }

    func test_FormattingPrompt_Document_ReturnsContent() {
        // Given
        let profile = TextCleanupProfile.document

        // When
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: profile)

        // Then
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt!.contains("prose"))
    }

    // MARK: - Email Prompt Content Tests

    func test_EmailPrompt_MentionsParagraphStructure() {
        // Given
        let profile = TextCleanupProfile.email
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: profile)

        // Then
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt!.contains("Paragraph") || prompt!.contains("paragraph"))
    }

    func test_EmailPrompt_MentionsGreeting() {
        // Given
        let profile = TextCleanupProfile.email
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: profile)

        // Then
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt!.contains("greeting"))
    }

    func test_EmailPrompt_MentionsSignature() {
        // Given
        let profile = TextCleanupProfile.email
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: profile)

        // Then
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt!.lowercased().contains("signature") || prompt!.lowercased().contains("name"))
    }

    // MARK: - Chat Prompt Content Tests

    func test_ChatPrompt_MentionsCompact() {
        // Given
        let profile = TextCleanupProfile.chat
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: profile)

        // Then
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt!.contains("compact"))
    }

    func test_ChatPrompt_MentionsNoBlankLines() {
        // Given
        let profile = TextCleanupProfile.chat
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: profile)

        // Then
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt!.lowercased().contains("no blank lines") || prompt!.lowercased().contains("no multi-paragraph"))
    }

    // MARK: - Markdown Prompt Content Tests

    func test_MarkdownPrompt_MentionsBulletLists() {
        // Given
        let profile = TextCleanupProfile.markdown
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: profile)

        // Then
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt!.contains("bullet") || prompt!.contains("-"))
    }

    func test_MarkdownPrompt_MentionsNumberedLists() {
        // Given
        let profile = TextCleanupProfile.markdown
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: profile)

        // Then
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt!.contains("numbered") || prompt!.contains("1."))
    }

    // MARK: - Document Prompt Content Tests

    func test_DocumentPrompt_MentionsProse() {
        // Given
        let profile = TextCleanupProfile.document
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: profile)

        // Then
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt!.contains("prose"))
    }

    func test_DocumentPrompt_MentionsParagraphs() {
        // Given
        let profile = TextCleanupProfile.document
        let prompt = TextCleanupPrompts.formattingSystemPrompt(for: profile)

        // Then
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt!.contains("paragraph"))
    }

    // MARK: - Profile From Raw Value Tests

    func test_ProfileFromRawValue_Default() {
        // Given
        let rawValue = "default"

        // When
        let profile = TextCleanupProfile(rawValue: rawValue)

        // Then
        XCTAssertEqual(profile, .default)
    }

    func test_ProfileFromRawValue_Email() {
        // Given
        let rawValue = "email"

        // When
        let profile = TextCleanupProfile(rawValue: rawValue)

        // Then
        XCTAssertEqual(profile, .email)
    }

    func test_ProfileFromRawValue_Invalid() {
        // Given
        let rawValue = "invalid"

        // When
        let profile = TextCleanupProfile(rawValue: rawValue)

        // Then
        XCTAssertNil(profile)
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
