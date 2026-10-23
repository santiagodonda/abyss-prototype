# AbyssPrototype — Project Handoff

Last consolidated transfer: 2026-10-22
Engine: Godot 4.7.2 stable
Goal: reach Beta 0.1 cooperative PC ↔ Android stability before campaign/progression expansion.

## 1. Vision
AbyssPrototype is a 2D cooperative submarine game inspired by Barotrauma.

Target:
- 4–5 friends in cooperative multiplayer.
- PC Host with Android support.
- Host-authoritative simulation.
- Core systems: submarine, rooms, flooding, pressure, oxygen, power, repairs, combat, creatures, revive, missions and multiplayer synchronization.

Priority:
1. robust cooperative skeleton,
2. mobile UX/performance,
3. Beta stability,
4. only then persistence/campaign/content expansion.

## 2. Durable rules
- Host authoritative.
- Do not reopen CLOSED systems without concrete regression evidence.
- Diagnose with exact logs.
- Distinguish production bugs from QA harness issues.
- Prefer minimal changes.
- Keep debug logs during construction.
- DebugHUD and GameplayHUD stay separate.
- Stable persistent player UUID is not current Beta-core work.
- No campaign/economy/stations/advanced crafting expansion during current Beta work.
- Android is a real target platform.

## 3. Network / Android environment
Validated LAN:
- Host PC: `192.168.1.5`
- Android: `192.168.1.28`
- ENet UDP port: `7777`
- Host observed on `0.0.0.0:7777`
- Android connects to `192.168.1.5`
- Do not use `127.0.0.1`
- Radmin VPN should not be used as Android LAN route.
- Android export: INTERNET ON, arm64-v8a ON, Custom Gradle OFF.

A previous Android connection failure was caused by missing INTERNET permission. Fixed.

## 4. CLOSED / validated systems
Do not reopen without regression evidence:
- Connections / avatars
- World interactions
- Rooms / Hatch
- Water
- O2
- Pressure
- Depth / Helm
- Creatures
- Harpoon combat
- Turret combat skeleton
- Player Health Authority
- Hull Authority
- Hull Repair Authority
- Personal Ammo Authority
- Power Authority
- Revive Authority
- Crew / Round Authority
- Mission Authority
- Mission packet ordering
- Restart Authority
- Player movement / position coherence
- Reconnect + state reconstruction
- Cross-system snapshot sanity
- Global Skeleton QA

Historical reinforced skeleton QA:
- Host + Client A + Client B
- PASS 10 / FAIL 0 / SKIP 0
- no ghost peer after disconnect
- historical backup: `AbyssPrototype_ReinforcedSkeleton_2026-09-24`

## 5. Roadmap
Beta 0.1:
- B1 — PC ↔ Android LAN
- B2 — Mobile Controls / UX
- B3 — Real Co-op Session
- B4 — Android Performance
- B5 — Beta UX / Feedback
- B6 — Bug & Stability Pass
- B7 — Beta 0.1 Candidate

After Beta 0.1:
- C1 — Persistence Foundation / Save
- C2 — Campaign Framework
- C3 — Stations + Economy
- C4 — Advanced Crafting + Progression
- C5 — Content Expansion
- C6 — Campaign Beta

Current:
- B1.1 = CLOSED / PASS
- B1.2 = next gameplay-smoke milestone
- QA-COOP-01 is introduced first to reduce manual two-character testing.

## 6. B1.1 PC ↔ Android LAN — CLOSED
Validated:
- Android connects to PC Host.
- Host sees Android peer.
- Android → PC movement.
- PC → Android movement.
- simultaneous movement.
- Door from Android.
- Door crossing both ways.
- Reactor from Android.
- OxygenGenerator from Android.
- PumpRight from Android.
- PressureRegulator from Android.
- SubmarineHelm from Android.
- same core interaction path from Host.
- Hull repair from Android.
- personal Harpoon ammo authority.
- Harpoon fire Android → Host.
- Host-authoritative projectile creation.
- ammo consumption synchronization.
- disconnect removes remote avatar / no ghost.
- target lock during interaction.

Recent Android controlled tests produced repeated `[NET INTERACT][OK]` for Reactor, OxygenGenerator, Door, PumpRight, PressureRegulator and SubmarineHelm.

