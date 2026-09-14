---
name: hyzer-flip-v2-data-resources
description: Design or review Hyzer Flip flight-model-v2 Godot Resource data. Use for mold parameters, projectile configuration, validation, or tunable balance values; not for per-throw runtime state or legacy v1 phase-curve tuning.
---

# Hyzer Flip V2 Data Resources

Read `docs/flight-model-v2.md` first. It is the target contract;
`scripts/flight/arcade/arcade_flight_prototype.gd` is only its executable subset.
Read `docs/architecture.md` for current ownership and migration status. Treat
the data shapes in `docs/flight-model.md`, `docs/disc-authoring.md`, and
`docs/disc-molds.md` as legacy context when they conflict with v2.

## Ownership

- Keep authored mold and balance data in typed, inspectable Godot `Resource`
  assets under `data/discs/` once the production v2 schema exists. Do not copy
  the prototype's inline `DiscParameters` packaging into production.
- Treat shared Resources as immutable. Release position, velocity, direction,
  launch pitch, release bank, temporary modifiers, tick, phase, orientation,
  and lifecycle belong to explicit command or runtime state.
- Keep one data type or composition of Resources for shared behavior; never add
  a script per mold.
- Separate mold identity factors from collision and lifecycle rules. A mold may
  expose `skip_factor` or `roll_factor` when the schema deliberately adopts
  them, while the actual impact classifier, bounce limits, damage, and effects
  remain projectile behavior.

## V2 data semantics

- Preserve distinct authored meanings for `turn_tendency`, `turn_resistance`,
  and `fade`. Turn tendency and resistance shape powered flight; fade is a
  late-flight input and cannot affect powered flight.
- Treat speed and carry/glide, plus skip and roll factors, as proposed target
  fields until their production behavior and units are implemented and tested.
  Do not claim the prototype's three coefficients are a finished schema.
- Treat a production v2 schema as available only when a typed Resource is
  consumed by the authoritative v2 path and its validation is exercised. A
  draft class or serialized field alone does not establish the contract.
- Do not carry forward mandatory unit-phase curves, phase completion, signed
  launch-pitch stability curves, or old range calibration unless the v2
  contract explicitly adopts them.
- Keep SI units and coordinate conventions explicit at the data boundary. Do
  not assume arcade strength coefficients are normalized to `0.0..1.0`.

## Validation and change discipline

- Validate required identifiers and links, finite values, documented ranges,
  compatible units, and any array or curve domains before simulation. Reject
  invalid authored data instead of silently substituting a fallback trajectory.
- Keep schema or gameplay-data versions explicit when replays, clients, or
  servers must agree. Make serialized meaning changes deliberate migrations.
- Do not invent numeric tuning or promote suggested fields merely to complete a
  task. Mark proposals and validate them against an intended release envelope.
- Update `docs/flight-model-v2.md` when the target data contract changes and
  `docs/disc-molds.md` when a mold identity or arena behavior changes. Use
  `$hyzer-flip-v2-disc-authoring` for new or materially retuned molds and
  `$hyzer-flip-v2-testing` for deterministic coverage.
