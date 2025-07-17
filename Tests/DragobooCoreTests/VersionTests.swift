// this_file: /root/repo/Tests/DragobooCoreTests/VersionTests.swift

import XCTest
@testable import DragobooCore

final class VersionTests: XCTestCase {
    
    func testVersionStructure() {
        let version = Version.current
        
        // Test that version properties are accessible
        XCTAssertFalse(version.semver.isEmpty, "Version semver should not be empty")
        XCTAssertFalse(version.commit.isEmpty, "Version commit should not be empty")
        XCTAssertFalse(version.buildDate.isEmpty, "Version buildDate should not be empty")
        
        // Test version string formats
        XCTAssertTrue(version.semver.contains("."), "Version should contain dots for semantic versioning")
        XCTAssertTrue(version.displayString.hasPrefix("v"), "Display string should start with 'v'")
    }
    
    func testFullVersionFormat() {
        let version = Version.current
        let fullVersion = version.fullVersion
        
        if version.isDevelopment {
            XCTAssertTrue(fullVersion.contains("-dev+"), "Development version should contain '-dev+'")
        } else {
            XCTAssertEqual(fullVersion, version.semver, "Release version should equal semver")
        }
    }
    
    func testDisplayString() {
        let version = Version.current
        let displayString = version.displayString
        
        XCTAssertTrue(displayString.hasPrefix("v"), "Display string should start with 'v'")
        XCTAssertTrue(displayString.contains("("), "Display string should contain build date in parentheses")
        XCTAssertTrue(displayString.contains(")"), "Display string should contain build date in parentheses")
    }
    
    func testCustomVersion() {
        let customVersion = Version(
            semver: "2.0.0",
            commit: "abc123def456",
            buildDate: "2025-01-01 00:00:00 UTC",
            isDevelopment: false
        )
        
        XCTAssertEqual(customVersion.semver, "2.0.0")
        XCTAssertEqual(customVersion.commit, "abc123def456")
        XCTAssertEqual(customVersion.buildDate, "2025-01-01 00:00:00 UTC")
        XCTAssertFalse(customVersion.isDevelopment)
        XCTAssertEqual(customVersion.fullVersion, "2.0.0")
        XCTAssertEqual(customVersion.displayString, "v2.0.0 (2025-01-01 00:00:00 UTC)")
    }
    
    func testDevelopmentVersion() {
        let devVersion = Version(
            semver: "1.0.0",
            commit: "abc123def456",
            buildDate: "2025-01-01 00:00:00 UTC",
            isDevelopment: true
        )
        
        XCTAssertTrue(devVersion.isDevelopment)
        XCTAssertEqual(devVersion.fullVersion, "1.0.0-dev+abc123d")
        XCTAssertEqual(devVersion.displayString, "v1.0.0-dev+abc123d (2025-01-01 00:00:00 UTC)")
    }
}