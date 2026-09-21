import Foundation
import Testing

@testable import AvailKit

@Suite("Availability engine")
struct EngineTests {
  let engine = AvailabilityEngine(calendar: Fixture.calendar)

  /// The ported fixtures, end to end.
  ///
  /// Every line below was recomputed from the 9am-7pm window, the 15-minute
  /// buffers, one line per day and the five-line cap. The JavaScript suite's
  /// expectation for the same events was nine lines against a 9am-5pm day with
  /// no buffers and one line per block; none of it carries over.
  ///
  /// The Tuesday line is AE4 exactly: a 2:30-3:30pm meeting, buffered out to
  /// 2:15-3:45pm.
  @Test func theFixtureEventListRendersTheRecomputedFiveLines() {
    let now = Fixture.date("2017-07-10 08:00")
    let availability = engine.generate(
      now: now, provider: Fixture.provider(Fixture.portedEvents)
    )
    #expect(
      availability.text == """
        Mon 7/10 9am-7pm
        Tue 7/11 9am-2:15pm, 3:45-7pm
        Wed 7/12 9am-7pm
        Thu 7/13 9am-7pm
        Fri 7/14 9-10:45am, 2:15-7pm
        """
    )
  }

  /// R11. Five lines, not more.
  @Test func atMostFiveLinesAreEmitted() {
    let now = Fixture.date("2017-07-10 08:00")
    let availability = engine.generate(now: now, provider: Fixture.provider([]))
    #expect(availability.days.count == 5)
  }

  /// R13a. The toggle reaches every line, not just the first.
  @Test func theTimezoneToggleReachesEveryLine() {
    let eastern = AvailabilityEngine(calendar: Fixture.calendar(in: "America/New_York"))
    let now = Fixture.date("2017-07-10 08:00", in: eastern.calendar)
    let availability = eastern.generate(
      now: now, appendsTimeZoneLabel: true, provider: Fixture.provider([])
    )
    #expect(availability.text.split(separator: "\n").allSatisfy { $0.hasSuffix(" ET") })
  }

  /// R5, AE8. An excluded calendar's events take no time away.
  @Test func anExcludedCalendarTakesNoTimeAway() {
    let structure = EventCalendar(
      identifier: "structure", title: "Supportive and Nourishing Structure"
    )
    let event = Fixture.event(
      "morning pages", from: "2017-07-14 10:00", to: "2017-07-14 12:00", source: structure
    )
    let now = Fixture.date("2017-07-14 08:00")

    // Buffered out to 9:45-12:15, the event leaves a 45-minute morning sliver
    // that does not clear the minimum, so the whole morning goes.
    let blocking = engine.generate(now: now, provider: Fixture.provider([event]))
    #expect(blocking.text.hasPrefix("Fri 7/14 12:15-7pm"))

    let excluded = engine.generate(
      now: now, excludedCalendarIdentifiers: ["structure"], provider: Fixture.provider([event])
    )
    #expect(excluded.text.hasPrefix("Fri 7/14 9am-7pm"))
  }

  /// R20, AE11. An annotator that throws on every batch produces exactly the
  /// deterministic result, with no error reaching the caller.
  @Test func anAnnotatorThatThrowsProducesTheDeterministicResult() {
    struct Boom: Error {}
    struct AlwaysFails: Annotator {
      func annotate(_ events: [NormalizedEvent]) throws -> [EventAnnotation] { throw Boom() }
    }

    let now = Fixture.date("2017-07-10 08:00")
    let failing = AvailabilityEngine(calendar: Fixture.calendar, annotator: AlwaysFails())
    #expect(
      failing.generate(now: now, provider: Fixture.provider(Fixture.portedEvents)).text
        == engine.generate(now: now, provider: Fixture.provider(Fixture.portedEvents)).text
    )
  }

  /// R2b. A calendar with no open time at all yields an empty result rather
  /// than an empty string offered as availability.
  @Test func aWindowWithNoOpenTimeYieldsAnEmptyResult() {
    let now = Fixture.date("2017-07-10 08:00")
    let booked = (0...40).map { offset -> NormalizedEvent in
      let day = Fixture.calendar.date(byAdding: .day, value: offset, to: now)!
      return NormalizedEvent(
        eventIdentifier: "booked \(offset)",
        title: "booked",
        calendar: Fixture.defaultCalendarSource,
        start: Fixture.calendar.startOfDay(for: day),
        end: Fixture.calendar.date(byAdding: .day, value: 1, to: Fixture.calendar.startOfDay(for: day))!,
        responseStatus: .accepted
      )
    }
    let availability = engine.generate(now: now, provider: Fixture.provider(booked))
    #expect(availability.isEmpty)
    #expect(availability.text.isEmpty)
  }

  /// The app's preview and the extension's insertion are the same call, so a
  /// second run over the same inputs is the same text.
  @Test func generationIsDeterministic() {
    let now = Fixture.date("2017-07-10 08:00")
    let first = engine.generate(now: now, provider: Fixture.provider(Fixture.portedEvents))
    let second = engine.generate(now: now, provider: Fixture.provider(Fixture.portedEvents))
    #expect(first.text == second.text)
  }
}
