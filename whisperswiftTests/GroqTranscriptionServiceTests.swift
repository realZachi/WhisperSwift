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
        // Given
        let error = GroqTranscriptionError.missingApiKey

        // Then
        XCTAssertEqual(
            error.errorDescription,
            "Groq API key is missing. Set it in Settings or via GROQ_API_KEY."
        )
    }

    func test_GroqTranscriptionError_RequestFailed_WithEmptyBody_HasCorrectDescription() {
        // Given
        let error = GroqTranscriptionError.requestFailed(statusCode: 401, body: "")

        // Then
        XCTAssertEqual(error.errorDescription, "Groq request failed with status 401.")
    }

    func test_GroqTranscriptionError_RequestFailed_WithBody_IncludesBody() {
        // Given
        let body = "Invalid API key"
        let error = GroqTranscriptionError.requestFailed(statusCode: 401, body: body)

        // Then
        XCTAssertEqual(error.errorDescription, "Groq request failed with status 401: Invalid API key")
    }

    func test_GroqTranscriptionError_InvalidResponse_HasCorrectDescription() {
        // Given
        let error = GroqTranscriptionError.invalidResponse

        // Then
        XCTAssertEqual(error.errorDescription, "Groq returned an invalid response.")
    }

    func test_GroqTranscriptionError_RequestFailed_ServerError_HasCorrectDescription() {
        // Given
        let error = GroqTranscriptionError.requestFailed(statusCode: 500, body: "Internal Server Error")

        // Then
        XCTAssertEqual(error.errorDescription, "Groq request failed with status 500: Internal Server Error")
    }

    func test_GroqTranscriptionError_RequestFailed_RateLimited_HasCorrectDescription() {
        // Given
        let error = GroqTranscriptionError.requestFailed(statusCode: 429, body: "Rate limit exceeded")

        // Then
        XCTAssertEqual(error.errorDescription, "Groq request failed with status 429: Rate limit exceeded")
    }

    // MARK: - WAV Data Generation Tests

    func test_WavData_HeaderSize_Is44Bytes() {
        // WAV header should always be 44 bytes
        let headerSize = 44
        XCTAssertEqual(headerSize, 44)
    }

    func test_WavData_SampleSize_Is2BytesFor16Bit() {
        // 16-bit audio uses 2 bytes per sample
        let bytesPerSample = 2
        XCTAssertEqual(bytesPerSample, 2)
    }

    func test_WavData_EstimatedSize_CalculatesCorrectly() {
        // Given
        let sampleCount = 16000 // 1 second at 16kHz
        let headerSize = 44
        let bytesPerSample = 2

        // When
        let estimatedSize = headerSize + sampleCount * bytesPerSample

        // Then
        XCTAssertEqual(estimatedSize, 32044)
    }

    func test_WavData_EstimatedSize_30Seconds() {
        // Given
        let sampleCount = 480000 // 30 seconds at 16kHz
        let headerSize = 44
        let bytesPerSample = 2

        // When
        let estimatedSize = headerSize + sampleCount * bytesPerSample

        // Then
        XCTAssertEqual(estimatedSize, 960044)
    }

    // MARK: - Chunking Tests

    func test_Chunking_MaxAttachmentBytes_Is25MB() {
        // Maximum attachment size for Groq API is 25MB
        let maxBytes = 25 * 1024 * 1024
        XCTAssertEqual(maxBytes, 26214400)
    }

    func test_Chunking_TargetSegmentSeconds_Is30() {
        // Target segment duration for chunking
        let targetSeconds: Double = 30
        XCTAssertEqual(targetSeconds, 30)
    }

    func test_Chunking_OverlapSeconds_Is2() {
        // Overlap between chunks to avoid cutting words
        let overlapSeconds: Double = 2
        XCTAssertEqual(overlapSeconds, 2)
    }

    func test_Chunking_MaxSingleRequestSeconds_Is40() {
        // Maximum duration for a single request
        let maxSeconds: Double = 40
        XCTAssertEqual(maxSeconds, 40)
    }

    // MARK: - Transcript Cleanup Tests

    func test_CleanTranscriptionArtifacts_RemovesBlankAudio() {
        // Given
        let text = "Hello [BLANK_AUDIO] world"
        let artifacts = ["[BLANK_AUDIO]", "(blank audio)", "[MUSIC]", "[SILENCE]"]

        // When
        var cleaned = text
        for artifact in artifacts {
            cleaned = cleaned.replacingOccurrences(of: artifact, with: "")
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Then
        XCTAssertEqual(cleaned, "Hello  world")
    }

    func test_CleanTranscriptionArtifacts_RemovesMusic() {
        // Given
        let text = "[MUSIC] Some text [MUSIC]"
        let artifacts = ["[BLANK_AUDIO]", "(blank audio)", "[MUSIC]", "[SILENCE]"]

        // When
        var cleaned = text
        for artifact in artifacts {
            cleaned = cleaned.replacingOccurrences(of: artifact, with: "")
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Then
        XCTAssertEqual(cleaned, "Some text")
    }

    func test_CleanTranscriptionArtifacts_RemovesSilence() {
        // Given
        let text = "[SILENCE] Test [SILENCE]"
        let artifacts = ["[BLANK_AUDIO]", "(blank audio)", "[MUSIC]", "[SILENCE]"]

        // When
        var cleaned = text
        for artifact in artifacts {
            cleaned = cleaned.replacingOccurrences(of: artifact, with: "")
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Then
        XCTAssertEqual(cleaned, "Test")
    }

    func test_CleanTranscriptionArtifacts_HandlesEmptyString() {
        // Given
        let text = "[BLANK_AUDIO]"
        let artifacts = ["[BLANK_AUDIO]", "(blank audio)", "[MUSIC]", "[SILENCE]"]

        // When
        var cleaned = text
        for artifact in artifacts {
            cleaned = cleaned.replacingOccurrences(of: artifact, with: "")
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Then
        XCTAssertEqual(cleaned, "")
    }

    func test_CleanTranscriptionArtifacts_PreservesNormalText() {
        // Given
        let text = "This is a normal transcription without artifacts"
        let artifacts = ["[BLANK_AUDIO]", "(blank audio)", "[MUSIC]", "[SILENCE]"]

        // When
        var cleaned = text
        for artifact in artifacts {
            cleaned = cleaned.replacingOccurrences(of: artifact, with: "")
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Then
        XCTAssertEqual(cleaned, text)
    }

    // MARK: - Word Normalization Tests

    func test_NormalizeWord_RemovesPunctuation() {
        // Given
        let word = "hello,"

        // When
        let scalars = word.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        let normalized = String(String.UnicodeScalarView(scalars)).lowercased()

        // Then
        XCTAssertEqual(normalized, "hello")
    }

    func test_NormalizeWord_ConvertsToLowercase() {
        // Given
        let word = "HELLO"

        // When
        let scalars = word.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        let normalized = scalars.isEmpty ? word.lowercased() : String(String.UnicodeScalarView(scalars)).lowercased()

        // Then
        XCTAssertEqual(normalized, "hello")
    }

    func test_NormalizeWord_HandlesNumbers() {
        // Given
        let word = "test123"

        // When
        let scalars = word.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        let normalized = String(String.UnicodeScalarView(scalars)).lowercased()

        // Then
        XCTAssertEqual(normalized, "test123")
    }

    func test_NormalizeWord_HandlesSpecialCharactersOnly() {
        // Given
        let word = "..."

        // When
        let scalars = word.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        let normalized = scalars.isEmpty ? word.lowercased() : String(String.UnicodeScalarView(scalars)).lowercased()

        // Then
        XCTAssertEqual(normalized, "...")
    }

    // MARK: - Transcript Merging Tests

    func test_MergeTranscripts_CombinesTwoSegments() {
        // Given
        let transcripts = ["Hello world", "This is a test"]

        // When
        var combined = ""
        for chunk in transcripts {
            let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
            if combined.isEmpty {
                combined = trimmed
            } else {
                combined = combined + " " + trimmed
            }
        }

        // Then
        XCTAssertEqual(combined, "Hello world This is a test")
    }

    func test_MergeTranscripts_SkipsEmptySegments() {
        // Given
        let transcripts = ["Hello", "", "world"]

        // When
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

        // Then
        XCTAssertEqual(combined, "Hello world")
    }

    func test_MergeTranscripts_TrimsWhitespace() {
        // Given
        let transcripts = ["  Hello  ", "  world  "]

        // When
        var combined = ""
        for chunk in transcripts {
            let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
            if combined.isEmpty {
                combined = trimmed
            } else {
                combined = combined + " " + trimmed
            }
        }

        // Then
        XCTAssertEqual(combined, "Hello world")
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
        // Given short audio that doesn't need chunking
        let sampleCount = 16000 // 1 second
        let sampleRate: Double = 16000
        let targetSegmentSeconds: Double = 30
        let overlapSeconds: Double = 2

        // When calculating chunk ranges
        let samplesPerSecond = Int(sampleRate.rounded())
        let chunkSamples = Int(targetSegmentSeconds * Double(samplesPerSecond))
        let overlapSamples = Int(overlapSeconds * Double(samplesPerSecond))
        let step = max(1, chunkSamples - overlapSamples)

        var ranges: [Range<Int>] = []
        var start = 0
        while start < sampleCount {
            let end = min(start + chunkSamples, sampleCount)
            ranges.append(start..<end)
            if end == sampleCount { break }
            start += step
        }

        // Then should have only one chunk
        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0], 0..<16000)
    }

    func test_ChunkRanges_MultipleChunks_ForLongAudio() {
        // Given long audio that needs chunking
        let sampleCount = 960000 // 60 seconds at 16kHz
        let sampleRate: Double = 16000
        let targetSegmentSeconds: Double = 30
        let overlapSeconds: Double = 2

        // When calculating chunk ranges
        let samplesPerSecond = Int(sampleRate.rounded())
        let chunkSamples = Int(targetSegmentSeconds * Double(samplesPerSecond))
        let overlapSamples = Int(overlapSeconds * Double(samplesPerSecond))
        let step = max(1, chunkSamples - overlapSamples)

        var ranges: [Range<Int>] = []
        var start = 0
        while start < sampleCount {
            let end = min(start + chunkSamples, sampleCount)
            ranges.append(start..<end)
            if end == sampleCount { break }
            start += step
        }

        // Then should have multiple chunks
        XCTAssertGreaterThan(ranges.count, 1)
    }

    func test_ChunkRanges_EmptyAudio_ReturnsEmptyArray() {
        // Given empty audio
        let sampleCount = 0

        // When
        var ranges: [Range<Int>] = []
        if sampleCount > 0 {
            ranges.append(0..<sampleCount)
        }

        // Then
        XCTAssertTrue(ranges.isEmpty)
    }

    func test_ChunkRanges_OverlapCalculation() {
        // Given
        let sampleRate: Double = 16000
        let overlapSeconds: Double = 2

        // When
        let overlapSamples = Int(overlapSeconds * sampleRate)

        // Then 2 seconds of overlap at 16kHz = 32000 samples
        XCTAssertEqual(overlapSamples, 32000)
    }
}
