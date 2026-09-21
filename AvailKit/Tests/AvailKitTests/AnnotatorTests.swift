import Foundation
import Testing

@testable import AvailKit

@Suite("Deterministic annotator")
struct DeterministicAnnotatorTests {
  let annotator = DeterministicAnnotator()

  /// R6, AE7.
  @Test func anAllDayEventNeverBlocks() throws {
    let event = Fixture.event(from: "2017-07-13 00:00", to: "2017-07-14 00:00", isAllDay: true)
    #expect(try annotator.annotate([event]) == [.free])
  }

  /// R7, AE9.
  @Test func aDeclinedInvitationNeverBlocksAndATentativeOneDoes() throws {
    let declined = Fixture.event(from: "2017-07-15 10:00", to: "2017-07-15 11:00", responseStatus: .declined)
    let tentative = Fixture.event(from: "2017-07-15 13:00", to: "2017-07-15 14:00", responseStatus: .tentative)
    let annotations = try annotator.annotate([declined, tentative])
    #expect(annotations[0].blocksAvailability == false)
    #expect(annotations[1].blocksAvailability == true)
  }

  /// R7a, AE13. Show As Free frees the time whoever owns the event.
  @Test func anEventMarkedFreeNeverBlocks() throws {
    let event = Fixture.event(from: "2017-07-10 10:00", to: "2017-07-10 12:00", availability: .free)
    #expect(try annotator.annotate([event]) == [.free])
  }

  /// KTD10. Subscribed and birthday calendars report `.notSupported` for every
  /// event; treating that as free would over-promise on the calendars the owner
  /// cannot fix.
  @Test func anEventWhoseAvailabilityIsNotSupportedBlocks() throws {
    let event = Fixture.event(
      from: "2017-07-10 10:00", to: "2017-07-10 12:00",
      source: EventCalendar(identifier: "holidays", title: "Holidays", supportsAvailability: false),
      availability: .notSupported
    )
    #expect(try annotator.annotate([event])[0].blocksAvailability == true)
  }

  /// KTD11. Only `.declined` frees time, so an unreadable status stays blocking.
  @Test func anEventWithNoAttendeesAndAnUnknownStatusBlocks() throws {
    let event = Fixture.event(
      from: "2017-07-10 10:00", to: "2017-07-10 12:00",
      responseStatus: .unknown, attendees: nil
    )
    #expect(try annotator.annotate([event])[0].blocksAvailability == true)
  }

  /// KTD11. The owner organizing their own event resolves to `.accepted`.
  @Test func anEventTheOwnerOrganizedWithNoAttendeesBlocks() throws {
    let event = Fixture.event(
      from: "2017-07-10 10:00", to: "2017-07-10 12:00",
      responseStatus: .accepted, attendees: nil
    )
    #expect(try annotator.annotate([event])[0].blocksAvailability == true)
  }

  /// R8.
  @Test func aBlockingEventCarriesFifteenMinutesOfBufferOnEachSide() throws {
    let event = Fixture.event(from: "2017-07-11 14:30", to: "2017-07-11 15:30")
    let annotation = try annotator.annotate([event])[0]
    #expect(annotation.blocksAvailability == true)
    #expect(annotation.bufferBefore == 15 * 60)
    #expect(annotation.bufferAfter == 15 * 60)
  }

  /// R18. One call for the whole list, one annotation per event, in order.
  @Test func everyEventIsResolvedInOnePass() throws {
    let events = (0..<5).map {
      Fixture.event("E\($0)", from: "2017-07-1\($0) 10:00", to: "2017-07-1\($0) 11:00")
    }
    #expect(try annotator.annotate(events).count == events.count)
  }
}

@Suite("Annotator fallback")
struct FallbackAnnotatorTests {
  /// R18: the seam exists so inference runs once over the batch, never once
  /// per event. A counting annotator is the only way to observe the shape.
  final class CountingAnnotator: Annotator, @unchecked Sendable {
    private(set) var calls = 0
    var failure: (any Error)?
    var truncateBy = 0

    func annotate(_ events: [NormalizedEvent]) throws -> [EventAnnotation] {
      calls += 1
      if let failure { throw failure }
      return Array(events.dropLast(truncateBy)).map { _ in EventAnnotation(blocksAvailability: false) }
    }
  }

  struct Boom: Error {}

  /// R20, AE11.
  @Test func anAnnotatorThatThrowsYieldsTheDeterministicAnnotations() throws {
    let primary = CountingAnnotator()
    primary.failure = Boom()
    let events = [
      Fixture.event("busy", from: "2017-07-11 14:30", to: "2017-07-11 15:30"),
      Fixture.event("allDay", from: "2017-07-13 00:00", to: "2017-07-14 00:00", isAllDay: true),
    ]
    let deterministic = try DeterministicAnnotator().annotate(events)
    #expect(try FallbackAnnotator(primary: primary).annotate(events) == deterministic)
  }

  /// A short or long result is as unusable as a thrown one: the annotations
  /// are positional, so a count mismatch cannot be reconciled.
  @Test func anAnnotatorThatReturnsTheWrongCountFallsBackForTheWholeBatch() throws {
    let primary = CountingAnnotator()
    primary.truncateBy = 1
    let events = [
      Fixture.event("a", from: "2017-07-11 14:30", to: "2017-07-11 15:30"),
      Fixture.event("b", from: "2017-07-12 14:30", to: "2017-07-12 15:30"),
    ]
    let annotations = try FallbackAnnotator(primary: primary).annotate(events)
    #expect(annotations == (try DeterministicAnnotator().annotate(events)))
  }

  @Test func theAnnotatorIsCalledOnceForAListOfManyEvents() throws {
    let primary = CountingAnnotator()
    let events = (0..<20).map {
      Fixture.event("E\($0)", from: "2017-07-11 09:00", to: "2017-07-11 10:00", identifier: "e\($0)")
    }
    _ = try FallbackAnnotator(primary: primary).annotate(events)
    #expect(primary.calls == 1)
  }

  /// A primary that succeeds is not second-guessed.
  @Test func aSuccessfulAnnotatorIsUsedAsGiven() throws {
    let primary = CountingAnnotator()
    let events = [Fixture.event(from: "2017-07-11 14:30", to: "2017-07-11 15:30")]
    #expect(try FallbackAnnotator(primary: primary).annotate(events) == [.free])
  }
}
