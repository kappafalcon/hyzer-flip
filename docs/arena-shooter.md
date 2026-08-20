# Arena Shooter Requirements

## Status and use

This document records the current arena-shooter requirements. It is a product
specification, not an implementation plan. Values and rules marked **TBD** must
remain configurable or be decided explicitly; do not silently invent them.

## Match rounds

- A match consists of a configured sequence of either **9** or **18** rounds.
- Round count belongs in match rules/configuration, not in scene code or a
  hard-coded UI flow.
- Round objectives, scoring, win conditions, respawn rules, and between-round
  transitions are **TBD**.

## Disc projectile gameplay

Discs are physical projectiles, never hitscan attacks.

- A disc type can define a maximum number of bounces before it breaks. The
  bounce limit and break behavior must be per-projectile configuration.
- A disc type can opt into skipping. Skips and bounces are distinct collision
  outcomes with independently configurable behavior.
- The projectile lifecycle must support continued flight, bounce, skip, break,
  and player contact. Damage and effect rules are **TBD**.
- Authoritative collision and lifecycle resolution must remain deterministic and
  server-owned when multiplayer is added.

### Proximity lock-on contact

Lock-on is a projectile-contact assist, not a replacement for projectile flight.
When a disc enters a configured capture area near an opposing player's hitbox,
the game must be able to resolve a guaranteed hitbox contact.

Capture range, target selection, line-of-sight rules, steering/correction
behavior, timing, and balance limits are **TBD**. Implementations must expose
those decisions as configuration rather than hard-coding them.

### Aiming and trajectory preview

While aiming a charged throw, the player should see the predicted flight before
release. When feasible, that prediction should include expected wall bounces and
skips.

The preview must use the same flight and collision rules as the real projectile
for the same initial state. It is a client-side visualization, not authority;
it may only predict the geometry and state known to that client.

## Controls

| Action | Current binding | Intent |
| --- | --- | --- |
| Move | W, A, S, D | Player movement |
| Hyzer angle | Q | Increase hyzer release angle |
| Anhyzer angle | E | Increase anhyzer release angle |
| Jump | Space | Supports a future wall-jump mechanic |
| Crouch | Ctrl | Supports a future hold-to-slide mechanic |
| Aim and charge | Hold right mouse button | Aim, charge a throw, and show trajectory preview |
| Throw | Left mouse button | Release the disc projectile |
| Menu | Tab | Open the menu |

Input actions should express gameplay intent (for example, `throw_charge` and
`throw_disc`) rather than embed device keys in gameplay code. Future wall-jump
and slide mechanics are not part of the current implementation scope.

## Related documents

- `docs/flight-model.md` defines flight-model conventions and limitations.
- `docs/disc-molds.md` defines configurable mold flight archetypes and
  mold-specific arena behavior.
- `docs/architecture.md` defines authority, simulation, collision, and scene
  ownership boundaries.
