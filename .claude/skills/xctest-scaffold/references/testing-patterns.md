# Testing Patterns

Reference patterns for URLProtocol-based mocking, async determinism, and system framework isolation in XCTest.

## URLProtocol Mocking

### Pattern: Intercepting URLSession Requests

`URLProtocol` subclasses intercept all requests made through a configured `URLSession`. This eliminates real network calls without requiring dependency injection at the HTTP layer.

### Configuration

```swift
final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data { client?.urlProtocol(self, didLoad: data) }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
```

### Session Construction

```swift
private func makeTestSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}
```

Use `URLSessionConfiguration.ephemeral` to avoid disk caching side effects.

### Response Simulation

```swift
// Success
MockURLProtocol.requestHandler = { request in
    let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
    )!
    return (response, nil)
}

// Failure
MockURLProtocol.requestHandler = { _ in
    throw URLError(.notConnectedToInternet)
}

// Sequential responses (for retry testing)
var callCount = 0
MockURLProtocol.requestHandler = { request in
    callCount += 1
    if callCount < 3 {
        throw URLError(.timedOut)
    }
    let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
    )!
    return (response, nil)
}
```

### Cleanup

Reset the handler in `tearDown()` to prevent test pollution:

```swift
override func tearDown() {
    MockURLProtocol.requestHandler = nil
    super.tearDown()
}
```

## Async Testing Strategies

### Direct Await

For `async` functions, call them directly in an `async` test method:

```swift
func test_webhookService_successfulPost_completesWithoutRetry() async {
    MockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (response, nil)
    }

    await sut.send()
    XCTAssertEqual(callCount, 1)
}
```

### XCTestExpectation for Detached Work

When testing fire-and-forget behavior or detached tasks:

```swift
func test_webhookService_networkFailure_doesNotBlockCaller() async {
    let completed = expectation(description: "send completes")

    MockURLProtocol.requestHandler = { _ in
        throw URLError(.notConnectedToInternet)
    }

    Task {
        await sut.send()
        completed.fulfill()
    }

    await fulfillment(of: [completed], timeout: 2.0)
}
```

### Injected Delays for Retry Testing

Retry logic with exponential backoff requires injectable delay providers to avoid wall-clock waits:

```swift
// Production signature
func send(delayProvider: @escaping (Int) async -> Void = { attempt in
    try? await Task.sleep(for: .seconds(pow(2.0, Double(attempt))))
}) async { ... }

// Test injection
await sut.send(delayProvider: { _ in })  // Zero delay
```

### Time Source Injection

For idle timer testing (Chapter 5 Auto-Assist):

```swift
protocol TimeSource {
    func now() -> TimeInterval
}

struct SystemTimeSource: TimeSource {
    func now() -> TimeInterval { CACurrentMediaTime() }
}

final class MockTimeSource: TimeSource {
    var currentTime: TimeInterval = 0
    func now() -> TimeInterval { currentTime }
}
```

Advance `mockTimeSource.currentTime` to simulate elapsed time without waiting.

## Protocol Abstraction for System Frameworks

### Haptics

```swift
protocol HapticPlaying: Sendable {
    func playPattern(named: String) async throws
    var isAvailable: Bool { get }
}

final class MockHapticPlayer: HapticPlaying {
    private(set) var playedPatterns: [String] = []
    var isAvailable: Bool = true
    var shouldThrow: Bool = false

    func playPattern(named pattern: String) async throws {
        if shouldThrow { throw HapticError.engineUnavailable }
        playedPatterns.append(pattern)
    }
}
```

### Audio

```swift
protocol AudioPlaying: Sendable {
    func play(asset: String) async
    func stop()
    func prepareToPlay(asset: String)
    var isPlaying: Bool { get }
}

final class MockAudioPlayer: AudioPlaying {
    private(set) var playedAssets: [String] = []
    private(set) var preparedAssets: [String] = []
    private(set) var stopCalled = false
    var isPlaying: Bool = false

    func play(asset: String) async {
        playedAssets.append(asset)
        isPlaying = true
    }

    func stop() {
        stopCalled = true
        isPlaying = false
    }

    func prepareToPlay(asset: String) {
        preparedAssets.append(asset)
    }
}
```

### UserDefaults Isolation

```swift
extension XCTestCase {
    func makeTestDefaults() -> UserDefaults {
        let suiteName = String(describing: type(of: self)) + "." + name
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
```

## Test Data Builders

### Beat Map Test Data

```swift
enum BeatMapTestData {
    static let validBeatMap: [TimeInterval] = [
        0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0
    ]

    static let nonMonotonic: [TimeInterval] = [
        0.5, 1.0, 0.8, 2.0
    ]

    static let exceedsTrackDuration: [TimeInterval] = [
        0.5, 1.0, 999.0
    ]

    static let insufficientSpacing: [TimeInterval] = [
        0.5, 0.501, 0.502
    ]

    static let empty: [TimeInterval] = []
}
```

### Cipher Test Data

```swift
enum CipherTestData {
    static let correctSegments: [Int] = [3, 7, 1]
    static let oneIncorrect: [Int] = [3, 7, 5]
    static let allIncorrect: [Int] = [0, 0, 0]
}
```

## Simulator Compatibility

Tests MUST run deterministically in the iOS Simulator. The following APIs are unavailable in the simulator and MUST be protocol-abstracted:

| Framework | API | Mock Strategy |
| --- | --- | --- |
| CoreHaptics | `CHHapticEngine` | `HapticPlaying` protocol |
| AVFoundation | `AVAudioSession` hardware | `AudioPlaying` protocol |
| ARKit | `ARSession` | Not used in this project |
| CoreMotion | `CMMotionManager` | Not used in this project |

Tests that reference simulator-incompatible APIs without protocol abstraction will fail deterministically, enforcing the isolation boundary by design.
