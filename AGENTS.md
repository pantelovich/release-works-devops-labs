# Steady Deploy repository instructions

- Before work, explicitly read the canonical local handoff file at `../coventry-release-works/docs/agent-coordination.md` from this repo root. Codex owns assignment and integration. Log starts, blockers and handovers with its scripts/agent_update.py helper.
- Copilot edits only its assigned file in its separate worktree. Stop edits if the canonical file is unavailable. Worktrees do not isolate Docker or cloud resources.

- Deliver one reviewable change at a time. Use branches prefixed with `codex/` for agent changes after the initial setup.
- Use [docs/agents.md](docs/agents.md) for Ruflo routing and review ownership.
- Preserve the distinction between internal practice, approved pro bono work and paid client work.
- Keep real client data, account identifiers and credentials out of practice materials.
- Validate changes with the checks in the README. Record an architecture decision for changes that affect service scope or lab implementation.
