---
name: hyzer-flip-v2-projectiles
description: Build or review Hyzer Flip flight-model-v2 projectile interactions. Use for impact classification, skips, rolls, stop/slide, bounce, breakage, lock-on contact, or trajectory previews; not for ordinary airborne mold tuning.
---

# Hyzer Flip V2 Projectiles

Read `docs/flight-model-v2.md`, `docs/arena-shooter.md`, and
`docs/architecture.md` before changing projectile behavior. The v2 document is
the target contract; the current prototype implements airborne flight only, so
do not present ground states or collision authority as completed work.

## Collision and lifecycle

- Keep visible disc flight deterministic and continuous. A projectile remains a
  projectile; proximity lock-on may assist contact after an explicit capture
  condition but must not become hitscan.
- Resolve `SKIP`, `ROLL`, and `STOP/SLIDE` from the actual impact state and
  surface: velocity, bank/orientation, impact angle, normal/material, remaining
  energy, and mold factors. Do not choose ground behavior from fade, turn
  tendency, or turn resistance alone.
- Carry incoming velocity and orientation into skips and rolls. Configure any
  energy loss, skip boost, slope response, friction, bounce limit, breakage, or
  terminal threshold explicitly; do not substitute fixed response speeds.
- Keep mold factors such as skip or roll tendency separate from projectile
  rules such as bounce counts, damage, status effects, capture, and despawn.
- Give spawn, impact, skip, roll, break, hit, stop, and despawn events stable
  identities and deterministic ordering so replay or networking cannot apply an
  outcome twice.

## Preview and authority

- Use the same flight, collision adapter, and projectile response rules for a
  trajectory preview and a real throw with matching known inputs.
- Treat preview as client visualization, not authority. Unknown geometry or
  remote state makes a prediction provisional and must not decide a server hit.
- Keep authoritative collision and lifecycle resolution server-owned when
  multiplayer is introduced. Replicate explicit state and events rather than a
  scene transform or rigid-body result.
- Keep all undecided balance values configurable and visibly marked TBD. Do not
  invent capture ranges, skip boosts, bounce counts, or damage values.

Use `$hyzer-flip-v2-physics-integration` for Godot query and fixed-step adapter
work and `$hyzer-flip-v2-testing` for impact, continuity, preview-parity, and
event-order coverage. Update `docs/arena-shooter.md` or
`docs/flight-model-v2.md` when product rules or target flight semantics change.
