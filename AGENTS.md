# Hyzer Flip Repository Guide

## Project intent

Hyzer Flip uses a deterministic, disc-golf-inspired arcade flight model and
will evolve into a multiplayer arena shooter. Build the project so flight
behavior is explainable, repeatable, and easy to tune without coupling it to
player controls, rendering, or networking.

## Working agreements

- Work on one user-scoped task at a time. Do not combine cleanup, flight-model,
  player, or networking changes unless the user asks for all of them.
- Preserve unrelated working-tree changes. Do not commit, push, or change
  branches unless the user asks.
- Prefer small, reviewable changes. Update relevant documentation when a durable
  architecture or workflow decision changes.
- Keep implementation work narrowly scoped: change at most one or two functions
  per task and touch no more than one source file, except for directly required
  assets or generated companion files. Ask before expanding beyond that scope.
- Treat `scenes/` as the canonical home for Godot scenes. Do not add duplicate
  root-level `.tscn` files.
- After an intentional tracked project-structure change, keep `README.md`
  accurate. Use `$project-readme-sync` when it is available.

## Architecture boundaries

- Keep flight simulation separate from `Node` behavior, UI, player input,
  collision presentation, and networking.
- Keep disc configuration in Godot `Resource` data under `data/discs/`; do not
  make a script per disc mold.
- Use SI units inside the flight model. Convert player- or lab-facing units at
  the boundary where input becomes throw data.
- Keep deterministic gameplay behavior explicit and testable. Do not rely on a
  rendering frame rate or engine rigid-body simulation as the authoritative
  flight result.

## Documentation routing

- Use `$godot-4-workflow` for Godot scenes, GDScript APIs, resources, input
  actions, and project-setting changes when the skill is available.
- Treat `docs/flight-model-v2.md` as this branch's target flight-model contract.
  Before changing v2 flight code or disc data, read it and use
  `$hyzer-flip-v2-flight-model` when available.
- Treat `scripts/flight/arcade/arcade_flight_prototype.gd` as the executable
  subset of that target. `docs/flight-model.md` documents the legacy
  implementation during migration and must not override the v2 contract.
- Keep `docs/flight-model-v2.md` current when target units, coordinate
  conventions, state semantics, simulation scope, or validation status change.
- Use `$hyzer-flip-v2-physics-integration` for fixed-step driving,
  collision-query adapters, skip/roll/stop integration, state presentation, or
  deterministic collision boundaries when available.
- Before changing disc mold definitions, flight archetypes, or mold-specific
  arena abilities, read `docs/disc-molds.md` and the v2 contract. Use
  `$hyzer-flip-v2-data-resources` for v2 mold data when available.
- Before adding or materially retuning a disc mold, read `docs/disc-authoring.md`
  as legacy integration context, then use `$hyzer-flip-v2-disc-authoring` when
  it is available. Do not carry legacy phase-curve or launch-pitch stability
  requirements into v2 work.
- Use `$hyzer-flip-v2-data-resources` for v2 disc Resources, projectile behavior
  configuration, data validation, or tunable balance values when available.
- Before changing scene organization, player boundaries, collision ownership, or
  networking, read `docs/architecture.md`.
- Use `$hyzer-flip-scene-architecture` for reusable scene composition,
  scene-tree ownership, collision topology, spawning, or lab/gameplay separation
  when available.
- Use `$hyzer-flip-networking` for server authority, replication, prediction,
  reconciliation, multiplayer spawning, or network determinism when available.
- Before changing arena rounds, disc projectile interactions, lock-on behavior,
  trajectory previews, or player controls, read `docs/arena-shooter.md`.
- Use `$hyzer-flip-rounds` for match flow,
  `$hyzer-flip-v2-projectiles` for v2 disc interactions and previews, and
  `$hyzer-flip-controls` for player input when those skills are available.
- Use `$hyzer-flip-v2-testing` for deterministic v2 simulation tests, replay
  fixtures, numerical baselines, and physics-validation work when available.

## Validation

- Run `git diff --check` after edits.
- Run a Godot editor scan after changing GDScript, scenes, or resources:
  `godot --headless --path . --editor --quit`.
- The macOS sandbox can report editor-settings or certificate write errors; only
  project parse errors should block the change.
