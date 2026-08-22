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

### Arcade flight policy

Arena throws use deterministic, disc-golf-inspired trajectories rather than
literal field-distance simulation. Design combat encounters around an effective
100–200 ft threat space. Longer throws may provide movement pressure, scouting,
or route control, but must not become reliable moving-target attacks.

Flight identity remains legible across release angles. The utility driver must
support spike-hyzer, straight-to-fade corner, and controlled flex-to-flat lines.
The beat-in distance driver must support maximum-power hyzer-flip-to-flat laser,
flat-release turning-S, and anhyzer-to-roller lines within its configured
envelope. The natural finish and turn directions mirror for backhand and
forehand spin direction.

This is authored gameplay calibration, not a hidden correction: flight profile,
release envelope, projectile collision behavior, and proximity capture are
separate inspectable configuration concerns.

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
| Charge and throw | Hold/release left mouse button | Hold to charge; release to launch the disc projectile |
| Aim / trajectory preview | Right mouse button | Future camera tightening and path preview; not implemented yet |
| Menu | Tab | Open the menu |

Input actions should express gameplay intent (for example, `throw_charge`) rather
than embed device keys in gameplay code. Future wall-jump and slide mechanics are
not part of the current implementation scope.

## Related documents

- `docs/flight-model.md` defines flight-model conventions and limitations.
- `docs/disc-molds.md` defines configurable mold flight archetypes and
  mold-specific arena behavior.
- `docs/architecture.md` defines authority, simulation, collision, and scene
  ownership boundaries.
