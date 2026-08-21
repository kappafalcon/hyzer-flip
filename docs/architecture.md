# Architecture

## Purpose

Hyzer Flip is being built in stages: a flight lab first, then player mechanics,
disc interactions, and eventually a multiplayer arena shooter. This document
defines the boundaries that keep those stages independently tunable.

## Current project layout

```text
data/discs/       Disc and aerodynamic Resource data
scenes/disc/      Reusable disc presentation scene
scenes/flight_lab/ Controlled flight-test scene
scenes/flight_range/ Visual ground-range measurement scene
scripts/disc/     Disc presentation and disc-data types
scripts/flight/   Flight state and flight simulation
scripts/throw/    Throw input data
scripts/ui/       Flight-lab and range UI behavior
```

`scenes/` is the canonical location for all `.tscn` files. Root-level duplicate
scenes are not part of the project structure.

## Dependency direction

```text
Player input / Flight Lab UI
            |
            v
      Throw parameters or command
            |
            v
Flight simulation <--- Disc and environment data
            |
            v
 Flight state / collision result
            |
            v
Disc scene, visuals, audio, gameplay effects, networking presentation
```

Dependencies flow downward. Flight simulation must not import or query UI,
player, scene-tree, renderer, or network state. Presenters may read simulation
state, but they must not be the source of its rules.

## Data and simulation ownership

| Concern | Owner | Notes |
| --- | --- | --- |
| Mold mass, diameter, inertia, and coefficient tables | `DiscData` and `AerodynamicData` Resources | Data, not bespoke scripts per disc |
| Release inputs | `ThrowParameters` now; a gameplay throw command later | Converts player-facing units at the boundary |
| Wind / air environment | `FlightEnvironment` | Pure world-space wind input; labs and future gameplay may supply it, but do not own aerodynamic rules |
| Aerodynamic integration | `FlightSimulator` | Pure 120 Hz midpoint solver over complete flight state |
| Scene transform and visuals | `Disc` scene | Projects `FlightState` onto the scene transform; never owns solver position |
| Lab ground-distance measurement | `scenes/flight_range/` | Observes presentation segments and stops at a horizontal ground-plane crossing; not authoritative collision |
| Flight Range disc selection | Flight Range UI | Selects an injected immutable `DiscData` resource only while the disc is idle |
| Input collection | Flight Lab or future player controller | Never belongs in the simulator |
| Collision queries and response | A dedicated gameplay/physics adapter | Must be deterministic and separate from aerodynamic forces |
| Network authority | Future server simulation | Clients predict and render; they do not define the result |

## Multiplayer direction

Multiplayer should be server-authoritative. A client sends a compact, validated
throw command; the server simulates the flight and publishes state snapshots.
Clients may predict their own throws and reconcile to server snapshots for
responsiveness.

Do not make Godot/Jolt rigid-body simulation the authoritative disc-flight
implementation. Different machines and frame timing can produce different
results. The authoritative path must instead use the same explicit simulation
state, timestep, inputs, and collision rules on every server run.

## Scene rules

- Scenes compose nodes and assets; they do not contain flight equations.
- Scripts on scenes adapt state to Godot transforms and gameplay events.
- Reusable objects live in their own scene directory and are instantiated by
  gameplay or lab scenes.
- Lab-only controls stay under `scenes/flight_lab/` and must not become a
  dependency of future player scenes.

## Documentation ownership

- `docs/flight-model.md` is the source of truth for units, coordinate
  conventions, simulation scope, and model limitations.
- This document is the source of truth for dependency direction and ownership.
- Update the applicable document in the same change whenever a listed boundary
  or convention changes.
