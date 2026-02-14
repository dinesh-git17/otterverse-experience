# Webhook Security Patterns

Reference documentation for XOR encoding procedures, repository scan patterns, retry isolation, and test strategies.

## XOR Encoding Procedure

### Encoding a Webhook URL

Given a raw URL string and a chosen `UInt8` XOR key:

```
Input:  "https://discord.com/api/webhooks/123456/abcdef"
Key:    0x5A

Step 1: Convert to UTF-8 bytes
  [0x68, 0x74, 0x74, 0x70, 0x73, ...]

Step 2: XOR each byte with key
  [0x68 ^ 0x5A, 0x74 ^ 0x5A, ...] = [0x32, 0x2E, ...]

Step 3: Store as [UInt8] array literal
  private let obfuscatedURL: [UInt8] = [0x32, 0x2E, ...]

Step 4: Store key inline
  private let xorKey: UInt8 = 0x5A
```

### Decoding at Runtime

```swift
guard let url = String(bytes: obfuscatedURL.map { $0 ^ xorKey }, encoding: .utf8) else {
    return
}
// Use url immediately. Do not store in a property.
```

### Key Selection

- Any `UInt8` value (0x01–0xFF) is valid.
- Avoid 0x00 (no-op XOR).
- Key does not need to be cryptographically random — this is obfuscation, not encryption.
- One key per encoded secret. Multiple secrets MAY share a key.

### Round-Trip Verification

After encoding, verify: `encoded.map { $0 ^ key }` produces the original UTF-8 bytes. XOR is its own inverse: `(a ^ k) ^ k == a`.

---

## Repository Scan Patterns

### Discord Webhook URL Regex

```regex
https?://(discord\.com|discordapp\.com)/api/webhooks/[0-9]+/[A-Za-z0-9_\-]+
```

Matches both `discord.com` and legacy `discordapp.com` domains.

### Partial Fragment Detection

```regex
discord(app)?\.com/api/webhooks
```

Catches incomplete URLs, URL construction via concatenation, and comment references.

### Secret Logging Detection

```regex
(print|NSLog|debugPrint|dump|Logger)\s*[\.(]\s*.*(webhook|discord|obfuscated|xorKey|decoded.*url)
```

Catches any logging call that references webhook-related identifiers.

### High-Entropy String Detection

```regex
["'][A-Za-z0-9_\-]{40,}["']
```

Flags suspiciously long alphanumeric string literals that may be API tokens or webhook URL fragments stored as raw strings.

### Exclusion Rules

Files excluded from scan:

- `CLAUDE.md` — governance rules reference patterns as examples
- `Design-Doc.md` — architecture spec references patterns as examples
- `.claude/skills/*/SKILL.md` — skill definitions reference patterns as rules
- `.claude/skills/*/references/*.md` — skill references define detection patterns

---

## Retry Policy Reference

### Timing Table

| Attempt | Action                      | Cumulative Time |
| ------- | --------------------------- | --------------- |
| 1       | Immediate POST              | 0s              |
| —       | Wait 1s                     | 1s              |
| 2       | Retry POST                  | 1s              |
| —       | Wait 2s                     | 3s              |
| 3       | Final retry POST            | 3s              |
| —       | All failed → silent discard | 3s+             |

### Formula

```
delay(n) = baseInterval * 2^(n-1)
  where baseInterval = 1 second
  and n = retry number (1-indexed, starting after first failure)
```

### Test Injection

For unit tests, backoff intervals MUST be injectable to avoid real delays:

```swift
// Production
WebhookService(retryIntervals: [1.0, 2.0])

// Test
WebhookService(retryIntervals: [0.0, 0.0])
```

Use `URLProtocol` stubs to intercept `URLSession` requests. No real network calls in tests. Mock URL: `https://test.invalid/webhook`.

---

## Test Isolation Strategies

### URLProtocol Stub

All webhook tests MUST use `URLProtocol`-based mocking:

1. Subclass `URLProtocol`
2. Override `canInit(with:)` to intercept webhook requests
3. Override `startLoading()` to return configured response/error
4. Register before test, unregister in `tearDown()`

### Response Simulation

| Scenario        | Simulated Response                  |
| --------------- | ----------------------------------- |
| Success         | HTTP 204 No Content                 |
| Server error    | HTTP 500 Internal Server Error      |
| Rate limited    | HTTP 429 Too Many Requests          |
| Network failure | `URLError(.notConnectedToInternet)` |
| Timeout         | `URLError(.timedOut)`               |

### Test Naming Convention

```
func test_webhookService_<scenario>_<expectedResult>()
```

Examples:
- `test_webhookService_successfulPost_completesWithoutRetry()`
- `test_webhookService_networkFailure_retriesThreeTimes()`
- `test_webhookService_allRetriesFail_silentlyDiscards()`
- `test_webhookService_fire_doesNotBlockMainThread()`
- `test_webhookService_payloadEncoding_matchesContract()`

---

## Threat Model Summary

| Threat                     | Likelihood | Impact         | Mitigation                         |
| -------------------------- | ---------- | -------------- | ---------------------------------- |
| URL extraction from binary | Low        | Channel spam   | XOR obfuscation (accepted risk)    |
| Plaintext URL in source    | Medium     | Repo exposure  | Pre-commit scan, skill enforcement |
| URL logged at runtime      | Medium     | Log exposure   | Logging prohibition, scan detection|
| Webhook blocks UI          | Medium     | UX degradation | Fire-and-forget, no await          |
| Retry storm on rate limit  | Low        | API abuse      | 3 attempt cap, exponential backoff |
| Payload tampering          | None       | N/A            | Static payload, no user input      |
