# CODEX — START HERE

This repository is being transferred from an extended ChatGPT-assisted Godot development session.

The repository is the source of truth.
These Markdown files preserve decisions, validation history and current direction.

## Required reading order
1. `AGENTS.md`
2. `PROJECT_HANDOFF.md`
3. `CURRENT_TASK.md`
4. actual current Godot project

Do not start by rewriting code.

## First message for the new Codex chat

You are continuing development of AbyssPrototype, a Godot 4.7.2 project.

Before modifying anything:

1. Read the applicable `AGENTS.md`.
2. Read `PROJECT_HANDOFF.md` completely.
3. Read `CURRENT_TASK.md`.
4. Perform a read-only inspection of the actual repository, especially the files and scene nodes relevant to the current task.
5. Treat repository contents as the source of truth and the handoff as historical/decision context.
6. Do not make changes yet.

Then return a continuity report containing:
- current project state;
- CLOSED systems that must not be reopened without evidence;
- current roadmap position;
- open/deferred issues;
- files/nodes relevant to the next task;
- mismatches between repository state and handoff;
- exact implementation plan for QA-COOP-01 Phase A;
- acceptance criteria.

Current goal: QA-COOP-01, automate the real PC Host Player for cooperative QA while I manually control the Android client.

Do not implement until you have completed this discovery pass.

## Second message, after the continuity report
If its understanding is correct:

`Implement QA-COOP-01 Phase A according to CURRENT_TASK.md. Keep the change isolated to QA infrastructure, run any local/static checks you can, and tell me exactly how to configure and execute the PC Host + Android validation.`

## After every validated phase
Ask Codex to:
1. update `harness/build-log.md`;
2. update `CURRENT_TASK.md`;
3. update `PROJECT_HANDOFF.md` only if project-level status/decisions changed;
4. state the exact next test;
5. keep QA runners OFF by default after validation.

## Stable checkpoint
After B1.2 passes:
- create a new backup / Git tag / commit;
- record the identifier in the handoff;
- then begin B2 Mobile Controls / UX.
