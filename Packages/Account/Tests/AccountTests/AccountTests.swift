import XCTest
@testable import Account

final class AccountTests: XCTestCase {
    func testV0CompatibilityRejectsVersionsLowerThan0210() {
        let result = evaluateMemosVersionCompatibility(.v0(version: "0.20.9"))
        XCTAssertEqual(result, .unsupported)
    }

    func testV0CompatibilityTreatsCanaryAsSupported() {
        let result = evaluateMemosVersionCompatibility(.v0(version: "canary"))
        XCTAssertEqual(result, .supported)
    }

    func testV0CompatibilityRejectsEmptyVersion() {
        let result = evaluateMemosVersionCompatibility(.v0(version: ""))
        XCTAssertEqual(result, .unsupported)
    }

    func testV0CompatibilityAccepts0210AndHigher() {
        let exact = evaluateMemosVersionCompatibility(.v0(version: "0.21.0"))
        let higher = evaluateMemosVersionCompatibility(.v0(version: "0.30.2"))
        XCTAssertEqual(exact, .supported)
        XCTAssertEqual(higher, .supported)
    }

    func testV1CompatibilitySupports0270To0291() {
        let v0270 = evaluateMemosVersionCompatibility(.v1(version: "0.27.0"))
        let v0271 = evaluateMemosVersionCompatibility(.v1(version: "0.27.1"))
        XCTAssertEqual(v0270, .supported)
        XCTAssertEqual(v0271, .supported)
    }

    func testV1CompatibilityRejectsLowerThan0260() {
        let result = evaluateMemosVersionCompatibility(.v1(version: "0.25.9"))
        XCTAssertEqual(result, .unsupported)
    }

    func testV1CompatibilitySupports0291() {
        let result = evaluateMemosVersionCompatibility(.v1(version: "0.29.1"))
        XCTAssertEqual(result, .supported)
    }

    func testV1CompatibilityRequiresWarningForHigherThan0291() {
        let result = evaluateMemosVersionCompatibility(.v1(version: "0.29.2"))
        XCTAssertEqual(result, .v1HigherThanSupported(version: "0.29.2"))
    }

    func testV1CompatibilityRejectsEmptyVersion() {
        let result = evaluateMemosVersionCompatibility(.v1(version: ""))
        XCTAssertEqual(result, .unsupported)
    }

    func testV1CompatibilityTreatsCanaryAsHigherThanSupported() {
        let result = evaluateMemosVersionCompatibility(.v1(version: "canary"))
        XCTAssertEqual(result, .v1HigherThanSupported(version: "canary"))
    }

    func testVersionParserHandlesPrefixAndSuffix() {
        let result = evaluateMemosVersionCompatibility(.v1(version: "v0.27.1-beta.3"))
        XCTAssertEqual(result, .supported)
    }
}
