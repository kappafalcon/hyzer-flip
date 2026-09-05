# Flight-Model V2 Tuning Command

Use this command to begin a bounded, evidence-led tuning pass on the default
flight-model-v2 solver. Replace every bracketed value with the behavior you
want to tune.

```text
Tune flight-model-v2 so that [disc mold / release envelope] produces
[desired readable shot shape], while preserving [important behavior that must
not regress].

Use $hyzer-flip-v2-flight-model and $hyzer-flip-v2-testing. Read
docs/flight-model-v2.md, docs/architecture.md, and the relevant solver,
fixture, and mold-data files before making a change. Treat the v2 document as
the authority; do not use legacy phase-curve rules.

Start with diagnosis, not a blind retune:
1. State the current baseline from an explicit, deterministic release case.
2. Identify one narrow tuning hypothesis, the parameter(s) or solver behavior
   involved, and the expected trajectory landmarks.
3. Propose the smallest change, limited to one source file and one or two
   functions unless expansion is necessary.
4. Add or update the smallest deterministic regression fixture that proves the
   intended change and protects the stated non-regression behavior.

Keep the solver pure, fixed-step, and in SI units. Preserve continuous state
through the vertical-velocity apex transition: fade must remain inactive during
powered flight and the transition tick, then affect a subsequent late-flight
tick. Do not couple tuning to Nodes, input, rendering, engine rigid bodies, or
frame rate.

If this pass changes mold Resource data, also use
$hyzer-flip-v2-data-resources. If it changes fixed-step driving, collision
queries, ground transitions, or presentation boundaries, also use
$hyzer-flip-v2-physics-integration instead of treating it as an airborne
tuning change.

Validate with the smallest relevant deterministic fixture, then run:
- godot --headless --path . --editor --quit
- git diff --check

Report the baseline, hypothesis, exact change, observed landmarks, and any
remaining limitation. Update docs/flight-model-v2.md only when the target
contract, conventions, scope, or validation status changed.
```

## Example invocation

```text
Tune flight-model-v2 so that a flat release of the stable driver stays nearly
straight through powered flight and finishes with a readable modest fade,
while preserving the existing hyzer-flip behavior of the understable driver.

[Use the tuning command above.]
```
