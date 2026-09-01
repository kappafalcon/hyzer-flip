# Architecture

## Purpose

Hyzer Flip uses a deterministic, authored arcade flight model. The arcade
flight lab is the project entry scene and the current player-facing test space;
future arena gameplay will build on the same command, simulation, and state
boundaries.

## Flight-model migration status

`docs/flight-model-v2.md` is the target contract for new flight-model work on
this branch. `scripts/flight/arcade/arcade_flight_prototype.gd` is its currently
executable subset: it implements deterministic powered and late airborne phases,
but not the target ground-contact states or production data boundary.

The `ArcadeThrowCommand` / `ArcadeFlightProfile` / `ArcadeFlightSimulator`
architecture below describes the legacy implementation that remains in the
project during migration. `docs/flight-model.md` documents that implementation;
neither it nor the current mold-authoring documents override the v2 target.

## Current project layout

```text
data/discs/                 Authored arcade mold Resources
scenes/arcade_flight_lab/   Main playable flight-lab scene
scenes/player/              Reusable player presentation and controls
scenes/ui/                  Reusable flight-lab HUD composition
scripts/flight/             Pure arcade simulation and state types
scripts/labs/               Playable flight-lab coordination and presentation
scripts/player/             Player intent collection and local presentation
tests/flight/               Deterministic arcade-flight fixture
```

`scenes/` is the canonical location for Godot scenes. `project.godot` starts
`scenes/arcade_flight_lab/arcade_flight_lab.tscn`.

## Dependency direction

```text
Player input
    |
    v
ArcadeThrowCommand ---> ArcadeFlightProfile + ArcadeFlightEnvironment
    |                                  |
    +----------> ArcadeFlightSimulator <+
                        |
                        v
                 ArcadeFlightState
                        |
                        v
     Arcade lab presentation, future collision adapter, networking
```

Dependencies flow downward. The simulator must not read player input, scene
nodes, physics-server state, rendering state, or network state. Presenters may
read explicit simulation state but never define flight rules.

## Ownership

| Concern | Owner | Notes |
| --- | --- | --- |
| Arcade mold identity | `ArcadeFlightProfile` Resources | Authored charge, phase, bank, launch-pitch, glide, and range guidance under `data/discs/` |
| Release input | `ArcadeThrowCommand` | Immutable snapshot of aim, charge, bank, pitch, origin, and fade direction |
| Arcade environment | `ArcadeFlightEnvironment` | Explicit global gravity input; no `Node` or physics-server access |
| Flight integration | `ArcadeFlightSimulator` | Pure fixed-step solver over explicit state and immutable inputs |
| Airborne state | `ArcadeFlightState` | Position, velocity, heading, orientation, bank, phase, travel, tick, and lifecycle |
| Player controls | `scenes/player/` and `scripts/player/` | Collect local input and emit an immutable throw command |
| Arcade flight lab | `scenes/arcade_flight_lab/` | Drives fixed simulation time, projects state, and may visually stop at a ground-plane crossing |
| Collision and projectile response | Future adapter | Must turn queries into explicit deterministic results outside the solver |
| Network authority | Future server simulation | Clients predict and present; they do not define results |

The lab's visual ground observation does not modify simulator state and is not
authoritative collision, bounce, skip, rolling, player contact, or despawn
logic.

## Scene rules

- Scenes compose nodes, resources, and signals; they do not own flight
  equations.
- The player owns local input and emits commands upward. The lab coordinates a
  player command with the simulation; it does not inspect player internals.
- Future arena scenes own spawning and gameplay lifecycle. The reusable player
  scene must not assume a particular lab or arena parent.
- New collision categories and projectile outcomes require a dedicated adapter
  and documented ownership before they are added.

## Documentation ownership

- `docs/flight-model-v2.md` defines the target flight behavior and explicitly
  separates implemented prototype behavior from future design targets.
- `docs/flight-model.md` records legacy simulation conventions and limitations
  while that implementation remains in the project.
- `docs/disc-molds.md` defines mold identities and data boundaries.
- `docs/arena-shooter.md` defines future projectile, round, and control
  requirements.
- This document defines scene and dependency ownership.
