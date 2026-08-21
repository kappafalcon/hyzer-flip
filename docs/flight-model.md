# Flight Model

## Purpose and status

Hyzer Flip is developing a deterministic, disc-golf-inspired flight simulator
for a Flight Lab and an arcade arena shooter. Physical aerodynamics inform the
prototype, but arena flight is gameplay-authored: it must be readable,
repeatable, and satisfying before it is field-distance accurate. The current
implementation is an early prototype, not a validated real-world or
network-authoritative model. This document records the current behavior and the
conventions future changes must preserve or explicitly replace.

## Units and conventions

The flight model uses SI units internally.

| Quantity | Unit | Current source |
| --- | --- | --- |
| Position and diameter | metres (m) | `Node3D` position; `DiscData.diameter` |
| Mass | kilograms (kg) | `DiscData.mass` |
| Velocity | metres per second (m/s) | `FlightState.velocity` |
| Wind velocity | metres per second (m/s) | `FlightEnvironment.wind_velocity` |
| Air-relative velocity | metres per second (m/s) | `FlightEnvironment.get_air_velocity` |
| Acceleration | metres per second squared (m/s²) | derived in `FlightSimulator` |
| Force | newtons (N) | derived in `FlightSimulator` |
| Moment | newton metres (N·m) | `calculate_pitching_moment` |
| Moment of inertia | kg·m² | `DiscData` inertia values |
| Spin rate | radians per second (rad/s) | `FlightState.spin_rate` |
| Legacy spin decay rate | radians per second squared (rad/s²) | `DiscData.spin_decay_rate` |
| Aerodynamic spin damping | dimensionless | `DiscData.aerodynamic_spin_damping` |
| Simulation time and tick | seconds (s), integer tick | `FlightState` |
| Aerodynamic lookup angle | degrees in data; radians in code | `AerodynamicData` converts on lookup |
| Aerodynamic stability references | metres per second (m/s) | `AerodynamicData` high-/low-speed moment interpolation |

Player- and lab-facing throw speed is supplied in mph, and spin in rpm.
`ThrowParameters` converts both at construction. Launch, release, and nose
angles are supplied in degrees and converted only where required.

Godot's world uses +Y as up. The current disc normal is the local +Y axis
(`FlightState.orientation.y`); the launch velocity points along local -Z with a
+Y component for launch angle. These conventions are implementation details of
the prototype and must be stated explicitly before they are changed.

## Arena flight contract

Arena balance is not a claim about real disc-golf distance, impact physics, or
measured aerodynamic coefficients. The desired effective combat space is
roughly 100–200 ft; a disc may continue beyond that distance, but it must not
become a dependable long-range moving-target attack merely because the Flight
Lab profile travels farther.

Each arena mold must expose its flight identity as authored data and validate a
bounded release envelope. Do not implement these identities through a
disc-specific script, presentation correction, or an untracked late-flight
torque.

| Flight identity | Required readable lines |
| --- | --- |
| Overstable | A flat release finishes consistently to its natural finish side; a hyzer release holds into a spike-hyzer line; an anhyzer release may flex before that same reliable finish. |
| Understable | A hyzer release flips toward flat and coasts as a long, low "laser" line; a flat release turns to its natural turn side; an anhyzer release continues turning into a roller when its configured release envelope permits it. |

"Natural finish side" and "natural turn side" are mirrored by spin direction:
RHBH and LHFH throws finish left with an overstable disc and turn right with an
understable disc; RHFH and LHBH throws mirror those directions. This makes the
same line families available to backhand and forehand players through disc
selection and release angle, rather than through aim-assist corrections.

The Flight Lab may retain long-range reference profiles for experimentation.
Those profiles are not the arena balance target. Arena collision behavior
(bounce, skip, energy retention, break, and contact assistance) remains an
explicit projectile rule separate from aerodynamic flight identity.

## Current prototype behavior

`FlightState` owns position, velocity, spin rate, orientation, elapsed time,
and tick. `Disc` is a presentation adapter: it accumulates engine physics time,
advances the pure solver at an explicit 120 Hz timestep, and projects the
resulting state onto its `Node3D` transform. Launch axes are built explicitly
from the intended launch direction, nose angle, and release/hyzer angle rather
than composed through Euler angles.

`scenes/flight_range/flight_range.tscn` is a lab-only visual measurement scene.
It observes each presentation segment emitted by `Disc`, finds the first swept
crossing of the horizontal plane at world `y = 0`, stops the presentation at
that interpolated point, and displays the release-to-impact horizontal distance.
This is not solver-owned collision state and does not implement bounce, skip,
roll, or any arena projectile rule.

For each simulation step, `FlightSimulator`:

1. Computes air-relative velocity as disc velocity minus the explicit
   `FlightEnvironment` wind velocity. The default environment is still air.
2. Computes airspeed and angle of attack from air-relative velocity in the
   disc's forward/normal axes.
