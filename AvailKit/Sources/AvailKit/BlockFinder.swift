import Foundation

/// Computes a day's free blocks from annotated events (R23): pure,
/// synchronous, and a function of nothing but its arguments and the injected
/// calendar.
public struct BlockFinder: Sendable {
  public let calendar: Calendar
  public let rules: AvailabilityRules

  public init(calendar: Calendar, rules: AvailabilityRules = .default) {
    self.calendar = calendar
    self.rules = rules
  }

  /// The day's window, derived from calendar components rather than by adding
  /// a fixed number of seconds to the previous day (KTD7). A day containing a
  /// daylight-saving transition is 23 or 25 hours long; its 9:00-to-19:00
  /// window is 10 hours either way.
  public func window(for day: Date) -> DateInterval {
    var components = calendar.dateComponents([.year, .month, .day], from: day)
    components.hour = rules.dayStartHour
    let start = calendar.date(from: components)!
    components.hour = rules.dayEndHour
    let end = calendar.date(from: components)!
    return DateInterval(start: start, end: max(start, end))
  }

  /// The blocks left in `day`'s window once every blocking event, widened by
  /// its own buffers, is taken out of it.
  ///
  /// - Parameter notBefore: the earliest instant to offer, for the day the
  ///   search starts on (R4). Ignored on other days.
  public func freeBlocks(
    on day: Date,
    annotated: [AnnotatedEvent],
    notBefore: Date? = nil
  ) -> [FreeBlock] {
    let window = window(for: day)
    let start = max(window.start, notBefore ?? window.start)
    guard start < window.end else { return [] }

    var cursor = start
    var blocks: [FreeBlock] = []

    for busy in Self.merged(annotated.compactMap(\.busyInterval)) {
      guard busy.end > cursor else { continue }
      guard busy.start < window.end else { break }
      append(&blocks, from: cursor, to: min(busy.start, window.end))
      cursor = max(cursor, busy.end)
      if cursor >= window.end { return blocks }
    }

    append(&blocks, from: cursor, to: window.end)
    return blocks
  }

  /// R3. A block shorter than the minimum is not offered, at the start and end
  /// of a day as much as in the middle of one.
  private func append(_ blocks: inout [FreeBlock], from start: Date, to end: Date) {
    guard end.timeIntervalSince(start) >= rules.minimumBlock else { return }
    blocks.append(FreeBlock(start: start, end: end))
  }

  /// Sorts by widened start and merges every overlapping or touching interval
  /// into a disjoint list (KTD6).
  ///
  /// The original algorithm walks the raw event list and advances past one
  /// overlapping event at a time, which is correct only because its events are
  /// sorted by unbuffered start. Buffers reorder effective starts, so merging
  /// first is what keeps R8 from silently dropping a block.
  static func merged(_ intervals: [DateInterval]) -> [DateInterval] {
    let sorted = intervals.sorted { $0.start < $1.start }
    var merged: [DateInterval] = []
    for interval in sorted {
      if let last = merged.last, interval.start <= last.end {
        merged[merged.count - 1] = DateInterval(
          start: last.start, end: max(last.end, interval.end)
        )
      } else {
        merged.append(interval)
      }
    }
    return merged
  }
}
