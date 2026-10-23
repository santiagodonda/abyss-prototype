# Phase QA-COOP-01A — Host Automation Foundation

## Objective
Create the smallest reliable Host-only cooperative QA runner for B1.2 preparation.

## Scope
- new/continued QA runner
- automate real Host Player
- wait for Android peer
- Reactor ON
- OxygenGenerator ON
- Door OPEN
- detect Android Door crossing
- PumpRight ON
- PressureRegulator ON
- deterministic PASS/FAIL summary

## Out of scope
- Android automation
- Hull repair automation
- Harpoon automation
- creature combat automation
- unconscious/revive automation
- mission automation
- production networking refactor
- crafting/material locker work
- mobile UX work

## Acceptance criteria
1. Runner is Host-only.
2. Runner defaults OFF.
3. Android stays human-controlled.
4. No core production networking script changes unless a verified blocker exists and is explicitly approved.
5. Host actions pass through normal gameplay interaction/authority behavior.
6. Remote crossing is detected from Host-visible remote state.
7. Final result: 8 PASS / 0 FAIL.
8. Disabling the runner restores normal manual behavior.
