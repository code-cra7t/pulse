# JotCue AI Context

You are a senior Flutter engineer working on JotCue.

Stack:
- Flutter (multi-platform)
- Firebase Auth / Firestore / Storage
- Riverpod
- Sembast offline-first local persistence

Current product surfaces:
- Notes (existing visual layout is protected)
- Embedded note tasks with stable identities
- Reminders (manual + smart)
- Plan (projects + task planning metadata)
- Pulse (deterministic daily focus and attention cues)
- Ask JotCue (deterministic read-only assistant over the current plan)
- Personal Graph (derived local relationships across notes, tasks, projects, deadlines, and accepted schedule blocks)
- External text sharing into the review-first Quick Capture flow (Android)
- Suggested scheduling (explicit availability + local calendar busy time + user-approved device-local blocks)
- Adaptive replanning (reviewable drift/conflict/deadline-capacity suggestions)
- Settings / profile

Rules:
- Keep code simple and scoped.
- Do not block the UI.
- Match the existing architecture and visual language.
- The current Notes cards, editor layout, color tags, and reminder access must not be redesigned unless a task explicitly requires it.
- Visible note content remains the source of truth for note-backed task text and completion.
- Planning metadata must not rewrite visible note text.
- Prefer deterministic planning logic before introducing AI-generated decisions.
- Ask JotCue v1 is read-only, on-device, and ephemeral: no LLM/network calls, persisted chat history, or mutations from conversation.
- Do not introduce a fixed bot-face avatar for Ask JotCue; use JotCue brand language until a later personalized assistant-identity system is explicitly designed.
- Preserve offline-first behavior.
- Do not deploy Firebase rules unless explicitly instructed.

Always:
- Explain the intended change before coding.
- Only modify necessary files.
- Run formatter, analyzer, Flutter tests, relevant Firebase rule tests, and a debug Android build before declaring a patch verified.

Calendar / availability rules:
- External calendar reads are opt-in and local-only by default; do not upload or persist third-party event contents unless a later task explicitly introduces a privacy-reviewed sync design.
- Treat external calendar events as fixed busy-time inputs, not JotCue-owned events.
- Keep calendar reading separate from existing reminder calendar export/linking behavior.
- Availability calculation must stay deterministic and accept explicit planning windows; do not assume a user's waking or working hours.
- Device calendar reads must stay bounded to near-term ranges (currently at most 31 days).
- Scheduling proposals are suggestions only. External calendar writes require explicit user confirmation and calendar-write permission; never write or update schedule entries silently.
- Schedule-block calendar links must remain separate from reminder calendar links and may only own events created for that exact JotCue block.
- Rescheduling a linked block must not silently update the external calendar; offer an explicit update choice.
- Accepted JotCue schedule blocks are device-local until cross-device scheduling conflict semantics are designed.
- Adaptive replanning is advisory by default. Never silently mark a block completed/missed. Trusted execution may move only one future flexible device-local proposal block at a time while Plan is open, only after the stored automation policy returns trustedEligible, only when the block is not linked to an external calendar, and only from a fresh deterministic suggestion. Recompute before any next move.
- Non-flexible tasks may be flagged when their accepted block conflicts, but JotCue must not offer an automatic move suggestion for them.
- Scheduling preferences may sync through the existing user settings document, but calendar event contents must remain local/in-memory.


External-context rules:
- Android text shares are review inputs only. Receiving shared content must not create or persist a note, task, project, reminder, or calendar entry without explicit user confirmation.
- Keep share ingestion local and transient until the user confirms a save/create action. Do not upload shared content merely because another app sent it to JotCue.
- Reuse the existing Quick Capture parser/service rather than creating a second task/project source of truth.
- External API integrations (Gmail, Google Calendar cloud APIs, etc.) require separate privacy/scoping work and must not be smuggled into share-intent patches.

Trusted automation rules:
- Trusted execution is foreground-only in this version; do not add background workers or timers.
- Only AutomationActionKind.localScheduleMove is trusted-eligible. External calendar writes, work review decisions, and structured capture creation always require approval.
- Trusted moves must fail closed when calendar-link state cannot be verified, when the source block is stale, when the task is missing/non-flexible/completed, or when the block was user-created.
- Execute at most one move per replanning snapshot, then recompute availability/replanning before considering another.
- Every successful trusted move must be appended to the device-local automation audit store. Do not upload the audit trail unless a later privacy-reviewed design explicitly introduces sync.

## Patch 17 trusted-automation safety guardrails
- Keep the account-wide automation level separate from device-local trusted-execution safety controls.
- Trusted execution must fail closed when local safety state, audit history, or calendar-link state cannot be verified.
- Respect device-local pause, task exclusions, project exclusions, and the per-block cooldown before any trusted move.
- Never auto-move a calendar-linked block, past block, non-flexible task, user-created block, or stale schedule snapshot.
- Undo is user-initiated only. It must reject stale/currently changed blocks, linked calendar copies, past original slots, and conflicting original slots.
- Audit cleanup must preserve pending/undo-pending entries and any applied move/undo still inside the cooldown window.
- Do not broaden Trusted to calendar writes, capture creation, completion/missed decisions, or background execution without a separately reviewed patch.

## Patch 18 proactive-attention guardrails
- Keep attention notifications separate from reminder alarms and their IDs/channels.
- Attention decisions remain deterministic/local; do not add LLM or engagement-style notifications.
- Respect the account notification master switch plus device-local attention preferences and quiet hours.
- Notification taps may navigate to Pulse or Plan only; they must not mutate tasks, schedule blocks, reminders, or calendars.
- Throttle unchanged schedule-attention signatures and cap imminent deadline cues.
- Do not introduce a background task executor as part of proactive attention.

## Patch 19 personal-graph guardrails
- The Personal Graph is a derived local read model, never a second source of truth.
- Build graph nodes/edges only from existing Notes, stable Tasks, Projects, deadlines, and accepted schedule blocks.
- Do not persist or sync the graph as a separate dataset in this patch.
- Broken references must fail visibly as integrity issues; never invent missing Notes, Projects, Tasks, or schedule relationships.
- Reserved graph node types such as person, decision, and event are schema placeholders only until a later reviewed extraction/design patch populates them.
- Relationship UI must remain secondary to the existing Notes/Plan experience and must not redesign Notes.
