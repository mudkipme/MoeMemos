import XCTest
@testable import Account

final class AccountTests: XCTestCase {
    func testV0CompatibilityRejectsVersionsLowerThan0210() {
        let result = evaluateMemosVersionCompatibility(.v0(version: "0.20.9"))
        XCTAssertEqual(result, .unsupported)
    }

    func testV0CompatibilityAccepts0210AndHigher() {
        let exact = evaluateMemosVersionCompatibility(.v0(version: "0.21.0"))
        let higher = evaluateMemosVersionCompatibility(.v0(version: "0.30.2"))
        XCTAssertEqual(exact, .supported)
        XCTAssertEqual(higher, .supported)
    }

    func testV1CompatibilitySupports0260And0261OnlyWithoutWarning() {
        let v0260 = evaluateMemosVersionCompatibility(.v1(version: "0.26.0"))
        let v0261 = evaluateMemosVersionCompatibility(.v1(version: "0.26.1"))
        XCTAssertEqual(v0260, .supported)
        XCTAssertEqual(v0261, .supported)
    }

    func testV1CompatibilityRejectsLowerThan0260() {
        let result = evaluateMemosVersionCompatibility(.v1(version: "0.25.9"))
        XCTAssertEqual(result, .unsupported)
    }

    func testV1CompatibilityRequiresWarningForHigherThan0261() {
        let result = evaluateMemosVersionCompatibility(.v1(version: "0.26.2"))
        XCTAssertEqual(result, .v1HigherThanSupported(version: "0.26.2"))
    }

    func testVersionParserHandlesPrefixAndSuffix() {
        let result = evaluateMemosVersionCompatibility(.v1(version: "v0.26.1-beta.3"))
        XCTAssertEqual(result, .supported)
    }
}
