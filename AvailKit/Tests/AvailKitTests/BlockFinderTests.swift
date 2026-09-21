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

  func blocks(
    on day: String,
    _ events: [NormalizedEvent],
    notBefore: Date? = nil,
    finder: BlockFinder? = nil
  ) -> [String] {
    let finder = finder ?? self.finder
    let annotated = AnnotatedEvent.pairing(events, with: DeterministicAnnotator().annotate(events))
    return times(
      finder.freeBlocks(on: Fixture.date(day), annotated: annotated, notBefore: notBefore),
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

  /// A later-starting event whose buffer reaches back before an earlier one's
  /// still merges: the finder sorts by widened start, not by raw start.
  @Test func mergingSortsByTheWidenedStartNotTheRawStart() {
    let events = [
      Fixture.event("late", from: "2017-07-12 12:00", to: "2017-07-12 13:00"),
      Fixture.event("early", from: "2017-07-12 11:00", to: "2017-07-12 11:50"),
    ]
    #expect(blocks(on: "2017-07-12", events) == ["09:00-10:45", "13:15-19:00"])
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
