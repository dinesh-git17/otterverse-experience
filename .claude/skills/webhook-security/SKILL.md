---
name: webhook-security
description: Enforce webhook architecture security including XOR-encoded secret storage, strict POST payload contract, exponential backoff retry policy, fire-and-forget execution model, and repository-wide plaintext secret scanning for WebhookService implementation. Use when WebhookService is created or modified, network logic is implemented, Chapter 6 completion logic is added, secret encoding or rotation is requested, or repository security scan is run. Triggers on webhook implementation, secret handling, retry logic, network isolation, payload contract, or security audit operations.
---

# Webhook Security

Deterministic enforcement of the project's webhook architecture covering XOR-encoded secret storage, Discord POST payload contract, exponential backoff retry policy, fire-and-forget execution model, and repository-wide plaintext secret scanning as defined in `Design-Doc.md` §9.1–§9.5, §11.4, and `CLAUDE.md` §5.

## Pre-Implementation Verification

Before generating or modifying webhook or network code, verify:

1. The target component is `WebhookService` at `Services/WebhookService.swift`.
2. No direct `URLSession` usage exists outside `WebhookService`.
3. No plaintext Discord webhook URLs exist anywhere in the repository.

If any verification fails, **HALT** and cite the conflict.

## Workflow

### Step 1: Determine Task Type

Identify the scope of work:

**Implementing WebhookService?** → Follow Full Implementation Workflow
**Modifying retry logic?** → Follow Retry Policy Workflow
**Adding or rotating secrets?** → Follow Secret Management Workflow
**Integrating webhook into Chapter 6?** → Follow Finale Integration Workflow
**Running security scan?** → Follow Repository Scan Workflow

---

### Full Implementation Workflow

#### Phase 1: Secret Storage

`WebhookService` MUST store the Discord webhook URL as an XOR-encoded `[UInt8]` byte array with a compile-time `UInt8` XOR key. The decoded URL is reconstructed at runtime only at the call site.

```
1. Store webhook URL as private let obfuscatedURL: [UInt8] = [...]
2. Store XOR key as private let xorKey: UInt8 = <value>
3. Decode at call site: String(bytes: obfuscatedURL.map { $0 ^ xorKey }, encoding: .utf8)
4. Never persist, cache, log, or retain the decoded string beyond immediate use
```

**Secret storage invariants:**

- The `[UInt8]` array and `UInt8` key are the ONLY permitted storage form in source code.
- No plaintext URL string literals anywhere in the repository.
- No string interpolation producing the URL.
- No `UserDefaults`, `Info.plist`, `.env`, or keychain storage of the URL.
- No logging of the decoded URL at any level (including `os.Logger`, `#if DEBUG`).
- No inclusion of the URL in comments, documentation, or test fixtures.

#### Phase 2: POST Contract

The webhook payload is static and immutable:

```json
{ "content": "@everyone SHE SAID YES! ❤️" }
```

**Contract enforcement:**

- HTTP method: `POST` only. No `GET`, `PUT`, `PATCH`, `DELETE`.
- Header: `Content-Type: application/json` required.
- Body: Exactly `{"content": "@everyone SHE SAID YES! ❤️"}` — no additional fields, no dynamic content, no variable substitution.
- JSON encoding: Use `JSONEncoder` or `JSONSerialization`. Validate encoding produces the exact expected payload.
- No alternate message formats, no conditional payloads, no user-generated content.

#### Phase 3: Network Execution

```swift
// Conceptual structure — not literal code
func fire() {
    Task {
        await executeWithRetry()
    }
}
```

- `fire()` is synchronous from the caller's perspective. The `Task` runs independently.
- The caller (Chapter 6 completion handler) MUST NOT `await` the webhook call.
- `URLSession.shared.data(for:)` executes off the main actor within the `Task`.
- No `@MainActor` isolation on the network call itself.
- The `Task` captures no UI state. Failure does not mutate any `@Observable` property visible to views.

#### Phase 4: Retry Logic

Exponential backoff with deterministic intervals:

| Attempt | Delay Before Attempt | Interval Formula |
| ------- | -------------------- | ---------------- |
| 1       | 0s (immediate)       | —                |
| 2       | 1s                   | `1 * 2^0`        |
| 3       | 2s                   | `1 * 2^1`        |

**After attempt 3 fails → silent discard. No further retries.**

**Retry rules:**

- Maximum 3 attempts total (1 initial + 2 retries).
- Backoff intervals: 1s, 2s (exponential, base 1s, factor 2).
- Use `Task.sleep(for: .seconds(n))` for delay between retries within the unstructured `Task`.
- No jitter required (single client, single endpoint, no thundering herd risk).
- Retry on any non-2xx HTTP status code or network error.
- No retry on successful 2xx response.
- Backoff intervals MUST be injectable for testing (default parameter or protocol).

#### Phase 5: Failure Isolation