3. Looks up lift, drag, and pitching-moment coefficients from `AerodynamicData`.
   Each profile interpolates between high- and low-airspeed pitching-moment
   curves, so turn and fade are a bounded property of the mold rather than an
   injected late-flight torque.
4. Calculates lift, drag, gravity, and a pitching moment using dynamic pressure
   `q = 0.5 * rho * speed²` and disc planform area.
5. Converts pitching moment to a gyroscopic roll rate around the current
   zero-sideslip roll axis using spin-axis angular momentum (`I_spin × spin`).
   That signed rate is applied directly to the orientation; it must not be
   sign-inverted again at the presentation-axis boundary.
6. Evaluates these derivatives at the beginning and midpoint of the timestep,
   then advances position, velocity, and orientation with the midpoint result.

Each disc may configure a legacy constant no-wobble spin decay rate and an
aerodynamic spin-damping coefficient. The latter scales aerodynamic torque
amplitude and the current spin rate, so spin loss falls with airspeed rather
than remaining a fixed loss every second. Lower spin reduces gyroscopic
stability in the precession equation, while the mold's air-relative-speed
moment curves determine whether the resulting rotation is turn or fade. These
parameters are authored prototype calibration, not measured disc-specific
aerodynamic data.

Every `AerodynamicData` profile defines matching high- and low-speed pitching
moment curves plus their reference speeds. The stable prototype uses the same
curve at both speeds. Fictional `ol_reliable` transitions from a positive
high-speed moment to a bounded negative low-speed moment, producing a turn then
fade without an abrupt spin threshold. This is gameplay calibration, not a
measured aerodynamic claim.

## Explicit limitations

- The solver accepts constant world-space wind through `FlightEnvironment` and
  uses it in all aerodynamic calculations. There are no player-facing wind
  controls, wind fields, gusts, terrain effects, or validated sideslip data yet.
- The solver has a fixed 120 Hz simulation timestep, but has not yet undergone
  a formal timestep-convergence study.
- There is no solver-owned collision, ground interaction, terminal-flight
  state, or replay serialization. The Flight Range's presentational ground
  measurement is not an authoritative collision implementation.
- Aerodynamic data is validated for finite, ordered angle samples with matching
  coefficient arrays. The current prototype distance-driver curve covers -20°
  through +20° and linearly interpolates between those samples.
- The current attitude model is a zero-sideslip gyroscopic-precession
  approximation. It does not yet simulate full three-axis angular velocity,
  wobble, or nutation. Those are the next candidates for a data-backed upgrade.

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

The angular-momentum precession denominator and aerodynamic spin-damping form
were independently adapted into GDScript after auditing the MIT-licensed
FrisPy reference implementation at commit `6fe3a7618248bbbf781b60a3abe17c17eb2c87be`.
No FrisPy source files, named-mold configurations, or coefficient data are
included. See `THIRD_PARTY_NOTICES.md`.

The current prototype distance-driver coefficients are author-authored,
unmeasured placeholder data. No aerodynamic coefficient data from the
GPL-3.0 Shotshaper repository is included. The profiles are suitable only as
prototype calibration; future arena profiles may be deliberately fictional as
long as their gameplay intent and validation envelope are documented. See
`THIRD_PARTY_NOTICES.md` for the CC BY 4.0 research attribution.

## Reference verification

`tests/flight_determinism_test.gd` runs a calm-air prototype-driver fixture:
26.8224 m/s (60 mph), 1300 rpm, 8° release angle, 10° launch angle, 0° nose
angle, and a 1.5 m release height. It verifies finite state, ground impact,
identical range across repeated runs, and a 380–430 ft Flight Lab regression
envelope. This is a legacy long-range prototype target, not the arena range
target, and it does not establish real-world aerodynamic accuracy or use a
third-party numerical baseline.

The same fixture also checks a 20° hyzer release with all other inputs held
constant. It must repeatably land in a 250–350 ft envelope and at least 20 m
shorter than the clean reference line. This is a regression guard for the
prototype's intended late-flight fade response, not a claim that the current
curve has been experimentally validated.

The fixture additionally checks 0° and −10° releases at the same speed and
spin. Each must land within 500 ft and 7.5 seconds, and its roll-rate
direction may change no more than once. These guards specifically prevent the
previous fade-then-turn feedback loop and excessive low-to-mid-angle glide.

`tests/ol_reliable_flight_test.gd` verifies a distinct fictional distance-driver
fixture at the same speed, spin, launch, nose, and release height. Its 8° hyzer
release must land within 360–440 ft in 5.0–6.5 seconds, flip past flat, then
finish in the configured fade direction after exactly one roll-direction change
without rolling through upside down.

The prototype fixture also verifies the wind boundary at one solver step: an
explicit 5 m/s tailwind lowers air-relative speed by 5 m/s compared with an
otherwise identical still-air step. This confirms that future wind features
will affect lift, drag, angle of attack, and pitching moment through the same
pure solver input.
