# Hyzer Flip Repository Guide

## Project intent

Hyzer Flip begins as a realistic disc-golf flight lab and will evolve into a
multiplayer arena shooter. Build the project so flight behavior is explainable,
repeatable, and easy to tune without coupling it to player controls, rendering,
or networking.

## Working agreements

- Work on one user-scoped task at a time. Do not combine cleanup, flight-model,
  player, or networking changes unless the user asks for all of them.
- Preserve unrelated working-tree changes. Do not commit, push, or change
  branches unless the user asks.
- Prefer small, reviewable changes. Update relevant documentation when a durable
  architecture or workflow decision changes.
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
- Before changing flight code or disc aerodynamic resources, read
  `docs/flight-model.md`.
- Keep that document current when changing units, coordinate conventions,
  simulation scope, or validation status.
- Use `$hyzer-flip-physics-integration` for fixed-step driving, collision-query
  adapters, bounce/skip integration, state presentation, or deterministic
  collision boundaries when available.
- Before changing disc mold definitions, flight archetypes, or mold-specific
  arena abilities, read `docs/disc-molds.md` and use `$hyzer-flip-disc-molds`
  when it is available.
- Use `$hyzer-flip-data-resources` for disc Resources, aerodynamic tables,
  projectile behavior configuration, data validation, or tunable balance values
  when available.
- Before changing scene organization, player boundaries, collision ownership, or
  networking, read `docs/architecture.md`.
- Use `$hyzer-flip-scene-architecture` for reusable scene composition,
  scene-tree ownership, collision topology, spawning, or lab/gameplay separation
  when available.
- Use `$hyzer-flip-networking` for server authority, replication, prediction,
  reconciliation, multiplayer spawning, or network determinism when available.
- Before changing arena rounds, disc projectile interactions, lock-on behavior,
  trajectory previews, or player controls, read `docs/arena-shooter.md`.
- Use `$hyzer-flip-rounds` for match flow, `$hyzer-flip-projectiles` for disc
  interactions and previews, and `$hyzer-flip-controls` for player input when
  those skills are available.
- Use `$hyzer-flip-testing` for deterministic simulation tests, replay fixtures,
  numerical baselines, and physics-validation work when available.

## Validation

- Run `git diff --check` after edits.
- Run a Godot editor scan after changing GDScript, scenes, or resources:
  `godot --headless --path . --editor --quit`.
- The macOS sandbox can report editor-settings or certificate write errors; only
  project parse errors should block the change.
