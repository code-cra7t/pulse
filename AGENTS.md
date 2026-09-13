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
- Scheduling proposals are suggestions only. Never write accepted work blocks to the external calendar unless a later patch explicitly introduces calendar-write approval.
- Accepted JotCue schedule blocks are device-local until cross-device scheduling conflict semantics are designed.
- Scheduling preferences may sync through the existing user settings document, but calendar event contents must remain local/in-memory.
