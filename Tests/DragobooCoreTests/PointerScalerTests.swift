import XCTest
@testable import DragobooCore

final class PointerScalerTests: XCTestCase {
    func testPrecisionFactorInitialization() {
        let scaler = PointerScaler(precisionFactor: 4.0)
        XCTAssertNotNil(scaler)
    }
    
    func testPrecisionFactorUpdate() {
        let scaler = PointerScaler(precisionFactor: 4.0)
        scaler.updatePrecisionFactor(8.0)
        XCTAssertNotNil(scaler)
    }
}