**Failure MUST NOT propagate beyond `WebhookService`:**

- No `throws` on public API. Errors caught internally.
- No error callbacks, delegates, or published error state.
- No UI alerts, banners, or visual indicators of webhook failure.
- No blocking of chapter progression, animation, audio, or confetti.
- `FlowCoordinator` state is unaffected by webhook success or failure.
- Auto-Assist logic is unaffected by webhook state.

**Failure output:** Silent discard. Log via `os.Logger` under `#if DEBUG` only.

---

### Retry Policy Workflow

When modifying retry logic, enforce these invariants:

1. Maximum 3 attempts. No configurable maximum beyond 3.
2. Exponential backoff: 1s → 2s. No linear, no fixed delay.
3. After final failure: silent discard. No escalation.
4. Intervals injectable for testing (zero-delay in test harness).
5. No `Timer`, `DispatchQueue.asyncAfter`, or `DispatchQueue` usage. Use `Task.sleep(for:)`.
6. No `Thread.sleep`. No GCD. No Combine delay operators.
7. Retry loop runs within the same unstructured `Task` — no nested task spawning.

---

### Secret Management Workflow

#### Encoding a New URL

```
1. Obtain the raw Discord webhook URL
2. Choose a UInt8 XOR key (or reuse existing)
3. Convert URL string to UTF-8 bytes
4. XOR each byte with the key to produce [UInt8] array
5. Replace the obfuscatedURL array in WebhookService.swift
6. Verify round-trip: decoded bytes produce the original URL
7. Destroy the plaintext URL from all local files, clipboard, shell history
```

#### Rotation

Per `Design-Doc.md` §9.5:

1. Generate new webhook URL in Discord Server Settings.
2. XOR-encode with existing or new key.
3. Replace `[UInt8]` array in `WebhookService.swift`.
4. Archive and distribute new TestFlight build.
5. Invalidate old webhook URL in Discord admin panel.

#### Verification

After any secret change:

- Run repository scan (see Repository Scan Workflow).
- Confirm no plaintext URL patterns in any tracked file.
- Confirm decoded URL produces a valid `https://discord.com/api/webhooks/` prefix.

---

### Finale Integration Workflow

Chapter 6 completion triggers three parallel systems simultaneously:

```
User slides "Slide to Confirm" handle to 100%
  ├── 1. WebhookService.fire()          ← fire-and-forget
  ├── 2. AudioManager.playFinale()      ← instant, pre-loaded
  └── 3. ConfettiView triggered         ← immediate animation
```

**Integration rules:**

- `WebhookService.fire()` is called from `FlowCoordinator` context.
- The call is NOT awaited. It returns immediately.
- Animations, audio, and confetti start in the same run loop iteration.
- Network latency, retry delays, and failures are invisible to the user.
- The slider completion UI feedback (haptics, visual state change) fires before the webhook call.
- No conditional logic: "if webhook succeeds, then play song." The song plays unconditionally.

**Prohibited patterns in Chapter 6 integration:**

- `await webhookService.fire()` — blocks the caller.
- `if try await webhookService.send() { playSong() }` — gates UI on network.
- Showing a loading spinner or progress indicator for webhook delivery.
- Disabling the slider until webhook confirms delivery.
- Retry UI (e.g., "Failed to send, try again?").

---

### Repository Scan Workflow

Scan the entire repository for plaintext secret leakage.

#### Scan Targets

All tracked files: `.swift`, `.md`, `.txt`, `.json`, `.yaml`, `.yml`, `.plist`, `.ahap`, `.strings`

#### Detection Patterns

**Discord webhook URLs (BLOCKING):**

```
https://discord\.com/api/webhooks/[0-9]+/[A-Za-z0-9_-]+
https://discordapp\.com/api/webhooks/[0-9]+/[A-Za-z0-9_-]+
```

**Partial URL fragments (BLOCKING):**

```
discord\.com/api/webhooks
discordapp\.com/api/webhooks
```

**Logged secrets (BLOCKING):**

```
print.*webhook
print.*url.*discord
Logger.*webhook.*url
log.*webhook.*decoded
```

**Hardcoded URL strings (BLOCKING):**

```
"https://discord.com/api/webhooks" as a String literal in .swift files
```

#### Allowed Exceptions

- XOR-encoded `[UInt8]` byte arrays in `WebhookService.swift`.
- Governance documents (`CLAUDE.md`, `Design-Doc.md`, `SKILL.md`) that reference patterns as rules.
- Test fixtures using `https://test.invalid/webhook` as the mock URL.
- Pre-commit auditor patterns that define detection regex.

#### Scan Report

```
WEBHOOK SECURITY SCAN: PASS
  Scanned: <N> files
  Violations: 0
  Status: CLEAN

WEBHOOK SECURITY SCAN: FAIL
  Scanned: <N> files
  Violations: <N>

  [SL-WEBHOOK] Plaintext webhook URL detected
    <file>:<line> — <matched pattern>

  Status: BLOCKED — remove plaintext secrets before commit
```

