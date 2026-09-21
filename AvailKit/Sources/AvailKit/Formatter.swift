import Foundation

/// Renders days as the original `avail` text.
///
/// Every string is built from `Calendar.dateComponents` on the injected
/// calendar. `DateFormatter` and `FormatStyle` both default to the
/// autoupdating locale and the current zone, which is the drift KTD3 exists to
/// prevent.
public struct AvailabilityFormatter: Sendable {
  public let calendar: Calendar

  public init(calendar: Calendar) {
    self.calendar = calendar
  }

  private static let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

  /// R9. The date prefix once, then the day's blocks separated by commas, and
  /// the timezone label at the end of the line when R13a's toggle is on.
  public func line(for day: DayAvailability, timeZoneLabel: Bool) -> String {
    let date = calendar.dateComponents([.weekday, .month, .day], from: day.day)
    let prefix = "\(Self.weekdays[date.weekday! - 1]) \(date.month!)/\(date.day!)"
    let blocks = day.blocks.map(format(_:)).joined(separator: ", ")
    return prefix + " " + blocks + (timeZoneLabel ? " " + timeZoneName : "")
  }

  public func text(_ days: [DayAvailability], timeZoneLabel: Bool) -> String {
    days.map { line(for: $0, timeZoneLabel: timeZoneLabel) }.joined(separator: "\n")
  }

  /// R12. `h[:mm]am/pm`, with the start's suffix omitted when both ends fall
  /// in the same half of the day.
  func format(_ block: FreeBlock) -> String {
    let start = calendar.dateComponents([.hour, .minute], from: block.start)
    let end = calendar.dateComponents([.hour, .minute], from: block.end)
    let sameHalf = Self.isAfternoon(start.hour!) == Self.isAfternoon(end.hour!)
    return Self.time(start, suffix: !sameHalf) + "-" + Self.time(end, suffix: true)
  }

  /// R13a. The season-independent generic short name -- `ET`, never `EDT` or
  /// `EST`. A fixed-offset zone has no generic name and falls back to its
  /// `GMT-6` form, which is correct: there is no regional name to print.
  var timeZoneName: String {
    let locale = calendar.locale ?? Locale(identifier: "en_US_POSIX")
    return calendar.timeZone.localizedName(for: .shortGeneric, locale: locale)
      ?? calendar.timeZone.abbreviation() ?? ""
  }

  private static func isAfternoon(_ hour: Int) -> Bool { hour >= 12 }

  private static func time(_ components: DateComponents, suffix: Bool) -> String {
    let hour = components.hour!
    let minute = components.minute!
    // 12 stays 12 rather than becoming 0, matching the original.
    let displayed = hour - (hour > 12 ? 12 : 0)
    let minutes = minute > 0 ? String(format: ":%02d", minute) : ""
    return "\(displayed)\(minutes)\(suffix ? (hour < 12 ? "am" : "pm") : "")"
  }
}
