import Foundation

/// The daily window, the caps, the minimum block and the buffers.
///
/// These are build-time constants with no on-device editing surface (R28).
/// They are a value rather than a set of globals so the suite can vary one of
/// them without reaching for ambient state.
public struct AvailabilityRules: Sendable, Hashable {
  /// R1. The daily window, on every day of the week including weekends.
  public var dayStartHour: Int
  public var dayEndHour: Int
  /// R3.
  public var minimumBlock: TimeInterval
  /// R8. Symmetric and uniform only because the deterministic annotator makes
  /// it so; the finder reads each event's own buffers.
  public var buffer: TimeInterval
  /// R11.
  public var maximumDays: Int
  /// R9a.
  public var maximumBlocksPerDay: Int
  /// R2. The preferred window runs through the end of day 7, counting today as
  /// day 0, extended past a Monday or a Tuesday.
  public var preferredSpanDays: Int
  /// R2a. What the second pass reads when the first does not supply enough
  /// qualifying days.
  public var secondPassDays: Int
  /// R4. Today's availability begins at the current time rounded up to this.
  public var startGranularity: TimeInterval

  public init(
    dayStartHour: Int = 9,
    dayEndHour: Int = 19,
    minimumBlock: TimeInterval = 60 * 60,
    buffer: TimeInterval = 15 * 60,
    maximumDays: Int = 5,
    maximumBlocksPerDay: Int = 3,
    preferredSpanDays: Int = 7,
    secondPassDays: Int = 30,
    startGranularity: TimeInterval = 30 * 60
  ) {
    self.dayStartHour = dayStartHour
    self.dayEndHour = dayEndHour
    self.minimumBlock = minimumBlock
    self.buffer = buffer
    self.maximumDays = maximumDays
    self.maximumBlocksPerDay = maximumBlocksPerDay
    self.preferredSpanDays = preferredSpanDays
    self.secondPassDays = secondPassDays
    self.startGranularity = startGranularity
  }

  public static let `default` = AvailabilityRules()
}
