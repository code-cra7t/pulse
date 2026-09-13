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
