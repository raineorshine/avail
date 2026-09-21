---
name: ship
description: "Finish a feature branch in a worktree: run the test gate, commit, rebase on master, squash, fast-forward merge into master, push, and extract the session's learnings. Use when done with a change in this repo and want it on master without opening a PR."
---

# Ship (finish feature → merge to master)

Solo-developer workflow for this repo. Take the current feature branch (usually in a worktree),
verify it, land it on `master` as a single commit via fast-forward merge, and push to `origin`. No
PR.

If the session is already on `master` in the main checkout (no feature branch), run the gate,
commit, and push; steps 3–5 are no-ops there.

## Procedure

### 0. Prefix the session title with 🚀

Read the session's title (`mcp__ccd_session_mgmt__get_session` with `"self"`) and set it back with a
`🚀 ` prefix (`mcp__ccd_session_mgmt__set_session_title`), replacing any existing lifecycle prefix
rather than stacking — a shipping session was usually `📦 ` a moment ago. Do this **now**, before
any of the work: the sidebar should say what the session is doing while it is doing it. Step 7 puts
the title back if the ship does not land. Do not report either. See `AGENTS.md` (Session titles).

### 1. Quality gate (must pass before committing)

```bash
cd AvailKit && xcodebuild test -scheme AvailKit-Package -destination 'platform=macOS'
```

- The Foundation-only Swift package, against this Mac. No simulator runtime, no signing, no device,
  and nothing to install first. It must print `** TEST SUCCEEDED **`; a failure exits 65.
- The scheme is `AvailKit-Package`, not `AvailKit`. SwiftPM vends a build-only scheme per library
  product and puts the test action on the aggregate, so `-scheme AvailKit` answers `Scheme AvailKit
  is not currently configured for the test action`. `swift test --package-path AvailKit` is the
  equivalent and is what CI runs.
- Ignore the empty XCTest shim that prints `Executed 0 tests, with 0 failures` ahead of the real
  run. The exit code is the signal, not that line.
- It must be **green**, not "green except the known ones". If expectations drift by exactly an hour
  or two, a test is reading the machine's timezone instead of injecting `Fixture.calendar` — fix the
  test, don't set `TZ` on the command line, which would hide it again for everyone else. See
  `AGENTS.md` (Repo → Testing).
- When the change touches anything outside the package, compile-check the shells too:

  ```bash
  xcodegen generate && xcodebuild build -project Avail.xcodeproj -scheme Avail -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
  ```

Fix every failure and re-run before proceeding.

### 2. Commit all staged and unstaged changes

Generate a commit message from the diff. Use an imperative, sentence-case subject (`Add …`, `Fix …`,
`Exclude …`, `Remove …`) to match the repo's history — no `type:` prefix. Follow the conventions in
`AGENTS.md` (Repo → Git). When `learn` is the caller, commit only the files it edited — it lands its
learnings alone — and say what was left behind.

Never commit `Avail.xcodeproj`; xcodegen generates it from `project.yml` and it is gitignored.

### 3. Rebase on master

```bash
git rebase master
```

If the rebase hits conflicts: resolve them, `git add` the resolved files, `git rebase --continue`,
and repeat until it completes. Where both sides only added lines, keep both — two sessions appending
to the same `AGENTS.md` list collide this way, and taking either side alone drops the other's
addition. Where both edited the same lines, prefer the branch's version unless it is clearly wrong.
Then re-run the step 1 gate and `git add` whatever changed: a conflict resolution is content nothing
has tested, and step 4 commits only what is staged.

### 4. Squash all commits into one

```bash
git reset --soft "$(git merge-base HEAD master)" && git commit -m "subject" -m "body"
```

Use a single message that describes the overall diff. Reset to the merge base, not to `master`: if
another worktree lands on `master` while a rebase is paused on a conflict, a soft reset onto the new
tip keeps a tree without its commits, so the squash would silently revert them. From the merge base,
step 5 refuses to fast-forward instead, and its retry loop takes the new commits in.

