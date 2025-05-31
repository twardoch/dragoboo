# Dragoboo Development Plan

## Current Status Summary

Based on the current codebase analysis, Dragoboo has a solid foundation with the core architecture, SwiftUI interface, and basic event tap functionality implemented. The main challenges are related to event modification reliability and system-level integration.

## Immediate Priorities (Current Sprint)

### Critical Issues to Resolve

- [ ] **Fix event modification reliability** - Double field modifications are failing, need to investigate integer field approach with accumulation
- [ ] **Resolve secured input mode conflicts** - App fails when secure input is active
- [ ] **Improve fn key detection consistency** - Current polling vs flags approach has timing issues
- [ ] **Add proper accumulation logic** - Small movements are being lost due to integer truncation

### Phase 1: Core Functionality Fixes ⚠️ URGENT

✅ Basic event tap creation and management  
✅ fn key detection (polling and flags)  
✅ Mouse movement event interception  
✅ Scroll wheel event handling

- [ ] **Fix double field modification failures** - Core scaling not working properly
- [ ] **Implement proper fractional accumulation** - Prevent movement loss on slow movements
- [ ] **Add robust integer field fallback** - When double fields fail
- [ ] **Optimize event processing performance** - Currently processing every movement event
- [ ] **Handle secure input mode gracefully** - Detect and warn users when it's active

### Phase 2: System Integration & Stability

✅ Basic accessibility permission checking  
✅ AXIsProcessTrusted integration  
✅ MenuBarExtra UI implementation

- [ ] **Add system sleep/wake event handling** - Event tap may need restarting
- [ ] **Implement proper cleanup on app termination** - Ensure event tap is disabled
- [ ] **Add display configuration change support** - Multiple monitor setups
- [ ] **Create LaunchAgent for startup** - Allow app to start automatically
- [ ] **Handle event tap timeout/disable gracefully** - Auto-recovery mechanisms

### Phase 3: User Experience Improvements

✅ Basic SwiftUI preferences interface  
✅ Precision factor slider (1x-10x)  
✅ Visual status indicators  
✅ Accessibility permission UI flow

- [ ] **Add visual feedback for precision mode** - More obvious when active
- [ ] **Implement better onboarding flow** - Guide users through setup
- [ ] **Create status bar icon variants** - Different icons for different states
- [ ] **Add keyboard shortcuts** - Quick access to common functions
- [ ] **Implement settings persistence validation** - Ensure settings survive app updates

## Phase 4: Advanced Features & Polish

### Event Processing Enhancements

- [ ] **Add support for custom modifier keys** - Beyond just fn key
- [ ] **Implement modifier key combinations** - fn+shift, fn+cmd, etc.
- [ ] **Create per-application settings** - Different factors for different apps
- [ ] **Add sensitivity curves** - Non-linear scaling options
- [ ] **Implement gesture detection** - Smart scaling based on movement patterns

### Performance & Diagnostics

- [ ] **Add performance profiling** - Monitor callback execution time
- [ ] **Implement battery usage optimization** - Reduce background CPU usage
- [ ] **Create diagnostic mode** - Detailed logging for troubleshooting
- [ ] **Add memory usage monitoring** - Prevent memory leaks
- [ ] **Implement event rate limiting** - Prevent overwhelming the system

### Testing & Quality Assurance

✅ Basic unit tests for PointerScaler

- [ ] **Expand test coverage** - Integration tests for event processing
- [ ] **Add performance benchmarks** - Ensure consistent performance
- [ ] **Test with multiple input devices** - External mice, trackpads, etc.
- [ ] **Verify behavior across macOS versions** - Compatibility testing
- [ ] **Test with external keyboards** - fn key compatibility issues

## Phase 5: Distribution & Deployment

### Code Signing & Security

- [ ] **Configure Developer ID certificate** - Required for distribution
- [ ] **Set up hardened runtime** - Security requirements
- [ ] **Implement notarization workflow** - Apple's security validation
- [ ] **Add privacy manifest** - Required for App Store submission
- [ ] **Configure sandboxing** - If targeting App Store

