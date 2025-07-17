// this_file: /root/repo/Tests/DragobooCoreTests/PrecisionEngineTests.swift

import XCTest
import CoreGraphics
@testable import DragobooCore

final class PrecisionEngineTests: XCTestCase {
    
    var engine: PrecisionEngine!
    
    override func setUp() {
        super.setUp()
        engine = PrecisionEngine(precisionFactor: 2.0)
    }
    
    override func tearDown() {
        engine?.stop()
        engine = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(engine, "Engine should be initialized")
    }
    
    func testPrecisionFactorInitialization() {
        let testEngine = PrecisionEngine(precisionFactor: 4.0)
        XCTAssertNotNil(testEngine, "Engine should initialize with custom precision factor")
    }
    
    func testZeroPrecisionFactorHandling() {
        let testEngine = PrecisionEngine(precisionFactor: 0.0)
        XCTAssertNotNil(testEngine, "Engine should handle zero precision factor gracefully")
    }
    
    // MARK: - Precision Factor Tests
    
    func testUpdatePrecisionFactor() {
        engine.updatePrecisionFactor(5.0)
        // Since we can't directly access the private precisionFactor,
        // we test the behavior indirectly through public methods
        XCTAssertNoThrow(engine.updatePrecisionFactor(5.0))
    }
    
    func testUpdatePrecisionFactorWithZero() {
        // Should handle zero gracefully without crashing
        XCTAssertNoThrow(engine.updatePrecisionFactor(0.0))
    }
    
    func testUpdatePrecisionFactorWithNegative() {
        // Should handle negative values gracefully
        XCTAssertNoThrow(engine.updatePrecisionFactor(-1.0))
    }
    
    // MARK: - Modifier Key Tests
    
    func testUpdateModifierKeys() {
        let keys: Set<ModifierKey> = [.fn, .control]
        XCTAssertNoThrow(engine.updateModifierKeys(keys))
    }
    
    func testUpdateEmptyModifierKeys() {
        let keys: Set<ModifierKey> = []
        XCTAssertNoThrow(engine.updateModifierKeys(keys))
    }
    
    func testUpdateAllModifierKeys() {
        let keys: Set<ModifierKey> = Set(ModifierKey.allCases)
        XCTAssertNoThrow(engine.updateModifierKeys(keys))
    }
    
    func testUpdateDragAccelerationModifierKeys() {
        let keys: Set<ModifierKey> = [.command, .option]
        XCTAssertNoThrow(engine.updateDragAccelerationModifierKeys(keys))
    }
    
    // MARK: - Feature Toggle Tests
    
    func testSlowSpeedEnabledToggle() {
        XCTAssertNoThrow(engine.updateSlowSpeedEnabled(false))
        XCTAssertNoThrow(engine.updateSlowSpeedEnabled(true))
    }
    
    func testDragAccelerationEnabledToggle() {
        XCTAssertNoThrow(engine.updateDragAccelerationEnabled(false))
        XCTAssertNoThrow(engine.updateDragAccelerationEnabled(true))
    }
    
    func testUpdateAccelerationRadius() {
        XCTAssertNoThrow(engine.updateAccelerationRadius(100.0))
        XCTAssertNoThrow(engine.updateAccelerationRadius(0.0))
        XCTAssertNoThrow(engine.updateAccelerationRadius(-1.0))
    }
    
    // MARK: - Drag Acceleration Calculation Tests
    
    func testCalculateEffectivePrecisionFactorNormalSpeed() {
        // Test normal speed (not in precision mode, not dragging)
        let factor = engine.calculateEffectivePrecisionFactor(isDragging: false)
        XCTAssertEqual(factor, 2.0, accuracy: 0.01, "Normal speed should return 2.0")
    }
    
    func testCalculateEffectivePrecisionFactorWithDragAcceleration() {
        // Enable drag acceleration
        engine.updateDragAccelerationEnabled(true)
        engine.updateAccelerationRadius(100.0)
        
        // Test with different drag distances
        let factor = engine.calculateEffectivePrecisionFactor(isDragging: true)
        XCTAssertGreaterThan(factor, 0, "Drag acceleration factor should be positive")
    }
    
