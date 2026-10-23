# CURRENT TASK — QA-COOP-01 Phase A

Status: NOT YET VALIDATED
Roadmap context: B1.1 is CLOSED; this task prepares B1.2.

## Goal
Automate the PC Host side while the human tester controls the Android client.

The QA must remain isolated test infrastructure and must not force changes into stable production networking.

## First Codex action — READ ONLY
Before editing:
1. Read `AGENTS.md`.
2. Read `PROJECT_HANDOFF.md`.
3. Inspect:
   - `main.tscn`
   - current `player.gd`
   - NetworkInteractionManager
   - NetworkInteractable
   - Reactor
   - OxygenGenerator
   - Door
   - PumpRight
   - PressureRegulator
   - current TestBot / QA scripts
4. Determine whether `coop_qa_runner.gd` / `CoopQARunner` already exists.
5. Verify actual node paths/names.
6. Verify how Host sees remote player positions.
7. Do not change files in this first response.

Report:
- files inspected,
- architecture relevant to the runner,
- mismatch with handoff,
- exact files proposed to add/modify,
- Phase A implementation plan,
- acceptance test.

## Phase A behavior
Host-only runner:
1. wait for one Android peer;
2. resolve references;
3. automate real Host Player;
4. ensure Reactor ON;
5. ensure OxygenGenerator ON;
6. ensure Door OPEN;
7. prompt human Android tester to cross;
8. detect remote peer crossed central Door;
9. ensure PumpRight ON;
10. ensure PressureRegulator ON;
11. print deterministic PASS/FAIL summary;
12. restore Host position if safe.

Expected:
- 8 PASS
- 0 FAIL

## Constraints
- Do not automate Android.
- Do not change NetworkManager.
- Do not change NetworkInteractionManager unless actual code proves a blocker and the user explicitly approves.
- Do not change NetworkInteractable based on historical hypotheses.
- Do not change CLOSED systems merely to support QA.
- Prefer one isolated QA runner plus one scene node.
- All other QA runners OFF.
- If a partial runner already exists, continue it rather than duplicate it.

## Validation
Run PC Host + real Android client.

Expected:
- runner waits for Android;
- Host Player is automated;
- Android remains human-controlled;
- Host actions use normal production interaction/authority paths;
- Android crossing is detected from Host-visible remote state;
- no REJECT introduced by automation;
- QA disabled restores normal manual gameplay.

After PASS:
- append evidence to `harness/build-log.md`
- update this file
- next: QA-COOP-01 Phase B / B1.2 hull-repair automation
