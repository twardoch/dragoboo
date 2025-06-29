# Dragoboo 🐉🖱️ - Precision Cursor Control for macOS

[![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)](https://www.apple.com/macos) [![Swift](https://img.shields.io/badge/Swift-5.10-orange.svg)](https://swift.org) [![SwiftUI](https://img.shields.io/badge/SwiftUI-Framework-purple.svg)](https://developer.apple.com/xcode/swiftui/) <!-- Assuming MIT License, add if LICENSE file exists: [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE) -->

## Part 1: Accessible Overview

### What is Dragoboo?
Dragoboo is a macOS utility meticulously designed to provide users with enhanced precision for their trackpad and mouse operations. It offers two primary features: a highly configurable "Slow Speed Mode" that temporarily reduces cursor sensitivity when specific modifier keys are held, and an intelligent "Drag Acceleration" mode that allows for slow initial drag movements which then smoothly accelerate to normal speed. This dual functionality ensures users can achieve pixel-perfect accuracy without sacrificing overall navigation speed.

### Who is Dragoboo For?
Dragoboo is invaluable for a wide range of Mac users:
*   **Designers and Artists:** Pixel-peeping in image editors, precise vector work, detailed illustration.
*   **Engineers and Architects:** Working with CAD software, intricate diagrams, and technical drawings.
*   **Video Editors and Animators:** Fine-tuning selections, keyframes, and timelines.
*   **Gamers:** Requiring precise aiming or selection in certain game genres.
*   **Accessibility Users:** Anyone who benefits from finer control over cursor movements.
*   **General Users:** Anyone who occasionally needs extra pointer accuracy for tasks like selecting small UI elements, precise text selection, or navigating dense interfaces.

### Why is Dragoboo Useful?
Modern high-resolution displays and fast default cursor speeds can make precise pointer tasks challenging. Dragoboo addresses this by:
*   **Providing On-Demand Precision:** Instantly switch to slow mode only when needed, without changing system settings.
*   **Enhancing Productivity:** Reduces errors and time spent on fine adjustments.
*   **Improving Workflow Ergonomics:** Offers a more controlled and less frustrating pointing experience.
*   **Customizable Control:** Allows users to tailor the slowdown intensity and activation keys to their preferences.
*   **Intelligent Dragging:** Makes it easy to start drags slowly for accuracy and then quickly cover larger distances.
*   **Non-Intrusive:** Operates quietly from the menu bar and only modifies cursor behavior temporarily and safely.

### Installation

**Requirements:**
*   macOS 13.0 (Ventura) or later.
*   Administrative privileges for the initial Accessibility permission grant.

**Steps:**

1.  **Download/Clone the Repository:**
    ```bash
    git clone https://github.com/twardoch/dragoboo.git
    cd dragoboo
    ```
    *(Note: If distributed as a compiled app, this step would be "Download the Dragoboo.app").*

2.  **Build and Run:**
    The primary way to build and run Dragoboo is using the provided shell script:
    ```bash
    ./run.sh
    ```
    This script compiles the Swift code using Swift Package Manager, creates a `.app` bundle, and launches it.

3.  **Grant Accessibility Permissions:**
    *   On the first launch, Dragoboo will prompt you if it doesn't have Accessibility permissions.
    *   The app's UI will guide you: click "Grant Permission," which opens System Settings.
    *   In `System Settings > Privacy & Security > Accessibility`, find Dragoboo in the list and enable the toggle.
    *   Dragoboo needs these permissions to monitor keyboard modifier keys and to control cursor movement.

### How to Use Dragoboo

#### From the Menu Bar (Graphical User Interface)

Once running, Dragoboo resides in the macOS menu bar, typically represented by a cursor icon (🖱️).

1.  **Access Settings:** Click the Dragoboo icon in the menu bar to open its configuration window.
    *(Image: Current README.md contains `<img width="300" alt="Dragoboo UI" src="docs/ui-screenshot.png">`. This path should be verified or image embedded/hosted if needed for the new README).*

2.  **Configure Slow Speed Mode:**
    *   **Toggle:** Check the "Slow speed" box to enable this feature.
    *   **Modifier Keys:** Click the symbols (`fn`, `⌃`, `⌥`, `⌘`) to select which key(s) will activate slow speed mode when held down. Selected keys are highlighted. Multiple keys can be selected (e.g., holding `fn` AND `Ctrl`). If no keys are selected, slow speed mode cannot be activated via key press.
    *   **Speed Slider:** Adjust the slider (default 1%-100%) to set how much the cursor slows down. 100% is normal speed; lower percentages mean slower movement. This slider also sets the *initial* speed for Drag Acceleration.

3.  **Configure Drag Acceleration:**
    *   **Toggle:** Check the "Drag acceleration" box to enable this feature.
    *   **Modifier Keys:** (Optional) Click the symbols to select modifier key(s) that must be held for drag acceleration to be active *during a drag*. If no keys are selected here, drag acceleration will apply to all drags (if the feature is toggled on).
    *   **Radius Slider:** Adjust the slider (default 50px-1000px) to define the distance over which the cursor accelerates from the initial slow speed (set by the "Slow speed" slider) to normal speed.

4.  **Using the Features:**
    *   **Slow Speed Mode:** If enabled and configured, press and hold your chosen modifier key(s). Your cursor movement and scrolling will now be slower, corresponding to the percentage set. Release the key(s) to return to normal speed. Active modifier keys in the UI will light up green when pressed.
    *   **Drag Acceleration:** If enabled, simply click and drag. The drag will start at the speed set by the "Slow speed" slider. As you continue to drag further (up to the configured radius), the cursor speed will smoothly increase to normal. If modifier keys are configured for drag acceleration, they must be held *during the drag* for this effect.

5.  **Quitting Dragoboo:**
    *   Click the Dragoboo icon in the menu bar.
    *   Click the "Quit" button or press `Cmd+Q` while the popover is active.

#### From the Command Line (Build & Management)

Dragoboo is primarily a GUI application, but its build and execution can be managed via the command line using the provided `Makefile` and scripts:

*   **Build and Run (Default):**
    ```bash
    make
    # or
    make run
    # (Both use ./run.sh)
    ```
*   **Build Only (No Launch):**
    ```bash
    make build
    # (Uses ./run.sh --no-launch)
    ```
*   **Build Release Version:**
    ```bash
    make release
    # (Uses ./run.sh --release)
    ```
*   **Stop a Running Instance:**
    ```bash
    make stop
    # (Uses ./stop.sh)
    ```
*   **Clean Build Artifacts:**
    ```bash
    make clean
    ```

#### Programmatic Usage (Core Logic)

While Dragoboo is designed as a standalone application, its core logic is encapsulated within the `DragobooCore` module, specifically in the `PrecisionEngine.swift` class.

*   **Direct Instantiation (Conceptual):**
    Technically, one could import `DragobooCore` into another Swift project and instantiate `PrecisionEngine`:
    ```swift
    import DragobooCore

    // Example:
    // let engine = PrecisionEngine(precisionFactor: 4.0) // Factor derived from desired percentage
    // engine.updateModifierKeys([.fn]) // Set desired modifier keys
    // engine.updateSlowSpeedEnabled(true) // Enable the slow speed feature in the engine
    // try? engine.start() // Start the engine
    // ...
    // engine.stop() // Stop the engine when done
    ```
*   **Limitations:**
    *   `PrecisionEngine` relies on `AppState` (in `DragobooApp.swift`) for managing settings persistence (`@AppStorage`) and UI updates. Using it standalone would require reimplementing this state management if persistence or dynamic UI updates are needed.
    *   The application lifecycle, menu bar integration, and accessibility permission flow are handled by `DragobooApp.swift`.
    *   Thus, direct programmatic use as a general-purpose library is not its primary design, but the core scaling and event tapping logic is modular.

---

## Part 2: Technical Deep-Dive

### How Dragoboo Works: Precision Engineered Control

Dragoboo's functionality is centered around a sophisticated event processing system that intercepts and modifies user input events at a low level, combined with a responsive state management system.

#### Architectural Overview

Dragoboo consists of two main modules:
1.  **`DragobooApp` (Application Layer):**
    *   Manages the application lifecycle (`@main struct DragobooApp`).
    *   Handles UI presentation (SwiftUI `ContentView` within a `MenuBarExtra`).
    *   Manages application state, user preferences, and permissions (`AppState` class).
    *   Interfaces with `DragobooCore` to enable/disable and configure features.
2.  **`DragobooCore` (Core Logic Layer):**
    *   Contains the `PrecisionEngine` class, responsible for all event tapping, processing, and cursor manipulation.
    *   Defines shared data types like `ModifierKey`.

#### Event Processing Pipeline

The heart of Dragoboo is the `PrecisionEngine`'s event handling:

1.  **Event Tap Creation (`CGEvent.tapCreate`):**
    *   An event tap is installed at `.cgAnnotatedSessionEventTap` (head insert, default options) to intercept system-wide mouse and keyboard flag events.
    *   It listens for a mask of events including:
        *   `flagsChanged`: To detect modifier key presses (fn, Ctrl, Opt, Cmd).
        *   `mouseMoved`, `leftMouseDragged`, `rightMouseDragged`, `otherMouseDragged`: For cursor movement.
        *   `scrollWheel`: For scrolling.
        *   `left/right/otherMouseDown/Up`: To track drag state.
        *   `tapDisabledByTimeout`, `tapDisabledByUserInput`: To attempt re-enabling the tap if it's disabled by the system.

2.  **Event Handling (`PrecisionEngine.handleEvent`)**:
    *   This is the C-style callback function, which then calls methods on the `PrecisionEngine` instance.
    *   **Modifier Key Changes (`handleFlagsChanged`):**
        *   Reads `event.flags` (`CGEventFlags`).
        *   Updates internal boolean states (`isSlowSpeedModifiersActive`, `isDragAccelerationModifiersActive`) based on currently pressed hardware modifier keys compared against the user-configured active modifier sets for each feature (stored in `modifierKeys` and `dragAccelerationModifierKeys`).
        *   Implements precedence: If conditions for both Slow Speed and Drag Acceleration modifiers are met, and their respective active key sets overlap, Slow Speed mode takes priority (i.e., `isDragAccelerationModifiersActive` may be set to `false`).
        *   If the effective state of Slow Speed Mode (`isSlowSpeedModifiersActive`) differs from the current operational state (`isInPrecisionMode`), it calls `handleActivationStateChange`.
    *   **Movement Events (`modifyMovementEvent`):**
        *   Extracts `deltaX` and `deltaY` from the event (checking both integer and double fields like `.mouseEventDeltaX`).
        *   If it's a drag event and drag tracking is active, updates `currentDragDistance` using the magnitude of the raw deltas.
        *   Determines the `effectiveFactor` for scaling (see "Algorithm Details" below).
        *   Applies scaling: `scaledDelta = delta / effectiveFactor`.
        *   Uses an **accumulation algorithm** for fractional movements to ensure smoothness:
            ```swift
            // In PrecisionEngine:
            accumulatedX += deltaX / effectiveFactor
            accumulatedY += deltaY / effectiveFactor
            let scaledX = Int(accumulatedX) // Integer part for current movement
            let scaledY = Int(accumulatedY)
            accumulatedX -= Double(scaledX) // Keep fractional remainder for next event
            accumulatedY -= Double(scaledY)
            ```
        *   If conditions warrant manual cursor control (Slow Speed is fully active OR applicable Drag Acceleration is active for a drag event):
            *   Calculates `newPosition = lastCursorPosition + CGPoint(x: scaledX, y: scaledY)`.
            *   Uses `CGWarpMouseCursorPosition(newPosition)` to directly move the cursor.
            *   Updates `lastCursorPosition` to `newPosition`.
            *   The original event is **consumed (returns `nil`)** to prevent default system handling of the movement.
        *   Otherwise (e.g., normal movement, or features not applicable), the original event is passed through (`Unmanaged.passUnretained(event)`).
    *   **Scroll Events (`modifyScrollEvent`):**
        *   If Slow Speed Mode is active (`isInPrecisionMode` and `slowSpeedEnabled`), scales `scrollWheelEventDeltaAxis1` (vertical) and `scrollWheelEventDeltaAxis2` (horizontal) by `precisionFactor`.
        *   Creates a **new, modified event** using `event.copy()` and `setDoubleValueField`, then returns `Unmanaged.passRetained(modifiedEvent)`.
    *   **Mouse Down/Up Events:**
        *   `left/right/otherMouseDown`: Calls `startDragTracking` if `dragAccelerationEnabled`. This sets `isDragging = true`, resets `currentDragDistance`, and initializes `lastCursorPosition` if needed.
        *   `left/right/otherMouseUp`: Calls `stopDragTracking` if `isDragging` was true. This sets `isDragging = false`.

3.  **State Management (`AppState.swift`):**
    *   `@Published` properties (e.g., `isPrecisionModeActive`, `isAccessibilityGranted`) drive the SwiftUI UI and can trigger updates to `PrecisionEngine`.
    *   `@AppStorage` properties persist user settings (e.g., `slowSpeedEnabled`, `slowSpeedPercentage`, `modifierKeysData`, `accelerationRadius`) via `UserDefaults`.
    *   Manages `isAccessibilityGranted` state by checking `AXIsProcessTrusted()` and initiates permission requests using `AXIsProcessTrustedWithOptions()`.
    *   Instantiates `PrecisionEngine`. When settings change in `AppState` (e.g., user moves a slider), corresponding update methods on the `PrecisionEngine` instance are called (e.g., `updateSlowSpeedPercentage` in AppState leads to `updatePrecisionFactor` in PrecisionEngine).
    *   The `precisionFactor` (used for slow speed mode) is computed in `AppState` as: `200.0 / slowSpeedPercentage`. This means:
        *   100% speed on slider = factor 2.0 (considered normal system speed).
        *   50% speed on slider = factor 4.0 (half of normal speed).
        *   5% speed on slider = factor 40.0 (1/20th of normal speed).

#### Algorithm Details

*   **Effective Precision Factor Calculation (`PrecisionEngine.calculateEffectivePrecisionFactor`):**
    This crucial method determines the divisor for mouse deltas.
    1.  **Normal Speed Baseline:** `normalSpeedFactor = 2.0`.
    2.  **Slow Speed Priority:** If `isInPrecisionMode` (actual slow speed operational state) AND `slowSpeedEnabled` (feature toggle from UI) are true, the method returns the fixed `precisionFactor` (which was derived from `slowSpeedPercentage` in `AppState`).
    3.  **Drag Acceleration:** If it's a drag event (`isDragging` parameter from `modifyMovementEvent`), AND the engine is tracking this drag (`self.isDragging` internal state), AND `dragAccelerationEnabled` (feature toggle) is true, AND `isDragAccelerationModifiersActive` (configured modifiers for drag accel are currently pressed) is true:
        *   `startFactor = 200.0 / self.slowSpeedPercentage` (drag starts at the speed set by the main UI slider; `PrecisionEngine` stores a copy of `slowSpeedPercentage` passed from `AppState` via `updatePrecisionFactor`).
        *   `progress = min(currentDragDistance / accelerationRadius, 1.0)`. Clamped progress of the drag.
        *   `easedProgress = progress * progress * (3.0 - 2.0 * progress)` (cubic easing function for smooth acceleration).
        *   `effectiveDragFactor = startFactor * (1.0 - easedProgress) + normalSpeedFactor * easedProgress`. This interpolates the factor from `startFactor` (slow) towards `normalSpeedFactor` as the drag progresses.
        *   Returns `effectiveDragFactor`.
    4.  **Default:** If neither of the above conditions are met, the method returns `normalSpeedFactor` (2.0), meaning no speed modification.

*   **Coordinate System Handling (`convertToGlobalTopLeft` private helper function):**
    *   `NSEvent.mouseLocation` provides screen coordinates with the origin at the bottom-left of the *main* screen.
    *   `CGWarpMouseCursorPosition` expects global screen coordinates with the origin at the top-left of the coordinate space (usually corresponding to the top-left of the main screen).
    *   The conversion is: `cgPoint.y = mainScreen.frame.height - nsEventPoint.y`, `cgPoint.x = nsEventPoint.x`.
    *   `PrecisionEngine.lastCursorPosition` is maintained in this global top-left coordinate system.
    *   *Note: Multi-monitor behavior is complex; current implementation assumes main screen context for `NSEvent.mouseLocation`'s frame of reference.*

#### Critical Components & Data Flow

*   **`DragobooApp.swift` (App & State):**
    *   Application entry point (`@main struct DragobooApp`).
    *   `AppState` (class, `ObservableObject`): The central nervous system for state.
        *   Holds user-configurable settings (persisted via `@AppStorage` like `slowSpeedEnabled`, `slowSpeedPercentage`, `modifierKeysData`, `dragAccelerationModifierKeysData`, `accelerationRadius`).
        *   Tracks dynamic state like `isPrecisionModeActive` (fed back from `PrecisionEngine`) and `isAccessibilityGranted`.
        *   Communicates settings changes to the `PrecisionEngine` instance.
*   **`ContentView.swift` (UI):**
    *   SwiftUI views that observe and interact with `AppState`.
    *   Provides UI elements (toggles, sliders, buttons) for users to configure features.
    *   Includes `AccessibilityRequestView` if permissions are needed.
    *   `ModifierKeyButtons` reusable view for selecting modifier keys, showing active state.
*   **`PrecisionEngine.swift` (Core Logic):**
    *   The workhorse. Manages the `CGEventTap`.
    *   Implements `handleEvent` and its sub-handlers (`handleFlagsChanged`, `modifyMovementEvent`, `modifyScrollEvent`, etc.).
    *   Performs all scaling calculations and cursor warping.
    *   Tracks internal states like `isInPrecisionMode`, `isDragging`, `currentDragDistance`, `accumulatedX/Y`.
    *   Has an `onPrecisionModeChange: ((Bool) -> Void)?` callback to inform `AppState` when slow speed mode activates/deactivates.
*   **`ModifierKey` (Enum in `PrecisionEngine.swift`):**
    *   `public enum ModifierKey: String, CaseIterable, Codable`
    *   Defines `fn, control, option, command`.
    *   Provides `cgEventFlag: CGEventFlags` for each key (e.g., `.maskSecondaryFn`).
    *   Provides `displayName: String` (e.g., "fn", "⌃").
    *   `Codable` conformance allows sets of these keys to be stored in `UserDefaults` (via `modifierKeysData` in `AppState`).

**Simplified Data Flow:**
1.  **User Configures UI (`ContentView`):** Changes are published by `AppState`.
2.  **`AppState` Updates `PrecisionEngine`:** e.g., `appState.updateSlowSpeedPercentage()` calls `engine.updatePrecisionFactor()`.
3.  **Hardware Input (Mouse/Keyboard):** Events reach macOS.
4.  **`CGEventTap` (in `PrecisionEngine`):** Intercepts relevant events.
5.  **`PrecisionEngine.handleEvent`:** Logic determines if/how to modify.
    *   Flags changed -> update internal modifier states, potentially toggle `isInPrecisionMode`.
    *   Movement/Scroll -> calculate `effectiveFactor`, scale deltas.
6.  **Output:**
    *   Warp cursor: `CGWarpMouseCursorPosition()`.
    *   Modified scroll: New event returned from tap.
    *   Passthrough: Original event returned.
7.  **Feedback to UI:** `engine.onPrecisionModeChange` updates `AppState.isPrecisionModeActive`, which SwiftUI uses to update `ModifierKeyButtons` visual state.

#### Safety & Reliability
*   **Temporary Modifications:** Cursor behavior changes are only active while Dragoboo's event tap is enabled. Quitting the app or stopping the engine restores normal system behavior immediately.
*   **No Persistent System Setting Changes:** Dragoboo does not alter global system `defaults` for trackpad or mouse sensitivity/acceleration.
*   **Standard Permissions:** Relies on the standard macOS Accessibility framework, requiring explicit user consent.
*   **Error Handling:** `PrecisionEngineError` enum defines errors for critical setup failures (e.g., `failedToCreateEventTap`, `failedToCreateRunLoopSource`). Logging via `os.Logger` is implemented in key areas for diagnostics.

### Coding and Contributing Rules

Dragoboo welcomes contributions. To ensure consistency, quality, and maintainability, please adhere to the following guidelines, synthesized from project documentation (`CLAUDE.md`, existing `README.md`, `TODO.md`):

#### General Principles:
*   **Readability Over Cleverness:** Write clear, self-documenting code where possible. Use descriptive names. Add comments to explain the *why* behind complex logic or non-obvious decisions, and *how* it connects to other parts.
*   **Iterate Gradually:** Prefer smaller, focused commits and Pull Requests. This facilitates easier review and understanding.
*   **Keep Project Documents Updated:** If your changes affect functionality, setup, or technical details, ensure `README.md`, `CHANGELOG.md`, or other relevant documents are updated. Consult `TODO.md` and `PLAN.md` for project context.
*   **Fail Safely & Gracefully:** The application should handle errors or unexpected states (e.g., permissions revoked) without crashing, ideally providing user-friendly feedback.
*   **Test Thoroughly:**
    *   Manually test all affected functionality, including edge cases.
    *   Consider adding unit tests for new or modified core logic in `DragobooCore`.
    *   Test across different macOS versions if feasible.

#### Code Style & Structure:
*   **Swift Best Practices:** Adhere to common Swift idioms and the Swift API Design Guidelines.
*   **Modularity:** Encapsulate reusable logic into well-defined functions/methods. `PrecisionEngine` itself is an example of modular core logic.
*   **State Management:** `AppState` is the source of truth for UI-related state and user preferences, persisted via `@AppStorage`. `PrecisionEngine` manages its own operational state derived from `AppState`'s settings.
*   **`this_file` Record:** As per `CLAUDE.md`, for any source file you modify, ensure a comment like `// this_file: Sources/DragobooCore/PrecisionEngine.swift` is present and correct near the top.
*   **Constants & Enums:** Use constants for fixed values and enums for related distinct values (like `ModifierKey`).
*   **Minimal Changes for Task:** Focus commits on changes directly relevant to the task or bug being addressed. Avoid unrelated refactoring within the same commit unless essential.
*   **Complete and Functional Code:** Ensure your submissions are complete and do not include placeholder comments like `# ... rest of the processing ...` in place of actual logic.

#### Development Process:
1.  **Understand Existing Code:** Before making changes, thoroughly analyze the relevant parts of the codebase, including how data flows and components interact.
2.  **Plan Your Changes:** For non-trivial changes, outline your approach. Break down complex problems.
3.  **Implement & Commit:** Write your code. Commit frequently with clear, concise messages that explain the purpose of the commit.
4.  **Document Your Work:** Update `CHANGELOG.md` for notable changes. Ensure in-code comments are clear. If user-facing aspects change, update `README.md`.
5.  **Consult Project Boards/Tasks:** Refer to `TODO.md` for current development tasks and priorities.

#### Guidelines from `CLAUDE.md` (Adapted for Contributors):
*   **Preserve Existing Structure:** Maintain the existing code architecture and patterns unless a change is a specific requirement of the task.
*   **Leverage Existing Code:** Before writing new utility functions or logic, check if similar functionality already exists within the project.
*   **Holistic Understanding:** Strive to understand how your changes fit into the overall application.
*   **Error Handling:** Implement robust error handling, especially for interactions with system APIs or file operations.
*   **Code Clarity:** Favor clear, straightforward code. Avoid overly complex or nested structures if simpler alternatives exist.

#### Submitting Contributions (Standard GitHub Flow):
*   Fork the repository.
*   Create a new branch for your feature or bug fix.
*   Make your changes, adhering to these guidelines.
*   Push your branch to your fork.
*   Open a Pull Request against the main Dragoboo repository, providing a clear description of the changes and their purpose.

---
**Dragoboo v2.0.0** - Precision when you need it, speed when you don't 🐉🖱️
