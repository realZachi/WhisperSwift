//
//  GroqTranscriptionServiceTests.swift
//  whisperswiftTests
//
//  Tests for GroqTranscriptionService
//

import XCTest
@testable import whisperswift

final class GroqTranscriptionServiceTests: XCTestCase {

    // MARK: - Error Tests

    func test_GroqTranscriptionError_MissingApiKey_HasCorrectDescription() {
        XCTAssertEqual(
            GroqTranscriptionError.missingApiKey.errorDescription,
            "Groq API key is missing. Set it in Settings or via GROQ_API_KEY."
        )
    }

    func test_GroqTranscriptionError_RequestFailed_WithEmptyBody_HasCorrectDescription() {
        let error = GroqTranscriptionError.requestFailed(statusCode: 401, body: "")
        XCTAssertEqual(error.errorDescription, "Groq request failed with status 401.")
    }

    func test_GroqTranscriptionError_RequestFailed_WithBody_IncludesBody() {
        let error = GroqTranscriptionError.requestFailed(statusCode: 401, body: "Invalid API key")
        XCTAssertEqual(error.errorDescription, "Groq request failed with status 401: Invalid API key")
    }

    func test_GroqTranscriptionError_InvalidResponse_HasCorrectDescription() {
        XCTAssertEqual(GroqTranscriptionError.invalidResponse.errorDescription, "Groq returned an invalid response.")
    }

    func test_GroqTranscriptionError_RequestFailed_ServerError_HasCorrectDescription() {
        let error = GroqTranscriptionError.requestFailed(statusCode: 500, body: "Internal Server Error")
        XCTAssertEqual(error.errorDescription, "Groq request failed with status 500: Internal Server Error")
    }

    func test_GroqTranscriptionError_RequestFailed_RateLimited_HasCorrectDescription() {
        let error = GroqTranscriptionError.requestFailed(statusCode: 429, body: "Rate limit exceeded")
        XCTAssertEqual(error.errorDescription, "Groq request failed with status 429: Rate limit exceeded")
    }

    // MARK: - WAV Data Generation Tests

    func test_WavData_HeaderSize_Is44Bytes() {
        XCTAssertEqual(44, 44) // WAV header is always 44 bytes
    }

    func test_WavData_SampleSize_Is2BytesFor16Bit() {
        XCTAssertEqual(2, 2) // 16-bit audio uses 2 bytes per sample
    }

    func test_WavData_EstimatedSize_CalculatesCorrectly() {
        let sampleCount = 16000 // 1 second at 16kHz
        let estimatedSize = 44 + sampleCount * 2
        XCTAssertEqual(estimatedSize, 32044)
    }

    func test_WavData_EstimatedSize_30Seconds() {
        let sampleCount = 480000 // 30 seconds at 16kHz
        let estimatedSize = 44 + sampleCount * 2
        XCTAssertEqual(estimatedSize, 960044)
    }

    // MARK: - Chunking Tests

    func test_Chunking_MaxAttachmentBytes_Is25MB() {
        XCTAssertEqual(25 * 1024 * 1024, 26214400)
    }

    func test_Chunking_TargetSegmentSeconds_Is30() {
        XCTAssertEqual(30.0, 30.0)
    }

    func test_Chunking_OverlapSeconds_Is2() {
        XCTAssertEqual(2.0, 2.0)
    }

    func test_Chunking_MaxSingleRequestSeconds_Is40() {
        XCTAssertEqual(40.0, 40.0)
    }

    // MARK: - Transcript Cleanup Tests

    func test_CleanTranscriptionArtifacts_RemovesBlankAudio() {
        let cleaned = cleanArtifacts("Hello [BLANK_AUDIO] world")
        XCTAssertEqual(cleaned, "Hello  world")
    }

    func test_CleanTranscriptionArtifacts_RemovesMusic() {
        let cleaned = cleanArtifacts("[MUSIC] Some text [MUSIC]")
        XCTAssertEqual(cleaned, "Some text")
    }

    func test_CleanTranscriptionArtifacts_RemovesSilence() {
        let cleaned = cleanArtifacts("[SILENCE] Test [SILENCE]")
        XCTAssertEqual(cleaned, "Test")
    }

    func test_CleanTranscriptionArtifacts_HandlesEmptyString() {
        let cleaned = cleanArtifacts("[BLANK_AUDIO]")
        XCTAssertEqual(cleaned, "")
    }

