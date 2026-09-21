import Foundation
import Testing

@testable import AvailKit

@Suite("Day grouper")
struct DayGrouperTests {
  let grouper = DayGrouper(calendar: Fixture.calendar)

  /// Records what the search asked for, so "at most two passes" is observable
  /// rather than inferred.
  final class RecordingProvider: @unchecked Sendable {
    private(set) var intervals: [DateInterval] = []
    let events: [NormalizedEvent]

    init(_ events: [NormalizedEvent]) { self.events = events }

    func provide(_ interval: DateInterval) -> [NormalizedEvent] {
      intervals.append(interval)
      return events.filter { $0.end > interval.start && $0.start < interval.end }
    }
  }

  /// A day booked from before 9am to after 7pm, so nothing qualifies on it.
  func fullyBooked(_ day: String) -> NormalizedEvent {
    Fixture.event("booked \(day)", from: "\(day) 08:00", to: "\(day) 20:00")
  }

  func day(_ offset: Int, from now: Date) -> String {
    let date = Fixture.calendar.date(byAdding: .day, value: offset, to: now)!
    let components = Fixture.calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
  }

  func labels(_ days: [DayAvailability]) -> [String] {
    days.map { availability in
      let components = Fixture.calendar.dateComponents([.month, .day], from: availability.day)
      return "\(components.month!)/\(components.day!)"
    }
  }

  /// R11, AE5. Two booked days at the front, six open behind them: the list
  /// starts on the third day and stops at five.
  @Test func theFirstFiveQualifyingDaysAreEmitted() {
    // Thursday, so the preferred window is days 0 through 7.
    let now = Fixture.date("2017-07-13 08:00")
    let provider = RecordingProvider([fullyBooked("2017-07-13"), fullyBooked("2017-07-14")])
    let days = grouper.qualifyingDays(now: now, provider: provider.provide)
    #expect(labels(days) == ["7/15", "7/16", "7/17", "7/18", "7/19"])
    #expect(provider.intervals.count == 1)
  }

  /// R2a, AE5a. The whole preferred window is booked, so the second pass runs
  /// and the five lines come from the days after it.
  @Test func theSearchReachesPastThePreferredWindow() {
    let now = Fixture.date("2017-07-13 08:00")
    let booked = (0...7).map { fullyBooked(day($0, from: now)) }
    let provider = RecordingProvider(booked)
    let days = grouper.qualifyingDays(now: now, provider: provider.provide)
    #expect(labels(days) == ["7/21", "7/22", "7/23", "7/24", "7/25"])
    #expect(provider.intervals.count == 2)
  }

  /// R2a, AE5b. Two qualifying days inside the window is not enough, so the
  /// search continues into the following 30 days rather than stopping short.
  @Test func aPartiallyQualifyingWindowContinuesIntoTheSecondPass() {
    let now = Fixture.date("2017-07-13 08:00")
    // Everything booked except days 3 and 5 of the preferred window.
    let booked = [0, 1, 2, 4, 6, 7].map { fullyBooked(day($0, from: now)) }
    let provider = RecordingProvider(booked)
    let days = grouper.qualifyingDays(now: now, provider: provider.provide)
    #expect(labels(days) == ["7/16", "7/18", "7/21", "7/22", "7/23"])
    #expect(provider.intervals.count == 2)
    #expect(provider.intervals[1].start == provider.intervals[0].end)
  }

  /// R2b, AE5d. Fewer than five qualifying days across both passes emits what
  /// there is, and no third pass runs.
  @Test func aShortResultIsEmittedRatherThanSearchedFurther() {
    let now = Fixture.date("2017-07-13 08:00")
    // Book every day of both passes but two.
    let booked = (0...37).filter { $0 != 2 && $0 != 30 }.map { fullyBooked(day($0, from: now)) }
    let provider = RecordingProvider(booked)
    let days = grouper.qualifyingDays(now: now, provider: provider.provide)
    #expect(labels(days) == ["7/15", "8/12"])
    #expect(provider.intervals.count == 2)
  }

  /// R10. A day whose only gaps are under an hour produces no entry at all.
  @Test func aDayWithNoQualifyingBlockIsNotEmitted() {
    let now = Fixture.date("2017-07-13 08:00")
    let chopped = [
      Fixture.event("a", from: "2017-07-13 09:30", to: "2017-07-13 12:00"),
      Fixture.event("b", from: "2017-07-13 12:45", to: "2017-07-13 15:00"),
      Fixture.event("c", from: "2017-07-13 15:45", to: "2017-07-13 20:00"),
    ]
    let provider = RecordingProvider(chopped)
    let days = grouper.qualifyingDays(now: now, provider: provider.provide)
    #expect(labels(days).first != "7/13")
  }

