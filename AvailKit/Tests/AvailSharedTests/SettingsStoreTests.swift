import Foundation
import Testing

@testable import AvailShared

@Suite("Settings store")
struct SettingsStoreTests {
  /// A store in a throwaway directory, so nothing here touches a real app
  /// group container.
  func store(named name: String = UUID().uuidString) -> SettingsStore {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("avail-tests-\(name)", isDirectory: true)
    return SettingsStore(directory: directory)
  }

  let calendars = [
    CalendarDescriptor(identifier: "cal-work", name: "Work"),
    CalendarDescriptor(identifier: "cal-structure", name: Settings.seededCalendarName),
    CalendarDescriptor(identifier: "cal-family", name: "Family"),
  ]

  @Test func aRoundTripPreservesEveryField() throws {
    let store = store()
    var settings = Settings.default
    settings.excludedCalendarIdentifiers = ["a", "b"]
    settings.appendsTimeZoneLabel = true
    settings.hasSeededExclusions = true

    try store.save(settings)
    #expect(store.load() == settings)
  }

  /// KTD5. A missing file is the ordinary first-run case, not an error.
  @Test func aMissingFileYieldsTheDocumentedDefaults() {
    let settings = store().load()
    #expect(settings == Settings.default)
    #expect(settings.excludedCalendarIdentifiers.isEmpty)
    #expect(settings.appendsTimeZoneLabel == false)
    #expect(settings.hasSeededExclusions == false)
  }

  /// Unreadable contents fall back to the defaults rather than throwing into
  /// an extension that has seconds to render something.
  @Test func unreadableContentsYieldTheDefaults() throws {
    let store = store()
    try FileManager.default.createDirectory(
      at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    try Data("not json".utf8).write(to: store.url)
    #expect(store.load() == Settings.default)
  }

  /// R5. The named calendar is excluded once, at first run.
  @Test func firstRunSeedsTheNamedExclusion() {
    let seeded = Settings.default.seeding(from: calendars)
    #expect(seeded.excludedCalendarIdentifiers == ["cal-structure"])
    #expect(seeded.hasSeededExclusions)
  }

  /// R5, and the reason the seed is recorded rather than recomputed: a later
  /// run must not undo the owner re-including that calendar.
  @Test func alaterRunDoesNotReseedAfterTheOwnerReincludesTheCalendar() {
    var settings = Settings.default.seeding(from: calendars)
    settings.excludedCalendarIdentifiers.remove("cal-structure")
    let again = settings.seeding(from: calendars)
    #expect(again.excludedCalendarIdentifiers.isEmpty)
  }

  /// A device without that calendar still records the seed, so adding the
  /// calendar later does not retroactively exclude it.
  @Test func theSeedIsRecordedEvenWhenTheNamedCalendarIsAbsent() {
    let settings = Settings.default.seeding(from: [calendars[0]])
    #expect(settings.excludedCalendarIdentifiers.isEmpty)
    #expect(settings.hasSeededExclusions)
  }

  /// A full resync can lose a calendar's identifier. R26 keys the selection on
  /// that identifier, so a stored one that no longer resolves is dropped and
  /// the calendar reverts to blocking. Recovering it by name would reintroduce
  /// the name matching R26 confines to first run, and would fight the no-reseed
  /// rule above.
  @Test func anIdentifierThatNoLongerResolvesIsDropped() {
    var settings = Settings.default
    settings.excludedCalendarIdentifiers = ["cal-work", "cal-gone"]
    let pruned = settings.pruned(against: calendars)
    #expect(pruned.excludedCalendarIdentifiers == ["cal-work"])
  }

  @Test func pruningAgainstNoCalendarsLeavesTheSelectionAlone() {
    var settings = Settings.default
    settings.excludedCalendarIdentifiers = ["cal-work"]
    // An empty calendar list means the store could not be read, not that every
    // calendar vanished.
    #expect(settings.pruned(against: []).excludedCalendarIdentifiers == ["cal-work"])
  }

  /// R25a. What one process writes, the other reads.
  @Test func whatOneProcessWritesTheOtherReads() throws {
    let name = UUID().uuidString
    var settings = Settings.default
    settings.appendsTimeZoneLabel = true
    try store(named: name).save(settings)
    #expect(store(named: name).load().appendsTimeZoneLabel)
  }

  /// KTD5. The app-group initializer puts the file inside the container it
  /// resolves, which is what makes both processes read the same bytes.
  ///
  /// The other half of KTD5 -- that a container which does not resolve is
  /// `nil` and fails immediately, where an unentitled `UserDefaults` suite
  /// would hand back a live object whose writes silently never arrive -- is
  /// iOS behavior and is not reachable here: macOS synthesizes a Group
  /// Containers path for any identifier, so the failing branch never runs on
  /// the destination this gate uses.
  @Test func theAppGroupStoreLivesInsideItsContainer() throws {
    let identifier = "group.com.raineorshine.avail"
    let container = try #require(
      FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    )
    let store = try #require(SettingsStore(appGroupIdentifier: identifier))
    #expect(store.url.deletingLastPathComponent().path == container.path)
    #expect(store.url.lastPathComponent == "settings.json")
  }
}
