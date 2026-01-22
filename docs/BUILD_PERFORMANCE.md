# Build Performance Guide

This document describes how to track, analyze, and improve build performance for WhisperSwift.

## Table of Contents

- [Tracking Build Times Locally](#tracking-build-times-locally)
- [CI Build Timing](#ci-build-timing)
- [Historical Build Time Expectations](#historical-build-time-expectations)
- [Xcode Build Timing Flags](#xcode-build-timing-flags)
- [Tips for Improving Build Performance](#tips-for-improving-build-performance)

## Tracking Build Times Locally

### Using the Build Timing Script

The easiest way to track build times locally is to use the provided script:

```bash
# Debug build (default)
./scripts/build-with-timing.sh

# Release build
./scripts/build-with-timing.sh Release
```

The script will:
1. Record the build start time
2. Run the xcodebuild command with timing flags
3. Calculate and display the total duration
4. Save timing data to `build/logs/build-timing.log` (human-readable)
5. Append to `build/logs/build-timing.json` (machine-readable)

### Manual Timing with Xcode

When building in Xcode, you can view build times:

1. **Build Timing Summary**: After a build, go to the Report Navigator (Cmd+9) and select the build log. Look for "Build Timing Summary" at the end.

2. **Per-Target Timing**: In the build log, each target shows its compilation time.

### Manual Timing from CLI

```bash
# Time a build manually
time xcodebuild -project whisperswift.xcodeproj \
    -scheme whisperswift \
    -configuration Debug \
    -showBuildTimingSummary \
    build
```

## CI Build Timing

### Viewing Build Times in GitHub Actions

1. Navigate to the Actions tab in the GitHub repository
2. Select a workflow run
3. The build timing summary is displayed in the job summary
4. Detailed timing artifacts are available for download

### Build Timing Artifacts

Each CI run produces the following artifacts:

- `build-timing-report.md`: Human-readable timing report
- `build-timing-combined.json`: Machine-readable timing data
- `debug-timing.json`: Debug build timing
- `release-timing.json`: Release build timing

Artifacts are retained for 90 days, allowing historical comparison.

### Comparing PR Build Times

When reviewing a pull request:
1. Check the build timing summary in the PR checks
2. Download artifacts from both the PR and main branch runs
3. Compare the JSON timing data to identify regressions

## Historical Build Time Expectations

### Expected Build Times

| Configuration | Clean Build | Incremental Build |
|---------------|-------------|-------------------|
| Debug         | 15-30s      | 2-10s             |
| Release       | 30-60s      | 5-15s             |

**Notes:**
- Times are approximate and depend on hardware (Apple Silicon vs Intel)
- CI builds may be slower due to runner specifications
- Incremental builds are much faster after the initial build

### Build Time Benchmarks by Machine

| Machine Type           | Debug (Clean) | Release (Clean) |
|------------------------|---------------|-----------------|
| M1 MacBook Pro         | ~20s          | ~35s            |
| M2 MacBook Air         | ~18s          | ~32s            |
| M3 MacBook Pro         | ~15s          | ~28s            |
| GitHub Actions (macos-14) | ~25s       | ~45s            |

### Performance Regression Thresholds

Consider investigating if build times increase by:
- More than 20% for incremental builds
- More than 50% for clean builds
- More than 100% for any build (likely indicates a problem)

## Xcode Build Timing Flags

### Available Timing Flags

```bash
# Show build timing summary at the end of build
xcodebuild ... -showBuildTimingSummary

# Show detailed build timing for each compilation unit
xcodebuild ... -showBuildTimingSummary OTHER_SWIFT_FLAGS="-Xfrontend -debug-time-compilation"

# Generate timing trace (Xcode 14+)
xcodebuild ... -resultBundlePath build/result.xcresult

# Parallel build jobs (default is based on CPU cores)
xcodebuild ... -jobs 4
```

### Enabling Detailed Timing in Xcode

1. Go to Product > Scheme > Edit Scheme
2. Select Build > Build Options
3. Enable "Show build operation timing summary"

### Build Settings for Performance Debugging

Add these to your xcodebuild command for more timing info:

```bash
# Show all build settings
xcodebuild ... -showBuildSettings

# Verbose output with timing
xcodebuild ... -verbose

# Debug Swift compilation times
OTHER_SWIFT_FLAGS="-Xfrontend -debug-time-compilation"

# Debug type checking times
OTHER_SWIFT_FLAGS="-Xfrontend -debug-time-function-bodies"
```

## Tips for Improving Build Performance

### 1. Use Incremental Builds

Avoid cleaning builds unless necessary:
- Use Cmd+B (Build) instead of Cmd+Shift+K followed by Cmd+B
- Only clean when you suspect build cache corruption

### 2. Optimize Swift Compilation

**Reduce Type Inference Complexity:**
```swift
// Slower - compiler must infer complex types
let items = data.map { $0.items }.flatMap { $0 }.filter { $0.isValid }

// Faster - explicit types help the compiler
let items: [Item] = data.flatMap { datum -> [Item] in
    datum.items.filter { item -> Bool in
        item.isValid
    }
}
```

**Use Whole Module Optimization for Release:**
```
// In Build Settings
SWIFT_COMPILATION_MODE = wholemodule  // For Release
```

### 3. Reduce Build Dependencies

- Minimize imports in each file
- Use forward declarations where possible
- Consider breaking large files into smaller modules

### 4. Hardware Recommendations

- Use Apple Silicon Macs for best performance
- Ensure adequate RAM (16GB+ recommended)
- Use SSD storage (standard on modern Macs)
- Close other resource-intensive applications during builds

### 5. Xcode Configuration

**Disable features not needed during development:**
- Turn off "Index while building" if not needed
- Disable "Build Documentation During Build" for Debug

**Optimize derived data:**
- Keep derived data on fast storage
- Periodically clean old derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData/*`

### 6. CI-Specific Optimizations

- Use caching for derived data (when supported)
- Run lint and build in parallel jobs
- Use incremental builds when possible
- Consider build caching services for large teams

## Troubleshooting Slow Builds

### Identifying Slow Files

1. Build with timing flags
2. Look for files taking longer than expected
3. Check for complex type inference or large functions

### Common Causes of Slow Builds

| Symptom | Likely Cause | Solution |
|---------|--------------|----------|
| All files rebuild | Bridging header change | Minimize bridging header |
| Single file slow | Complex Swift types | Add explicit type annotations |
| Linking slow | Too many symbols | Review dependencies |
| Indexing slow | Large workspace | Close unused projects |

### Getting Help

If you experience persistent build performance issues:
1. Generate a build timing report using the script
2. Check for recent changes that may have caused regression
3. Review the Xcode build logs for warnings
4. Consider profiling with Instruments
