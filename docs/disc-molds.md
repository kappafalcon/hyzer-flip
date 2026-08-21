# Disc Molds and Gameplay Archetypes

## Purpose

Each disc mold combines two independently configurable concerns:

1. **Flight identity** — physical dimensions, mass, inertia, and authored
   aerodynamic coefficients that determine its deterministic trajectory.
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

## Arena mold roster

| Archetype | Flight identity | Arena behavior | Configuration notes |
| --- | --- | --- | --- |
| Putter | Slow and flat-coasting | Low direct damage and stun on hit | Damage, stun duration, and immunity rules are **TBD** |
| Mid | Medium-speed, versatile flight | Reveals a player's location and slows on hit; AOE damage is a candidate | Reveal trigger/duration, slow, AOE eligibility, and damage rules are **TBD** |
| Utility driver | Overstable, Firebird-type utility line: spike-hyzer, straight-to-fade corner line, or flex-to-flat | Skips and deals damage; AOE damage is a candidate | Skip profile, damage, AOE eligibility, and bounce limit are **TBD** |
| Beat-in distance driver | Understable, high-power line: hyzer-flip, straight-to-turning S line, or roller | Remains a physical projectile | The validated max-power release envelope and hit behavior are **TBD** |

The current prototype distance-driver and Ol Reliable assets are Flight Lab
profiles. They do not establish the final arena roster or its combat range.

## Arcade flight identities

Arena molds are tuned for recognizable line families, not real-world distance
fidelity. The intended combat range is 100–200 ft. A mold's behavior must be
defined within a bounded release envelope and mirrored by throw handedness;
never rely on an invisible aim correction to make a line work.

| Archetype | Flat release | Hyzer release | Anhyzer release |
| --- | --- | --- | --- |
| Utility driver (overstable) | Straight-to-fade line that can bend around corners | Spike-hyzer | Controlled flex-to-flat line |
| Beat-in distance driver (understable) | Straight-to-turning S line | At maximum configured power, hyzer-flips toward flat and coasts as a low laser line | Continues turning into a roller when the envelope permits it |

For RHBH/LHFH, the overstable finish is left and the understable turn is right;
RHFH/LHBH mirrors those directions. This relationship, rather than a specific
real-world mold comparison, is the arena tuning contract.

## Deterministic distance-driver expectation

The beat-in distance driver should deterministically flip from a maximum-power
hyzer release toward flat within a defined, validated release envelope. On a
flat release it should begin straight and become a turning S line; on an
anhyzer release it should continue into a roller. Deterministic means the same
disc data, throw command, environment, and simulation tick produce the same
trajectory; it does not mean every possible hyzer angle or wind condition yields
the same laser-like line.

Implement this through data-driven aerodynamics and an explicit validation
envelope, not randomness, animation, or a hidden "flip to flat" correction.

## Prototype distance-driver asset

`data/discs/prototype_distance_driver.tres` is the Flight Lab's current
distance-driver configuration. It owns only physical disc configuration and
references the shared `prototype_distance_driver_aerodynamics.tres` profile; it
does not add a disc-specific flight script or arena behavior. Its stated flight
character is a design target, not a validated release-envelope guarantee. The
current authored regression envelope distinguishes an 8° clean full-flight line
from a materially shorter 20° hyzer fade line at the same 60 mph launch speed,
and bounds the 0° and −10° releases against repeated roll reversals.

## Ol Reliable prototype asset

`data/discs/ol_reliable.tres` is a fictional, data-only flippy distance driver.
It shares the physical geometry of the prototype driver but references an
independent aerodynamic resource. Its positive high-speed moment flips an 8°
hyzer release past flat; its bounded negative low-speed moment curve then
produces one fading reversal. The stated behavior is limited to its tested 60
mph fixture and is not a representation of, or data copied from, a real disc
mold.

## Tuning rules

- All flight and arena behavior values must be inspectable configuration.
- Keep generic projectile rules reusable; molds opt into or override them with
  data where appropriate.
- Treat disc-golf flight descriptions as desired flight character, not as a
  substitute for measured data. Arcade profiles may be fictional, but their
  expected line family and release envelope must be testable.
- Validate mold changes against repeatable throw scenarios before treating them
  as balance changes.

## Related documents

- `docs/flight-model.md` defines the simulator's current units and limitations.
- `docs/arena-shooter.md` defines projectile lifecycle, collision, and preview
  requirements.
