# avail

Smart, text-based calendar availability reporter. A small Node CLI (`bin.js` → `index.js` →
`find-free-blocks.js`) plus an Express server for the Google Calendar OAuth flow.

## Dependencies

The lockfile is `yarn.lock`, in yarn v1 format; there is no `package-lock.json`. Install with
`yarn install --frozen-lockfile` — `npm install` would write a second, competing lockfile that
nothing else in the repo reads. `engines.node` is `>=18`: the source uses arrow functions and
destructuring, so the `>=0.12.0` it advertised for years was never true.

## Testing

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
