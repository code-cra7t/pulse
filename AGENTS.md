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
- Adaptive replanning is advisory: never silently mark a block completed/missed, move a block, or displace work. Every mutation requires an explicit user action.
- Non-flexible tasks may be flagged when their accepted block conflicts, but JotCue must not offer an automatic move suggestion for them.
- Scheduling preferences may sync through the existing user settings document, but calendar event contents must remain local/in-memory.
