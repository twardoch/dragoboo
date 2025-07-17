// this_file: /root/repo/Tests/DragobooAppTests/AppStateTests.swift

import XCTest
import SwiftUI
@testable import DragobooApp
@testable import DragobooCore

final class AppStateTests: XCTestCase {
    
    var appState: AppState!
    
    override func setUp() {
        super.setUp()
        appState = AppState()
    }
    
    override func tearDown() {
        appState = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(appState, "AppState should be initialized")
        XCTAssertFalse(appState.isPrecisionModeActive, "Precision mode should be inactive initially")
    }
    
    func testDefaultSettings() {
        XCTAssertTrue(appState.slowSpeedEnabled, "Slow speed should be enabled by default")
        XCTAssertTrue(appState.dragAccelerationEnabled, "Drag acceleration should be enabled by default")
        XCTAssertEqual(appState.slowSpeedPercentage, 100.0, "Slow speed percentage should be 100% by default")
        XCTAssertEqual(appState.accelerationRadius, 200.0, "Acceleration radius should be 200.0 by default")
    }
    
    func testDefaultModifierKeys() {
        let defaultKeys = appState.modifierKeys
        XCTAssertEqual(defaultKeys, [.fn], "Default modifier keys should be [.fn]")
        
        let defaultDragKeys = appState.dragAccelerationModifierKeys
        XCTAssertEqual(defaultDragKeys, [], "Default drag acceleration modifier keys should be empty")
    }
    
    // MARK: - Precision Factor Tests
    
    func testPrecisionFactorCalculation() {
        appState.slowSpeedPercentage = 100.0
        XCTAssertEqual(appState.precisionFactor, 2.0, accuracy: 0.01, "100% should give factor 2.0")
        
        appState.slowSpeedPercentage = 50.0
        XCTAssertEqual(appState.precisionFactor, 4.0, accuracy: 0.01, "50% should give factor 4.0")
        
        appState.slowSpeedPercentage = 25.0
        XCTAssertEqual(appState.precisionFactor, 8.0, accuracy: 0.01, "25% should give factor 8.0")
        
        appState.slowSpeedPercentage = 200.0
        XCTAssertEqual(appState.precisionFactor, 1.0, accuracy: 0.01, "200% should give factor 1.0")
    }
    
    func testPrecisionFactorZeroPercentage() {
        appState.slowSpeedPercentage = 0.0
        XCTAssertEqual(appState.precisionFactor, 2.0, accuracy: 0.01, "Zero percentage should fallback to 2.0")
    }
    
    func testPrecisionFactorNegativePercentage() {
        appState.slowSpeedPercentage = -50.0
        XCTAssertEqual(appState.precisionFactor, 2.0, accuracy: 0.01, "Negative percentage should fallback to 2.0")
    }
    
    // MARK: - Modifier Key Management Tests
    
    func testModifierKeyToggle() {
        // Start with default [.fn]
        XCTAssertTrue(appState.modifierKeys.contains(.fn))
        
        // Toggle fn off
        appState.toggleModifierKey(.fn)
        XCTAssertFalse(appState.modifierKeys.contains(.fn))
        
        // Toggle fn back on
        appState.toggleModifierKey(.fn)
        XCTAssertTrue(appState.modifierKeys.contains(.fn))
        
        // Add another key
        appState.toggleModifierKey(.control)
        XCTAssertTrue(appState.modifierKeys.contains(.control))
        XCTAssertTrue(appState.modifierKeys.contains(.fn))
        
        // Remove control
        appState.toggleModifierKey(.control)
        XCTAssertFalse(appState.modifierKeys.contains(.control))
        XCTAssertTrue(appState.modifierKeys.contains(.fn))
    }
    
    func testDragAccelerationModifierKeyToggle() {
        // Start with empty set
        XCTAssertTrue(appState.dragAccelerationModifierKeys.isEmpty)
        
        // Add a key
        appState.toggleDragAccelerationModifierKey(.command)
        XCTAssertTrue(appState.dragAccelerationModifierKeys.contains(.command))
        
        // Remove the key
        appState.toggleDragAccelerationModifierKey(.command)
        XCTAssertFalse(appState.dragAccelerationModifierKeys.contains(.command))
        
        // Add multiple keys
        appState.toggleDragAccelerationModifierKey(.option)
        appState.toggleDragAccelerationModifierKey(.control)
        XCTAssertTrue(appState.dragAccelerationModifierKeys.contains(.option))
        XCTAssertTrue(appState.dragAccelerationModifierKeys.contains(.control))
        XCTAssertEqual(appState.dragAccelerationModifierKeys.count, 2)
    }
    
    func testModifierKeyPersistence() {
        // Set some keys
        appState.toggleModifierKey(.control)
        appState.toggleModifierKey(.option)
        
        let keys = appState.modifierKeys
        XCTAssertTrue(keys.contains(.control))
        XCTAssertTrue(keys.contains(.option))
        XCTAssertTrue(keys.contains(.fn))
        
        // Create new AppState to test persistence
        // Note: In a real test, you'd need to mock UserDefaults or use a test bundle
        // For now, just test that the getter/setter works
        let testKeys: Set<ModifierKey> = [.command, .option]
        appState.modifierKeys = testKeys
        XCTAssertEqual(appState.modifierKeys, testKeys)
    }
    
