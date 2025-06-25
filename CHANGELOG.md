# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- This CHANGELOG.md file.

### Removed
- Obsolete `Tests/DragobooCoreTests/PointerScalerTests.swift` file, as `PointerScaler.swift` no longer exists.
- Obsolete `recovery_trackpad.sh` script, as the current app version doesn't modify persistent system settings.
- Unused `private static let fnKeyCode: CGKeyCode` from `PrecisionEngine.swift`.
- Redundant `private var shouldActivateSlowSpeedMode: Bool` from `PrecisionEngine.swift`.
- Unused `@AppStorage("precisionFactor") private var legacyPrecisionFactor: Double` from `AppState.swift`.
- Unused `@Published var isDragging = false` from `AppState.swift`.
- Unused `func updatePrecisionFactor(_ factor: Double)` method from `AppState.swift`.
- Unused `@Environment(\.dismiss) private var dismiss` from `ContentView.swift`.

### Changed
- Simplified slow speed activation logic in `PrecisionEngine.swift`'s `handleFlagsChanged` and `handleActivationStateChange` methods.
- Simplified comments in `AppState.swift`'s `init()` method related to removed legacy properties.
- Updated `README.md` to remove reference to the obsolete `recovery_trackpad.sh` script.

### Fixed
- (No specific bug fixes in this batch of changes, focus was on slimming)
