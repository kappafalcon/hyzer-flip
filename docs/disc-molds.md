# Disc Molds and Gameplay Archetypes

## Purpose

Each disc mold combines two independently configurable concerns:

1. **Flight identity** — physical dimensions, mass, inertia, and aerodynamic
   coefficients that determine its trajectory.
2. **Arena behavior** — gameplay effects and collision rules such as bouncing,
   skipping, stunning, or revealing opponents.

Keep these concerns separate. A mold's flight profile must remain tunable without
rewriting its gameplay behavior, and an arena ability must not alter the shared
flight solver through hidden heuristics.

## Data direction

`DiscData` and `AerodynamicData` remain the source of physical and aerodynamic
configuration. A future, separate gameplay resource may hold mold-specific
projectile behavior, such as bounce limits, skip settings, hit effects, and
reveal behavior. These are design targets, not current code types.

New molds and variations must be data-driven. Do not create a custom script per
mold. Mold variation, wear/beat state, or future balance tuning should be an
explicit data override rather than an untracked code change.

## Current mold roster

| Archetype | Flight identity | Arena behavior | Configuration notes |
| --- | --- | --- | --- |
| Putter | Slow, straight, putter-like flight | May stun a player on projectile contact | Stun enablement, duration, and immunity rules are **TBD** |
| Mid | Neutral to understable flight | May rebound from walls | Rebound eligibility, energy retention, and bounce limit are **TBD** |
| Overstable driver | Overstable, approximately 9-speed character; capable of a strong fading hook around corners | May skip and reveal a player it scans over | Scan volume, reveal duration, skip profile, and hit rules are **TBD** |
| Distance driver | Beat-in Destroyer-like character: high-speed, understable-to-flat hyzer-flip and a fast, laser-like line | Remains a physical projectile | `data/discs/beat_in_destroyer.tres` uses the current `wraith_aerodynamics.tres` prototype profile. Valid release envelope, target coefficients, and speed tuning are **TBD**. |

## Deterministic distance-driver expectation

The distance driver should deterministically flip from a hyzer release toward
flat within a defined, validated release envelope. Deterministic means the same
disc data, throw command, environment, and simulation tick produce the same
trajectory; it does not mean every possible hyzer angle or wind condition yields
the same laser-like line.

Implement this through data-driven aerodynamics and an explicit validation
envelope, not randomness, animation, or a hidden "flip to flat" correction.

## Beat-In Destroyer prototype asset

`data/discs/beat_in_destroyer.tres` is the Flight Lab's current distance-driver
configuration. It owns only the physical disc configuration and references the
shared `data/discs/wraith_aerodynamics.tres` profile; it does not add a
disc-specific flight script or arena behavior. Its stated flight character is a
design target, not a validated release-envelope guarantee.

## Tuning rules

- All flight and arena behavior values must be inspectable configuration.
- Keep generic projectile rules reusable; molds opt into or override them with
  data where appropriate.
- Treat real disc-golf descriptions (for example, "beat-in Destroyer" and
  "9-speed") as desired flight character, not as a substitute for measured or
  tested coefficient data.
- Validate mold changes against repeatable throw scenarios before treating them
  as balance changes.

## Related documents

- `docs/flight-model.md` defines the simulator's current units and limitations.
- `docs/arena-shooter.md` defines projectile lifecycle, collision, and preview
  requirements.
