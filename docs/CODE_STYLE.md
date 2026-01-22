# Coding Conventions

## Swift Style

- 4-space indentation
- Types: `UpperCamelCase`
- Methods/variables: `lowerCamelCase`

## Project Structure

- UI code in `whisperswift/UI/`
- Service logic in `whisperswift/Services/`

## Concurrency

Use Swift actors for thread-safe services:
- `GroqTranscriptionService` - API communication
- `AudioRecorder` - audio capture

## Linting & Formatting

- **SwiftLint**: Rules in `.swiftlint.yml`
  - Cyclomatic complexity: 15 warn / 25 error
  - File length: 700 warn / 1200 error
- **SwiftFormat**: Rules in `.swiftformat`
  - 4-space indent
  - 120 character line width
