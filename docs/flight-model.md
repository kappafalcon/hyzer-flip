# Flight Model

## Purpose and status

Hyzer Flip is developing a physically informed disc-flight simulator that can
later support deterministic gameplay. The current implementation is an early
prototype, not a validated or network-authoritative model. This document records
the current behavior and the conventions future changes must preserve or
explicitly replace.

## Units and conventions

The flight model uses SI units internally.

| Quantity | Unit | Current source |
| --- | --- | --- |
| Position and diameter | metres (m) | `Node3D` position; `DiscData.diameter` |
| Mass | kilograms (kg) | `DiscData.mass` |
| Velocity | metres per second (m/s) | `FlightState.velocity` |
| Acceleration | metres per second squared (m/s²) | derived in `FlightSimulator` |
| Force | newtons (N) | derived in `FlightSimulator` |
| Moment | newton metres (N·m) | `calculate_pitching_moment` |
| Moment of inertia | kg·m² | `DiscData` inertia values |
| Spin rate | radians per second (rad/s) | `FlightState.spin_rate` |
| Aerodynamic lookup angle | degrees in data; radians in code | `AerodynamicData` converts on lookup |

Player- and lab-facing throw speed is supplied in mph, and spin in rpm.
`ThrowParameters` converts both at construction. Launch, release, and nose
angles are supplied in degrees and converted only where required.

Godot's world uses +Y as up. The current disc normal is the local +Y axis
(`FlightState.orientation.y`); the launch velocity points along local -Z with a
+Y component for launch angle. These conventions are implementation details of
the prototype and must be stated explicitly before they are changed.

## Current prototype behavior

`Disc` owns the presentation and advances the flight simulation in
`_physics_process`. `FlightState` currently contains velocity, spin rate, and
orientation; position remains on the `Node3D`.

`scenes/flight_range/flight_range.tscn` is a lab-only visual measurement scene.
It observes each presentation segment emitted by `Disc`, finds the first swept
crossing of the horizontal plane at world `y = 0`, stops the presentation at
that interpolated point, and displays the release-to-impact horizontal distance.
This is not solver-owned collision state and does not implement bounce, skip,
roll, or any arena projectile rule.

For each simulation step, `FlightSimulator`:

1. Computes speed and an angle of attack from velocity and the disc normal.
2. Looks up lift, drag, and pitching-moment coefficients from `AerodynamicData`.
3. Calculates lift, drag, gravity, and a pitching moment using dynamic pressure
   `q = 0.5 * rho * speed²` and disc planform area.
4. Converts pitching moment to a gyroscopic roll rate, then rotates the disc
   orientation around the current roll axis.
5. Updates velocity from the net force. `Disc` then advances its position from
   that velocity.

The current `apply_turn` and `apply_spin_decay` helpers are not invoked by
`step`; the effective prototype behavior therefore has no heuristic turn and no
spin decay.

## Explicit limitations

- Air velocity is currently the world velocity: there is no wind or sideslip.
- The integration timestep comes directly from Godot physics processing; a
  fixed simulation tick and convergence tests are not yet implemented.
- There is no solver-owned collision, ground interaction, terminal-flight
  state, or replay serialization. The Flight Range's presentational ground
  measurement is not an authoritative collision implementation.
- `FlightState` is not yet a complete standalone simulation state because it
  does not carry position or tick/time.
- Aerodynamic tables have no provenance, validation, or explicit valid-angle
  range beyond their current interpolated values.

Do not conceal these limitations with gameplay heuristics. Any improvement must
either resolve one deliberately or remain clearly marked as a prototype.

## Research reference

The initial physical reference is Giljarhus, Gooding, and Njærheim (2022),
"Disc golf trajectory modelling combining computational fluid dynamics and rigid
body dynamics," *Sports Engineering*.

The study derives lift, drag, and pitching moment from aerodynamic coefficient
curves and transforms air velocity through disc, zero-sideslip, and wind axes.
It models gyroscopic precession from pitching moment and uses explicit
Runge-Kutta integration. Future fidelity work should compare its assumptions
with this document before changing force or attitude calculations.

Source: <https://link.springer.com/article/10.1007/s12283-022-00390-5>