### Packaging & Installation

✅ Basic .app bundle creation via run.sh  
✅ Makefile for build automation

- [ ] **Create DMG installer** - Professional distribution package
- [ ] **Set up Homebrew cask** - Package manager integration
- [ ] **Implement auto-update mechanism** - Sparkle or custom solution
- [ ] **Create uninstaller script** - Clean removal of components
- [ ] **Add installation verification** - Ensure proper setup

### Documentation & Support

✅ Comprehensive README with usage instructions  
✅ Technical documentation in README

- [ ] **Create user guide with screenshots** - Step-by-step setup guide
- [ ] **Write troubleshooting guide** - Common issues and solutions
- [ ] **Document API for DragobooCore** - Enable third-party integration
- [ ] **Create contribution guidelines** - Open source development
- [ ] **Set up issue templates** - Structured bug reporting

## Phase 6: Advanced System Integration

### Display & Input Device Support

- [ ] **Handle multiple displays with different DPIs** - Scale appropriately per display
- [ ] **Support gaming mice with high DPI** - Handle extreme sensitivity settings
- [ ] **Verify Magic Trackpad compatibility** - Apple's external trackpad
- [ ] **Handle Bluetooth device disconnection** - Graceful handling of wireless devices
- [ ] **Test with Touch Bar MacBooks** - Ensure fn key works properly

### System Events & Power Management

- [ ] **Implement system sleep/wake handling** - Restart event tap after wake
- [ ] **Add display configuration change support** - Handle monitor connect/disconnect
- [ ] **Handle user switching** - Multiple user accounts
- [ ] **Implement idle detection** - Reduce resource usage when inactive
- [ ] **Add thermal throttling awareness** - Reduce CPU usage when system is hot

## Phase 7: Future Enhancements

### Advanced Features

- [ ] **Add gesture-based scaling** - Different factors for different movement types
- [ ] **Implement predictive scaling** - AI-based movement prediction
- [ ] **Create preset management** - Save/load different configurations
- [ ] **Add integration with other tools** - BTT, Karabiner, etc.
- [ ] **Implement remote configuration** - Sync settings across devices

### Analytics & Monitoring

- [ ] **Add privacy-respecting usage analytics** - Understand how users interact
- [ ] **Implement crash reporting** - Automatic error reporting
- [ ] **Create usage statistics** - Help improve the user experience
- [ ] **Set up performance monitoring** - Track performance over time
- [ ] **Add A/B testing framework** - Test new features safely

## Known Issues & Technical Debt

### Current Problems

1. **Double field modification failure** - Event modification not working reliably
2. **Secure input mode conflicts** - App doesn't work with secure input active
3. **Fractional movement loss** - Small movements are truncated to zero
4. **Event processing overhead** - Processing every mouse movement event
5. **fn key detection inconsistencies** - Timing issues between polling and flags

### Technical Debt

1. **Excessive debug logging** - Too much output in production builds
2. **Hard-coded scaling factors** - Should be configurable
3. **Missing error recovery** - Event tap failures not handled gracefully
4. **Lack of configuration validation** - Invalid settings not prevented
5. **Memory usage not monitored** - Potential for memory leaks

## Development Guidelines

### Code Quality Standards

- Follow Swift API design guidelines and naming conventions
- Use proper error handling with Result types where appropriate
- Implement comprehensive logging with appropriate levels
- Write unit tests for all core functionality
- Use property wrappers (@AppStorage, @Published) appropriately

### Performance Requirements

- Event tap callback execution must be under 1ms
- Memory usage should remain stable over long periods
- CPU usage should be minimal when precision mode is inactive
- Battery impact should be negligible

### Security & Privacy

- Request minimal necessary permissions
- Handle accessibility permissions gracefully
- Implement proper cleanup on termination
- Respect user privacy - no data collection without consent
- Follow Apple's security best practices
