import Foundation
import Testing

@testable import AvailKit

@Suite("Block finder")
struct BlockFinderTests {
  let finder = BlockFinder(calendar: Fixture.calendar)

  /// Renders a day's blocks as `HH:mm-HH:mm`, so a failure reads as times
  /// rather than as two `Date` descriptions in UTC.
  func times(_ blocks: [FreeBlock], in calendar: Calendar = Fixture.calendar) -> [String] {
    blocks.map { block in
      let start = calendar.dateComponents([.hour, .minute], from: block.start)
      let end = calendar.dateComponents([.hour, .minute], from: block.end)
      return String(
        format: "%02d:%02d-%02d:%02d", start.hour!, start.minute!, end.hour!, end.minute!
      )
    }
  }

  /// Buffers that differ per event. The shipped annotator's uniform buffer
  /// cannot reorder anything -- subtracting one constant from every start
  /// preserves their order -- so only a skewed one can show that the merge
  /// sorts by the widened start rather than the raw one.
  struct SkewedAnnotator: Annotator {
    let wideTitle: String
    let bufferBefore: TimeInterval

    func annotate(_ events: [NormalizedEvent]) -> [EventAnnotation] {
      events.map { event in
        EventAnnotation(
          blocksAvailability: true,
          bufferBefore: event.title == wideTitle ? bufferBefore : 0,
          bufferAfter: 0
        )
      }
    }
  }

  func blocks(
    on day: String,
    _ events: [NormalizedEvent],
    notBefore: Date? = nil,
    finder: BlockFinder? = nil,
    annotator: any Annotator = DeterministicAnnotator()
  ) -> [String] {
    let finder = finder ?? self.finder
    let annotated = AnnotatedEvent.pairing(events, with: FallbackAnnotator(primary: annotator).annotate(events))
    return times(
      finder.freeBlocks(
        on: Fixture.date(day, in: finder.calendar), annotated: annotated, notBefore: notBefore
      ),
      in: finder.calendar
    )
  }

  /// R1.
  @Test func aDayWithNoEventsIsOpenForTheWholeWindow() {
    #expect(blocks(on: "2017-07-12", []) == ["09:00-19:00"])
  }

  /// R3, AE6. A 45-minute gap does not survive; a 3-hour one does.
  @Test func aBlockShorterThanAnHourIsNotOffered() {
    let events = [
      Fixture.event("a", from: "2017-07-12 09:30", to: "2017-07-12 10:30"),
      Fixture.event("b", from: "2017-07-12 11:30", to: "2017-07-12 15:30"),
    ]
    // 09:00-09:15 (15m), 10:45-11:15 (30m), 15:45-19:00 (3h15m): only the last
    // clears an hour.
    #expect(blocks(on: "2017-07-12", events) == ["15:45-19:00"])
  }

  @Test func anEventOverlappingTheStartOfTheDayShortensTheFirstBlock() {
    let events = [Fixture.event(from: "2017-07-12 08:00", to: "2017-07-12 10:00")]
    #expect(blocks(on: "2017-07-12", events) == ["10:15-19:00"])
  }

  @Test func anEventOverlappingTheEndOfTheDayShortensTheLastBlock() {
    let events = [Fixture.event(from: "2017-07-12 15:00", to: "2017-07-12 21:00")]
    #expect(blocks(on: "2017-07-12", events) == ["09:00-14:45"])
  }

  @Test func anEventAdjacentToTheStartOfTheDayLeavesTheRestIntact() {
    let events = [Fixture.event(from: "2017-07-12 09:00", to: "2017-07-12 10:00")]
    #expect(blocks(on: "2017-07-12", events) == ["10:15-19:00"])
  }

  @Test func anEventAdjacentToTheEndOfTheDayLeavesTheRestIntact() {
    let events = [Fixture.event(from: "2017-07-12 18:00", to: "2017-07-12 19:00")]
    #expect(blocks(on: "2017-07-12", events) == ["09:00-17:45"])
  }

  @Test func twoOverlappingEventsProduceOneMergedExclusion() {
    let events = [
      Fixture.event("a", from: "2017-07-12 10:00", to: "2017-07-12 11:30"),
      Fixture.event("b", from: "2017-07-12 11:00", to: "2017-07-12 12:30"),
    ]
    #expect(blocks(on: "2017-07-12", events) == ["12:45-19:00"])
  }

