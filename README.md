# Hyzer Flip

Hyzer Flip is a Godot disc-golf arena prototype built around deterministic,
authored arcade flight. The project starts in the Arcade Flight Lab, where a
first-person player can move, choose a disc profile, set release bank, charge a
throw, and inspect the resulting line.

## Project structure

The target layout below names both the current project boundaries and planned
ones. Create a future directory only when its first owned asset or system is
introduced.

```text
res://
├── assets/                     Add only when art, audio, or shaders arrive
├── data/
│   ├── discs/                  ArcadeFlightProfile Resources
│   ├── arena/                  Future round, spawn, and map config Resources
│   └── projectiles/            Future projectile-behavior Resources
├── docs/                       Durable architecture and gameplay contracts
├── scenes/
│   ├── arcade_flight_lab/      Current main, playable simulation harness
│   ├── player/                 Reusable player scene
│   ├── tests/                  Isolated visual prototype scenes
│   ├── arena/                  Future match composition and spawning
│   ├── shared/                 Reusable non-player scenes, when needed
│   └── ui/                     Reusable UI scenes
├── scripts/
│   ├── flight/                 Current pure deterministic model
│   │   └── arcade/             Isolated flight-model-v2 prototype
│   ├── player/                 Input collection and player presentation
│   ├── labs/                   Lab scene controllers
│   ├── arena/                  Future match lifecycle and spawning
│   ├── projectiles/            Future collision/query adapters and outcomes
│   └── ui/                     UI-only presenters and controls
├── tests/
│   ├── flight/                 Deterministic simulation fixtures
│   ├── arena/                  Future match-flow tests
│   └── projectiles/            Future collision/outcome tests
```

## Main scene

`scenes/arcade_flight_lab/arcade_flight_lab.tscn` is configured as the project
main scene.

Controls in the lab:

- W, A, S, D — move
- Mouse — look
- Q / E — add 5° hyzer / anhyzer release bank
- Hold and release left mouse — charge and throw

## Arcade flight architecture

`ArcadeThrowCommand` captures immutable release input. `ArcadeFlightProfile`
contains mold tuning. `ArcadeFlightSimulator` advances complete
`ArcadeFlightState` at a deterministic 120 Hz timestep with explicit gravity
from `ArcadeFlightEnvironment`. Scenes only collect input and present state;
they do not own flight rules.

The current lab visualizes a ground-plane crossing, but collision, bounce,
skip, rolling, player contact, and network authority are future explicit
systems.

See [architecture](docs/architecture.md), [flight model](docs/flight-model.md),
[disc molds](docs/disc-molds.md), [disc authoring](docs/disc-authoring.md), and
[arena requirements](docs/arena-shooter.md).

## Verification

Run the deterministic arcade fixture:

```sh
godot --headless --path . --script res://tests/flight/arcade_flight_architecture_test.gd
```

Run an editor parse scan:

```sh
godot --headless --path . --editor --quit
```

Run the isolated flight-model-v2 prototype's deterministic matrix:

```sh
godot --headless --path . --scene res://scenes/tests/arcade_flight_lab.tscn
```
