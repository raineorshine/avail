import Foundation

/// The horizon search: which days qualify, in what order, and how much of each
/// one is worth printing.
///
/// The event *provider* rather than a pre-fetched list is what lets R2a live
/// here. Whether a second pass is needed depends on how many days qualified,
/// which only this code knows; a one-shot entry point would push that decision
/// out into the app and the extension, twice.
public struct DayGrouper: Sendable {
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

  /// The days to print, in chronological order, at most `rules.maximumDays` of
  /// them (R11).
  ///
  /// The provider is called at most twice: once for the preferred window, and
  /// once more for the following 30 days when the first pass does not supply
  /// enough qualifying days (R2a). Fewer than enough after both passes emits
  /// what there is and stops (R2b).
  public func qualifyingDays(
    now: Date,
    provider: (DateInterval) throws -> [NormalizedEvent]
  ) rethrows -> [DayAvailability] {
    let horizon = Horizon(calendar: calendar, rules: rules)
    let finder = BlockFinder(calendar: calendar, rules: rules)
    let searchStart = horizon.searchStart(from: now)

    var events = try provider(horizon.interval(from: now))
    var days = qualifying(
      horizon.days(from: now), events: events, finder: finder, notBefore: searchStart
    )

    if days.count < rules.maximumDays {
      // The second pass reads the following 30 days. Its events are added to
      // the first pass's rather than replacing them, because an event can span
      // the boundary and each fetch returns it.
      events = deduplicated(events + (try provider(horizon.secondPassInterval(from: now))))
      days += qualifying(
        horizon.secondPassDays(from: now), events: events, finder: finder, notBefore: nil
      )
    }

    return Array(days.prefix(rules.maximumDays))
  }

  private func qualifying(
    _ days: [Date], events: [NormalizedEvent], finder: BlockFinder, notBefore: Date?
  ) -> [DayAvailability] {
    let annotated = AnnotatedEvent.pairing(events, with: annotate(events))
    return days.compactMap { day in
      let blocks = finder.freeBlocks(
        on: day,
        annotated: annotated,
        notBefore: calendar.isDate(day, inSameDayAs: notBefore ?? day) ? notBefore : nil
      )
      // R10. A day with no qualifying block produces no line.
      guard !blocks.isEmpty else { return nil }
      return DayAvailability(day: day, blocks: capped(blocks))
    }
  }

  /// R9a. The three longest blocks, ties broken by the earlier start, restored
  /// to chronological order for rendering.
  func capped(_ blocks: [FreeBlock]) -> [FreeBlock] {
    guard blocks.count > rules.maximumBlocksPerDay else { return blocks }
    let kept = blocks
      .sorted { left, right in
        left.duration == right.duration
          ? left.start < right.start : left.duration > right.duration
      }
      .prefix(rules.maximumBlocksPerDay)
    return kept.sorted { $0.start < $1.start }
  }

  private func annotate(_ events: [NormalizedEvent]) -> [EventAnnotation] {
    // R20: an annotator that cannot answer is not allowed to fail the run.
    (annotator as? FallbackAnnotator ?? FallbackAnnotator(primary: annotator)).annotate(events)
  }

  /// KTD12. Keyed on identifier *and* start, so the occurrences of a recurring
  /// series stay distinct.
  private func deduplicated(_ events: [NormalizedEvent]) -> [NormalizedEvent] {
    var seen: Set<NormalizedEvent.ID> = []
    return events.filter { seen.insert($0.id).inserted }
  }
}
