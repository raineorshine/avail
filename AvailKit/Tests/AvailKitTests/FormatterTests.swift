import Foundation
import Testing

@testable import AvailKit

@Suite("Formatter")
struct FormatterTests {
  let formatter = AvailabilityFormatter(calendar: Fixture.calendar)

  func block(_ start: String, _ end: String, on day: String = "2017-07-11") -> FreeBlock {
    FreeBlock(start: Fixture.date("\(day) \(start)"), end: Fixture.date("\(day) \(end)"))
  }

  func line(_ blocks: [FreeBlock], timeZoneLabel: Bool = false, formatter: AvailabilityFormatter? = nil)
    -> String
  {
    let formatter = formatter ?? self.formatter
    return formatter.line(
      for: DayAvailability(day: blocks[0].start, blocks: blocks), timeZoneLabel: timeZoneLabel
    )
  }

  /// R12. The start's suffix is dropped when both ends sit in the same half of
  /// the day and kept when they do not.
  @Test func aBlockCrossingNoonKeepsTheStartSuffix() {
    #expect(line([block("09:00", "14:15")]) == "Tue 7/11 9am-2:15pm")
  }

  @Test func anAfternoonBlockOmitsTheStartSuffix() {
    #expect(line([block("15:45", "19:00")]) == "Tue 7/11 3:45-7pm")
  }

  @Test func aMorningBlockOmitsTheStartSuffix() {
    #expect(line([block("09:00", "10:45")]) == "Tue 7/11 9-10:45am")
  }

  /// Noon is the afternoon, so a block ending at noon exactly crosses.
  @Test func noonCountsAsTheAfternoon() {
    #expect(line([block("09:00", "12:00")]) == "Tue 7/11 9am-12pm")
    #expect(line([block("12:00", "17:00")]) == "Tue 7/11 12-5pm")
  }

  @Test func zeroMinutesAreOmittedAndOthersAreZeroPadded() {
    #expect(line([block("09:00", "16:00")]) == "Tue 7/11 9am-4pm")
    #expect(line([block("09:05", "16:05")]) == "Tue 7/11 9:05am-4:05pm")
  }

  /// R9, AE4. One line per day: the date prefix once, then the day's blocks
  /// separated by commas.
  @Test func adayRendersAsOneLineWithItsBlocksCommaSeparated() {
    #expect(line([block("09:00", "14:15"), block("15:45", "19:00")]) == "Tue 7/11 9am-2:15pm, 3:45-7pm")
  }

  /// R13. No timezone label by default.
  @Test func noLineCarriesATimezoneLabelByDefault() {
    #expect(!line([block("09:00", "14:15")]).contains("GMT"))
  }

  /// R13a, AE12c. The label is the season-independent generic short name, so
  /// it reads `ET` whatever the date — never `EDT` or `EST`. A fixed offset
  /// cannot exercise this: it has no generic name and renders as `GMT-6`,
  /// which is why this one case injects a named zone.
  @Test func theTimezoneToggleAppendsTheGenericShortName() {
    let eastern = AvailabilityFormatter(calendar: Fixture.calendar(in: "America/New_York"))
    let day = Fixture.date("2017-07-11", in: eastern.calendar)
    let blocks = [
      FreeBlock(
        start: Fixture.date("2017-07-11 09:00", in: eastern.calendar),
        end: Fixture.date("2017-07-11 14:15", in: eastern.calendar)
      ),
      FreeBlock(
        start: Fixture.date("2017-07-11 15:45", in: eastern.calendar),
        end: Fixture.date("2017-07-11 19:00", in: eastern.calendar)
      ),
    ]
    let rendered = eastern.line(
      for: DayAvailability(day: day, blocks: blocks), timeZoneLabel: true
    )
    #expect(rendered == "Tue 7/11 9am-2:15pm, 3:45-7pm ET")
  }

  /// The same zone in January renders the same label, which is the point of
  /// the generic form.
  @Test func theTimezoneLabelDoesNotChangeWithTheSeason() {
    let eastern = AvailabilityFormatter(calendar: Fixture.calendar(in: "America/New_York"))
    let winter = Fixture.date("2017-01-10 09:00", in: eastern.calendar)
    let rendered = eastern.line(
      for: DayAvailability(
        day: winter,
        blocks: [FreeBlock(start: winter, end: winter.addingTimeInterval(5 * 3600))]
      ),
      timeZoneLabel: true
    )
    #expect(rendered.hasSuffix(" ET"))
  }

  /// KTD3. The pin itself, asserted rather than assumed: a wrong-sign edit to
  /// the fixture zone fails here rather than drifting every expectation by
  /// twelve hours.
  @Test func theSuitesFixedZoneIsMinusSixHoursWithNoDaylightSaving() {
    let now = Fixture.date("2017-07-11 12:00")
    #expect(Fixture.timeZone.secondsFromGMT(for: now) == -21600)
    #expect(Fixture.timeZone.isDaylightSavingTime(for: now) == false)
    #expect(Fixture.calendar.timeZone == Fixture.timeZone)
    #expect(Fixture.calendar.locale == Locale(identifier: "en_US_POSIX"))
  }

  @Test func daysAreJoinedByNewlines() {
    let days = [
      DayAvailability(day: block("09:00", "19:00", on: "2017-07-10").start, blocks: [block("09:00", "19:00", on: "2017-07-10")]),
      DayAvailability(day: block("09:00", "19:00", on: "2017-07-11").start, blocks: [block("09:00", "19:00", on: "2017-07-11")]),
    ]
    #expect(formatter.text(days, timeZoneLabel: false) == "Mon 7/10 9am-7pm\nTue 7/11 9am-7pm")
  }
}
