# Swift Unit Testing Guide

## Overview

Swift has two main testing frameworks:

1. **XCTest** - The traditional, mature framework (what you're currently using)
2. **Swift Testing** - Apple's modern framework introduced in Xcode 16 (WWDC 2024)

Both are actively maintained and can coexist in the same project. XCTest is **not deprecated**.

## Current Setup (XCTest)

Your project uses XCTest, which is excellent for:
- ✅ Mature, stable API
- ✅ Full Xcode integration
- ✅ Works with Swift Package Manager
- ✅ Excellent for CI/CD
- ✅ Coverage reporting with `llvm-cov`

### Best Practices for XCTest

#### 1. Test Structure

```swift
import XCTest
@testable import ProtokolLib

final class MyFeatureTests: XCTestCase {
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        // Initialize test dependencies
    }
    
    override func tearDown() {
        // Clean up after each test
        super.tearDown()
    }
    
    // MARK: - Test Methods
    
    func testFeatureName_WhenCondition_ShouldResult() {
        // Arrange
        let input = "test"
        
        // Act
        let result = process(input)
        
        // Assert
        XCTAssertEqual(result, expected, "Should process input correctly")
    }
    
    func testAsyncOperation() async throws {
        let result = try await asyncOperation()
        XCTAssertNotNil(result)
    }
}
```

#### 2. Test Naming Convention

Use descriptive names: `test[Feature]_[WhenCondition]_[ShouldResult]`

Examples:
- `testJSONRPCRequest_WhenCreated_ShouldHaveCorrectVersion`
- `testMCPClient_WhenServerUnavailable_ShouldReturnError`
- `testConnectionManager_WhenReconnecting_ShouldRetryThreeTimes`

#### 3. Test Organization

Group related tests using `// MARK:` comments:

```swift
final class MCPClientTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testInit() { }
    func testInitWithCustomConfig() { }
    
    // MARK: - Connection Tests
    
    func testConnect() { }
    func testDisconnect() { }
    
    // MARK: - Error Handling Tests
    
    func testHandleParseError() { }
    func testHandleNetworkError() { }
}
```

#### 4. Async/Await Support

XCTest fully supports async/await:

```swift
func testAsyncOperation() async throws {
    let client = MCPClient()
    let result = try await client.connect()
    XCTAssertTrue(result.isConnected)
}
```

#### 5. Assertions

Use specific assertions for better error messages:

```swift
// ✅ Good - specific assertion
XCTAssertEqual(actual, expected, "Should match expected value")
XCTAssertNotNil(value, "Should not be nil")
XCTAssertTrue(condition, "Should be true")
XCTAssertThrowsError(try riskyOperation(), "Should throw error")

// ❌ Avoid - generic assertion
XCTAssert(condition)  // Less informative
```

#### 6. Test Coverage

Run tests with coverage:
```bash
swift test --enable-code-coverage --parallel
```

Generate lcov report:
```bash
./scripts/coverage.sh
```

#### 7. Parallel Execution

Enable parallel test execution (default in Swift 5.9+):
```bash
swift test --parallel
```

#### 8. Test Doubles (Mocks/Stubs)

For complex dependencies, create protocol-based mocks:

```swift
protocol TransportProtocol {
    func send(_ data: Data) async throws -> Data
}

class MockTransport: TransportProtocol {
    var sendCallCount = 0
    var lastSentData: Data?
    var responseData: Data?
    
    func send(_ data: Data) async throws -> Data {
        sendCallCount += 1
        lastSentData = data
        return responseData ?? Data()
    }
}

func testMCPClient_UsesTransport() async throws {
    let mockTransport = MockTransport()
    let client = MCPClient(transport: mockTransport)
    
    _ = try await client.sendRequest(.initialize)
    
    XCTAssertEqual(mockTransport.sendCallCount, 1)
}
```

## Swift Testing (Modern Alternative)

If you want to explore the new framework:

### Key Differences

| Feature | XCTest | Swift Testing |
|---------|--------|---------------|
| Syntax | `func testX()` | `@Test func x()` |
| Assertions | `XCTAssertEqual()` | `#expect(actual == expected)` |
| Setup | `setUp()` | `init()` |
| Organization | Subclass `XCTestCase` | Struct/Class/Actor |
| Parallel | Optional flag | Default |
| Macros | No | Yes (`#expect`, `#require`) |

### Example Migration

**XCTest:**
```swift
final class MCPTypesTests: XCTestCase {
    func testClientInfoCreation() {
        let info = ClientInfo(name: "Test", version: "1.0")
        XCTAssertEqual(info.name, "Test")
    }
}
```

**Swift Testing:**
```swift
struct MCPTypesTests {
    @Test func clientInfoCreation() {
        let info = ClientInfo(name: "Test", version: "1.0")
        #expect(info.name == "Test")
    }
}
```

### When to Use Swift Testing

- ✅ New projects or new test files
- ✅ Want better async/await integration
- ✅ Need parameterized tests
- ✅ Want more expressive assertions

### When to Stick with XCTest

- ✅ Existing large test suites (like yours)
- ✅ Need UI automation tests
- ✅ Need performance tests (`XCTMetric`)
- ✅ Team familiarity with XCTest

## Running Tests

### Via npm (kodrdriv compatible)
```bash
npm test              # Run all tests
npm run test:coverage # Run with coverage
```

### Via Swift CLI
```bash
swift test                    # Run tests
swift test --parallel         # Run in parallel
swift test --enable-code-coverage  # With coverage
swift test --filter MCPTypesTests  # Run specific test class
```

### Via Xcode
1. Open `Package.swift` in Xcode
2. Press `⌘+U` to run all tests
3. Press `⌘+6` to see test navigator
4. Click ▶️ next to individual tests

## Coverage Reports

Your project includes `scripts/coverage.sh` which:
1. Runs tests with coverage
2. Generates `coverage/lcov.info` (for CI/tooling)
3. Generates `coverage/html/index.html` (for viewing)

View HTML report:
```bash
open coverage/html/index.html
```

## CI/CD Integration

Your `.github/workflows/test.yml` already:
- ✅ Runs tests with coverage
- ✅ Generates lcov reports
- ✅ Uploads to Codecov

## Recommendations

1. **Stick with XCTest** for now - it's working well and you have good coverage
2. **Consider Swift Testing** for new test files if you want to experiment
3. **Use parallel execution** - it's fast and reliable
4. **Organize tests** with MARK comments
5. **Write descriptive test names** - they serve as documentation
6. **Test edge cases** - nil values, empty strings, error conditions
7. **Mock external dependencies** - don't rely on network/filesystem in unit tests

## Resources

- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Swift Testing Documentation](https://developer.apple.com/documentation/testing)
- [Swift Testing on GitHub](https://github.com/apple/swift-testing)
- [WWDC 2024: Meet Swift Testing](https://developer.apple.com/videos/play/wwdc2024/10179/)
