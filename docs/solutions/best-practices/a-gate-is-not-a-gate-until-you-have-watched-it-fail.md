---
module: avail
date: 2026-09-20
problem_type: best_practice
component: development_workflow
severity: high
applies_when:
  - Adding a check to CI, to the ship gate, or to a plan's Verification Contract
  - Writing a test whose name contrasts two behaviors
  - Asserting in documentation that the build system enforces an invariant
tags:
  - verification
  - ci
  - swift-package-manager
  - grep-portability
  - mutation-testing
---

# A gate is not a gate until you have watched it fail

## Context

The iOS rewrite shipped with four verification mechanisms that were written,
documented, and believed. Every one of them was asserted rather than exercised.
Three of the four did not work, and all three failed silently — the tree was
green and the documentation said the invariant held.

They were found by a code review that ran the gates instead of reading them.
None was found by reading.

## Guidance

**Run every new check against input it must reject, not only against input it
must accept.** A check that has only ever been observed passing is an untested
branch, and the branch that matters is the failing one.

The four instances, all from one change:

1. **An invariant nothing enforced.** The plan and `AGENTS.md` both stated that
   the Swift package manifest made `AvailKit`'s "imports Foundation and nothing
   else" rule a build-system invariant. It does not. A package target imports a
   system framework with no manifest entry, so adding `import EventKit` to the
   module compiles cleanly — `swift build` reported `Build complete!`. Only half
   of what the manifest was credited with is real: `AvailShared` genuinely
   cannot reach `AvailKit`, because it does not depend on it. The other half
   rested on a grep that lived in a plan document and ran in no gate at all.

2. **A check whose exit status depends on which `grep` is installed.** That grep
   was written `! grep -rhE '^import ' Sources | grep -qvE '^import Foundation$'`.
   The combination of `-q` and `-v` does not agree across implementations: under
   `ugrep` the pipeline returns 1 on a tree that *does* violate the rule, so the
   check passes exactly when it should fail. The portable form is an emptiness
   test, which behaves identically everywhere:

   ```sh
   test -z "$(grep -rhE '^import ' AvailKit/Sources | grep -vE '^import Foundation$')"
   ```

   This surfaced only because the gate was pointed at a deliberately violating
   tree. Against a clean tree both forms agree.

3. **A job that reported success when it failed.** The CI job building the app
   and the extension carried `continue-on-error: true`. It is the only automated
   check on `App/`, `MessagesExtension/` and `Shared/Sources`, none of which has
   a test target — so the one guard over roughly three quarters of the code
   could go red and the run stayed green.

4. **A gate command that errored as written.** The plan's Verification Contract
   named `xcodebuild test -scheme AvailKit`. Declaring a second library product
   moves SwiftPM's test action onto the `AvailKit-Package` aggregate scheme, and
   the documented command answers
   `xcodebuild: error: Scheme AvailKit is not currently configured for the test
   action`. Found by running it on the first unit, not by reviewing it.

The same failure appears in tests, where it is easy to miss because the suite is
green:

- A daylight-saving test resolved its date against the default fixture calendar
  rather than the `America/Denver` one it injected, so it asserted on 11 March —
  the day *before* the transition it was named for.
- A test named `mergingSortsByTheWidenedStartNotTheRawStart` could not
  distinguish those two sort orders at all, because it used the shipped
  annotator's uniform buffer, and subtracting one constant from every start
  preserves their order.

Both passed. Both were caught by mutating the implementation and checking that
the test went red — and both now do.

## Why This Matters

A wrong gate is worse than a missing one. A missing gate is visibly missing; a
wrong gate is a standing, documented claim that something is checked, and it
redirects attention away from the thing it claims to cover. Instance 1 had
already propagated from the plan into `AGENTS.md`, where the next agent would
read it as settled fact.

The cost asymmetry is what makes the practice worth the minute it takes: writing
the check is most of the work, and breaking the tree on purpose to watch it fail
is the cheap remainder.

## When to Apply

- Any check added to `.github/workflows/`, to the `ship` skill's gate, or to a
  plan's Verification Contract.
- Any claim that a build system, type system, or manifest enforces something.
  Ask what *specifically* rejects the violation, then produce the violation.
- Any test whose name contrasts two behaviors ("X not Y", "handles Z"). If the
  implementation can be mutated to the wrong behavior and the test still passes,
  the name is a claim the test does not support.
- Any shell check in CI using `grep -q` with `-v`, or any exit-status idiom that
  varies across implementations.

## Examples

Verifying instance 1, in a scratch copy so the working tree is untouched:

```sh
cp -R AvailKit /tmp/probe/ && printf '\nimport EventKit\n' >> /tmp/probe/AvailKit/Sources/AvailKit/AvailKit.swift
cd /tmp/probe/AvailKit && swift build     # "Build complete!" — the manifest does not stop it
```

Verifying the replacement gate, both ways round:

```sh
test -z "$(grep -rhE '^import ' AvailKit/Sources | grep -vE '^import Foundation$')"
# clean tree: passes.  same command after the import above: fails.  Both confirmed.
```

Verifying a test bites, by mutating the implementation rather than the test:

```sh
# BlockFinder.merged sorts by the widened start; remove the sort and re-run.
sed -i '' 's/let sorted = intervals.sorted { $0.start < $1.start }/let sorted = intervals/' \
  AvailKit/Sources/AvailKit/BlockFinder.swift
swift test --filter mergingSortsByTheWidenedStartNotTheRawStart   # must fail
```

Where the surviving checks live: the purity gate in
`.github/workflows/test.yml:22` and `.claude/skills/ship/SKILL.md:28`, the
zero-test guard at `.github/workflows/test.yml:37`, the corrected claim at
`AGENTS.md:18`, and the two repaired tests at
`AvailKit/Tests/AvailKitTests/BlockFinderTests.swift:124` and `:173`.
