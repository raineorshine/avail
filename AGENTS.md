# avail

Smart, text-based calendar availability reporter. A small Node CLI (`bin.js` → `index.js` →
`find-free-blocks.js`) plus an Express server for the Google Calendar OAuth flow. Not published to
npm; `master` is the only thing that ships.

## Repo

- `find-free-blocks.js` — the whole algorithm: `flattenEvents` merges per-calendar event lists into
  one sorted list, `printFreeBlocks` renders the gaps. This is what the tests cover.
- `index.js` / `bin.js` — the Express server and the stdin-driven CLI around it.
- `config.json` — Google API credentials, gitignored. `config.example.json` is the template.

### Dependencies

The lockfile is `yarn.lock`, in yarn v1 format; there is no `package-lock.json`. Install with
`yarn install --frozen-lockfile` — `npm install` would write a second, competing lockfile that
nothing else in the repo reads. `engines.node` is `>=18`: the source uses arrow functions and
destructuring, so the `>=0.12.0` it advertised for years was never true.

### Testing

`npm test` runs mocha over `test/spec.js`. There is no lint, formatter, type check, or build step —
the test suite is the entire gate, and `.github/workflows/test.yml` runs it on a current Node LTS
for every push to `master` and every pull request.

`test/spec.js` sets `process.env.TZ = 'Etc/GMT+6'` on its first line, before any require. The
fixtures carry `-06:00` offsets and the expectations are rendered in **local** time, so an unpinned
suite passes only on a machine set to -06:00 and fails by an hour or more everywhere else — it was
red for years for exactly this reason, and a UTC CI runner would have been red too. `Etc/GMT+6` is a
fixed offset with no DST, so the expectations hold whatever date the suite runs on.

Any new spec file needs the same line, and any new expectation should be written against that
offset. When a spec drifts by a whole number of hours, that missing line is why — fix the spec,
don't set `TZ` on the command line, which hides it again for everyone else.

### Git

Imperative, sentence-case subjects (`Add …`, `Fix …`, `Exclude …`), matching the existing history.
No `type:` prefix. Work happens on a branch in a worktree and lands on `master` as a single commit
via fast-forward merge — no PRs, no merge commits. The `ship` skill is that procedure.

## Session titles

A lifecycle prefix on the session title says what the session is doing while it is doing it, so the
sidebar answers "which of these is mid-ship" without opening any of them. The sidebar already shows
a status dot (running / awaiting input / idle) and a branch glyph for worktree sessions; neither can
be set from here — `set_session_title` takes a title string and nothing else. So a **single leading
emoji on the title** is the only lever, and it is spent on what the app cannot know: where the work
stands.

| Prefix | Means                                                                                     |
| ------ | ----------------------------------------------------------------------------------------- |
| `⏳ `  | implementing — the weakest of them; every other prefix takes precedence                   |
| `📦 `  | done on the branch — tested and shippable without re-running anything                     |
| `🚀 `  | shipping to `master`, or shipped                                                          |
| `🚙 `  | parked: the work is sound and waiting on the user (a decision, a credential, a click)     |
| `⏲️ `  | waiting on a task scheduled for later — nothing to do until it fires                      |
| `🪦 `  | dead end — kept for the findings, not to resume                                           |
| `📚 `  | extracting learnings into `AGENTS.md`, `README.md` or the skills                          |

**Never mention a prefix in the response** — not what it was set to, not that it was already right,
not that it was left alone. It is sidebar state; say nothing about it unless asked.

These are **stages, not flags**: exactly one prefix at a time, and setting a new one replaces
whatever was there. **Every title carries one**, and a prefix comes off only when another takes its
place — a bare title says nothing about the session, and the sidebar cannot tell it apart from a
chat that never had a stage at all. A session with nothing left to do keeps the prefix of the last
stage it reached. The harness names a session without one, so putting the first prefix on that
inherited title is part of the first response, not something to wait for a stage change to prompt.
Only one reads cleanly at sidebar width, and `🚀 ` after `📦 ` is noise — the later stage implies
the earlier.

Set a prefix **optimistically** — when the stage _starts_, not when it succeeds — and correct it if
the stage falls over. A title that only becomes true at the end is blank for the whole stretch the
sidebar is there to describe. `🚀 ` is set by the `ship` skill, which sets it before the gate and
puts it back if the ship does not land, so it stays true on its own. `📚 ` goes on the moment a
`learn` skill is invoked, before anything is read. The rest are set by hand
(`mcp__ccd_session_mgmt__set_session_title`), and nothing reconciles a title against reality: an
abandoned session keeps whatever prefix it had.

**Handing back is itself a stage.** A response that closes on something for the user to do — a
decision, a Google credential, a click through the OAuth consent screen — is a park, and `🚙 ` goes
on before that response, since the idle dot cannot tell "waiting on you" from "given up on".

**Ask which session this is before renaming one.** `mcp__ccd_session_mgmt__get_session` with
`"self"` is the only answer, and it changes under a fork: a forked session carries the whole
transcript, the id it read earlier in that transcript, and a different id of its own, so a rename
that reuses the remembered one retitles the session it forked _from_. A fork also starts in the
worktree of the session it forked from, and nothing stops a branch being checked out there, which
moves that worktree under the other session's feet; put it back on the branch it was on when the
work is landed.