  /// KTD6. The original's recursion advances past one overlapping event at a
  /// time and is correct only because its events are sorted by unbuffered
  /// start. Buffers reorder effective starts, so merging first is what keeps
  /// R8 from silently dropping a block.
  @Test func twoEventsWhoseBuffersOverlapProduceOneMergedExclusion() {
    let events = [
      Fixture.event("a", from: "2017-07-12 10:00", to: "2017-07-12 11:00"),
      Fixture.event("b", from: "2017-07-12 11:20", to: "2017-07-12 12:00"),
    ]
    // 10:45 and 11:05 do not overlap as events but do once buffered, and the
    // 20-minute gap between them is under the minimum anyway.
    #expect(blocks(on: "2017-07-12", events) == ["12:15-19:00"])
  }

  /// KTD6, and the reason the merge cannot be rewritten to sort the annotated
  /// events by `event.start` before widening them.
  ///
  /// `wide` starts an hour after `narrow` but carries a 90-minute buffer, so
  /// its *widened* start is half an hour earlier. Sorted by the widened start
  /// the two merge into 10:30-12:30 and the morning block ends at 10:30;
  /// sorted by the raw start they merge into 11:00-12:30 instead and 10:30 to
  /// 11:00 is wrongly offered as free.
  @Test func mergingSortsByTheWidenedStartNotTheRawStart() {
    let events = [
      Fixture.event("narrow", from: "2017-07-12 11:00", to: "2017-07-12 11:30"),
      Fixture.event("wide", from: "2017-07-12 12:00", to: "2017-07-12 12:30"),
    ]
    let skewed = SkewedAnnotator(wideTitle: "wide", bufferBefore: 90 * 60)
    #expect(
      blocks(on: "2017-07-12", events, annotator: skewed) == ["09:00-10:30", "12:30-19:00"]
    )
  }

  @Test func anEventEntirelyOutsideTheWindowRemovesNothing() {
    let events = [Fixture.event(from: "2017-07-12 06:00", to: "2017-07-12 07:00")]
    #expect(blocks(on: "2017-07-12", events) == ["09:00-19:00"])
  }

  @Test func eventsOnOtherDaysRemoveNothing() {
    let events = [Fixture.event(from: "2017-07-11 10:00", to: "2017-07-11 16:00")]
    #expect(blocks(on: "2017-07-12", events) == ["09:00-19:00"])
  }

  @Test func anEventSpanningTheWholeDayLeavesNoQualifyingBlock() {
    let events = [Fixture.event(from: "2017-07-12 08:00", to: "2017-07-12 20:00")]
    #expect(blocks(on: "2017-07-12", events) == [])
  }

  /// R6, AE7. A non-blocking annotation removes nothing even though the event
  /// covers the window.
  @Test func anAllDayEventLeavesTheDayFullyOpen() {
    let events = [
      Fixture.event(from: "2017-07-13 00:00", to: "2017-07-14 00:00", isAllDay: true)
    ]
    #expect(blocks(on: "2017-07-13", events) == ["09:00-19:00"])
  }

  /// R4. The day's search starts where the caller says, not at 9:00.
  @Test func theSearchStartsAtTheGivenTimeWhenItIsInsideTheWindow() {
    let notBefore = Fixture.date("2017-07-12 14:30")
    #expect(blocks(on: "2017-07-12", [], notBefore: notBefore) == ["14:30-19:00"])
  }

  @Test func aStartAfterTheWindowLeavesNoBlock() {
    let notBefore = Fixture.date("2017-07-12 19:30")
    #expect(blocks(on: "2017-07-12", [], notBefore: notBefore) == [])
  }

  /// KTD7. The original advances days by a fixed count of milliseconds, which
  /// drifts by an hour across a transition inside the horizon. 12 March 2017
  /// is the US spring-forward date.
  @Test func aDayWindowCrossingADaylightSavingTransitionStillResolvesToNineAndSeven() {
    let denver = Fixture.calendar(in: "America/Denver")
    let finder = BlockFinder(calendar: denver)
    let day = Fixture.date("2017-03-12", in: denver)
    let window = finder.window(for: day)
    #expect(denver.component(.hour, from: window.start) == 9)
    #expect(denver.component(.hour, from: window.end) == 19)
    // The day is an hour short in real time, and the window is not.
    #expect(window.duration == 10 * 3600)
    #expect(blocks(on: "2017-03-12", [], finder: finder) == ["09:00-19:00"])
  }

  /// The following day, on the far side of the transition, is unaffected.
  @Test func theDayAfterADaylightSavingTransitionIsUnaffected() {
    let denver = Fixture.calendar(in: "America/Denver")
    let finder = BlockFinder(calendar: denver)
    let window = finder.window(for: Fixture.date("2017-03-13", in: denver))
    #expect(denver.component(.hour, from: window.start) == 9)
    #expect(denver.component(.hour, from: window.end) == 19)
  }
}