A **worktree-isolated session** cannot run that line as written: the harness refuses any `git` call
it cannot verify stays inside the worktree, which includes a command substitution naming `git`. Run
`git merge-base HEAD master` on its own and pass the SHA it prints to `git reset --soft`. The same
refusal governs steps 5 and 6 — see below.

### 5. Fast-forward merge into master

Use this exactly — it resolves the branch and the main checkout (`$MAIN`, the directory holding the
shared `.git`), so nothing is hardcoded:

```bash
BRANCH=$(git branch --show-current) && MAIN="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")" && git -C "$MAIN" merge --ff-only "$BRANCH"
```

**If `--ff-only` fails with "Not possible to fast-forward":** another worktree merged into `master`
in the meantime, so this branch is no longer a direct descendant. This is expected when running
parallel agent sessions and is safe — nothing was merged or lost. Recover by re-integrating on the
new `master`:

1. Go back to **step 3** (`git rebase master`) — this replays this branch's single squashed commit
   onto the updated `master`, surfacing any genuine conflict with the work that landed first.
   Resolve conflicts the same way.
2. Redo **step 4** to re-squash onto the new base.
3. Retry **step 5**.

Repeat until the fast-forward succeeds. Because `master`'s ref only advances via this atomic
`--ff-only` step, at most one worktree wins each round and the others simply rebase and retry — no
merge commits, no clobbering.

**If the harness refuses the command** — "redirects git to the shared checkout via `-C`" — this is a
worktree-isolated session, and neither this step nor step 6 can touch the main checkout at all.
Land it on the remote instead, from the worktree, and skip step 6's push:

```bash
git push origin HEAD:master
```

That is the same atomic advance of one ref, so the concurrency argument above still holds: a second
worktree's push is rejected as non-fast-forward, and the recovery is the same rebase-and-retry loop.
What it does not do is move the main checkout's local `master`, which is left one commit behind
`origin/master` — say so in the report and leave the `git pull --ff-only` to the user or to a
session that is not worktree-isolated.

### 6. Push and post-merge

```bash
MAIN="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")" && git -C "$MAIN" push origin master
```

- Push `master` to `origin` from the main worktree. Already done if step 5 fell back to pushing
  `HEAD:master`.
- The branch is now merged into `master`. If this worktree is finished with, it and the branch can
  be cleaned up from the main checkout:

  ```bash
  BRANCH=$(git branch --show-current) && MAIN="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")" && git -C "$MAIN" worktree remove <this-worktree-path> && git -C "$MAIN" branch -d "$BRANCH"
  ```

  Only do this when the user confirms the worktree is no longer needed.

### 7. Correct the title if the ship did not land

The push in step 6 is what counts as shipped. If it succeeded, the `🚀 ` from step 0 is already
right — leave it. If it failed, or the ship was abandoned before the push, put the title back to the
prefix that is true now (`📦 ` for a branch that is done and gated, otherwise whatever stage it
actually reached). Do not report this step.

### 8. Extract the learnings

Invoke the `learn` skill. A shipped change is the moment its lessons are worth writing down: the
branch is landed, nothing is pending, and whatever the session learned about the algorithm, the
calendar API or the workflow is still in context — an hour later it is in nobody's. This is not
optional and the user does not have to ask for it; it is the last stage of shipping.

Skip this step when `ship` was itself invoked by `learn` or `learn-organize` (their procedures end
in a ship), or the two would call each other forever. Landing the learnings is that ship's whole
job.

`learn` puts `📚 ` on the title, replacing the `🚀 `. Put `🚀 ` back when it finishes: the session
shipped, and that is the stage it rests at.

If `learn` finds nothing worth recording, that is a normal outcome — say so in one line and move on.

### 9. Report completion

Report the commit subject and that `master` is pushed. Skip narration. Print `🚀 Shipped` as the
last line of the response, after the learn report.
