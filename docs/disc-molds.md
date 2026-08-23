# Disc Molds and Gameplay Archetypes

## Purpose

Each arcade mold has two separate concerns:

1. **Flight identity** — an `ArcadeFlightProfile` Resource under
   `data/discs/` authoring charge, phase, bank, launch-pitch stability, glide,
   steering, and combat-range guidance.
2. **Arena behavior** — future projectile configuration for bounce, skip,
   contact, damage, status effects, and similar gameplay rules.

Never create a script per mold. Release bank, launch pitch, charge, and other
per-throw inputs stay in `ArcadeThrowCommand` and `ArcadeFlightState`; shared
Resources remain immutable configuration.

## Current arcade roster

| Archetype | Profile | Intended release lines | Arena behavior |
| --- | --- | --- | --- |
| Neutral mid | `neutral_mid_arcade_draft.tres` | Flat opening stays straight into a late bite; an uphill hyzer rolls early into a weighted descent; anhyzer settles toward flat | TBD |
| Utility driver | `utility_driver_arcade_draft.tres` | Straight through apex, hyzer-amplified progressive spike-fade corner, flex-to-flat | Skip, damage, AOE, and bounce limits are TBD |
| Beat-in distance driver | `beat_in_distance_driver_arcade_draft.tres` | Maximum-power hyzer-flip laser, turning-S, roller entry | Projectile contact behavior is TBD |

For left-fading throws, overstable finish is left and understable turn is right.
Right-fading throws mirror those results.

## Tuning rules

- Keep mold values inspectable in `ArcadeFlightProfile` Resources.
- Preserve the documented release matrix: overstable spike/fade/flex, neutral
  held-hyzer/straight/settling-anhyzer, and understable flip/turn/roller-entry.
- Treat launch pitch separately from release bank. Uphill shifts a profile
  toward fade; downhill shifts it toward turn without replacing its base role.
- Validate the full release envelope through the deterministic arcade fixture
  whenever a profile change alters a mold's stated identity.
- Keep projectile interaction rules separate from flight identity until a
  dedicated projectile configuration and collision adapter exist.

## Authoring workflow

Use the [arcade disc authoring contract](disc-authoring.md) when adding or
materially retuning a mold. It defines the required design decisions, external
Resource rules, deterministic verification, and integration checklist. This
document remains the roster and archetype specification; the contract is the
repeatable creation workflow.
