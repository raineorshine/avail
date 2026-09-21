import Foundation

/// A stretch of open time inside one day's window.
public struct FreeBlock: Sendable, Hashable {
  public let start: Date
  public let end: Date

  public init(start: Date, end: Date) {
    self.start = start
    self.end = end
  }

  public var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// One day's qualifying blocks, in chronological order.
public struct DayAvailability: Sendable, Hashable {
  /// Any instant inside the day; the formatter reads its calendar components.
  public let day: Date
  public let blocks: [FreeBlock]

  public init(day: Date, blocks: [FreeBlock]) {
    self.day = day
    self.blocks = blocks
  }
}
