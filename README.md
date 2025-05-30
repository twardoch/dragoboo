# Dragoboo 🐉🖱️

**Dragoboo is a macOS utility designed to give you an instant precision boost for your trackpad and mouse. By simply holding down the `fn` key, you can temporarily slow down your cursor movement, allowing for finer control in detailed tasks.**

Whether you're a designer pixel-peeping in an image editor, an engineer working with CAD software, or just someone who occasionally needs that extra bit of accuracy, Dragoboo aims to make your pointer interactions smoother and more precise without interrupting your workflow.

[![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)](https://www.apple.com/macos) [![Swift](https://img.shields.io/badge/Swift-5.10-orange.svg)](https://swift.org) [![SwiftUI](https://img.shields.io/badge/SwiftUI-Framework-purple.svg)](https://developer.apple.com/xcode/swiftui/) [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE) ## Table of Contents

- [Features](#features)
- [Why Dragoboo?](#why-dragoboo)
- [User Experience (UX)](#user-experience-ux)
  - [Installation](#installation)
  - [First Launch & Permissions](#first-launch--permissions)
  - [Usage](#usage)
  - [Settings](#settings)
- [Technical Deep Dive](#technical-deep-dive)
  - [Core Architecture](#core-architecture)
  - [Event Handling](#event-handling)
  - [State Management](#state-management)
  - [Key Components](#key-components)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Building from Source](#building-from-source)
    - [Using the Command Line (Recommended)](#using-the-command-line-recommended)
    - [Using Xcode](#using-xcode)
  - [Running the App](#running-the-app)
  - [Stopping the App](#stopping-the-app)
- [Configuration](#configuration)
- [Privacy & Security](#privacy--security)
- [Development Insights](#development-insights)
  - [Project Structure](#project-structure)
  - [Planning & Roadmap](#planning--roadmap)
  - [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgements](#acknowledgements)

## Features

- **Instant Precision Mode:** Hold the `fn` key to temporarily reduce cursor sensitivity.
- **Customizable Slowdown Factor:** Adjust how much the cursor slows down (from 1x to 10x) via a simple slider in the menu bar popover. Default is 4x.
- **Menu Bar App:** Lives discreetly in your macOS menu bar, providing quick access to settings without cluttering your Dock.
- **Universal Support:** Works with both built-in trackpads and external mice.
- **Comprehensive Action Coverage:** Precision mode applies to standard cursor movements, dragging actions (left, right, other), and even scroll wheel events.
- **SwiftUI Interface:** Modern and clean user interface for settings.
- **Lightweight:** Designed to be efficient and have minimal impact on system performance.
- **Accessibility Focused:** Requires and guides users through granting necessary Accessibility permissions.

## Why Dragoboo?

Many creative and technical tasks on a Mac require precise cursor placement. While macOS offers global tracking speed adjustments, these are cumbersome to change frequently. Dragoboo provides an "on-demand" precision mode, activated by a key you already have: the `fn` key. This allows for quick switching between fast navigation and meticulous control without needing to dive into System Settings or use complex third-party tools.

The core idea was born out of a need for finer trackpad control during detailed graphical work, as detailed in the initial [research document (`_private/research.md`)](_private/research.md).

## User Experience (UX)

### Installation

Dragoboo is typically run from the build output. Once built (see [Building from Source](#building-from-source)), the `Dragoboo.app` bundle can be placed in your `/Applications` folder or run from any location.

### First Launch & Permissions

Upon first launch, Dragoboo will check if it has the necessary **Accessibility permissions**. These permissions are crucial for the app to monitor and modify mouse/trackpad events system-wide.

1.  If permissions are not granted, the app's menu bar popover will display a message prompting you to grant them.
2.  Clicking the "Grant Permission" button will attempt to open **System Settings > Privacy & Security > Accessibility**.
3.  You will need to find "Dragoboo" in the list and enable it. You might need to unlock System Settings with your administrator password.

Without these permissions, Dragoboo cannot function.

### Usage

Once installed and permissions are granted:

1.  **Launch Dragoboo:** The app icon (a cursor arrow) will appear in your macOS menu bar.
2.  **Activate Precision Mode:** Simply **press and hold the `fn` key** on your keyboard. While the `fn` key is held, your cursor (and scrolling) will move significantly slower, based on the configured slowdown factor.
3.  **Release `fn` Key:** Release the `fn` key to return to normal cursor speed.

The menu bar icon will change to indicate when precision mode is active (e.g., from `cursorarrow` to `cursorarrow.click.2`).

### Settings

Click the Dragoboo icon in the menu bar to open a small popover window:

- **Accessibility Status:** Shows if permissions are granted.
- **Slowdown Factor Slider:** Adjust the precision multiplier from 1x (no slowdown) to 10x. The default is 4x. Changes are applied live.
- **Precision Mode Indicator:** A label confirms "Precision mode active" when the `fn` key is held.
- **Status Indicator:** A small circle (gray for ready, green for active) and text provide a quick visual cue.
- **Quit Button:** To close the application.

## Technical Deep Dive

### Core Architecture

Dragoboo follows a modular design:

- **`DragobooApp` (SwiftUI Application):**

  - Manages the main application lifecycle.
  - Provides the `MenuBarExtra` user interface using SwiftUI.
  - Hosts the `AppState` observable object to bridge UI and core logic.
  - Located in `Dragoboo/Dragoboo/DragobooApp.swift`.

- **`DragobooCore` (Swift Package):**
  - Contains the core logic for event handling and pointer scaling.
  - This separation allows the core functionality to be potentially reused or tested independently.
  - The primary class here is `PointerScaler`.
  - Located in `Sources/DragobooCore/`.

### Event Handling

The heart of Dragoboo is its ability to intercept and modify system-wide input events. This is achieved using macOS's **Quartz Event Services**, specifically `CGEvent.tapCreate`:

1.  **Event Tap Creation:** An event tap is established at the `.cgSessionEventTap` point, placed at `.headInsertEventTap` to process events before other applications.
2.  **Events of Interest:** The tap listens for:
    - `mouseMoved`
    - `leftMouseDragged`, `rightMouseDragged`, `otherMouseDragged`
    - `scrollWheel`
    - `flagsChanged` (to detect `fn` key state changes)
3.  **Callback Mechanism:** A C-style callback function (`eventTapCallback` in the initial research, now encapsulated within `PointerScaler`) is invoked for each relevant event.
4.  **`fn` Key Detection:**
    - The primary method is checking the `flags` of an incoming event for `.maskSecondaryFn`. This is handled within the `flagsChanged` event type.
    - As a fallback and for continuous state checking during mouse/scroll events, `CGEventSource.keyState(.combinedSessionState, key: 0x3F)` is used to poll the `fn` key's state (key code `0x3F` is for `fn`).
5.  **Delta Scaling:**
    - When the `fn` key is detected as pressed, the `PointerScaler` retrieves the delta values from mouse movement or scroll wheel events (e.g., `.mouseEventDeltaX`, `.mouseEventDeltaY`, `.scrollWheelEventDeltaAxis1`).
    - These delta values are then divided by the `precisionFactor`.
    - The modified delta values are written back into the event using `setDoubleValueField`.
    - The modified event is then passed on to the system.
6.  **Run Loop Integration:** The event tap is added to the current run loop to ensure it processes events continuously.
7.  **Error Handling:** The system includes logging for event tap creation failures and attempts to re-enable the tap if it's disabled by timeout or user input.

### State Management

- **`AppState` (ObservableObject):** This class in `DragobooApp.swift` serves as the central point for managing the application's state and acts as a ViewModel.
  - `@Published var isPrecisionModeActive`: Tracks if the `fn` key is currently pressed.
  - `@Published var isAccessibilityGranted`: Reflects the status of Accessibility permissions.
  - `@AppStorage("precisionFactor") var precisionFactor: Double`: Persists the user-selected slowdown factor using `UserDefaults`.
  - It initializes and manages the `PointerScaler` instance from `DragobooCore`.
  - Communicates changes from `PointerScaler` (like `fn` key state) to the SwiftUI UI via its `onPrecisionModeChange` callback.

### Key Components

- **`DragobooApp.swift`:**
  - `DragobooApp`: The main `@main` struct defining the app and its `MenuBarExtra` scene.
  - `AppState`: Manages overall application state, permissions, and interaction with `PointerScaler`.
- **`ContentView.swift`:**
  - `ContentView`: The main SwiftUI view for the menu bar popover.
  - `AccessibilityRequestView`: Shown if permissions are not granted.
  - `PrecisionSettingsView`: Allows adjustment of the slowdown factor.
  - `StatusIndicator`: Visual feedback for precision mode.
- **`PointerScaler.swift` (in `DragobooCore`):**
  - The core engine responsible for creating and managing the `CGEventTap`.
  - Handles event callbacks, `fn` key detection logic, and scaling of mouse/scroll deltas.
  - Provides an `onPrecisionModeChange` callback to notify `AppState` of `fn` key status.
  - Manages its own lifecycle with `start()` and `stop()` methods.
- **`Info.plist`:**
  - Configures the app as a "UI Element" (`LSUIElement = true`), so it runs as a menu bar agent without a Dock icon.
  - Specifies the minimum macOS deployment target.

## Getting Started

### Prerequisites

- **macOS:** Version 13.0 or later.
- **Xcode:** Version 15.0 or later (for building from source).
- **Xcode Command Line Tools:** Required for `xcodebuild`. Install via `xcode-select --install`.
- **(Optional) `xcpretty`:** For nicer build output in the terminal. Install via `gem install xcpretty`. The `run.sh` script will fall back if it's not found.

### Building from Source

You can build Dragoboo using the provided shell script or directly within Xcode.

#### Using the Command Line (Recommended)

The repository includes a `run.sh` script to simplify the build and run process.

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd dragoboo
    ```
2.  **Make scripts executable (if needed):**
    ```bash
    chmod +x run.sh stop.sh
    ```
3.  **Build and Run:**

    ```bash
    ./run.sh
    ```

    This will:

    - Clean the build directory (optional, can be forced with `--clean`).
    - Build the app in Debug configuration.
    - Launch the app.

4.  **Other `run.sh` options:**

    - `./run.sh --help`: Show all available script options.
    - `./run.sh --release`: Build in Release configuration.
    - `./run.sh --clean`: Force a clean build before building.
    - `./run.sh --no-launch`: Build the app but do not launch it.

    A `Makefile` is also provided for common tasks:

    ```bash
    make          # Build and run (default)
    make build    # Build without running
    make clean    # Clean build directory
    make release  # Build release version
    make rebuild  # Clean and then build
    make help     # Show Makefile help
    ```

#### Using Xcode

1.  Open `Dragoboo.xcodeproj` in Xcode.
2.  Select the "Dragoboo" scheme and a macOS run destination (My Mac).
3.  Click the "Build and Run" button (or press `⌘R`).

### Running the App

After building, the `Dragoboo.app` bundle will be located in the `build/Build/Products/<Configuration>/` directory (e.g., `build/Build/Products/Debug/Dragoboo.app`).

You can launch it by:

- Using `./run.sh` (which handles launching).
- Double-clicking `Dragoboo.app` in Finder.
- Running `open build/Build/Products/Debug/Dragoboo.app` from the terminal (adjust path if built in Release).

### Stopping the App

- Click the Dragoboo icon in the menu bar and select "Quit".
- Run `./stop.sh` from the terminal.
- If run from Xcode, stopping the process in Xcode will terminate the app.

## Configuration

The primary configuration option is the **Slowdown Factor**, adjustable from 1x to 10x using the slider in the menu bar popover. This setting is persisted across app launches using `@AppStorage` (which relies on `UserDefaults`).

## Privacy & Security

- **Accessibility Permissions:** Dragoboo **requires** Accessibility permissions in **System Settings > Privacy & Security > Accessibility**. This is essential for the app to monitor and modify mouse and keyboard events system-wide. The app will guide you to grant these permissions.
- **No Data Collection:** Dragoboo does not collect, store, or transmit any personal data.
- **No Network Connectivity:** The app does not connect to the internet.
- **Local Operation:** All event processing and modification happen locally on your Mac.
- **Targeted Modification:** Event modification only occurs when the `fn` key is actively held down.

## Development Insights

### Project Structure

Dragoboo/├── Dragoboo.xcodeproj # Xcode project file├── Dragoboo/ # Main application target group│ ├── DragobooApp.swift # App entry point, MenuBarExtra, AppState│ ├── ContentView.swift # SwiftUI views for the popover│ ├── Assets.xcassets # App icons and other assets│ └── Info.plist # Application configuration├── Sources/│ └── DragobooCore/ # Swift Package for core logic│ └── PointerScaler.swift # Event tap and scaling logic├── Tests/│ └── DragobooCoreTests/ # Unit tests for DragobooCore│ └── PointerScalerTests.swift├── \_private/│ └── research.md # Initial research and planning├── Package.swift # Swift Package Manager manifest├── README.md # This file├── PLAN.md # Detailed development plan├── TODO.md # Short-term tasks├── Makefile # Makefile for build automation├── run.sh # Build and run script└── stop.sh # Script to stop the app

### Planning & Roadmap

The development process is guided by:

- [`PLAN.md`](PLAN.md): A comprehensive checklist of development phases and deliverables, covering research, implementation, testing, and release.
- [`TODO.md`](TODO.md): A list of immediate, actionable tasks for the current development sprint.
- [`CLAUDE.md`](CLAUDE.md): Contains initial guidelines and thoughts on implementation, particularly regarding API choices and architectural decisions.

### Testing

- **Unit Tests:** Basic unit tests for `DragobooCore` are located in `Tests/DragobooCoreTests/`. These currently cover `PointerScaler` initialization and factor updates.
- **Manual Testing:** Crucial for verifying the end-to-end UX, `fn` key interaction, and behavior across different applications and input devices.

## Troubleshooting

- **App Not Working / No Slowdown:**
  1.  **Check Accessibility Permissions:** Ensure Dragoboo is enabled in **System Settings > Privacy & Security > Accessibility**. This is the most common reason for the app not functioning. Try toggling the permission off and on.
  2.  **Restart Dragoboo:** Quit the app from its menu bar icon and relaunch it.
  3.  **Check `fn` Key Configuration:** On some MacBooks, the `fn` key might be configured to perform its special feature (e.g., Show Emoji & Symbols, Start Dictation) instead of acting as a standard modifier. Check **System Settings > Keyboard > Keyboard > Press fn key to...**. For Dragoboo to work best, this should ideally be set to "Do Nothing" or a setting that doesn't conflict. Dragoboo attempts to detect the `fn` key regardless, but system-level interception might interfere.
- **`xcpretty` Not Found (during `./run.sh`):**
  - The `run.sh` script will fall back to standard `xcodebuild` output. If you want prettier output, install `xcpretty`: `sudo gem install xcpretty`.
- **CoreSimulator Version Mismatch (Build Error):**
  - This error (`CoreSimulator is out of date...`) might appear if your Xcode or macOS is not fully up-to-date, or if there's a mismatch between Xcode's components.
  - Ensure macOS and Xcode are updated to their latest compatible versions.
  - Sometimes, restarting your Mac or reinstalling Xcode Command Line Tools (`sudo rm -rf /Library/Developer/CommandLineTools; xcode-select --install`) can help. This error primarily affects simulator builds, which Dragoboo doesn't rely on for its core functionality.
- **`fn` Key on External Keyboards:**
  - The reliability of `fn` key detection can vary with third-party external keyboards. Dragoboo is primarily tested with built-in MacBook keyboards and Apple Magic Keyboards. If you experience issues, this might be a limitation.

## Contributing

Contributions are welcome! If you'd like to contribute, please:

1.  Fork the repository.
2.  Create a new branch for your feature or bug fix.
3.  Refer to `PLAN.md` and `TODO.md` for areas of development.
4.  Follow the existing code style and architectural patterns.
5.  Write tests for new functionality if applicable.
6.  Submit a pull request with a clear description of your changes.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details. _(Note: A `LICENSE` file was not explicitly provided in the source; assuming MIT as a common open-source license. Please create/update this file if a different license applies.)_

## Acknowledgements

- The initial research and problem statement that inspired Dragoboo.
- The macOS developer community for resources on `CGEventTap` and SwiftUI.

## Reminders for contributors

- **Readability > cleverness.** Clear names & comments.
- **Fail safely.** If the tap can’t activate, surface a user-friendly banner and exit.
- **Keep PLAN.md & TODO.md living documents.** Update as you learn.
- **Commit often, push daily.** Small PRs enable fast review.

## Development Guidelines

- Only modify code directly relevant to the specific request. Avoid changing unrelated functionality.
- Never replace code with placeholders like `# ... rest of the processing ...`. Always include complete code.
- Break problems into smaller steps. Think through each step separately before implementing.
- Always provide a complete PLAN with REASONING based on evidence from code and logs before making changes.
- Explain your OBSERVATIONS clearly, then provide REASONING to identify the exact issue. Add console logs when needed to gather more information.

Dragoboo is a macOS utility that provides precision cursor control through temporary slowdown functionality.

## Core Business Logic

### Precision Control System

- Activates temporary cursor slowdown when fn key is held
- Scales both cursor movement and scroll wheel input
- Configurable slowdown factor (1x-10x)
- Persists user preferences across sessions
- Works universally with trackpads and mice

### Event Processing Pipeline

The event interception and modification system:

1. Creates system-wide event tap for mouse/trackpad inputs
2. Monitors fn key state continuously
3. Applies precision scaling to movement deltas when active
4. Handles multiple event types including movement, dragging, and scrolling

### Permission Management

- Requires macOS Accessibility permissions
- Guides users through permission granting process
- Validates permission status on launch
- Prevents operation without proper access

### State Management System

Centralizes control through AppState which:

- Tracks precision mode status
- Manages accessibility permissions
- Controls slowdown factor settings
- Coordinates UI feedback

## Critical Components

### Core Files

- `DragobooApp.swift`: Application entry point and state coordination
- `PointerScaler.swift`: Event interception and scaling engine
- `ContentView.swift`: UI feedback and settings interface

### Key Integrations

- Event tap system for system-wide input capture
- Accessibility permissions framework
- User defaults for persistence
- Menu bar integration for status and control

### Data Flow

1. System input events → Event tap
2. Event tap → Pointer scaler
3. Pointer scaler → Modified events
4. State changes → UI updates
