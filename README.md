# Hyzerflip

Hyzerflip is an experimental disc golf game built in Godot, with a focus on physically simulated disc flight.

The flight system aims to model recognizable disc golf behavior—hyzer, turn, fade, spin, nose angle, and aerodynamic stability—while remaining deterministic enough for competitive gameplay.

## Project Structure

```text
hyzer-flip/
├── data/
│   └── discs/
│
├── docs/
│
├── scenes/
│   ├── disc/
│   ├── flight_lab/
│   └── flight_range/
│
├── scripts/
│   ├── disc/
│   ├── flight/
│   ├── throw/
│   └── ui/
│
└── project.godot
```

### `data/`

Contains Godot resources representing game data.

```text
data/
└── discs/
    ├── beat_in_destroyer.tres
    ├── test_aerodynamics.tres
    ├── test_disc.tres
    └── wraith_aerodynamics.tres
```

Disc properties are stored separately from the code that operates on them. This allows different discs and aerodynamic profiles to use the same underlying flight simulation.

---

### `scenes/`

Contains Godot scenes (`.tscn`).

```text
scenes/
├── disc/
│   └── disc.tscn
│
├── flight_lab/
│   └── flight_lab.tscn
│
└── flight_range/
    └── flight_range.tscn
```

#### `disc/`

Contains the physical disc scene used during simulation.

#### `flight_lab/`

Contains scenes used to test and visualize disc flight.

The Flight Lab provides a controlled environment for experimenting with throw parameters and aerodynamic behavior without requiring the rest of the game.

#### `flight_range/`

Contains a visual flight-range measurement scene. It stops the prototype disc
at its first ground-plane crossing and displays the horizontal release-to-impact
distance; it does not model bounce, skip, or roll.

---

### `scripts/`

Contains the project's GDScript source code, organized by responsibility.

```text
scripts/
├── disc/
│   ├── aerodynamic_data.gd
│   ├── disc.gd
│   └── disc_data.gd
│
├── flight/
│   ├── flight_simulator.gd
│   └── flight_state.gd
│
├── throw/
│   └── throw_parameters.gd
│
└── ui/
    ├── flight_lab.gd
    └── flight_range.gd
```

#### `disc/`

Defines the disc itself and the data used to describe its physical and aerodynamic characteristics.

* **`disc.gd`** — behavior associated with the physical disc object.
* **`disc_data.gd`** — physical properties and configuration of a disc.
* **`aerodynamic_data.gd`** — aerodynamic characteristics used by the flight model.

#### `flight/`

Contains the core flight simulation.

* **`flight_state.gd`** — represents the current state of a flying disc.
* **`flight_simulator.gd`** — advances the flight state through the simulation and applies the aerodynamic model.

The simulator operates incrementally: each simulation step takes the current state of the disc, evaluates the forces acting on it, and advances it through a small amount of simulation time.

Keeping the simulator separate from the disc object makes the flight model easier to test, reason about, and eventually reproduce across multiplayer clients.

#### `throw/`

Handles the transition between player input and the beginning of a simulated flight.

* **`throw_parameters.gd`** — describes the initial conditions of a throw, such as release speed, spin, and release angles.

This separates **how a disc is thrown** from **what happens to it after release**. A
future gameplay controller will own input collection; it should not be part of the
flight simulation itself.

#### `ui/`

Contains scripts associated with development and gameplay interfaces.

* **`flight_lab.gd`** — controls the Flight Lab interface and passes test parameters into the throw/flight systems.
* **`flight_range.gd`** — controls the visual ground-distance measurement scene.

---

### `docs/`

Contains development notes and supporting project documentation.

```text
docs/
├── architecture.md
├── arena-shooter.md
├── disc-molds.md
└── flight-model.md
```

---

## Architecture

The disc flight pipeline is intentionally separated into a few distinct concepts:

```text
Throw Parameters
       │
       ▼
Initial Flight State
       │
       ▼
Flight Simulator
       │
       ▼
Updated Flight State
       │
       ▼
     Disc
```

This separation is intended to keep the physics system independent from player controls, UI, and eventually networking.

## Design Goals

The flight system is being developed around several principles:

* **Physics-driven** — disc trajectories emerge from the simulation rather than predefined flight paths.
* **Deterministic** — identical initial conditions should produce identical trajectories.
* **Learnable** — players should be able to understand and master how discs react to different releases.
* **Disc-specific** — different discs can have distinct aerodynamic characteristics without requiring separate flight code.
* **Scalable** — the simulation architecture should support many discs and eventually multiplayer gameplay.
* **Gameplay-first realism** — real disc aerodynamics inform the model, while repeatability and competitive gameplay remain priorities.

## Development

Hyzerflip is currently in early development. The primary focus is building and validating the core disc-flight simulation before expanding the surrounding game systems.
