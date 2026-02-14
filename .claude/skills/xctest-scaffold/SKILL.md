---
name: xctest-scaffold
description: Generate deterministic XCTest unit tests conforming to project naming conventions, mandatory coverage matrix, URLProtocol-based network mocking, system framework isolation, and async determinism guarantees. Use when unit tests are requested, coverage is added for new logic, test validation against project standards is requested, or any mandatory coverage area is modified. Triggers on test creation, test scaffold, coverage enforcement, mock generation, or test validation requests.
---

# XCTest Scaffold

Generate XCTest unit tests that enforce the project's strict naming conventions, mandatory coverage matrix, dependency isolation rules, and deterministic async testing patterns defined in `CLAUDE.md` §7 and `Design-Doc.md` §13.

## Pre-Scaffold Verification

Before generating any test code, verify:

1. The target component exists in the codebase.
2. The component falls within the mandatory coverage matrix.
3. No duplicate test coverage exists for the target scenario.

If any verification fails, **HALT** and cite the conflict.

## Naming Convention Enforcement

All test methods MUST follow this exact pattern:

```
func test_<unit>_<scenario>_<expectedResult>()
```

**Rules:**

- `<unit>`: The type or subsystem under test, in lowerCamelCase.
- `<scenario>`: The specific condition or input being tested, in lowerCamelCase.
- `<expectedResult>`: The expected outcome, in lowerCamelCase.
- Underscores separate the three segments. No additional underscores within segments.
- camelCase naming (e.g., `testFlowCoordinatorAdvances`) is **prohibited**.

**Examples:**

```swift
func test_flowCoordinator_completeChapter3_advancesToChapter4()
func test_flowCoordinator_firstLaunch_startsAtChapter1()
func test_flowCoordinator_resumeAfterCompletion_returnsToChapter6()
func test_cipherValidation_correctSegments_returnsTrue()
func test_cipherValidation_incorrectSegment_incrementsFailureCount()
func test_cipherValidation_threeFailures_activatesAutoAssist()
func test_webhookService_successfulPost_completesWithoutRetry()
func test_webhookService_singleFailure_retriesOnce()
func test_webhookService_thirdFailure_discardsPayload()
func test_webhookService_networkFailure_doesNotBlockCaller()
func test_beatMap_timestamps_areMonotonicallyIncreasing()
func test_beatMap_timestamps_areWithinTrackDuration()
func test_beatMap_spacing_meetsMinimumInterval()
```

## Mandatory Coverage Matrix

The following components MUST have test coverage. If coverage is missing for any row, scaffold tests immediately.

### FlowCoordinator

| Scenario                     | Expected Result                                     | Test Name                                                      |
| ---------------------------- | --------------------------------------------------- | -------------------------------------------------------------- |
| Complete chapter N (1–5)     | Advances to chapter N+1                             | `test_flowCoordinator_completeChapterN_advancesToChapterN1`    |
| Complete chapter 6           | Remains at chapter 6 (terminal state)               | `test_flowCoordinator_completeChapter6_remainsAtTerminalState` |
| First launch                 | `currentChapter` is 1                               | `test_flowCoordinator_firstLaunch_startsAtChapter1`            |
| Save checkpoint              | `UserDefaults` key `highestUnlockedChapter` updated | `test_flowCoordinator_saveCheckpoint_persistsToUserDefaults`   |
| Load checkpoint              | Restores `currentChapter` from persisted value      | `test_flowCoordinator_loadCheckpoint_restoresPersistedChapter` |
| Resume after full completion | Returns to chapter 6                                | `test_flowCoordinator_resumeAfterCompletion_returnsToChapter6` |

### Auto-Assist Activation

| Scenario                        | Expected Result              | Test Name                                           |
| ------------------------------- | ---------------------------- | --------------------------------------------------- |
| Chapter 2: 3 deaths             | Auto-Assist activates        | `test_autoAssist_chapter2ThreeDeaths_activates`     |
| Chapter 2: 2 deaths             | Auto-Assist remains inactive | `test_autoAssist_chapter2TwoDeaths_remainsInactive` |
| Chapter 3: 3 incorrect attempts | Auto-Assist activates        | `test_autoAssist_chapter3ThreeIncorrect_activates`  |
| Chapter 4: 5 misses             | Auto-Assist activates        | `test_autoAssist_chapter4FiveMisses_activates`      |
| Chapter 5: 10s idle             | Auto-Assist activates        | `test_autoAssist_chapter5TenSecondsIdle_activates`  |