    // MARK: - Feature Toggle Tests
    
    func testSlowSpeedToggle() {
        let initialState = appState.slowSpeedEnabled
        
        appState.toggleSlowSpeed()
        XCTAssertEqual(appState.slowSpeedEnabled, !initialState)
        
        appState.toggleSlowSpeed()
        XCTAssertEqual(appState.slowSpeedEnabled, initialState)
    }
    
    func testDragAccelerationToggle() {
        let initialState = appState.dragAccelerationEnabled
        
        appState.toggleDragAcceleration()
        XCTAssertEqual(appState.dragAccelerationEnabled, !initialState)
        
        appState.toggleDragAcceleration()
        XCTAssertEqual(appState.dragAccelerationEnabled, initialState)
    }
    
    // MARK: - Settings Update Tests
    
    func testUpdateSlowSpeedPercentage() {
        appState.updateSlowSpeedPercentage(75.0)
        XCTAssertEqual(appState.slowSpeedPercentage, 75.0)
        
        appState.updateSlowSpeedPercentage(25.0)
        XCTAssertEqual(appState.slowSpeedPercentage, 25.0)
    }
    
    func testUpdateAccelerationRadius() {
        appState.updateAccelerationRadius(150.0)
        XCTAssertEqual(appState.accelerationRadius, 150.0)
        
        appState.updateAccelerationRadius(300.0)
        XCTAssertEqual(appState.accelerationRadius, 300.0)
    }
    
    // MARK: - Accessibility Permission Tests
    
    func testAccessibilityPermissionInitialState() {
        // Note: This test depends on the system state of accessibility permissions
        // In a real test environment, you'd mock AXIsProcessTrusted()
        XCTAssertNotNil(appState.isAccessibilityGranted)
    }
    
    func testRequestAccessibility() {
        // This test would normally prompt the user
        // In a unit test, we can only test that the method doesn't crash
        XCTAssertNoThrow(appState.requestAccessibility())
    }
    
    func testRefreshPermissions() {
        // Test that refresh doesn't crash
        XCTAssertNoThrow(appState.refreshPermissions())
    }
    
    // MARK: - State Consistency Tests
    
    func testStateConsistency() {
        // Test that related state changes work together
        appState.updateSlowSpeedPercentage(50.0)
        XCTAssertEqual(appState.slowSpeedPercentage, 50.0)
        XCTAssertEqual(appState.precisionFactor, 4.0, accuracy: 0.01)
        
        appState.toggleSlowSpeed()
        // Even when disabled, the percentage should remain
        XCTAssertEqual(appState.slowSpeedPercentage, 50.0)
        XCTAssertFalse(appState.slowSpeedEnabled)
        
        appState.toggleSlowSpeed()
        XCTAssertTrue(appState.slowSpeedEnabled)
        XCTAssertEqual(appState.slowSpeedPercentage, 50.0)
    }
    
    // MARK: - JSON Encoding/Decoding Tests
    
    func testModifierKeyJSONEncoding() {
        let keys: Set<ModifierKey> = [.fn, .control, .option]
        appState.modifierKeys = keys
        
        // The setter should encode and the getter should decode
        let retrievedKeys = appState.modifierKeys
        XCTAssertEqual(retrievedKeys, keys, "Keys should survive JSON encoding/decoding")
    }
    
    func testDragAccelerationModifierKeyJSONEncoding() {
        let keys: Set<ModifierKey> = [.command, .option]
        appState.dragAccelerationModifierKeys = keys
        
        // The setter should encode and the getter should decode
        let retrievedKeys = appState.dragAccelerationModifierKeys
        XCTAssertEqual(retrievedKeys, keys, "Drag acceleration keys should survive JSON encoding/decoding")
    }
    
    // MARK: - Edge Cases
    
    func testEmptyModifierKeys() {
        appState.modifierKeys = []
        XCTAssertTrue(appState.modifierKeys.isEmpty, "Should handle empty modifier keys")
    }
    
    func testAllModifierKeys() {
        let allKeys = Set(ModifierKey.allCases)
        appState.modifierKeys = allKeys
        XCTAssertEqual(appState.modifierKeys, allKeys, "Should handle all modifier keys")
    }
    
    func testExtremePercentageValues() {
        appState.updateSlowSpeedPercentage(0.1)
        XCTAssertTrue(appState.precisionFactor > 0, "Should handle very small percentages")
        
        appState.updateSlowSpeedPercentage(1000.0)
        XCTAssertTrue(appState.precisionFactor > 0, "Should handle very large percentages")
    }
    
    func testExtremeRadiusValues() {
        XCTAssertNoThrow(appState.updateAccelerationRadius(0.0))
        XCTAssertNoThrow(appState.updateAccelerationRadius(10000.0))
        XCTAssertNoThrow(appState.updateAccelerationRadius(-100.0))
    }
}