  /// R9a, AE5c. Five qualifying blocks, two of them three hours long: the
  /// three longest survive, the earlier of the tied pair wins, and what is
  /// left is rendered in chronological order, not longest first.
  @Test func atMostThreeBlocksSurviveADayAndTheyStayChronological() {
    let now = Fixture.date("2017-07-12 08:00")
    // Four instantaneous events, each buffered to a 30-minute separator, cut
    // the window into five qualifying blocks: 09:00-10:00 (1h),
    // 10:30-11:45 (1h15m), 12:15-13:30 (1h15m), 14:00-15:30 (1h30m),
    // 16:00-19:00 (3h).
    let events = ["10:15", "12:00", "13:45", "15:45"].map {
      Fixture.event($0, from: "2017-07-12 \($0)", to: "2017-07-12 \($0)")
    }
    let provider = RecordingProvider(events)
    let days = grouper.qualifyingDays(now: now, provider: provider.provide)
    #expect(days[0].blocks.count == 3)
    let starts = days[0].blocks.map { block -> String in
      let components = Fixture.calendar.dateComponents([.hour, .minute], from: block.start)
      return String(format: "%02d:%02d", components.hour!, components.minute!)
    }
    // 3h and 1h30m take the first two slots. The two 1h15m blocks tie for the
    // third, and the earlier one wins. Rendering is chronological, not
    // longest first.
    #expect(starts == ["10:30", "14:00", "16:00"])
  }

  /// R4, AE10. Today's first block starts at the rounded-up time, not at 9am.
  @Test func todaysSearchStartsAtTheRoundedUpTime() {
    let now = Fixture.date("2017-07-13 14:10")
    let provider = RecordingProvider([])
    let days = grouper.qualifyingDays(now: now, provider: provider.provide)
    #expect(days[0].blocks[0].start == Fixture.date("2017-07-13 14:30"))
    // Later days start at 9am regardless.
    #expect(days[1].blocks[0].start == Fixture.date("2017-07-14 09:00"))
  }

  /// A day whose remaining time is under an hour drops out, so an invocation
  /// late in the evening starts tomorrow.
  @Test func aLateInvocationSkipsTodayEntirely() {
    let now = Fixture.date("2017-07-13 18:30")
    let provider = RecordingProvider([])
    let days = grouper.qualifyingDays(now: now, provider: provider.provide)
    #expect(labels(days).first == "7/14")
  }

  /// R4. Late enough that rounding up crosses midnight, today is gone rather
  /// than offered back as a fully open day.
  ///
  /// This is the one case where the search start belongs to no day in the
  /// list: at 23:45 it rounds to tomorrow 00:00, so a day-0 window that only
  /// honored a start falling on its own date would see no start at all and
  /// report 9am-7pm for hours that have already gone.
  @Test func anInvocationLateEnoughToRoundPastMidnightDropsToday() {
    let now = Fixture.date("2017-07-13 23:45")
    let provider = RecordingProvider([])
    let days = grouper.qualifyingDays(now: now, provider: provider.provide)
    #expect(!labels(days).contains("7/13"))
    #expect(labels(days).first == "7/14")
  }

  /// KTD12. Two occurrences of one series both take time away; deduplicating
  /// on the shared identifier alone would hand back a day that looks open.
  @Test func twoOccurrencesOfOneSeriesBothBlock() {
    let now = Fixture.date("2017-07-13 08:00")
    let events = [
      Fixture.event("standup", from: "2017-07-13 09:00", to: "2017-07-13 17:00", identifier: "series"),
      Fixture.event("standup", from: "2017-07-14 09:00", to: "2017-07-14 17:00", identifier: "series"),
    ]
    let provider = RecordingProvider(events)
    let days = grouper.qualifyingDays(now: now, provider: provider.provide)
    #expect(days[0].blocks.count == 1)
    #expect(days[1].blocks.count == 1)
    #expect(Fixture.calendar.component(.hour, from: days[0].blocks[0].start) == 17)
    #expect(Fixture.calendar.component(.hour, from: days[1].blocks[0].start) == 17)
  }
}
