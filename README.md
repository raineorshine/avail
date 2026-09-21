# avail

Smart, text-based calendar availability reporter, as a native iOS app.

Its iMessage extension sits in the Messages `+` menu. One tap drops the next
five days that have open time into the compose field, one line per day:

```
Mon 7/10 9am-7pm
Tue 7/11 9am-2:15pm, 3:45-7pm
Wed 7/12 9am-7pm
Thu 7/13 9am-7pm
Fri 7/14 9-10:45am, 2:15-7pm
```

The text is inserted, not sent — review and edit it before it goes.

## Rules

Free time is computed from 9am to 7pm on every day of the week, weekends
included, reading Apple Calendar through EventKit. Blocks shorter than an hour
are not offered, each blocking event takes 15 minutes of buffer on either side
of itself, and today starts at the current time rounded up to the next half
hour. All-day events, declined invitations, and events whose Show As reads
Free take no time away. A day's line carries at most its three longest blocks.

Everything runs on the device. There is no server, no account, and no network
call.

## Building

Requires Xcode and [xcodegen](https://github.com/yonaskolb/XcodeGen); the
project file is generated and not committed.

```sh
xcodegen generate
open Avail.xcodeproj
```

Running on a phone needs a paid Apple Developer Program membership — not as a
one-time cost but as a live one, since the app stops launching if it lapses.
Free provisioning expires every seven days.

In the containing app, choose which calendars block your availability and
preview exactly what the extension will insert.

## Layout

- `AvailKit/` — a local Swift package holding the availability rules, the
  block finder and the formatter. Imports Foundation and nothing else.
- `Shared/Sources/` — the EventKit read, compiled into both targets.
- `App/`, `MessagesExtension/` — the containing app and the extension.

## License

ISC © [Raine Revere](https://github.com/raineorshine)
