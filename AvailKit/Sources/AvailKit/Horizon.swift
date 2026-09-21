import Foundation

/// The window the search covers, and where inside today it starts.
///
/// R2's Monday and Tuesday extension changes how much calendar the first pass
/// reads, not which days appear: because R2a reaches past the preferred window
/// whenever fewer than five days qualify, the days shown are the first five
/// with a qualifying block either way.
public struct Horizon: Sendable {
  public let calendar: Calendar
  public let rules: AvailabilityRules

  public init(calendar: Calendar, rules: AvailabilityRules = .default) {
    self.calendar = calendar
    self.rules = rules
  }

  /// R4. Now, rounded up to the next half hour; a time already on one is left
  /// alone. Derived from components rather than by rounding the absolute time,
  /// because not every zone's offset is a whole number of half hours.
  public func searchStart(from now: Date) -> Date {
    var components = calendar.dateComponents(
      [.era, .year, .month, .day, .hour, .minute, .second, .nanosecond], from: now
    )
    let minute = components.minute ?? 0
    let granularityMinutes = Int(rules.startGranularity / 60)
    let isOnTheMark =
      minute % granularityMinutes == 0 && (components.second ?? 0) == 0
      && (components.nanosecond ?? 0) == 0
    components.second = 0
    components.nanosecond = 0
    guard !isOnTheMark else { return calendar.date(from: components)! }

    let next = (minute / granularityMinutes + 1) * granularityMinutes
    components.minute = 0
    return calendar.date(from: components)!.addingTimeInterval(TimeInterval(next * 60))
  }

  /// R2. The offset of the last day in the preferred window: 7, unless that
  /// lands on a Monday or a Tuesday, in which case the window is extended past
  /// them.
  public func span(from now: Date) -> Int {
    var span = rules.preferredSpanDays
    while Self.isMondayOrTuesday(startOfDay(now, offsetBy: span), in: calendar) { span += 1 }
    return span
  }

  /// Every day in the preferred window, as start-of-day dates, from today
  /// through the span.
  public func days(from now: Date) -> [Date] {
    (0...span(from: now)).map { startOfDay(now, offsetBy: $0) }
  }

  /// The interval the preferred window's events are read over.
  ///
  /// Day-aligned rather than starting at `searchStart`, so an event that began
  /// before the search does but runs into it is still read. `searchStart`
  /// governs which blocks are offered, not which events are fetched.
  public func interval(from now: Date) -> DateInterval {
    DateInterval(start: startOfDay(now, offsetBy: 0), end: startOfDay(now, offsetBy: span(from: now) + 1))
  }

  /// R2a. The 30 days after the preferred window.
  public func secondPassDays(from now: Date) -> [Date] {
    let first = span(from: now) + 1
    return (first..<(first + rules.secondPassDays)).map { startOfDay(now, offsetBy: $0) }
  }

  public func secondPassInterval(from now: Date) -> DateInterval {
    let first = span(from: now) + 1
    return DateInterval(
      start: startOfDay(now, offsetBy: first),
      end: startOfDay(now, offsetBy: first + rules.secondPassDays)
    )
  }

  private func startOfDay(_ now: Date, offsetBy days: Int) -> Date {
    calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now))!
  }

  private static func isMondayOrTuesday(_ date: Date, in calendar: Calendar) -> Bool {
    // Gregorian weekdays are 1-based from Sunday.
    let weekday = calendar.component(.weekday, from: date)
    return weekday == 2 || weekday == 3
  }
}
