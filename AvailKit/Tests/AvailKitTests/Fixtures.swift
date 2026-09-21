import Foundation

@testable import AvailKit

/// Test inputs and the pinned calendar every expectation is rendered against.
///
/// The timezone pin is KTD3. `test/spec.js` set `process.env.TZ = 'Etc/GMT+6'`
/// on its first line; the Swift equivalent is a fixed-offset `Calendar`
/// injected into the module, never ambient state. `Etc/GMT+6` is a fixed
/// -06:00 with no daylight saving, so expectations hold whatever date the
/// suite runs on, and the fixtures below carry -06:00 offsets to match.
enum Fixture {
  /// The suite's pinned zone: a fixed -06:00 offset, no daylight saving.
  static let timeZone = TimeZone(secondsFromGMT: -6 * 3600)!

  /// The calendar every block-finding and formatting expectation is computed
  /// against. `en_US_POSIX` and an explicit `firstWeekday` keep weekday and
  /// month arithmetic independent of the host's locale.
  static let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.firstWeekday = 1
    return calendar
  }()

  /// The same calendar in a named zone, for the cases a fixed offset cannot
  /// exercise: a fixed offset renders its short generic name as `GMT-6` and
  /// never as `ET`, and a zone with no daylight-saving transition passes the
  /// transition test vacuously.
  static func calendar(in identifier: String) -> Calendar {
    var calendar = Self.calendar
    calendar.timeZone = TimeZone(identifier: identifier)!
    return calendar
  }

  /// Parses `yyyy-MM-dd HH:mm` in the given zone, defaulting to the pinned one.
  ///
  /// Built from `DateComponents` rather than a `DateFormatter`, which defaults
  /// to the autoupdating locale and the current zone.
  static func date(_ text: String, in calendar: Calendar = Fixture.calendar) -> Date {
    let parts = text.split(separator: " ")
    let day = parts[0].split(separator: "-").map { Int($0)! }
    let time = parts.count > 1 ? parts[1].split(separator: ":").map { Int($0)! } : [0, 0]
    let components = DateComponents(
      year: day[0], month: day[1], day: day[2], hour: time[0], minute: time[1]
    )
    return calendar.date(from: components)!
  }

  static let defaultCalendarSource = EventCalendar(
    identifier: "work", title: "Work", supportsAvailability: true
  )

  /// A timed event that blocks by default; every rule the deterministic
  /// annotator applies is a named argument away.
  static func event(
    _ title: String = "Event",
    from start: String,
    to end: String,
    in calendar: Calendar = Fixture.calendar,
    identifier: String? = nil,
    source: EventCalendar = Fixture.defaultCalendarSource,
    isAllDay: Bool = false,
    responseStatus: ParticipantStatus = .accepted,
    availability: EventAvailability = .busy,
    attendees: [EventAttendee]? = nil,
    notes: String? = nil,
    location: String? = nil,
    url: URL? = nil,
    conferenceURL: URL? = nil
  ) -> NormalizedEvent {
    NormalizedEvent(
      eventIdentifier: identifier ?? "\(title)-\(start)",
      title: title,
      notes: notes,
      location: location,
      url: url,
      conferenceURL: conferenceURL,
      attendees: attendees,
      calendar: source,
      start: date(start, in: calendar),
      end: date(end, in: calendar),
      isAllDay: isAllDay,
      responseStatus: responseStatus,
      availability: availability
    )
  }
}

extension Fixture {
  /// The event list carried over from the JavaScript suite's `test/events.json`.
  ///
  /// The events port directly as inputs. Every expected output *string* is
  /// recomputed: the old assertions were written against a 9am-5pm day, no
  /// buffers, one line per block and no line cap, all four of which this
  /// version changes, so an expectation copied across would be wrong while
  /// looking plausible.
  static var portedEvents: [NormalizedEvent] {
    struct Record: Decodable {
      struct Endpoint: Decodable { let dateTime: String }
      let summary: String
      let start: Endpoint
      let end: Endpoint
    }

    let url = Bundle.module.url(forResource: "events", withExtension: "json")!
    let records = try! JSONDecoder().decode([Record].self, from: Data(contentsOf: url))
    return records.map { record in
      NormalizedEvent(
        eventIdentifier: record.summary,
        title: record.summary,
        calendar: defaultCalendarSource,
        start: offsetDate(record.start.dateTime),
        end: offsetDate(record.end.dateTime),
        responseStatus: .accepted,
        availability: .busy
      )
    }
  }

  /// Parses the fixtures' `2017-07-11T14:30:00-06:00` form without a
  /// `DateFormatter`, which would default to the autoupdating locale.
  static func offsetDate(_ text: String) -> Date {
    let parts = text.split(separator: "T")
    let day = parts[0].split(separator: "-").map { Int($0)! }
    let time = parts[1].prefix(8).split(separator: ":").map { Int($0)! }
    let sign = parts[1].contains("+") ? 1 : -1
    let offset = parts[1].suffix(6).dropFirst().split(separator: ":").map { Int($0)! }

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: sign * (offset[0] * 3600 + offset[1] * 60))!
    return calendar.date(
      from: DateComponents(
        year: day[0], month: day[1], day: day[2],
        hour: time[0], minute: time[1], second: time[2]
      )
    )!
  }

  /// Serves events out of a list the way the EventKit reader serves them out
  /// of the store: everything overlapping the requested interval.
  static func provider(_ events: [NormalizedEvent]) -> (DateInterval) -> [NormalizedEvent] {
    { interval in events.filter { $0.end > interval.start && $0.start < interval.end } }
  }
}