Harpoon evidence:
- ammo pickup `0 -> 6`
- Android fired `harpoon_gun`
- Host created authoritative projectiles
- ammo decremented correctly
Conclusion: Harpoon Gun/Ammo/Fire networking PASS; remaining issue is UX feedback.

Current decision:
Do not modify `NetworkInteractable` or `NetworkInteractionManager` based on the old distance hypothesis.

## 7. Interaction target-lock fix
A concrete regression existed where the interactable could change between PRESS and RELEASE / during hold.

`player.gd` was updated so the selected target remains locked for the duration of the interaction.

Validated:
- PRESS target remains LOCKED through RELEASE.
- Hull hold repair works.
- Host core interactions consistent.
- Android core interactions consistent.

Do not remove this behavior.

## 8. Enlarged submarine layout — CLOSED
Final logical rooms:
- RoomLeft: position `(-275,158)`, size `(900,807)`, transform `(0,0)`
- RoomRight: position `(655,158)`, size `(900,807)`, transform `(0,0)`

Floor:
- Left `Rect2(-275,115,900,850)`
- Right `Rect2(655,115,900,850)`
- Floor node `(0,0)`

Walls:
- WallTop `(640,100)`, shape `(1890,30)`
- WallBottom `(640,980)`, shape `(1890,30)`
- WallLeft `(-290,540)`, shape `(30,880)`
- WallRight `(1570,540)`, shape `(30,880)`
- MiddleWallTop `(640,200)`, shape `(30,200)`
- Door `(640,360)`, collision `(30,120)`
- MiddleWallBottom `(640,700)`, shape `(30,560)`

Preserved exterior/top:
- ExteriorHatch `(850,158)`
- HatchInteriorPoint `(820,220)`
- HatchExteriorPoint `(850,75)`
- SeaCreature `(1080,75)`
- SubmarineTurret `(970,135)`
- HullIntegrityPoint `(1080,158)`

RoomLeft:
- SubmarineHelm `(-120,230)`
- MaterialLocker `(140,230)`
- DivingGearLocker `(400,230)`
- OxygenTankRack `(-120,450)`
- WrenchRack `(140,450)`
- ScrewdriverRack `(400,450)`
- WeldingToolRack `(-120,670)`
- WeldingFuelRack `(140,670)`
- CraftingStation `(400,670)`
- Reactor `(-120,850)`
- ReactorRepairPoint `(40,850)`
- OxygenGenerator `(260,850)`
- OxygenGeneratorRepairPoint `(420,850)`

RoomRight:
- HarpoonGunRack `(950,380)`
- HarpoonAmmoRack `(1250,380)`
- TurretControl `(1400,230)`
- PumpRight `(900,650)`
- PumpRepairPoint `(900,840)`
- PressureRegulator `(1200,650)`
- PressureRegulatorRepairPoint `(1200,840)`
- HullBreach `(1450,650)`
- TestBot `(800,500)`

Other:
- ExteriorTestPoint `(1650,250)`
- InteriorTestPoint retained from prior layout.

Camera intended limits:
- Left `-305`
- Top `-95`
- Right `1585`
- Bottom `995`
- smoothing off during layout QA.

Validated:
- room/floor/wall alignment
- central Door
- exterior zone
- SeaCreature exterior
- ExteriorHatch exit/re-entry
- underwater transition
- HullBreach repair
- improved interaction spacing

Status:
- `LAYOUT-01C = PASS / CLOSED`
- `HATCH / EXTERIOR LAYOUT = PASS / CLOSED`

## 9. OPEN / DEFER

### CraftingStation
OPEN / DEFER for current LAN core.
Client did not get useful gameplay behavior in Android test.
Not considered fully multiplayer-integrated.
Does not block B1.1.

### MaterialLocker
OPEN / DEFER for current LAN core.
Not considered fully multiplayer-integrated.
Does not block B1.1.

### Harpoon pickup/ammo feedback
OPEN UX.
Networking works, but pickup feedback is weak/unclear.

### TurretControl
Incomplete interaction / defer.
Historical source inspection showed `interact()` effectively `pass`, and its InteractionArea was disabled at that time.
Do not treat this as a networking regression.
Turret combat skeleton itself had previously been validated.

## 10. B1.2 intended gameplay smoke
Approximately 5–10 min:
- Door
- Reactor
- Pump
- OxygenGenerator
- flooding
- Hull/Breach
- Harpoon Gun
- personal ammo
- harpoon firing
- SeaCreature
- turret where implementation allows
- damage
- unconscious
- revive
- mission progression
- disconnect/no ghost

