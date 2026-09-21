import Foundation

extension DateInterval {
  /// An interval that cannot be inverted.
  ///
  /// `DateInterval(start:end:)` traps when the end precedes the start, and two
  /// ordinary things produce that: an event whose end is before its start, and
  /// a rules value whose day end is earlier than its day start.
  static func clamped(from start: Date, to end: Date) -> DateInterval {
    DateInterval(start: start, end: Swift.max(start, end))
  }
}
