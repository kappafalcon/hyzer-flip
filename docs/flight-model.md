# Arcade Flight Model

## Purpose and status

Hyzer Flip uses a deterministic, disc-golf-inspired arcade flight model. It is
gameplay-authored rather than a claim of measured aerodynamic fidelity: every
throw should be readable, repeatable, and tunable through explicit profile
data. The arcade flight lab is the current playable harness and project entry
scene.

## Units and conventions

The simulation uses SI units internally.

| Quantity | Unit | Owner |
| --- | --- | --- |
| Position, travel distance | metres (m) | `ArcadeFlightState` |
| Velocity | metres per second (m/s) | `ArcadeFlightState` |
| Acceleration and gravity | metres per second squared (m/s²) | `ArcadeFlightEnvironment` and profile curves |
| Simulation time | seconds (s) | `ArcadeFlightState` |
| Simulation tick | integer | `ArcadeFlightState` |
| Bank and launch pitch | degrees | `ArcadeThrowCommand` and `ArcadeFlightProfile` |

Godot world +Y is up. Arcade horizontal forward uses the project's -Z
convention. Positive bank produces leftward fade; the opposite fade direction
mirrors that lateral behavior.

## Flight contract

The current flight-lab calibration keeps full-charge, 2° shallow-uphill throws
under 100 ft and reaches the visual ground plane within 0.9 seconds (0.8
seconds for the utility driver).
Profile range guidance informs balance but does not terminate an airborne
state. Flight identity is entirely authored in `ArcadeFlightProfile` Resources:

| Flight identity | Hyzer release | Flat release | Anhyzer release |
| --- | --- | --- | --- |
| Overstable | Spike-hyzer line | Straight-to-reliable-fade line | Controlled flex-to-flat line |
| Neutral | Held gentle hyzer | Straightest line | Controllable anhyzer settling toward flat |
| Understable | Maximum-power hyzer-flip laser | Turning-S line | Roller-entry line when configured |

Release bank chooses the initial hyzer or anhyzer line. Launch pitch is a
separate signed stability modifier: downward shifts a profile toward turn and
upward shifts it toward fade. Both are bounded, inspectable profile behavior;
neither is hidden aim correction. Every valid profile must apply a signed
launch-pitch bias: all sampled downhill pitches add turn and all sampled uphill
pitches add fade. Profiles that omit either response are rejected before
simulation.

## Simulation ownership

`ArcadeFlightSimulator` is a pure fixed-step solver. It accepts explicit
`ArcadeFlightState`, immutable `ArcadeFlightProfile`,
`ArcadeFlightEnvironment`, and timestep inputs; it returns an explicit next
state without mutating its input. A high-throughput caller can supply a
distinct preallocated output state to `step_into()` and double-buffer it per
projectile to avoid per-tick allocations. It does not read or modify `Node`,
transform, input, renderer, physics-server, or network state.

The intended timestep is `ArcadeFlightSimulator.FIXED_TIMESTEP_SECONDS`
(120 Hz). A caller may accumulate engine time, but render-frame timing must not
change a trajectory.

Profile curves use unit charge and phase input domains. Flight phase clamps at
`1.0` and continues sampling terminal curve values while the disc remains
airborne. Phase completion and combat-range guidance do not end flight; an
explicit collision or lifecycle result must do that.

Heading curvature is a bounded steering impulse. The current solver scales it
by the squared remaining phase, so hard-fading or lofted discs cannot continue
turning until they boomerang back toward release after phase completion. Bank
continues to orient the disc toward its turn/fade side and reduces vertical
glide support by its cosine. A profile can additionally author a banked descent
acceleration; it scales with bank magnitude to pull a spike-fading mold toward
the ground after its apex without changing its unbanked launch. Positive launch
pitch strengthens that banked descent, so an uphill hyzer can form an arc before
falling through its late fade rather than drifting sideways in the sky.

## Collision boundary and limitations

The current simulator owns airborne movement only. It has no authoritative
collision queries, ground interaction, bounce, skip, rolling, player contact,
despawn, wind, replay serialization, or network authority. The arcade lab may
visually stop a disc at its horizontal ground-plane crossing, but that is only
presentation. A future fixed-step collision adapter must query the completed
airborne segment and return explicit projectile/lifecycle results.

## Verification

`tests/flight/arcade_flight_architecture_test.gd` is the deterministic fixture. It
checks profile validation, finite repeatable state, pitch stability ordering,
phase/range non-termination, mirrored lateral behavior, visual ground-plane
arrival-time and range caps, and the current overstable, neutral, and
understable release envelopes. It is a regression fixture for authored arcade
behavior, not real-world-distance validation.
