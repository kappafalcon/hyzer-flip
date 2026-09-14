# Hyzer-Flip Arcade Disc Flight Model

## Status and authority

This document is the target flight-model contract for the
`feature/flight_model_v2` branch. New v2 design and implementation work must
follow this contract.

[`arcade_flight_prototype.gd`](../scripts/flight/arcade/arcade_flight_prototype.gd)
is the currently executable subset of this design. Its two airborne phases are
implemented and deterministically exercised. The prototype includes a
pitch-gated, per-profile powered-flight carry calibration; ground contact,
skip, roll, stop/slide, and the proposed production data shape remain design
targets unless the code and validation say otherwise.

[`flight-model.md`](flight-model.md) records the legacy flight implementation
during migration. It may explain existing code, but it does not override this
target contract.

## Purpose

This document defines the projectile flight model for an arcade-style arena shooter built around disc-golf shot shaping.

The goal is **not to reproduce full disc aerodynamics**. The goal is to reproduce the *readable behavior* of disc golf in a deterministic, tunable projectile system suitable for competitive multiplayer.

A player should be able to learn a disc the same way a player learns a weapon in an arena shooter: the same disc, release parameters, and game state should produce the same trajectory.

The defining gameplay idea is:

> **Shot shape is the weapon system.**

Players should be able to intentionally throw hyzer-flips, turnovers, hooks, skips, rollers, and shaped shots around cover rather than relying on unpredictable rigid-body aerodynamics.

---

## Design Principles

1. **Deterministic** — identical inputs produce identical results.
2. **Readable** — players can understand why a disc flew the way it did.
3. **Skill-expressive** — release angle, velocity, disc selection, and terrain interaction create meaningful mastery.
4. **Arcade-first** — believable disc-golf behavior matters more than physical accuracy.
5. **Multiplayer-friendly** — the simulation should be simple enough to reproduce consistently at a fixed timestep.
6. **Data-driven** — molds can have distinct flight personalities without requiring different physics implementations.
7. **Continuous** — transitions between flight states must preserve velocity and orientation rather than resetting the projectile.

---

## High-Level State Model

The disc uses one deterministic simulation with state-dependent forces and rules.

```text
THROW / RELEASE
      |
      v
POWERED_FLIGHT (pre-apex)
      |
      v
APEX TRANSITION
      |
      v
LATE_FLIGHT (post-apex)
      |
      v
GROUND CONTACT
   /    |    \
  v     v     v
SKIP   ROLL  STOP/SLIDE
```

`POWERED_FLIGHT` and `LATE_FLIGHT` are not separate simulators. They are states within the same flight simulation. Position, velocity, orientation, angular state, and other relevant values carry continuously across state transitions.

---

# 1. Release

A throw initializes the disc's flight state.

Important release parameters can include:

- Initial position
- Initial velocity / throw power
- Throw direction
- Vertical launch angle
- Roll/release angle (hyzer, flat, anhyzer)
- Disc mold/data
- Optional throw modifiers or character abilities

The release establishes the initial trajectory. After release, the projectile follows deterministic rules rather than player steering.

---

# 2. Powered Flight / Pre-Apex

Powered flight represents the high-energy portion of the throw before the disc reaches its apex.

This is where the majority of intentional shot shaping occurs.

## Core behavior

The state processes standard arcade-projectile movement plus controlled disc-specific turning behavior.

Relevant influences may include:

- Initial/incoming velocity
- Gravity or authored vertical force
- Release roll angle
- Turn tendency
- Turn resistance / stability
- Carry/glide behavior

### Fade is disabled during powered flight.

This is an intentional gameplay simplification.

Real disc aerodynamics do not literally separate turn and fade at the apex, but doing so creates trajectories that are easier to predict, tune, balance, and master.

## Turn Tendency

`turn_tendency` represents how strongly a disc wants to rotate toward anhyzer during powered flight.

Higher turn tendency can cause:

- Hyzer -> flat
- Hyzer -> flat -> anhyzer
- Flat -> anhyzer
- Anhyzer -> increasingly steep anhyzer / potential roller setup

## Turn Resistance / Stability

`turn_resistance` represents how strongly the mold resists powered-flight turnover.

Keeping turn tendency and resistance conceptually separate provides more tuning space than making one value represent both behaviors.

Example:

| Disc Type | Turn Tendency | Turn Resistance | Expected Powered Flight |
| --- | --- | --- | --- |
| Utility driver | Low | Very high | Holds hyzer strongly |
| Stable driver | Medium | Medium | Hyzer-flips toward flat |
| Beat/understable driver | High | Low | Flips and continues turning |

The exact implementation may combine these values mathematically, but mold data should preserve their conceptual distinction.

A mold may additionally target flat during powered flight after a positive
hyzer release. This is an authored hyzer-flip hold for laser-style shots, not
early fade: it must retain the release-bank context, stop at flat rather than
continuing into anhyzer, and leave flat and anhyzer releases on their normal
powered-turn paths.

## Why this matters for combat

A learned trajectory becomes a combat tool.

For example, an understable disc released on hyzer might reliably:

1. Begin left of the target line.
2. Flip toward flat.
3. Continue turning around an obstacle.
4. Strike a player behind cover.

The player is rewarded for knowing the projectile's authored shot shape rather than reacting to random aerodynamic behavior.

---

# 3. Apex Transition

The apex is the transition between powered flight and late flight.

The transition should preferably come from the disc's vertical trajectory rather than a hard-coded traveled distance.

A simple deterministic condition is approximately:

```text
previous_vertical_velocity > 0
current_vertical_velocity <= 0
```

This allows upward, level, and downward throws to behave naturally relative to their trajectories.

## Glide / Carry

A mold's `glide` or `carry` value should influence **how the disc reaches the apex**, rather than simply defining "fade begins after X meters."

Possible effects include:

- Reduced effective descent while the disc has sufficient speed
- Longer vertical carry
- Slower loss of altitude
- A modifier to the authored vertical trajectory

The implementation can remain deliberately arcade-like as long as it is deterministic.

### Current prototype calibration

The executable prototype represents carry with a per-profile gravity multiplier
while a release is rising in `POWERED_FLIGHT`. It applies only to shallow,
positive launch pitches (currently `> 0°` through `12°`), so a normal shallow
throw gains readable carry while steeper releases retain their established
ballistic envelope. The multiplier is local prototype calibration, not a
production Resource schema or real-world aerodynamic coefficient. Full gravity
resumes in `LATE_FLIGHT` after the continuous vertical-velocity apex crossing.
The current player-lab charge envelope is 17.05 m/s at zero charge, 22.00 m/s
at half charge, and 26.95 m/s at full charge.

The apex transition does **not** reset velocity, orientation, turn state, or momentum.

---

# 4. Late Flight / Post-Apex

Late flight begins after the apex.

It receives the complete incoming state produced by powered flight and introduces forces/behaviors associated with the end of a disc's flight.

Relevant influences include:

- Incoming velocity
- Incoming roll/orientation
- Existing turn state
- Gravity/descent
- Fade
- Mold-specific late-flight behavior

## Fade

Fade becomes active during late flight.

`fade` represents the disc's tendency to bank/hook back toward its fading direction as its flight resolves.

This creates predictable interactions between early turn and late fade.

Example: a beat-in driver may turn during powered flight but possess only modest fade. If it enters late flight already at a steep anhyzer orientation, its fade may be insufficient to recover before ground contact. The result can naturally become a roller.

An overstable utility driver may enter late flight on hyzer and have strong fade, producing a hard hook followed by an aggressive ground impact suitable for skipping.

---

# 5. Visual Banking / Orientation

The disc's visible orientation should evolve continuously throughout flight, including powered flight.

A disc following:

```text
20° hyzer -> flat -> 30° anhyzer
```

should visually rotate through those orientations.

The mesh orientation is important gameplay feedback: players should be able to look at a disc and understand its current flight state and likely ground interaction.

This does not require full rigid-body aerodynamic torque. Orientation can be a deterministic representation of the projectile's turn/bank state.

---

# 6. Ground Contact

Ground contact determines the next state from the disc's actual impact conditions.

The simulation should consider values such as:

- Impact velocity
- Horizontal speed
- Vertical speed
- Disc roll/bank angle
- Impact angle relative to the surface
- Surface normal
- Mold skip factor
- Mold roll behavior
- Optional surface material

The primary ground states are:

- `SKIP`
- `ROLL`
- `STOP/SLIDE`

Ground behavior should **not** be selected simply because `fade > turn resistance` or vice versa. Turn and fade determine the incoming flight; the resulting physical orientation and velocity at impact determine the ground response.

---

# 7. Skip State

