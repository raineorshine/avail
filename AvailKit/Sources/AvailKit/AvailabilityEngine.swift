import Foundation

/// What one generation produced.
public struct Availability: Sendable, Hashable {
  public let days: [DayAvailability]
  public let text: String

  public init(days: [DayAvailability], text: String) {
    self.days = days
    self.text = text
  }

  /// True when no day in either pass had open time (R2b permits this). The
  /// shells show their own message for it rather than offering an empty
  /// string.
  public var isEmpty: Bool { days.isEmpty }
}

/// The module's single entry point: events and settings in, rendered text out.
///
/// It takes an event *provider* rather than a pre-fetched list, because R2a's
/// second pass is a second fetch and the decision to make it depends on how
/// many days qualified. A closure over Foundation types keeps the module's
/// purity intact while leaving the EventKit read outside it, which is what
/// makes the app's preview and the extension's insertion the same code by
/// construction.
public struct AvailabilityEngine: Sendable {
  public let calendar: Calendar
  public let rules: AvailabilityRules
  public let annotator: any Annotator

  public init(
    calendar: Calendar,
    rules: AvailabilityRules = .default,
    annotator: any Annotator = DeterministicAnnotator()
  ) {
    self.calendar = calendar
    self.rules = rules
    self.annotator = annotator
  }

  /// - Parameters:
  ///   - excludedCalendarIdentifiers: R5. The reader also scopes its predicate
  ///     to the calendars that are left, so exclusion is applied at the fetch
  ///     as well; filtering here is what keeps the rule provable without a
  ///     calendar store.
  ///   - appendsTimeZoneLabel: R13a's toggle.
  public func generate(
    now: Date = Date(),
    excludedCalendarIdentifiers: Set<String> = [],
    appendsTimeZoneLabel: Bool = false,
    provider: (DateInterval) throws -> [NormalizedEvent]
  ) rethrows -> Availability {
    let grouper = DayGrouper(calendar: calendar, rules: rules, annotator: annotator)
    let days = try grouper.qualifyingDays(now: now) { interval in
      try provider(interval).filter {
        !excludedCalendarIdentifiers.contains($0.calendar.identifier)
      }
    }
    let formatter = AvailabilityFormatter(calendar: calendar)
    return Availability(
      days: days, text: formatter.text(days, timeZoneLabel: appendsTimeZoneLabel)
    )
  }
}
