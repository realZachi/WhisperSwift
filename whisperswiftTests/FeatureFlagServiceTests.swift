//
//  FeatureFlagServiceTests.swift
//  whisperswiftTests
//
//  Tests for FeatureFlagService feature flag management.
//

import XCTest
@testable import whisperswift

final class FeatureFlagServiceTests: XCTestCase {

    var testDefaults: UserDefaults!
    var flagService: LocalFeatureFlagService!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "FeatureFlagServiceTests")!
        testDefaults.removePersistentDomain(forName: "FeatureFlagServiceTests")
        flagService = LocalFeatureFlagService(userDefaults: testDefaults)
    }

    override func tearDown() async throws {
        await flagService.resetAllToDefaults()
        testDefaults.removePersistentDomain(forName: "FeatureFlagServiceTests")
        testDefaults = nil
        flagService = nil
        try await super.tearDown()
    }

    // MARK: - FeatureFlagValue Tests

    func test_FeatureFlagValue_BooleanAccessor_ReturnsCorrectValue() {
        let value = FeatureFlagValue.boolean(true)
        XCTAssertEqual(value.boolValue, true)
        XCTAssertNil(value.stringValue)
        XCTAssertNil(value.intValue)
        XCTAssertNil(value.doubleValue)
    }

    func test_FeatureFlagValue_StringAccessor_ReturnsCorrectValue() {
        let value = FeatureFlagValue.string("test")
        XCTAssertNil(value.boolValue)
        XCTAssertEqual(value.stringValue, "test")
        XCTAssertNil(value.intValue)
        XCTAssertNil(value.doubleValue)
    }

    func test_FeatureFlagValue_IntegerAccessor_ReturnsCorrectValue() {
        let value = FeatureFlagValue.integer(42)
        XCTAssertNil(value.boolValue)
        XCTAssertNil(value.stringValue)
        XCTAssertEqual(value.intValue, 42)
        XCTAssertNil(value.doubleValue)
    }

    func test_FeatureFlagValue_DoubleAccessor_ReturnsCorrectValue() {
        let value = FeatureFlagValue.double(3.14)
        XCTAssertNil(value.boolValue)
        XCTAssertNil(value.stringValue)
        XCTAssertNil(value.intValue)
        XCTAssertEqual(value.doubleValue, 3.14)
    }

    func test_FeatureFlagValue_Equality() {
        let value1 = FeatureFlagValue.boolean(true)
        let value2 = FeatureFlagValue.boolean(true)
        let value3 = FeatureFlagValue.boolean(false)

        XCTAssertEqual(value1, value2)
        XCTAssertNotEqual(value1, value3)
    }

    // MARK: - LocalFeatureFlagService Boolean Tests

    func test_IsEnabled_DefaultValue_WhenNotSet() {
        XCTAssertFalse(flagService.isEnabled(.debugOverlay))
    }

    func test_IsEnabled_ReturnsSetValue() async {
        await flagService.setValue(.boolean(true), for: .debugOverlay)
        XCTAssertTrue(flagService.isEnabled(.debugOverlay))
    }

    func test_IsEnabled_ReturnsFalseAfterReset() async {
        await flagService.setValue(.boolean(true), for: .debugOverlay)
        await flagService.resetToDefault(.debugOverlay)
        XCTAssertFalse(flagService.isEnabled(.debugOverlay))
    }

    // MARK: - LocalFeatureFlagService Integer Tests

    func test_Integer_DefaultValue_WhenNotSet() {
        XCTAssertEqual(flagService.integer(for: .apiMaxRetries), 3)
    }

    func test_Integer_ReturnsSetValue() async {
        await flagService.setValue(.integer(5), for: .apiMaxRetries)
        XCTAssertEqual(flagService.integer(for: .apiMaxRetries), 5)
    }

    // MARK: - LocalFeatureFlagService Double Tests

    func test_Double_DefaultValue_WhenNotSet() {
        XCTAssertEqual(flagService.double(for: .apiTimeoutSeconds), 30.0)
    }

    func test_Double_ReturnsSetValue() async {
        await flagService.setValue(.double(60.0), for: .apiTimeoutSeconds)
        XCTAssertEqual(flagService.double(for: .apiTimeoutSeconds), 60.0)
    }

    // MARK: - LocalFeatureFlagService String Tests

    func test_String_ReturnsEmptyForNonStringFlag() {
        XCTAssertTrue(flagService.string(for: .debugOverlay).isEmpty)
    }

    // MARK: - Persistence Tests

    func test_SetValue_PersistsToUserDefaults() async {
        await flagService.setValue(.boolean(true), for: .debugOverlay)
        let newService = LocalFeatureFlagService(userDefaults: testDefaults)
        XCTAssertTrue(newService.isEnabled(.debugOverlay))
    }

    func test_ResetAllToDefaults_ClearsAllOverrides() async {
        await flagService.setValue(.boolean(true), for: .debugOverlay)
        await flagService.setValue(.integer(10), for: .apiMaxRetries)

        await flagService.resetAllToDefaults()

        XCTAssertFalse(flagService.isEnabled(.debugOverlay))
        XCTAssertEqual(flagService.integer(for: .apiMaxRetries), 3)
    }

    // MARK: - AllValues Tests

    func test_AllValues_ReturnsAllFlags() async {
        let allValues = await flagService.allValues()
        XCTAssertEqual(allValues.count, FeatureFlag.allCases.count)
    }

    func test_OverriddenFlags_ReturnsOnlyOverrides() async {
        var overridden = await flagService.overriddenFlags()
        XCTAssertTrue(overridden.isEmpty)

        await flagService.setValue(.boolean(true), for: .debugOverlay)
        overridden = await flagService.overriddenFlags()
        XCTAssertEqual(overridden.count, 1)
        XCTAssertNotNil(overridden[.debugOverlay])
    }

    // MARK: - FeatureFlag Enum Tests

    func test_FeatureFlag_AllCases_HaveDefaults() {
        for flag in FeatureFlag.allCases {
            _ = flag.defaultValue
        }
    }

    func test_FeatureFlag_AllCases_HaveDescriptions() {
        for flag in FeatureFlag.allCases {
            XCTAssertFalse(flag.description.isEmpty, "Flag \(flag.rawValue) has empty description")
        }
    }

    func test_FeatureFlag_AllCases_HaveCategories() {
        for flag in FeatureFlag.allCases {
            _ = flag.category
        }
    }

    // MARK: - Global Convenience Functions Tests

    func test_IsFeatureEnabled_GlobalFunction() {
        _ = isFeatureEnabled(.debugOverlay)
    }

    func test_FeatureFlagInt_GlobalFunction() {
        XCTAssertEqual(featureFlagInt(.apiMaxRetries), 3)
    }

    func test_FeatureFlagDouble_GlobalFunction() {
        XCTAssertEqual(featureFlagDouble(.apiTimeoutSeconds), 30.0)
    }

    func test_FeatureFlagString_GlobalFunction() {
        XCTAssertTrue(featureFlagString(.debugOverlay).isEmpty)
    }
}
