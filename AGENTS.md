# AbyssPrototype — Repository Instructions

## Read before editing
Before making any change:
1. Read `AGENTS.md`.
2. Read `PROJECT_HANDOFF.md` completely.
3. Read `CURRENT_TASK.md`.
4. Inspect the actual current files in the repository.
5. Treat repository contents as the source of truth when they conflict with historical notes.
6. If a material mismatch exists between repository state and handoff, report it before changing code.

## Project
- Engine: Godot 4.7.2 stable.
- Project: AbyssPrototype.
- Game: 2D cooperative submarine game inspired by Barotrauma.
- Current target: Beta 0.1 cooperative PC Host ↔ Android client.
- Primary Android test device: Motorola G24 Power, 8 GB RAM.
- Networking: ENet/UDP, port 7777.
- Architecture: Host authoritative.
- LAN Host used in tests: 192.168.1.5.
- Android used in tests: 192.168.1.28.
- Android export: INTERNET permission ON, arm64-v8a ON, Custom Gradle OFF.

## Core engineering rules
- Do not reopen a system marked CLOSED in `PROJECT_HANDOFF.md` without concrete regression evidence.
- Diagnose from logs before modifying networking or authority code.
- Prefer the smallest change that solves the observed problem.
- Ideally modify 1–3 existing scripts per iteration.
- Do not refactor working systems merely to improve style during Beta core.
- Preserve Host authority.
- Do not disable validation merely to make a test pass.
- Preserve useful debug logging.
- Keep DebugHUD separate from GameplayHUD.
- Do not introduce campaign, economy, stations, advanced crafting, progression or unrelated content during Beta core.
- `peer_id` is not a persistent player identity design.
- Distinguish production bugs, QA harness bugs, UX issues and deferred/incomplete features.

## QA rules
- QA is testing infrastructure, not gameplay.
- Only one QA may have `Start On Run = ON` at a time.
- All QA systems default to `Start On Run = OFF`.
- QA output convention:
  - `[QA][STEP XX][PASS]`
  - `[QA][STEP XX][FAIL]`
  - `[QA][STEP XX][SKIP]`
  - final summary
- After a critical fix, run the corresponding smoke/QA before continuing.
- PC ↔ Android changes must be verified on real Android when relevant.

## Existing scripts
- Inspect the full current script before editing it.
- Preserve validated behavior unless the task requires changing it.
- Leave modified files internally complete and coherent.
- Do not change `NetworkManager` without concrete evidence.
- Do not change `NetworkInteractionManager` or `NetworkInteractable` based only on old hypotheses; recent Host and Android tests passed core interaction paths.

## Current priority
Continue from `CURRENT_TASK.md`.

Immediate work: QA-COOP-01, a Host-only cooperative QA runner that automates the real Host Player while the human tester controls Android.

Important:
- Do not automate Android in the current phase.
- Prefer the real Host Player over TestBot where server validation uses Peer 1 / Host Player position.
- Keep the runner isolated from production systems.
- Implement and validate a small Phase A before combat/revive/full B1.2 automation.

## Context maintenance
After each approved implementation/QA phase:
- update `PROJECT_HANDOFF.md` only when project-level status/decisions change;
- update `CURRENT_TASK.md` with the exact next step;
- append observed evidence to `harness/build-log.md`;
- record material phase discoveries in `harness/context/`;
- preserve prior decisions and explicitly mark superseded assumptions.

## Drift check
Before a substantial change, verify:
- Is it required for the current Beta milestone?
- Is the affected system CLOSED?
- Do logs prove a regression?
- Can the change stay in QA instead of production?
- What exact test will prove success?
