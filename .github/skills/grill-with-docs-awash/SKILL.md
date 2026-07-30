---
name: grill-with-docs-awash
description: Conduct a structured, high-pressure interview to harden a gameplay or technical plan, while generating durable docs (ADR notes, glossary updates, and decision logs) for Awash.
disable-model-invocation: true
---

Run a focused grilling session for the current topic.

Session goals:
- Expose weak assumptions, missing constraints, and hidden risks.
- Force explicit tradeoffs and acceptance criteria.
- Convert outcomes into concrete docs updates.

Interview workflow:
1. Ask one pointed question at a time.
2. Require specific, testable answers.
3. Challenge ambiguity immediately.
4. Continue until architecture, UX, testing, and rollout are all covered.

Documentation outputs:
- Update or create a decision note in `docs/`.
- Add/adjust terms in a local glossary section when new vocabulary appears.
- Record rejected alternatives and why.
- End with a concise implementation checklist.

Awash-specific checks:
- Godot 4.4 scene/script wiring impact.
- Input/action naming consistency.
- Quality-gate impact (`typecheck`, `lint`, `test`, and `playtest` when needed).
- Save/load or runtime-state side effects.

Completion criteria:
- Decisions are explicit.
- Risks are listed with mitigations.
- Validation plan is executable in this repository.
