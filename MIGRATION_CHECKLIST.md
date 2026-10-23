# Migration checklist — ChatGPT to Codex

## Before Codex
- [ ] Make a full backup of the current Godot project.
- [ ] Preferably initialize/confirm Git.
- [ ] Commit the current known-working state before Codex edits.
- [ ] Copy this entire handoff package into the project root, preserving `harness/`.
- [ ] Confirm `AGENTS.md` is at the same repository root as `project.godot`.

## In Codex
- [ ] Open the whole project/repository folder.
- [ ] Use the first prompt in `CODEX_START_HERE.md`.
- [ ] Require a read-only continuity report before first edit.
- [ ] Compare its understanding against `PROJECT_HANDOFF.md`.
- [ ] Then authorize QA-COOP-01 Phase A.

## During implementation
- [ ] Keep changes small.
- [ ] Review diff.
- [ ] Reject production-network refactors without concrete evidence.
- [ ] Run real PC Host + Android validation.
- [ ] Record PASS/FAIL evidence.

## After each validated phase
- [ ] Commit/tag stable point.
- [ ] Update `harness/build-log.md`.
- [ ] Update `CURRENT_TASK.md`.
- [ ] Update `PROJECT_HANDOFF.md` if milestone status changed.
- [ ] Leave QA runners OFF by default.

## After B1.2 PASS
- [ ] Create fresh complete backup.
- [ ] Record commit/tag/backup name.
- [ ] Move to B2 Mobile Controls / UX.
