---
name: hyzer-flip-v2-physics-integration
description: Design or review the boundary between Hyzer Flip flight-model-v2 and Godot physics. Use for fixed-step driving, collision queries, ground transitions, or state presentation; not for mold tuning.
---

# Hyzer Flip V2 Physics Integration

Read `docs/flight-model-v2.md`, `docs/architecture.md`, and
`docs/arena-shooter.md` first. Treat v2 as the target contract and the isolated
prototype as its airborne-only executable subset. Ground states remain
unimplemented until code and tests establish them.

## Ownership and stepping

- Keep one pure fixed-step flight solver over explicit state, immutable mold
  data, environment data, and timestep. It must not read or mutate `Node`, scene
  transforms, input, rendering, physics-server, or network state.
- Keep authoritative state complete enough to replay, including position,
  velocity, orientation/bank, airborne or ground phase, lifecycle, tick, and
  time. Presentation transforms are projections of that state.
- Use an accumulator or equivalent driver to execute fixed solver steps. Render
  frames and client physics-callback counts must not change the trajectory.
- Keep integration order explicit: advance an intended segment, query collision,
  resolve a deterministic response, then publish state to presentation and
  networking.

## Collision adapter

- Put Godot space queries behind an adapter that accepts plain segment/shape and
  configuration data and returns plain collision results. Never pass collider
  nodes or query dictionaries into the flight solver.
- Sweep fast-moving discs across the completed segment. Return contact fraction
  or distance, position, normal, stable collider/surface identity, collision
  category, and required material data.
- Define masks, exclusions, simultaneous-contact ordering, iteration bounds,
  starting-in-contact behavior, and terminal fallbacks explicitly.

## V2 ground transition

- Choose `SKIP`, `ROLL`, or `STOP/SLIDE` from actual impact velocity, horizontal
  and vertical speed, bank/orientation, impact angle, surface normal/material,
  and configured mold factors. Never infer the outcome from fade versus turn
  ratings alone.
- Preserve incoming momentum, orientation, and remaining energy across contact;
  apply explicit deterministic response rules rather than replacing them with a
  canned skip or roll speed.
- Keep skip boost, roll response, bounce limits, breakage, and contact effects
  visible in configuration and bounded for deterministic replay.
- Do not make a Jolt `RigidBody3D` authoritative. Engine physics may provide
  queries or presentation while explicit simulation remains gameplay authority.

Use `$hyzer-flip-v2-projectiles` for lifecycle decisions and
`$hyzer-flip-v2-testing` for collision-boundary, continuity, and convergence
coverage. Update the v2 and architecture documents when these boundaries or
their implementation status change.
