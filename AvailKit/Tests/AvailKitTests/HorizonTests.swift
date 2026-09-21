import Foundation
import Testing

@testable import AvailKit

@Suite("Horizon")
struct HorizonTests {
  let horizon = Horizon(calendar: Fixture.calendar)

  func weekday(_ date: Date) -> String {
    ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][
      Fixture.calendar.component(.weekday, from: date) - 1
    ]
  }

  /// R2, AE1. 10 July 2017 is a Monday. Day 7 is a Monday too, and day 8 is a
  /// Tuesday, so the window runs to day 9.
  @Test func aWindowStartingOnMondaySpansNineDaysAndEndsOnWednesday() {
    let now = Fixture.date("2017-07-10 08:00")
    #expect(weekday(now) == "Mon")
    #expect(horizon.span(from: now) == 9)
    #expect(weekday(horizon.days(from: now).last!) == "Wed")
  }

  /// R2, AE2.
  @Test func aWindowStartingOnTuesdaySpansEightDaysAndEndsOnWednesday() {
    let now = Fixture.date("2017-07-11 08:00")
    #expect(weekday(now) == "Tue")
    #expect(horizon.span(from: now) == 8)
    #expect(weekday(horizon.days(from: now).last!) == "Wed")
  }

  /// R2, AE3. Day 7 of a Thursday is a Thursday, so nothing is extended.
  @Test func aWindowStartingOnThursdaySpansExactlySevenDays() {
    let now = Fixture.date("2017-07-13 08:00")
    #expect(weekday(now) == "Thu")
    #expect(horizon.span(from: now) == 7)
    #expect(weekday(horizon.days(from: now).last!) == "Thu")
  }

  /// Every other starting weekday lands on a day 7 that is neither a Monday
  /// nor a Tuesday, so seven is the rule and eight and nine are the exceptions.
  @Test(arguments: [
    ("2017-07-12", "Wed", 7), ("2017-07-14", "Fri", 7), ("2017-07-15", "Sat", 7),
    ("2017-07-16", "Sun", 7),
  ])
  func theOtherWeekdaysSpanSevenDays(day: String, name: String, span: Int) {
    let now = Fixture.date("\(day) 08:00")
    #expect(weekday(now) == name)
    #expect(horizon.span(from: now) == span)
  }

  /// The window never ends on a Monday or a Tuesday, whatever day it starts on.
  @Test(arguments: 0..<7)
  func theWindowNeverEndsOnAMondayOrATuesday(offset: Int) {
    let now = Fixture.calendar.date(
      byAdding: .day, value: offset, to: Fixture.date("2017-07-10 08:00")
    )!
    let last = weekday(horizon.days(from: now).last!)
    #expect(last != "Mon")
    #expect(last != "Tue")
  }

  /// The day list is the offsets 0 through the span, inclusive.
  @Test func theDayListCoversEveryDayInTheWindow() {
    let now = Fixture.date("2017-07-13 08:00")
    #expect(horizon.days(from: now).count == 8)
  }

  /// R4, AE10.
  @Test func theSearchStartsAtTheNextHalfHour() {
    let start = horizon.searchStart(from: Fixture.date("2017-07-13 14:10"))
    #expect(start == Fixture.date("2017-07-13 14:30"))
  }

  /// R4. On the half hour exactly, the search starts now and does not skip
  /// forward to the top of the hour.
  @Test func theSearchStartsNowWhenNowIsAlreadyOnTheHalfHour() {
    let start = horizon.searchStart(from: Fixture.date("2017-07-13 14:30"))
    #expect(start == Fixture.date("2017-07-13 14:30"))
  }

  @Test func aTimePastTheHalfHourRoundsUpToTheTopOfTheNextHour() {
    let start = horizon.searchStart(from: Fixture.date("2017-07-13 14:45"))
    #expect(start == Fixture.date("2017-07-13 15:00"))
  }

  /// Seconds count: 14:30:01 is past the half hour.
  @Test func secondsPastTheHalfHourRoundUp() {
    let now = Fixture.date("2017-07-13 14:30").addingTimeInterval(1)
    #expect(horizon.searchStart(from: now) == Fixture.date("2017-07-13 15:00"))
  }

  /// R2a. The second pass reads the 30 days after the preferred window, and
  /// begins where it left off.
  @Test func theSecondPassReadsTheFollowingThirtyDays() {
    let now = Fixture.date("2017-07-13 08:00")
    #expect(horizon.secondPassDays(from: now).count == 30)
    #expect(horizon.secondPassInterval(from: now).start == horizon.interval(from: now).end)
    #expect(horizon.secondPassDays(from: now).first! == horizon.secondPassInterval(from: now).start)
  }

  /// The fetch interval is day-aligned so an event that starts before the
  /// search does but runs into it is still read.
  @Test func theFetchIntervalCoversWholeDays() {
    let now = Fixture.date("2017-07-13 14:10")
    let interval = horizon.interval(from: now)
    #expect(interval.start == Fixture.date("2017-07-13 00:00"))
    #expect(interval.end == Fixture.date("2017-07-21 00:00"))
  }
}