### Cipher Segment Validation

| Scenario                       | Expected Result                 | Test Name                                                            |
| ------------------------------ | ------------------------------- | -------------------------------------------------------------------- |
| All segments correct           | Validation returns true         | `test_cipherValidation_allSegmentsCorrect_returnsTrue`               |
| One segment incorrect          | Validation returns false        | `test_cipherValidation_oneSegmentIncorrect_returnsFalse`             |
| Incorrect attempt              | Failure counter increments by 1 | `test_cipherValidation_incorrectAttempt_incrementsFailureCount`      |
| Three consecutive failures     | Auto-Assist flag set to true    | `test_cipherValidation_threeConsecutiveFailures_activatesAutoAssist` |
| Correct attempt after failures | Failure counter does not reset  | `test_cipherValidation_correctAfterFailures_doesNotResetCounter`     |

### Webhook Retry Logic

| Scenario                             | Expected Result                 | Test Name                                                        |
| ------------------------------------ | ------------------------------- | ---------------------------------------------------------------- |
| Server returns 200                   | No retry, completion fires      | `test_webhookService_serverReturns200_completesWithoutRetry`     |
| First attempt fails, second succeeds | Retries once, completes         | `test_webhookService_firstFailsSecondSucceeds_retriesOnce`       |
| Three consecutive failures           | Silently discards payload       | `test_webhookService_threeConsecutiveFailures_discardsPayload`   |
| Retry backoff intervals              | Delays increase between retries | `test_webhookService_retryBackoff_delaysIncreaseBetweenAttempts` |
| Network failure                      | Does not block calling thread   | `test_webhookService_networkFailure_doesNotBlockCaller`          |

### Beat Map Data Integrity

| Scenario            | Expected Result                | Test Name                                               |
| ------------------- | ------------------------------ | ------------------------------------------------------- |
| All timestamps      | Monotonically increasing       | `test_beatMap_allTimestamps_areMonotonicallyIncreasing` |
| All timestamps      | Within track duration bounds   | `test_beatMap_allTimestamps_areWithinTrackDuration`     |
| Adjacent timestamps | Meet minimum spacing threshold | `test_beatMap_adjacentTimestamps_meetMinimumSpacing`    |
| Beat map            | Contains at least one entry    | `test_beatMap_entries_isNonEmpty`                       |

## Dependency Isolation Rules

Tests MUST NOT:

- Perform real network calls. All `URLSession` interactions use `URLProtocol` stubs.
- Instantiate `CHHapticEngine`. Haptic logic is tested through protocol abstractions.
- Depend on real audio playback timing. Audio manager interactions are protocol-mocked.
- Access `SpriteKit` scenes or `SKView`. Game logic is extracted into testable pure functions.
- Depend on device-only APIs (`CoreHaptics`, `ARKit`, device sensors).
- Import UI modules (`SwiftUI`, `UIKit`) in test targets for logic tests.
- Use real `UserDefaults`. Inject a test-scoped `UserDefaults(suiteName:)` instance.

## Mocking Strategy

### URLProtocol Stub (Webhook Tests)

All webhook tests MUST use a custom `URLProtocol` subclass to intercept network requests.

**Required stub structure:**

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

**URLSession configuration for tests:**

```swift
let configuration = URLSessionConfiguration.ephemeral
configuration.protocolClasses = [MockURLProtocol.self]
let session = URLSession(configuration: configuration)
```

**Rules:**

- `MockURLProtocol.requestHandler` MUST be reset in `tearDown()`.
- No test may reference a real Discord webhook URL. Use `https://test.invalid/webhook`.
- Response status codes and retry behavior are controlled via the handler.

### Protocol Abstraction (System Frameworks)

System framework dependencies MUST be abstracted behind protocols for testability.

**Pattern:**

```swift
protocol HapticPlaying {
    func playPattern(named: String) async throws
    var isAvailable: Bool { get }
}

protocol AudioPlaying {
    func play(asset: String) async
    func stop()
    var isPlaying: Bool { get }
}
```

