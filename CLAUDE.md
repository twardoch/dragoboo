---
this_file: /Users/adam/Developer/vcs/github.twardoch/pub/dragoboo/CLAUDE.md
---

# Dragoboo 🐉🖱️

**Dragoboo is a macOS utility designed to give you an instant precision boost for your trackpad and mouse. By simply holding down the `fn` key, you can temporarily slow down your cursor movement, allowing for finer control in detailed tasks.**

Whether you're a designer pixel-peeping in an image editor, an engineer working with CAD software, or just someone who occasionally needs that extra bit of accuracy, Dragoboo aims to make your pointer interactions smoother and more precise without interrupting your workflow.

### Planning & Roadmap

The development process is guided by:

- [`PLAN.md`](PLAN.md): A comprehensive checklist of development phases and deliverables, covering research, implementation, testing, and release.
- [`TODO.md`](TODO.md): A list of immediate, actionable tasks for the current development sprint.
- [`CLAUDE.md`](CLAUDE.md): Contains initial guidelines and thoughts on implementation, particularly regarding API choices and architectural decisions.

### Testing

- **Unit Tests:** Basic unit tests for `DragobooCore` are located in `Tests/DragobooCoreTests/`. These currently cover `PointerScaler` initialization and factor updates.
- **Manual Testing:** Crucial for verifying the end-to-end UX, `fn` key interaction, and behavior across different applications and input devices.


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

# Use tools 

When you work, ask intelligent questions to the `deepseek/deepseek-r1-0528:free` model via the `chat_completion` tool, analyze the reasoning, and then ask other quetions to the `openai/o3` model via the `chat_completion` tool. 

