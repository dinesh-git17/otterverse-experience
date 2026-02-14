# Story Decomposition Patterns

Strategies for splitting epics into vertically-sliced, INVEST-compliant stories.

## Splitting Strategies

### 1. Workflow Steps

Split along sequential user or system actions.

**When:** A process has distinct phases (input, processing, output, confirmation).

**Example:** Publishing flow becomes: direct publish, editor review queue, legal review gate, staging preview, production deploy.

### 2. Operations (CRUD)

Split "manage X" into discrete operations.

**When:** The epic verb is "manage", "handle", or "support".

**Example:** "Manage user profile" becomes: create profile, view profile, edit profile, delete profile.

### 3. Business Rule Variations

Same feature, different rules applied.

**When:** Logic branches based on context, user type, or configuration.

**Example:** "Flexible date search" becomes: exact date, date range, relative dates (+/- N days), weekends only.

### 4. Data Variations

Start with one data type, expand later.

**When:** Multiple data sources or formats feed the same pipeline.

**Example:** "Geographic search" becomes: search by country, then by city, then by neighborhood.

### 5. Major Effort First

Isolate infrastructure-heavy first slice from trivial subsequent slices.

**When:** The first implementation requires architectural investment; additional instances are incremental.

**Example:** "Support payment methods" becomes: credit card (full payment infra), then debit card (trivial delta), then Apple Pay (integration delta).

### 6. Simple Then Complex

Core path first, edge cases later.

**When:** A feature has a clean happy path with complex edge cases.

**Example:** "Search flights" becomes: basic one-way search, then add max-stops filter, then add nearby airports, then add flexible dates.

### 7. Defer Performance

Make it work, then make it fast.

**When:** Correctness can be validated independently of performance.

**Example:** "Display search results" becomes: show results (any latency), then optimize to sub-200ms P95.

### 8. Spike Then Implement

Timebox investigation before committing to implementation.

**When:** Uncertainty is high — unknown API behavior, unclear feasibility, or multiple viable approaches.

**Example:** "Integrate haptic feedback" becomes: spike on CHHapticEngine capabilities (2 days), then implement pattern playback.

### 9. Interface Boundaries

Split at system integration points.

**When:** The epic crosses component or service boundaries.

**Example:** "Add audio to chapter transitions" becomes: define audio event protocol, implement AudioManager playback, wire FlowCoordinator triggers.

## Quality Checks

Every story produced by these patterns must pass:

| Criterion       | Test                                                        |
| --------------- | ----------------------------------------------------------- |
| **Independent** | Can be built and deployed without other stories in progress |
| **Negotiable**  | Implementation approach has flexibility                     |
| **Valuable**    | Delivers observable user or system value                    |
| **Estimable**   | Team can size it relative to other stories                  |
| **Small**       | Fits within a single sprint or work cycle                   |
| **Testable**    | Has concrete, verifiable acceptance criteria                |

## Vertical Slicing Rule

Every story must touch multiple architectural layers and produce an observable result. Reject horizontal stories that deliver infrastructure without a consuming feature.

**Valid:** "Add heartbeat haptic feedback on chapter completion" (touches HapticManager, FlowCoordinator, chapter view)

**Invalid:** "Set up haptic engine" (infrastructure-only, no observable user value)