Production types (`HapticManager`, `AudioManager`) conform to these protocols. Tests inject mock implementations that record calls without touching hardware.

**Mock implementation pattern:**

```swift
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

### UserDefaults Isolation

Tests MUST NOT use `UserDefaults.standard`. Inject a test-scoped suite:

```swift
let testDefaults = UserDefaults(suiteName: #function)!
// ... test logic ...
testDefaults.removePersistentDomain(forName: #function)
```

Clean up the test suite in `tearDown()` to prevent cross-test contamination.

## Async Determinism Guarantees

### XCTestExpectation for Async Completion

All async operations MUST use explicit expectations with bounded timeouts:

```swift
func test_webhookService_networkFailure_doesNotBlockCaller() async {
    let expectation = expectation(description: "Webhook completes")

    MockURLProtocol.requestHandler = { _ in
        throw URLError(.notConnectedToInternet)
    }

    Task {
        await webhookService.send()
        expectation.fulfill()
    }

    await fulfillment(of: [expectation], timeout: 2.0)
}
```

**Rules:**

- Every async test MUST have a bounded timeout. Maximum: 5 seconds.
- No `Task.sleep` for synchronization. Use `XCTestExpectation` or direct `await`.
- No `DispatchQueue.asyncAfter` in tests. Prohibited by project governance.
- No `Thread.sleep` or `usleep`. Deterministic expectations only.
- Retry backoff intervals MUST be injected as parameters, not hardcoded `Task.sleep` durations, enabling tests to use zero-delay intervals.

### Injected Timing for Retry Logic

Webhook retry backoff MUST accept an injectable delay provider:

```swift
// Production: exponential backoff
// Test: zero-delay for deterministic execution
let testDelayProvider: (Int) -> Duration = { _ in .zero }
```

This ensures retry tests complete in milliseconds, not seconds.

### Idle Timer Testing (Auto-Assist Chapter 5)

Chapter 5 Auto-Assist triggers after 10 seconds of idle time. Tests MUST:

- Inject a controllable time source (protocol-abstracted `CACurrentMediaTime()` equivalent).
- Advance time programmatically rather than waiting real-time.
- Verify the trigger fires at exactly the threshold, not before.

## Architecture Safety Rules

### Import Restrictions

Test files for logic components MUST NOT import:

- `SwiftUI` — View layer is not under test.
- `SpriteKit` — Scene rendering is not under test.
- `CoreHaptics` — Device-dependent; mock via protocol.
- `AVFoundation` — Hardware-dependent; mock via protocol.

Test files MAY import:

- `XCTest` — Required.
- `Foundation` — Required for `URLProtocol`, `UserDefaults`.
- The app module `@testable import StarlightSync` — Required for access to internal types.

### Test File Organization

```
StarlightSyncTests/
├── Coordinators/
│   └── FlowCoordinatorTests.swift
├── Services/
│   └── WebhookServiceTests.swift
├── Chapters/
│   ├── CipherValidationTests.swift
│   └── AutoAssistTests.swift
├── Models/
│   └── BeatMapTests.swift
└── Helpers/
    ├── MockURLProtocol.swift
    ├── MockHapticPlayer.swift
    ├── MockAudioPlayer.swift
    └── TestUserDefaults.swift
```

**Rules:**

- Test file names MUST end with `Tests.swift`.
- Mock/stub files live in `Helpers/`. One mock per file.
- Test directory structure mirrors the app target structure.
- No test file exceeds 300 lines. Split by scenario group if needed.

### Test Class Structure

Every test class MUST follow this structure:

```swift
import XCTest
@testable import StarlightSync

final class FlowCoordinatorTests: XCTestCase {

    // MARK: - Properties

    private var sut: FlowCoordinator!
    private var testDefaults: UserDefaults!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: #function)
        sut = FlowCoordinator(userDefaults: testDefaults)
    }

    override func tearDown() {
        sut = nil
        testDefaults.removePersistentDomain(forName: #function)
        testDefaults = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_flowCoordinator_firstLaunch_startsAtChapter1() {
        XCTAssertEqual(sut.currentChapter, 1)
    }
}
```

**Rules:**

- System Under Test is named `sut`. Declared as implicitly unwrapped optional (`!`) since `setUp()` guarantees initialization. This is the sole permitted use of `!` in the test target.
- `setUp()` creates fresh instances for every test. No shared mutable state across tests.
- `tearDown()` nils all references and cleans up `UserDefaults` suites.
- `// MARK:` sections enforce consistent structure: Properties, Lifecycle, Tests.

## Workflow

### Step 1: Identify Coverage Gap

Determine which mandatory coverage areas lack tests by cross-referencing the coverage matrix against existing test files.

### Step 2: Scaffold Test File

Create the test file in the correct directory per the organization rules. Apply the class structure template.

### Step 3: Generate Test Methods

For each coverage row, generate a test method following the naming convention. Implement the body with:

1. **Arrange** — Configure mocks, inject dependencies, set initial state.
2. **Act** — Execute the operation under test.
3. **Assert** — Verify the expected outcome with `XCTAssert*` methods.

### Step 4: Wire Mocks

Replace all external dependencies with mocks:

- `URLSession` → `MockURLProtocol`
- `HapticManager` → `MockHapticPlayer` (protocol)
- `AudioManager` → `MockAudioPlayer` (protocol)
- `UserDefaults.standard` → `UserDefaults(suiteName:)`

### Step 5: Verify Determinism

Confirm every test:

- Passes when run in isolation.
- Passes when run as part of the full suite.
- Passes when run in any order (no implicit dependencies).
- Completes within 5 seconds.

### Step 6: Post-Generation Validation

After generating test code, verify against the checklist:

- [ ] Test method names follow `test_<unit>_<scenario>_<expectedResult>` pattern
- [ ] No camelCase test names (e.g., `testSomething` is prohibited)
- [ ] All mandatory coverage rows have corresponding test methods
- [ ] No real network calls (`URLProtocol` stub in place)
- [ ] No `CHHapticEngine` instantiation
- [ ] No real audio playback
- [ ] No `SpriteKit` or `SwiftUI` imports in logic tests
- [ ] `UserDefaults` isolated via `suiteName`
- [ ] All async tests use bounded `XCTestExpectation` (max 5s timeout)
- [ ] No `Task.sleep`, `Thread.sleep`, `DispatchQueue.asyncAfter` in tests
- [ ] `tearDown()` cleans up all state
- [ ] `MockURLProtocol.requestHandler` reset between tests
- [ ] Test file placed in correct directory
- [ ] Test file name ends with `Tests.swift`
- [ ] No force unwraps except `sut` and `testDefaults` declarations
- [ ] No `print` statements in test code
- [ ] No deprecated APIs (`ObservableObject`, `@Published`, Combine)
- [ ] Retry delays are injectable, not hardcoded

If any check fails, fix before declaring the scaffold complete.

## Anti-Patterns (Reject These)

- **Real network calls in tests.** All `URLSession` traffic routes through `MockURLProtocol`.
- **camelCase test names.** `testFlowCoordinatorAdvances` is forbidden. Use `test_flowCoordinator_completeChapter1_advancesToChapter2`.
- **Shared mutable state.** Each test gets fresh instances via `setUp()`. No `static` test fixtures.
- **Sleep-based synchronization.** `Task.sleep`, `Thread.sleep`, and `usleep` are prohibited. Use `XCTestExpectation`.
- **Device-dependent assertions.** Tests must pass on simulator. No `CHHapticEngine`, no `AVAudioSession.sharedInstance()`.
- **Magic numbers in assertions.** Use `GameConstants` values. `XCTAssertEqual(sut.currentChapter, GameConstants.firstChapter)`.
- **Hardcoded webhook URLs.** Use `https://test.invalid/webhook` in all test fixtures.
- **Importing SwiftUI in test files.** Logic tests do not touch the view layer.
- **Testing private methods directly.** Test through public/internal API surface only.
- **Unbounded expectations.** Every `XCTestExpectation` must have a timeout of 5 seconds or less.

## Resources

- **Testing Patterns**: See [references/testing-patterns.md](references/testing-patterns.md) for URLProtocol mocking patterns, async testing strategies, and dependency injection techniques
