# JotCue AI Gateway contract — schema v1

Patch 22 adds an optional Hybrid Ask JotCue transport. The Flutter app never
stores a provider API secret. A production build may configure one HTTPS gateway
URL with:

```bash
flutter build apk --dart-define=JOTCUE_AI_GATEWAY_URL=https://example.com/jotcue/assistant
```

Without this value, or when the URL is invalid, Ask JotCue stays local-only.
Plain HTTP is accepted only for localhost development.

## Request

`POST` JSON:

```json
{
  "schemaVersion": 1,
  "query": "Could you make chapter four urgent?",
  "context": {
    "now": "2026-09-13T21:00:00.000",
    "tasks": [],
    "projects": [],
    "scheduleBlocks": [],
    "summary": {}
  },
  "allowedTools": []
}
```

The context is intentionally bounded. Patch 22 never sends account identity,
Note bodies, source Note IDs or line indexes, reminder text, external calendar
event contents, automation audit data, notification history, or a raw Personal
Graph payload. Task titles and Project names are personal content and are sent
only after the user enables Hybrid mode on that device.

The gateway should enforce its own authentication/app-attestation strategy,
rate limits, abuse controls, provider credentials, logging policy, and data
retention policy. Those server responsibilities are not implemented by the
Flutter client.

## Response

The response must be a JSON object smaller than 64 KiB. It may contain prose:

```json
{
  "answer": "You have two blockers before the application can move forward."
}
```

or an allow-listed tool suggestion:

```json
{
  "toolCall": {
    "name": "task.set_priority",
    "arguments": {
      "taskId": "task-id",
      "priority": "critical"
    }
  }
}
```

Patch 22 allows exactly these tool names:

- `task.set_completion` — `taskId`, `completed`
- `task.set_priority` — `taskId`, `priority`
- `schedule.move_block` — `blockId`, `startsAt`

The server must not assume a returned tool call will execute. Flutter treats the
response as untrusted input, resolves IDs against current local state, rebuilds
an `AskJotCueActionProposal`, applies the existing automation permission policy,
and requires the same explicit Apply step as deterministic Ask JotCue actions.
Calendar-linked moves and stale/unavailable schedule targets still fail closed
inside the local executor.

Unknown tools, malformed arguments, invalid/stale IDs, oversized responses,
timeouts, and non-success HTTP responses produce no mutation.