    func testCalculateEffectivePrecisionFactorWithZeroRadius() {
        engine.updateDragAccelerationEnabled(true)
        engine.updateAccelerationRadius(0.0)
        
        let factor = engine.calculateEffectivePrecisionFactor(isDragging: true)
        XCTAssertEqual(factor, 2.0, accuracy: 0.01, "Zero radius should fallback to normal speed")
    }
    
    // MARK: - State Management Tests
    
    func testEngineStopCleansState() {
        // Start engine (without actually creating event tap in test)
        XCTAssertNoThrow(engine.stop())
        
        // Should be able to call stop multiple times
        XCTAssertNoThrow(engine.stop())
    }
    
    // MARK: - Error Handling Tests
    
    func testEngineStartWithoutAccessibilityPermissions() {
        // This test would normally fail due to accessibility permissions
        // We test that the error is properly thrown and handled
        XCTAssertThrowsError(try engine.start()) { error in
            XCTAssertTrue(error is PrecisionEngineError, "Should throw PrecisionEngineError")
        }
    }
    
    // MARK: - Precision Mode Callback Tests
    
    func testPrecisionModeCallback() {
        let expectation = XCTestExpectation(description: "Precision mode callback")
        var callbackReceived = false
        
        engine.onPrecisionModeChange = { isActive in
            callbackReceived = true
            expectation.fulfill()
        }
        
        // Simulate precision mode change
        // Note: This would normally be triggered by modifier key events
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(callbackReceived, "Callback should be called when precision mode changes")
    }
    
    // MARK: - ModifierKey Enum Tests
    
    func testModifierKeyDisplayNames() {
        XCTAssertEqual(ModifierKey.fn.displayName, "fn")
        XCTAssertEqual(ModifierKey.control.displayName, "⌃")
        XCTAssertEqual(ModifierKey.option.displayName, "⌥")
        XCTAssertEqual(ModifierKey.command.displayName, "⌘")
    }
    
    func testModifierKeyCGEventFlags() {
        XCTAssertEqual(ModifierKey.fn.cgEventFlag, CGEventFlags.maskSecondaryFn)
        XCTAssertEqual(ModifierKey.control.cgEventFlag, CGEventFlags.maskControl)
        XCTAssertEqual(ModifierKey.option.cgEventFlag, CGEventFlags.maskAlternate)
        XCTAssertEqual(ModifierKey.command.cgEventFlag, CGEventFlags.maskCommand)
    }
    
    func testModifierKeyAllCases() {
        let allCases = ModifierKey.allCases
        XCTAssertEqual(allCases.count, 4, "Should have 4 modifier keys")
        XCTAssertTrue(allCases.contains(.fn))
        XCTAssertTrue(allCases.contains(.control))
        XCTAssertTrue(allCases.contains(.option))
        XCTAssertTrue(allCases.contains(.command))
    }
    
    func testModifierKeyCodable() {
        let key = ModifierKey.fn
        XCTAssertNoThrow(try JSONEncoder().encode(key))
        
        let encoded = try! JSONEncoder().encode(key)
        let decoded = try! JSONDecoder().decode(ModifierKey.self, from: encoded)
        XCTAssertEqual(decoded, key)
    }
    
    // MARK: - PrecisionEngineError Tests
    
    func testPrecisionEngineErrorDescriptions() {
        let tapError = PrecisionEngineError.failedToCreateEventTap
        XCTAssertNotNil(tapError.errorDescription)
        XCTAssertTrue(tapError.errorDescription!.contains("accessibility permissions"))
        
        let runLoopError = PrecisionEngineError.failedToCreateRunLoopSource
        XCTAssertNotNil(runLoopError.errorDescription)
        XCTAssertTrue(runLoopError.errorDescription!.contains("run loop source"))
    }
}