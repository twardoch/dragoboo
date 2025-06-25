# Dragoboo Code Streamlining Plan for MVP v1.0

This document outlines the plan to streamline the Dragoboo codebase for a performant, focused MVP v1.0.

## Phase 1: Analysis and Planning (Completed)

1.  **Analyze `PointerScalerTests.swift` and `algorithms.mdc`:** (Completed)
    *   **Finding:** `PointerScaler.swift` (and related files like `EventTap.swift`, `StateManager.swift` from `algorithms.mdc`) appears to be from a previous architecture. The core scaling logic is now in `PrecisionEngine.swift`.
    *   **Decision:** `Tests/DragobooCoreTests/PointerScalerTests.swift` is obsolete. `.cursor/rules/algorithms.mdc` is outdated.

2.  **Evaluate `recovery_trackpad.sh`:** (Completed)
    *   **Finding:** The script and README confirm it's a legacy tool for older versions that might have altered system defaults. Dragoboo v2.0 uses temporary event modification and cursor warping, making this script unnecessary.
    *   **Decision:** `recovery_trackpad.sh` is obsolete.

3.  **Review `PrecisionEngine.swift` for Slimming Opportunities:** (Completed)
    *   **State Management:** `AppState` is the source of truth. `PrecisionEngine` receives settings. The interplay between `precisionFactor` and `slowSpeedPercentage` in the engine is functional but could be more direct if `AppState` passed both, or if the engine always derived one from the other based on a single input. For MVP, current state is acceptable after other cleanups.
    *   **`fnKeyCode`:** Identified as unused.
    *   **`shouldActivateSlowSpeedMode`:** Redundant with `isSlowSpeedModifiersActive` and `isInPrecisionMode` for state change logic.
    *   **`convertToGlobalTopLeft`:** Current implementation is standard for main screen coordinate conversion and acceptable for MVP. TODO for multi-monitor robustness is valid for future.
    *   **Logging/Comments:** Generally acceptable. Minor verbosity can be tolerated.
    *   **Error Handling:** `PrecisionEngineError` covers critical startup. Acceptable for MVP.
    *   **`calculateEffectivePrecisionFactor`:** Complex but necessary for features. Acceptable for MVP.

4.  **Review `AppState.swift` for Slimming Opportunities:** (Completed)
    *   **`legacyPrecisionFactor`:** Appears unused and can be removed.
    *   **`updatePrecisionFactor(_ factor: Double)` method:** Appears unused.
    *   **Default Values & Logging:** Acceptable for MVP.

5.  **General Code Cleanup Review:** (Completed)
    *   Identified unused `@Published var isDragging` in `AppState`.
    *   Identified unused `@Environment(\.dismiss) private var dismiss` in `ContentView`.
    *   Potentially unused `logger` in `DragobooApp` struct (minor).

6.  **Update Documentation (`README.md`):** (Completed)
    *   Reference to `recovery_trackpad.sh` needs removal. (Done by editing README.md)

## Phase 2: Implementation

1.  **Create `PLAN.md`, `TODO.md`, and `CHANGELOG.md`:** (This step)
    *   Populate these files based on the analysis and decisions from Phase 1. `PLAN.md` is this file.

2.  **Implement Code Removals and Cleanups:**
    *   **Delete Obsolete Files:**
        *   Remove `Tests/DragobooCoreTests/PointerScalerTests.swift`.
        *   Remove `recovery_trackpad.sh`.
    *   **Clean up `PrecisionEngine.swift`:**
        *   Remove `private static let fnKeyCode: CGKeyCode`.
        *   Remove `private var shouldActivateSlowSpeedMode: Bool`.
        *   Adjust logic in `handleFlagsChanged` and `handleActivationStateChange` to use `isSlowSpeedModifiersActive` and `isInPrecisionMode` directly for state change detection.
    *   **Clean up `AppState.swift` (in `DragobooApp.swift`):**
        *   Remove `@AppStorage("precisionFactor") private var legacyPrecisionFactor: Double`.
        *   Simplify comments in `init()` related to `legacyPrecisionFactor`.
        *   Verify and remove `func updatePrecisionFactor(_ factor: Double)` if confirmed unused.
        *   Remove `@Published var isDragging = false`.
        *   (Optional, low priority) Remove `logger` from `DragobooApp` struct if deemed truly unnecessary. For this pass, I will keep it as it's conventional.
    *   **Clean up `ContentView.swift`:**
        *   Remove `@Environment(\.dismiss) private var dismiss`.

3.  **Testing:**
    *   Thoroughly manually test the application after all changes:
        *   Slow speed mode activation with different modifier keys.
        *   Slow speed percentage adjustments.
        *   Drag acceleration behavior (start speed, acceleration over radius).
        *   Interaction between slow speed and drag acceleration (precedence).
        *   UI controls responsiveness.
        *   Accessibility permission request and handling.
        *   App behavior on start, quit, and if permissions change.
    *   Ensure no regressions in core functionality.

4.  **Update `CHANGELOG.md`:**
    *   Document all significant changes made during the implementation phase. This will be done as changes are made.

5.  **Final Review:**
    *   Quickly review the changed files for any missed opportunities or errors.
    *   Ensure the codebase is in a clean, functional state for an MVP.

6.  **Submit:**
    *   Commit all changes with a comprehensive commit message.
    *   Branch name should reflect the nature of the work (e.g., `refactor/streamline-mvp`).

## Out of Scope for MVP v1.0 Slimming (Future Considerations):

*   Extensive refactoring of `calculateEffectivePrecisionFactor` if current logic is correct.
*   Overhauling the logging system (e.g., configurable log levels).
*   Robust multi-monitor support for `convertToGlobalTopLeft` beyond current implementation.
*   Updating `.cursor/rules/algorithms.mdc` (as it's not user-facing like README).
*   Dynamically fetching app version for display in UI instead of hardcoded string.
*   Adding new unit tests for `PrecisionEngine` (current focus is on removing obsolete tests and code).
