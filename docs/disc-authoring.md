# Arcade Disc Authoring Contract

## Purpose

Use this contract when adding or materially retuning an arcade disc mold. Its
goal is a reviewable `ArcadeFlightProfile` asset whose intended flight can be
reproduced from explicit data, a throw command, an environment, and the fixed
simulation timestep.

This contract covers a mold's airborne flight identity only. It does not
authorize a projectile scene, collision logic, bounce or skip rules, contact
effects, inventory, or a custom script per mold.

## Before authoring

Record these decisions in the request, design note, or pull request:

| Decision | Required rule |
| --- | --- |
| Identity | Give the mold a unique, stable `profile_id`, display name, and one stability archetype: overstable, neutral, or understable. |
| Intended lines | State the three release-envelope outcomes for hyzer, flat, and anhyzer at the chosen charge and fade direction. |
| Pitch role | State how uphill and downhill launch pitch should reinforce, rather than replace, the mold's base stability. |
| Roller | Enable roller entry only when roller is part of the intended release envelope; otherwise leave the existing disabled convention in place. |
| Balance intent | State the combat role and range guidance. Range guidance informs tuning but does not end airborne flight. |

Do not select numbers solely to make a profile look different. Start from an
approved comparable profile or an explicit calibration target, label genuinely
new values as a proposal, and validate the resulting release envelope.

## Asset rules

1. Create one external text Resource at
   `data/discs/<profile_id>_arcade_draft.tres` while the mold is in draft.
   Preserve its path and `.uid` once it is referenced. A rename or promotion
   needs an intentional migration of every reference.
2. Use `ArcadeFlightProfile` as the asset's script class. Do not create a
   mold-specific GDScript, put flight coefficients in a scene, or use a
   mutable Resource as per-throw state.
3. Author every required field and curve visibly in the Resource:
   identity and stability; speed, phase, bank, heading, banked descent, pitch,
   and range limits; charge multipliers; phase speed, bank, and
   vertical-acceleration curves; and the launch-pitch stability curve. Fill in
   the profile's Inspector-visible `authoring_notes` field and retain concise
   comments beside serialized curve data so a source review does not require
   decoding Curve `_data` arrays.
4. Keep all curve domains at `0.0` through `1.0`. Charge and phase use that
   unit domain. Launch pitch is normalized from the profile's configured
   negative pitch limit through flat (`0.5`) to its positive limit. Its
   stability curve must be negative below flat (turn) and positive above flat
   (fade); validation rejects profiles that omit either signed response.
5. Keep units in SI: metres, metres/second, metres/second-squared, seconds,
   and degrees. Positive bank remains mold-relative; the command's spin
   direction performs world-side mirroring.
6. Treat `ArcadeFlightProfile` as shared immutable configuration. Put origin,
   aim, charge, release bank, launch pitch, fade direction, and runtime lifecycle in
   `ArcadeThrowCommand` and `ArcadeFlightState`.

## Flight identity rules

The profile must preserve its declared envelope under the deterministic
simulator:

| Archetype | Hyzer | Flat | Anhyzer |
| --- | --- | --- | --- |
| Overstable | Spike-hyzer | Straight-to-reliable-fade | Flex-to-flat |
| Neutral | Held gentle hyzer | Straightest line | Settles toward flat |
| Understable | Hyzer-flip-to-flat laser | Turning-S | Roller entry when configured |

Use the profile's phase bank and heading response to author the flight line.
Release bank and launch pitch are command inputs, not hidden aim correction.
Uphill pitch shifts toward fade and downhill pitch shifts toward turn, but
neither may erase the archetype's basic role. Opposite fade directions must
mirror lateral behavior for the same profile and release.

`maximum_travel_distance_meters` is balance guidance. It must not be used to
terminate airborne state. Phase completion is likewise not a despawn event.
Only an explicit lifecycle or future collision result can end flight.

## Required integration and verification

1. Let `ArcadeFlightProfile.validate()` reject incomplete or invalid authored
   data before simulation. Do not add a silent fallback profile.
2. Add the asset deliberately to the intended profile selector or owner; the
   active flight lab uses its scene-owned `available_flight_profiles` list.
   Do not make the player mutate or own the selected profile.
3. Extend `tests/flight/arcade_flight_architecture_test.gd` for every new or
   materially retuned mold. Load the external `.tres`, assert the declared
   stability and validation success, then cover its three release lines,
   pitch ordering where relevant, deterministic repeatability, and spin-side
   mirroring. Assert roller phase and bank gates only for roller-capable molds.
4. Run the deterministic fixture and the Godot editor scan. Investigate project
   parse errors; sandbox editor-setting errors are non-blocking.
5. Update `docs/disc-molds.md` with the roster entry and stated release lines.
   Update `docs/flight-model.md` only when this work changes simulation units,
   conventions, curve semantics, or validation scope. Update
   `docs/architecture.md` only when it changes ownership or authority.

## Definition of done

- The asset is external, typed, uniquely identified, and validates.
- The mold has a stated role and complete release envelope.
- Per-throw values remain outside the shared Resource.
- The same profile, command, environment, and ticks yield the same result.
- Tests cover the authored behavior; a visual lab result alone is not proof.
- Projectile gameplay remains separate until a dedicated deterministic
  collision and lifecycle boundary exists.
