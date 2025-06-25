import SwiftUI
import DragobooCore

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    // @Environment(\.dismiss) private var dismiss // Removed as unused
    
    var body: some View {
        VStack(spacing: 16) {
            if !appState.isAccessibilityGranted {
                AccessibilityRequestView()
            } else {
                VStack(spacing: 12) {
                    SlowSpeedToggleView()
                    DragAccelerationToggleView()
                    BottomSection()
                }
            }
        }
        .onAppear { 
            appState.refreshPermissions() 
        }
        .padding(16)
        .frame(width: 300)
    }
}

struct AccessibilityRequestView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Accessibility Permission Required")
                .font(.headline)
            
            Text("Dragoboo needs accessibility permissions to modify cursor movement.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Grant Permission") {
                appState.requestAccessibility()
            }
            .controlSize(.large)
        }
    }
}

struct SlowSpeedToggleView: View {
    @EnvironmentObject var appState: AppState
    @State private var slowSpeedPercentage: Double = 100.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("Slow speed", isOn: Binding(
                    get: { appState.slowSpeedEnabled },
                    set: { _ in appState.toggleSlowSpeed() }
                ))
                .toggleStyle(.checkbox)
                .help("Enable to slow down cursor movement when holding modifier keys")
                
                Spacer()
                
                if appState.slowSpeedEnabled {
                    ModifierKeyButtons(
                        modifierKeys: appState.modifierKeys,
                        toggleAction: appState.toggleModifierKey,
                        isFeatureActive: appState.isPrecisionModeActive
                    )
                }
            }
            
            // Always show slider since it affects drag acceleration too
            VStack(spacing: 4) {
                Slider(value: $slowSpeedPercentage, in: 1...100, step: 5) { _ in
                    appState.updateSlowSpeedPercentage(slowSpeedPercentage)
                }
                .help("100% = normal speed, lower = slower cursor movement")
                
                Text("\(Int(slowSpeedPercentage))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .onAppear {
                slowSpeedPercentage = appState.slowSpeedPercentage
            }
        }
    }
}

struct ModifierKeyButtons: View {
    @EnvironmentObject var appState: AppState
    let modifierKeys: Set<ModifierKey>
    let toggleAction: (ModifierKey) -> Void
    let isFeatureActive: Bool
    
    init(modifierKeys: Set<ModifierKey>, toggleAction: @escaping (ModifierKey) -> Void, isFeatureActive: Bool = false) {
        self.modifierKeys = modifierKeys
        self.toggleAction = toggleAction
        self.isFeatureActive = isFeatureActive
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(ModifierKey.allCases, id: \.self) { key in
                Text(key.displayName)
                    .font(.system(.body, design: .default))
                    .foregroundColor(textColor(for: key))
                    .onTapGesture {
                        toggleAction(key)
                    }
                    .help("Click to toggle \(helpText(for: key))")
            }
        }
    }
    
    private func textColor(for key: ModifierKey) -> Color {
        let isSelected = modifierKeys.contains(key)
        let isActive = isFeatureActive && isSelected
        
        if isActive {
            return .green
        } else if isSelected {
            return .primary
        } else {
            return .secondary.opacity(0.5)
        }
    }
    
    private func helpText(for key: ModifierKey) -> String {
        switch key {
        case .fn: return "Function key"
        case .control: return "Control key"
        case .option: return "Option/Alt key"
        case .command: return "Command key"
        }
    }
}

struct DragAccelerationToggleView: View {
    @EnvironmentObject var appState: AppState
    @State private var accelerationRadius: Double = 200.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("Drag acceleration", isOn: Binding(
                    get: { appState.dragAccelerationEnabled },
                    set: { _ in appState.toggleDragAcceleration() }
                ))
                .toggleStyle(.checkbox)
                .help("Enable to start slow and accelerate while dragging")
                
                Spacer()
                
                if appState.dragAccelerationEnabled {
                    ModifierKeyButtons(
                        modifierKeys: appState.dragAccelerationModifierKeys,
                        toggleAction: appState.toggleDragAccelerationModifierKey,
                        isFeatureActive: false  // TODO: Add drag acceleration active state if needed
                    )
                }
            }
            
            if appState.dragAccelerationEnabled {
                VStack(spacing: 4) {
                    Slider(value: $accelerationRadius, in: 50...1000, step: 50) { _ in
                        appState.updateAccelerationRadius(accelerationRadius)
                    }
                    .help("Distance over which cursor accelerates from slow to normal speed")
                    
                    Text("\(Int(accelerationRadius))px")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .onAppear {
                    accelerationRadius = appState.accelerationRadius
                }
            }
        }
    }
}

struct BottomSection: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack {
            Button(action: {
                if let url = URL(string: "https://drago.boo") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Text("Dragoboo v2.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Visit Dragoboo website")
            
            Spacer()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
            .help("Quit Dragoboo (⌘Q)")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}