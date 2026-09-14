---
name: hyzer-flip-v2-flight-model
description: Design, implement, or review Hyzer Flip flight-model-v2 airborne behavior. Use for release state, powered turn, apex transitions, late fade, banking, or solver changes; not for collision responses or legacy v1 profile tuning.
---

# Hyzer Flip V2 Flight Model

## Authority

Read `docs/flight-model-v2.md` before changing flight behavior. Treat it as the
target contract. Use `scripts/flight/arcade/arcade_flight_prototype.gd` as the
currently executable subset and `docs/flight-model.md` only to understand
legacy code during migration. Never let a legacy phase-curve, range, or
launch-pitch rule override v2.

## Airborne contract

- Keep one deterministic solver with continuous `POWERED_FLIGHT` and
  `LATE_FLIGHT` states; do not build separate simulators or reset state between
  them.
- Initialize release from explicit position, velocity or power, direction,
  launch pitch, release bank, mold data, and explicit modifiers. Do not steer a
  disc from live player input after release.
- During powered flight, apply authored turn behavior. Keep `turn_tendency` and
  `turn_resistance` conceptually separate even if the solver combines them.
  Resistance may cancel turn or flex existing anhyzer toward flat; it must not
  manufacture early fade.
- Disable fade throughout powered flight and the apex-transition tick. Activate
  it only in late flight, after the vertical apex crossing.
- Detect an apex from vertical trajectory, normally a positive-to-nonpositive
  vertical-velocity crossing, rather than distance or normalized flight phase.
- Preserve normally integrated position, velocity, bank, orientation, time,
  and tick across the transition. Continuous state forbids resets or teleports;
  it does not require adjacent states to be identical.
- Keep bank and orientation continuous and readable as gameplay feedback. They
  need not result from rigid-body aerodynamic torque.
- The current prototype may apply per-profile carry only while a shallow,
  positive release is rising in powered flight. Keep that release envelope
  explicit, return to full gravity after apex, and do not use carry to extend
  high-angle lob releases.
- A sniper-style mold may hold a positive hyzer release at flat during powered
  flight. Preserve the initial release-bank context for that decision, and do
  not apply the hold to flat or anhyzer releases that are meant to turn over.

## Determinism and boundaries

- Use SI units, explicit state and environment inputs, and a caller-enforced
  fixed timestep. Render timing and scene transforms must not define results.
- Keep the solver independent of `Node`, input, rendering, physics queries, and
  networking. Special abilities enter as explicit data or command modifiers.
- Do not add scientific lift/drag tables, gyroscopic precession, uncontrolled
  randomness, or authoritative rigid-body flight unless the target contract is
  deliberately changed.
- Treat ground contact, skip, roll, stop/slide, production Resources, and
  cross-platform bitwise determinism as targets rather than implemented facts
  until code and validation establish them.
- Treat prototype constants and trajectory thresholds as local calibration,
  not universal model rules.

Update `docs/flight-model-v2.md` when target units, conventions, state semantics,
scope, or validation status changes. Use `$hyzer-flip-v2-testing` for regression
coverage and `$hyzer-flip-v2-physics-integration` at the collision boundary.
