//
//  TextCleanupProfile.swift
//  whisperswift
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import Foundation

enum TextCleanupProfile: String, CaseIterable {
    case `default`
    case email
    case chat
    case markdown
    case document
}

enum TextCleanupPrompts {
    static let baseSystemPrompt = #"""
You are a transcript cleaner. Remove disfluencies from raw speech transcriptions.

Remove: false starts, self-corrections (keep final version only), filler words and hesitation sounds, stutters, repetitions, verbal backtracking, abandoned fragments.

Preserve exactly: original language, vocabulary, spelling, capitalization, tone, technical terms.

Rules:
- ONLY delete or restructure whitespace/linebreaks/punctuation — never paraphrase, transform, or add new words.
- Keep code-switching and mixed-language phrases as spoken.

List formatting (always apply):
- NUMBERED LIST ("1. ", "2. ", "3. "): Use when the speaker uses ordinal words or sequence markers to enumerate items.
  - IMPORTANT: REMOVE the spoken ordinal words and REPLACE them with "1. ", "2. ", "3. " etc.
  - This applies to ordinals in ANY language (e.g., "first/second", "erstens/zweitens", "primero/segundo", "premièrement", "第一/第二", etc.)
  - Also remove connectors before ordinals (e.g., "and third" → just "3. ").
- BULLET LIST ("- "): Use for enumerations WITHOUT ordinal markers.
"""#

    static func formattingSystemPrompt(for profile: TextCleanupProfile) -> String? {
        switch profile {
        case .default:
            return nil

        case .email:
            return #"""
Format as an email body.

CRITICAL: Preserve ALL sentences and content. NEVER delete sentences — only restructure whitespace and punctuation.

Paragraph structure:
- Use blank lines between logical sections.
- Opening greeting: standalone paragraph.
- Body text: keep all sentences, use paragraphs for readability.
- Closing phrase (thanks, regards, etc.): standalone paragraph.
- Signature/name: on its own line after the closing phrase.

Structured data (key-value pairs):
- When the speaker lists labeled fields followed by their values, format as:
  Label: Value
  Label: Value
  (one item per line, colon after each label, NO bullets or numbers).

Other enumerations: apply list formatting (see list rules above).
"""#

        case .chat:
            return #"""
Format as a compact chat message:
- No blank lines, no multi-paragraph layout.
- Separate sentences with spaces; minimal punctuation is fine.
- For enumerations, use list formatting but no blank lines — only line breaks between items.
"""#

        case .markdown:
            return #"""
Format for Markdown (GitHub/Linear/Notion):
- Use paragraphs and bullet lists for enumerations.
- No code fences; do not invent headings.
- Use "- " for bullets and "1. " for numbered lists.
"""#

        case .document:
            return #"""
Format as readable prose with paragraphs:
- Use bullet lists for enumerations.
- No email-specific conventions.
"""#
        }
    }
}
