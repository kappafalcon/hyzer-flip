# Hyzer Flip

Hyzer Flip is a Godot disc-golf arena prototype built around deterministic,
authored arcade flight. The project starts in the Arcade Flight Lab, where a
first-person player can move, choose a disc profile, set release bank, charge a
throw, and inspect the resulting line.

## Project structure

```text
hyzer-flip/
├── data/discs/                 Arcade mold Resources
├── docs/                       Architecture and gameplay contracts
├── scenes/
│   ├── arcade_flight_lab/      Main scene
│   └── player/                 Reusable player scene
├── scripts/
│   ├── flight/                 Pure arcade solver, state, commands, profiles
│   ├── player/                 Player controls and presentation
│   └── ui/                     Arcade-lab presentation
├── tests/
│   └── arcade_flight_architecture_test.gd
├── AGENTS.md
└── project.godot
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
[disc molds](docs/disc-molds.md), and [arena requirements](docs/arena-shooter.md).

## Verification

Run the deterministic arcade fixture:

```sh
godot --headless --path . --script res://tests/arcade_flight_architecture_test.gd
```

Run an editor parse scan:

```sh
godot --headless --path . --editor --quit
```