---

## Structural Constraints

### Singleton Pattern

```swift
@MainActor
@Observable
final class WebhookService {
    static let shared = WebhookService()
    private init() { /* XOR arrays initialized */ }
}
```

- `@MainActor` isolation for coordinator access.
- `@Observable` only if state exposure is required (not typical).
- `private init` prevents additional instances.
- No `ObservableObject`, no `@Published`, no Combine.

### Method Signatures

Public API surface MUST be minimal:

```swift
func fire()
```

- `fire()` — synchronous entry point. Spawns unstructured `Task` internally.
- No return value. No `throws`. No `async`.
- No public access to `URLSession`, URL construction, or retry state.
- Internal retry count, backoff state, and decoded URL are `private`.

### Component Boundary

| Caller            | May Call `WebhookService`?   |
| ----------------- | ---------------------------- |
| `FlowCoordinator` | YES — sole authorized caller |
| Chapter Views     | NO                           |
| `SKScene`         | NO                           |
| `AudioManager`    | NO                           |
| `HapticManager`   | NO                           |
| Test harness      | YES — via injected protocol  |

### Error Handling

- All `try` calls on `URLSession` wrapped in `do/catch`.
- Catch blocks: log via `os.Logger` under `#if DEBUG`, continue retry loop or discard.
- No `try!` on network operations.
- `try?` permitted only where the discarded error is the final retry failure.

### Naming

| Element           | Name                           |
| ----------------- | ------------------------------ |
| Singleton         | `WebhookService.shared`        |
| Fire method       | `fire()`                       |
| Obfuscated URL    | `obfuscatedURL`                |
| XOR key           | `xorKey`                       |
| Retry count       | `maxRetryCount`                |
| Backoff intervals | `retryIntervals`               |
| Test mock URL     | `https://test.invalid/webhook` |

---

## Anti-Patterns (Reject These)

- **Plaintext webhook URL in source code.** XOR-encoded `[UInt8]` array is the only permitted form.
- **Awaiting `fire()` from the caller.** Webhook is fire-and-forget. The caller never waits.
- **Gating Chapter 6 UI on webhook success.** Animation, audio, and confetti are unconditional.
- **Logging the decoded webhook URL.** Not even under `#if DEBUG`.
- **Retrying more than 3 times.** Three attempts, then silent discard.
- **Using `Timer` or `DispatchQueue` for retry delays.** Use `Task.sleep(for:)`.
- **Exposing webhook errors to UI.** No alerts, banners, or error state in views.
- **Direct `URLSession` calls outside `WebhookService`.** All network routes through `WebhookService`.
- **Dynamic payload content.** The payload is static: `{"content": "@everyone SHE SAID YES! ❤️"}`.
- **Storing the decoded URL in a property.** Decode at call site, use immediately, let it go out of scope.
- **Using `ObservableObject` or `@Published` on `WebhookService`.** Use `@Observable`.
- **Using Combine for retry or delay logic.** Use `async/await` with `Task.sleep(for:)`.
- **Using `DispatchQueue` or GCD for background execution.** Use unstructured `Task`.
- **Including real Discord webhook URLs in test fixtures.** Use `https://test.invalid/webhook`.
- **`print()` for webhook debug logging.** Use `os.Logger` under `#if DEBUG`.

## Post-Implementation Validation

After implementing or modifying webhook code, verify:

- [ ] Webhook URL stored as XOR-encoded `[UInt8]` with `UInt8` key only
- [ ] No plaintext webhook URLs in any repository file
- [ ] Decoded URL never logged, persisted, cached, or retained
- [ ] POST payload is exactly `{"content": "@everyone SHE SAID YES! ❤️"}`
- [ ] No additional fields in payload
- [ ] Retry policy: 3 attempts, exponential backoff (1s, 2s)
- [ ] Silent discard after final failure
- [ ] `fire()` is non-blocking — caller never awaits
- [ ] No UI impact on webhook failure (animations, audio, confetti unaffected)
- [ ] `FlowCoordinator` is the sole caller of `WebhookService.fire()`
- [ ] No direct `URLSession` usage outside `WebhookService`
- [ ] No `throws` on public API
- [ ] Backoff intervals injectable for testing
- [ ] Test fixtures use `https://test.invalid/webhook` only
- [ ] No Combine, no GCD, no `ObservableObject`
- [ ] No `print()` statements (use `os.Logger` under `#if DEBUG`)
- [ ] No force unwraps on URL decoding or network response handling
- [ ] Chapter 6 finale fires webhook, audio, and confetti in parallel — none gated on another

## Resources

- **References**: See [references/security-patterns.md](references/security-patterns.md) for XOR encoding procedures, scan patterns, and test isolation strategies