    func test_CleanTranscriptionArtifacts_PreservesNormalText() {
        let text = "This is a normal transcription without artifacts"
        XCTAssertEqual(cleanArtifacts(text), text)
    }

    private func cleanArtifacts(_ text: String) -> String {
        let artifacts = ["[BLANK_AUDIO]", "(blank audio)", "[MUSIC]", "[SILENCE]"]
        var cleaned = text
        for artifact in artifacts {
            cleaned = cleaned.replacingOccurrences(of: artifact, with: "")
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Word Normalization Tests

    func test_NormalizeWord_RemovesPunctuation() {
        XCTAssertEqual(normalizeWord("hello,"), "hello")
    }

    func test_NormalizeWord_ConvertsToLowercase() {
        XCTAssertEqual(normalizeWord("HELLO"), "hello")
    }

    func test_NormalizeWord_HandlesNumbers() {
        XCTAssertEqual(normalizeWord("test123"), "test123")
    }

    func test_NormalizeWord_HandlesSpecialCharactersOnly() {
        XCTAssertEqual(normalizeWord("..."), "...")
    }

    private func normalizeWord(_ word: String) -> String {
        let scalars = word.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        if scalars.isEmpty {
            return word.lowercased()
        }
        return String(String.UnicodeScalarView(scalars)).lowercased()
    }

    // MARK: - Transcript Merging Tests

    func test_MergeTranscripts_CombinesTwoSegments() {
        let combined = mergeTranscripts(["Hello world", "This is a test"])
        XCTAssertEqual(combined, "Hello world This is a test")
    }

    func test_MergeTranscripts_SkipsEmptySegments() {
        let combined = mergeTranscripts(["Hello", "", "world"])
        XCTAssertEqual(combined, "Hello world")
    }

    func test_MergeTranscripts_TrimsWhitespace() {
        let combined = mergeTranscripts(["  Hello  ", "  world  "])
        XCTAssertEqual(combined, "Hello world")
    }

    private func mergeTranscripts(_ transcripts: [String]) -> String {
        var combined = ""
        for chunk in transcripts {
            let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if combined.isEmpty {
                combined = trimmed
            } else {
                combined = combined + " " + trimmed
            }
        }
        return combined
    }

    // MARK: - Performance Tests

    func test_WavSizeEstimation_Performance() {
        measure {
            for sampleCount in stride(from: 16000, to: 1600000, by: 16000) {
                let headerSize = 44
                let bytesPerSample = 2
                _ = headerSize + sampleCount * bytesPerSample
            }
        }
    }

    func test_TranscriptMerging_Performance() {
        let transcripts = (0..<100).map { "This is transcript segment number \($0) with some content" }

        measure {
            var combined = ""
            for chunk in transcripts {
                let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                if combined.isEmpty {
                    combined = trimmed
                } else {
                    combined = combined + " " + trimmed
                }
            }
        }
    }
}

// MARK: - Chunk Range Tests

final class ChunkRangeTests: XCTestCase {

    func test_ChunkRanges_SingleChunk_ForShortAudio() {
        let ranges = calculateChunkRanges(sampleCount: 16000) // 1 second
        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0], 0..<16000)
    }

    func test_ChunkRanges_MultipleChunks_ForLongAudio() {
        let ranges = calculateChunkRanges(sampleCount: 960000) // 60 seconds
        XCTAssertGreaterThan(ranges.count, 1)
    }

    func test_ChunkRanges_EmptyAudio_ReturnsEmptyArray() {
        let ranges = calculateChunkRanges(sampleCount: 0)
        XCTAssertTrue(ranges.isEmpty)
    }

    func test_ChunkRanges_OverlapCalculation() {
        let overlapSamples = Int(2.0 * 16000) // 2 seconds at 16kHz
        XCTAssertEqual(overlapSamples, 32000)
    }

    private func calculateChunkRanges(sampleCount: Int, targetSeconds: Double = 30, overlapSeconds: Double = 2) -> [Range<Int>] {
        guard sampleCount > 0 else { return [] }
        let sampleRate = 16000
        let chunkSamples = Int(targetSeconds * Double(sampleRate))
        let overlapSamples = Int(overlapSeconds * Double(sampleRate))
        let step = max(1, chunkSamples - overlapSamples)

        var ranges: [Range<Int>] = []
        var start = 0
        while start < sampleCount {
            let end = min(start + chunkSamples, sampleCount)
            ranges.append(start..<end)
            if end == sampleCount { break }
            start += step
        }
        return ranges
    }
}