A skip generally occurs when a disc reaches a surface with sufficient speed and an orientation suitable for deflection.

The mold modifies that response through a `skip_factor` or equivalent property.

Example archetypes:

- Beaded putter: low skip factor; absorbs ground contact and stops quickly.
- Neutral midrange: moderate skip factor.
- Utility driver: high skip factor; produces long, aggressive skips.

Because this is an arcade shooter, skips may intentionally exaggerate real physics.

A possible gameplay mechanic is **skip boost**, where a correctly executed skip preserves or even increases projectile speed. This creates intentional bank-shot tech: skilled players can use the floor or terrain to attack from unexpected angles.

---

# 8. Roll State

A roll occurs when the disc reaches the ground on an edge/orientation capable of converting its remaining momentum into rolling motion.

An understable disc that turns deeply onto anhyzer and fails to fade out can naturally enter this state.

Roll behavior can depend on:

- Incoming velocity
- Roll angle at impact
- Disc mold
- Surface slope
- Surface material
- Remaining energy

The velocity from flight should carry into the roll rather than being replaced with a fixed rolling speed.

This allows intentional roller attacks underneath or around cover.

---

# 9. Stop / Slide State

Not every disc should skip or roll.

Low-speed or relatively flat impacts can enter a stop/slide response.

This is especially useful for putters and other low-ground-play projectiles. A mold can be deliberately designed to "stick" near its impact location rather than producing large secondary movement.

---

# 10. Suggested Mold Data

The exact data model can evolve, but a disc mold may eventually expose values similar to:

```text
speed
carry / glide
turn_tendency
turn_resistance
fade
skip_factor
roll_factor
```

Additional values should only be added when they create a meaningful gameplay or tuning distinction.

Avoid reproducing real-world aerodynamics merely for realism. Every parameter should justify itself through predictable projectile behavior, player readability, or balancing needs.

---

# 11. Example Disc Archetypes

## Neutral Putter

- Low speed
- Low turn
- High controllability
- Mild fade
- Very low skip
- Low roll potential

Combat identity: short-range precision projectile that tends to stay where it lands.

## Neutral Midrange

- Medium speed
- Moderate turn resistance
- Low/moderate fade
- Moderate glide

Combat identity: predictable general-purpose projectile.

## Beat-In Driver

- High speed
- High turn tendency
- Low/moderate turn resistance
- Low/moderate fade

Combat identity: high-skill shaping projectile capable of hyzer-flips, turnovers, curved attacks, and rollers.

## Utility Driver

- High speed
- Low turn tendency
- Very high turn resistance
- High fade
- Very high skip factor

Combat identity: hard-hooking projectile used for corners, aggressive ground skips, and reliable directional shots.

---

# 12. Determinism Requirements

The flight model is intended for competitive multiplayer and should be designed around deterministic simulation from the beginning.

At minimum:

- Use a fixed simulation timestep.
- Avoid uncontrolled random forces.
- Keep flight behavior derived from explicit state and mold data.
- Ensure state transitions use deterministic thresholds.
- Preserve state across transitions.
- Treat special abilities as explicit modifiers rather than hidden physics changes.

Given the same:

```text
Disc Data
+ Throw Parameters
+ Starting Transform
+ Environment/Collision State
+ Simulation Step
```

the game should attempt to produce the same result.

---

# 13. What This Model Is Not

This is **not** intended to be a scientifically accurate disc-flight simulator.

It does not need to reproduce every aerodynamic interaction involving:

- Lift coefficients
- Drag coefficients
- Reynolds number
- Gyroscopic precession
- Spin decay
- Angle-of-attack-dependent torque
- Full rigid-body aerodynamic forces

Those systems may produce realism, but they also introduce tuning complexity and behavior that can work against competitive projectile readability.

Real disc golf is the inspiration and visual language, not a constraint on the simulation.

---

# 14. Core Gameplay Philosophy

The final test for a flight mechanic is not:

> "Is this exactly what a real disc would do?"

It is:

> "Can a player understand, learn, reproduce, and intentionally exploit this behavior?"

A beginner should be able to throw a disc directly at an opponent.

An experienced player should be able to know that a particular disc, released at a particular angle and power, will flip around a wall, fade into a lane, skip from the floor, or turn into a roller underneath cover.

That difference in knowledge and execution is the intended skill ceiling.

**Shot shape is the weapon system.**