Problem:
The tester had to manually control both PC Host Player and Android client.

Decision:
Introduce Host-only cooperative QA automation.

## 11. QA-COOP-01 design
Goal:
Automate Host side while the human tester controls only Android.

Important design decision:
Use the real Host `Player` for Host-side QA actions rather than TestBot where interaction validation depends on Peer 1 / Host Player position.

Reason:
`NetworkInteractionManager` validates Peer 1 using the real Host Player position; using another bot body could produce artificial distance-validation failures.

Therefore:
- Host Player may be moved/teleported in controlled QA steps.
- Android stays human-controlled.
- Do not automate Android in the current phase.
- Do not modify NetworkManager for this.
- Do not modify NetworkInteractionManager merely to support the runner.
- Runner remains isolated QA infrastructure.

Proposed names:
- `res://coop_qa_runner.gd`
- scene node `CoopQARunner`

Important:
This runner was designed/proposed but NOT confirmed integrated and PASS before this transfer.
Inspect the repository to determine whether it already exists.

## 12. QA-COOP-01 Phase A acceptance
Sequence:
1. runner arms only on Host;
2. wait for one Android client;
3. resolve references;
4. move real Host Player near Reactor;
5. Reactor ON through normal interaction path;
6. move near OxygenGenerator;
7. OxygenGenerator ON;
8. Door OPEN;
9. ask Android human to cross Door;
10. detect remote Android crossing;
11. PumpRight ON;
12. PressureRegulator ON;
13. deterministic PASS/FAIL summary;
14. optionally restore Host position;
15. no production-system rewrite to make QA work.

Expected summary:
- PASS 8
- FAIL 0

Runner defaults `Start On Run = OFF`.
For the specific run, enable intentionally and keep all other QA OFF.

If Phase A passes, extend the same runner incrementally.

## 13. Planned QA-COOP expansion
Phase B:
- Android repairs HullBreach
- verify authoritative repair completion
- verify Pump/Pressure recovery

Phase C:
- Android gets Harpoon Gun + ammo
- verify ammo authority
- Android fires
- verify projectile/ammo
- optionally creature damage/encounter

Phase D:
- controlled damage/unconscious
- Android revive
- verify authoritative revive
- avoid accidental all-crew-dead/restart during setup

Phase E:
- mission state checks
- Android disconnect
- verify remote avatar removal/no ghost
- final B1.2 summary

Keep Android human-driven so mobile input/UX issues stay visible.

## 14. Old distance hypothesis — downgraded
Earlier some `[NET INTERACT][REJECT]` events suggested a possible mismatch between local overlap selection and authoritative distance validation.

Historical observations included:
- NetworkInteractable distance around 140
- validation enabled
- Player interaction radius around 90
- PressureRegulator InteractionArea offset

But after target locking + layout enlargement:
- Host core interactions passed repeatedly.
- Android core interactions passed repeatedly.
- no systematic REJECT remained.

Current decision:
Do not alter this path without new exact evidence.

## 15. Latest stable functional evidence
Host:
- Reactor repeated OK
- OxygenGenerator repeated OK
- Door repeated OK
- PumpRight repeated OK
- PressureRegulator repeated OK
- Helm functionally confirmed
- Hull repair confirmed

Android:
- connects and receives snapshots
- Reactor/O2/Door/Pump/Pressure/Helm repeated OK
- Hull repair authoritative completion
- ammo pickup authoritative
- Harpoon fire authoritative with projectile creation and ammo decrement
- disconnect removes remote avatar

Conclusion:
`B1.1 PC ↔ Android LAN = PASS / CLOSED`

## 16. Current next milestone
Do NOT restart B1.1.

Immediate:
`QA-COOP-01 Phase A`

Then:
`B1.2 cooperative gameplay smoke`

After B1.2 PASS:
1. create fresh complete project snapshot/backup,
2. promote it to stable post-LAN baseline,
3. continue to B2 Mobile Controls / UX.

## 17. Future-session protocol
At a new coding session:
1. read `AGENTS.md`
2. read this file
3. read `CURRENT_TASK.md`
4. inspect actual repository
5. report material mismatch
6. continue from current next step
7. do not repeat CLOSED QA without a concrete reason
