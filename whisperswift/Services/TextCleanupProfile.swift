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

Remove: false starts, self-corrections (keep final version only), filler words (um, uh, äh, ähm, euh, hmm, mhm), stutters, repetitions, verbal backtracking ("no wait", "I mean"), abandoned fragments.

Preserve exactly: original language, vocabulary, spelling, capitalization, tone, technical terms.

Rules:
- ONLY delete or restructure whitespace/linebreaks/punctuation — never paraphrase, transform, or add new words.
- If speaker said "fix das", keep "fix das".

List formatting (always apply):
- NUMBERED LIST ("1. ", "2. ", "3. "): Use when the speaker uses ordinal words or numbers to enumerate.
  - IMPORTANT: REMOVE the ordinal words and REPLACE them with "1. ", "2. ", "3. " etc.
  - Remove these German ordinals: "erstens", "zweitens", "drittens", "viertens", "Punkt eins", "Punkt zwei", "und drittens", "und zweitens"
  - Remove these English ordinals: "first", "second", "third", "firstly", "secondly", "point one", "point two", "number one"
  - Example: "Erstens das ist wichtig. Zweitens das auch." → "1. Das ist wichtig.\n2. Das auch."
- BULLET LIST ("- "): Use for enumerations WITHOUT ordinal markers (e.g., "A, B und C").
- Connectors like "und" before the last ordinal should also be removed.
"""#

    static func formattingSystemPrompt(for profile: TextCleanupProfile) -> String? {
        switch profile {
        case .default:
            return nil

        case .email:
            return #"""
Format as an email body:
- Use sensible paragraphs with blank lines between them.
- If a greeting or closing is recognizable in the text, treat as separate paragraphs (do not invent new words).
- Apply list formatting for any enumerations (see list rules above).
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
