---
name: hyzer-flip-v2-disc-authoring
description: Add or materially retune Hyzer Flip flight-model-v2 disc molds. Use for mold identity, release envelopes, and deterministic calibration; not for collision implementation or legacy v1 phase-curve profiles.
---

# Hyzer Flip V2 Disc Authoring

Read `docs/flight-model-v2.md` before authoring. It is the target contract.
Consult `docs/disc-authoring.md` and `docs/disc-molds.md` for existing asset paths,
roster intent, and migration context only; their v1 phase curves and
launch-pitch stability rules do not override v2. The current prototype is an
executable calibration harness, not the final Resource schema.

## Define the mold before tuning it

- State the mold's stable identity, combat role, intended power range, and
  expected hyzer, flat, and anhyzer lines before selecting values.
- Describe powered-flight behavior through separate `turn_tendency` and
  `turn_resistance`, then describe post-apex recovery through `fade`.
- Keep fade disabled before apex. Do not reproduce a desired early line by
  leaking fade into powered flight or by restoring legacy phase-curve rules.
- Treat launch pitch as an explicit release input. Do not assume the v1 rule
  that pitch must directly bias stability unless v2 deliberately adopts it.
- For the current prototype, retune against the configured player-lab charge
  envelope and the shallow carry envelope separately. Presentation-time scaling
  changes perceived speed only; it is not a mold-speed parameter.
- When authoring a sniper hyzer-flip, specify the flip-distance landmark, the
  flat-hold window, and the terminal range. Do not sacrifice the mold's stated
  flat-turnover and anhyzer/roller lines to create the hyzer laser.
- Define roller or skip intent separately from airborne identity. Ground outcome
  still depends on actual impact velocity, bank, angle, normal, surface, and
  configured mold factors.

## Authoring boundary

- Use one shared immutable Resource per mold under `data/discs/` when a
  production v2 Resource type is consumed and validated by the authoritative
  v2 path. Do not add mold-specific scripts or store per-throw state in an
  asset.
- Preserve stable resource paths and `.uid` files. During migration, do not
  silently reinterpret an existing v1 `ArcadeFlightProfile` as v2 data.
- Treat speed, carry/glide, `skip_factor`, and `roll_factor` as proposals until
  their schema and simulation meaning are implemented. Do not invent values or
  present prototype constants as validated balance.
- Keep SI units and the documented bank/handedness conventions at simulation
  boundaries.

## Verification and completion

- Validate identical data, release, environment, and fixed ticks produce the
  same state sequence within explicit tolerances.
- Cover the declared release envelope, the powered-to-late apex transition,
  absence of pre-apex fade, continuous bank/orientation, and mirrored lateral
  behavior where supported.
- Test roller or skip expectations only when the corresponding ground system is
  implemented; otherwise record them as unvalidated target behavior.
- Update `docs/disc-molds.md` for the roster and `docs/flight-model-v2.md` only
  when the target contract or validation status changes. Use
  `$hyzer-flip-v2-data-resources` for schema work and
  `$hyzer-flip-v2-testing` for fixtures.
