---
name: hyzer-flip-v2-testing
description: Define or review repeatable Hyzer Flip flight-model-v2 verification. Use for deterministic trajectories, apex and phase invariants, release envelopes, replays, or ground-state tests; not for visual-only inspection.
---

# Hyzer Flip V2 Testing

Read `docs/flight-model-v2.md` and `docs/architecture.md` first. The v2 document
is the target contract; the isolated prototype is the executable subset.
Legacy fixtures may explain existing code but cannot define v2 expectations.

## Airborne invariants

- Build each case from explicit initial state, mold data, environment, timestep,
  and tick count or terminal event. Do not make authoritative assertions from a
  `Node3D` transform, render frame, live input, or editor-only state.
- Repeat identical inputs and compare complete meaningful state with documented
  floating-point tolerances. Do not claim cross-platform bitwise determinism
  without evidence.
- Assert one ordered `POWERED_FLIGHT` to `LATE_FLIGHT` transition at the
  vertical-velocity apex. Rising releases should cross from positive to
  nonpositive vertical velocity; level or downward release semantics must be
  explicit in the fixture.
- Compare otherwise identical runs with and without fade to prove fade has no
  effect during powered flight or on the apex-transition tick, then prove it
  affects a later complete late-flight tick.
- Assert continuity across apex: no reset or teleport of position, velocity,
  bank, orientation, tick, or time. Allow ordinary fixed-step integration on
  the transition tick.
- Verify state remains finite and bank/orientation visually follows the authored
  turn and fade state.

## Behavior and future states

- Test mold behavior through meaningful landmarks and release envelopes:
  hyzer-flip or held hyzer, flat turn or straightness, anhyzer/flex, apex bank,
  late fade, cover clearance, and terminal direction as appropriate.
- When carry is tuned, compare an eligible shallow release with an otherwise
  identical no-carry run, then prove a release outside the carry envelope keeps
  its established trajectory. Keep charge-speed calibration checks in the
  player-lab boundary; presentation time scaling must not change solver states.
- For a sniper hyzer-flip, assert the distance where bank first reaches flat,
  that it remains flat through powered flight, its center-line carry, and its
  terminal range. Retain independent flat-turnover and anhyzer/roller fixtures.
- Keep prototype calibration thresholds fixture-local. A golden trajectory is a
  regression baseline, not proof of realism or a universal mold rule.
- When ground states are implemented, classify `SKIP`, `ROLL`, and `STOP/SLIDE`
  from explicit impact velocity, orientation, surface normal/material, and mold
  factors. Verify incoming momentum and orientation carry into the response.
- Treat a ground state as implemented only when an authoritative collision and
  lifecycle path plus an automated fixture exercise it. Record earlier
  acceptance criteria in `docs/flight-model-v2.md` or `docs/disc-molds.md`, not
  as a passing placeholder test.
- Until then, mark ground interaction, production Resource validation, replay
  serialization, networking, and cross-platform guarantees as uncovered target
  behavior rather than fabricating passing tests.

## Validation workflow

Run the smallest relevant deterministic fixture. For the current isolated
prototype, use:

```sh
godot --headless --path . --scene res://scenes/tests/arcade_flight_lab.tscn
```

After GDScript, scene, or Resource changes, also run
`godot --headless --path . --editor --quit`. Update
`docs/flight-model-v2.md` when a test changes target semantics, fixed-step
conventions, known limitations, or validation status.
