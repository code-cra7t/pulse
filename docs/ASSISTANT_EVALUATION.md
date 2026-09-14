# Assistant Evaluation and Hardening

Patch 33 adds a repeatable safety-focused evaluation gate for Ask JotCue before
assistant autonomy is broadened further.

## Run the focused evaluation

```bash
flutter test test/assistant_evaluation_test.dart
```

The evaluation uses the real deterministic assistant, Hybrid routing/tool
adapter, account guard, action executor, and multi-step plan executor. It does
not call a live AI service.

## Scenario coverage

The curated Patch 33 suite covers ambiguous and similarly named Tasks/Projects,
exact stable-ID target resolution, deadline changes, invalid dependencies and
blockers, impossible schedules, stale/deleted targets, account switching,
mixed-account context, unavailable Hybrid service, unsupported/malicious Hybrid
tools, stale Hybrid tool targets, valid allow-listed Hybrid proposals,
timezone-offset schedule proposals, clock advancement between preview and
Apply, calendar-linked schedule blocks, availability changes, multi-action
partial failure, and account switching between multi-step actions.

Existing focused unit suites remain authoritative for lower-level parser,
reasoning, storage, synchronization, calendar, policy, and platform behavior.
The Patch 33 evaluation is deliberately cross-cutting: it checks that those
layers compose safely in realistic assistant scenarios.

## Scorecard

Each focused run prints intent/action accuracy, target-resolution accuracy,
wrong-action rate, false-positive mutation rate, best-next-action quality, safe
Hybrid/local fallback behavior, observed local scenario latency, and observed
Hybrid/fallback scenario latency.

Latency numbers are observational test-harness measurements, not production
SLAs. A five-second per-scenario ceiling exists only to catch hangs or accidental
network-like blocking in this deterministic test suite.

## Patch 33 release gates

The curated suite must meet all of these gates:

- intent/action accuracy: 100%
- target-resolution accuracy: 100%
- wrong-action rate: 0%
- false-positive mutation rate: 0%
- best-next-action quality: 100%
- fallback safety: 100%
- silent incorrect mutations: **zero**

A safe refusal or abstention is preferred to guessing. A failed or stale action
must not be counted as a successful mutation. Multi-step execution must report
partial success honestly and stop remaining steps after a failure.

The focused evaluation supplements rather than replaces `flutter analyze`,
`flutter test`, the Firestore emulator suites, and the platform build gates used
by the broader release process.
