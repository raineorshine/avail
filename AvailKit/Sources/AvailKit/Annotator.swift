import Foundation

/// What the annotation stage decides about one event: whether it takes time
/// away, and how much padding sits on each side of it.
public struct EventAnnotation: Sendable, Hashable {
  public var blocksAvailability: Bool
  public var bufferBefore: TimeInterval
  public var bufferAfter: TimeInterval

  public init(
    blocksAvailability: Bool,
    bufferBefore: TimeInterval = 0,
    bufferAfter: TimeInterval = 0
  ) {
    self.blocksAvailability = blocksAvailability
    self.bufferBefore = bufferBefore
    self.bufferAfter = bufferAfter
  }

  /// An event that takes no time away.
  public static let free = EventAnnotation(blocksAvailability: false)
}

/// The one place inference will ever run.
///
/// The whole batch resolves in a single call (R18). A per-event call shape is
/// precisely what this seam exists to prevent: it would put a network round
/// trip inside block finding, and block finding is a pure synchronous function
/// of its input by contract (R23).
///
/// An implementation with a time budget expresses a timeout by throwing;
/// `FallbackAnnotator` treats that like any other failure (R20).
public protocol Annotator: Sendable {
  /// Returns one annotation per event, positionally, in the order given.
  func annotate(_ events: [NormalizedEvent]) throws -> [EventAnnotation]
}

/// The shipped rule set: R6, R7, R7a and R8, and the fallback for R20.
///
/// The order below is the rule order, and each line is one requirement.
public struct DeterministicAnnotator: Annotator {
  /// R8's buffer, symmetric and uniform only because this annotator makes it
  /// so; nothing downstream assumes symmetry.
  public let buffer: TimeInterval

  public init(buffer: TimeInterval = 15 * 60) {
    self.buffer = buffer
  }

  public func annotate(_ events: [NormalizedEvent]) -> [EventAnnotation] {
    events.map { event in
      // R6. All-day events never block. The carve-out that makes travel and
      // conference all-day events blocking is deferred work behind this seam.
      if event.isAllDay { return .free }
      // R7. Declined invitations do not block; tentatively accepted ones do,
      // and an unknown status blocks, because only `.declined` frees (KTD11).
      if event.responseStatus == .declined { return .free }
      // R7a. Show As Free frees the time whoever owns the event.
      // `.notSupported` is not `.free` and falls through to blocking (KTD10).
      if event.availability == .free { return .free }
      // R8.
      return EventAnnotation(
        blocksAvailability: true, bufferBefore: buffer, bufferAfter: buffer
      )
    }
  }
}

/// Substitutes the deterministic rule set for the whole batch when the wrapped
/// annotator cannot answer (R20), so generation completes with no error
/// surfaced and no missing days.
public struct FallbackAnnotator: Annotator {
  public let primary: any Annotator
  public let fallback: DeterministicAnnotator

  public init(primary: any Annotator, fallback: DeterministicAnnotator = DeterministicAnnotator()) {
    self.primary = primary
    self.fallback = fallback
  }

  public func annotate(_ events: [NormalizedEvent]) -> [EventAnnotation] {
    // Annotations are positional, so a short or long result is as unusable as
    // a thrown one and falls back for the whole batch rather than being
    // patched up per event.
    guard let annotations = try? primary.annotate(events), annotations.count == events.count
    else {
      return fallback.annotate(events)
    }
    return annotations
  }
}
