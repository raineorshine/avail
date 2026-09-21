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

    var annotated = annotating(
      try provider(horizon.interval(from: now)).deduplicatedByOccurrence()
    )
    var days = qualifying(
      horizon.days(from: now), annotated: annotated, finder: finder, notBefore: searchStart
    )

    if days.count < rules.maximumDays {
      // The second pass reads the following 30 days. An event can span the
      // boundary and each fetch returns it, so only what the first pass did
      // not already carry is annotated: the batch stays one call, and events
      // already resolved are not re-sent to an annotator that has a time
      // budget and falls back for the whole batch when it runs out.
      let resolved = Set(annotated.map(\.event.id))
      let fresh = try provider(horizon.secondPassInterval(from: now))
        .deduplicatedByOccurrence()
        .filter { !resolved.contains($0.id) }
      if !fresh.isEmpty { annotated += annotating(fresh) }
      days += qualifying(
        horizon.secondPassDays(from: now), annotated: annotated, finder: finder, notBefore: nil
      )
    }

    return Array(days.prefix(rules.maximumDays))
  }

  private func qualifying(
    _ days: [Date], annotated: [AnnotatedEvent], finder: BlockFinder, notBefore: Date?
  ) -> [DayAvailability] {
    // Merged once per pass rather than once per day: which intervals are busy
    // does not depend on the day being examined, and a horizon runs to forty
    // days in the worst case.
    let busy = BlockFinder.merged(annotated.compactMap(\.busyInterval))
    return days.compactMap { day in
      // `notBefore` is passed to every day, not just the one it falls on.
      // The finder clamps with `max(window.start, notBefore)`, so a start
      // earlier than a later day's 9am is inert; and when a late-evening run
      // rounds the start past midnight, this is what still drops today
      // instead of offering hours that have already gone.
      let blocks = finder.freeBlocks(on: day, busy: busy, notBefore: notBefore)
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

  /// R20: an annotator that cannot answer is not allowed to fail the run.
  private func annotating(_ events: [NormalizedEvent]) -> [AnnotatedEvent] {
    AnnotatedEvent.pairing(events, with: FallbackAnnotator(primary: annotator).annotate(events))
  }
}
