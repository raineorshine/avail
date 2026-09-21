import Foundation

/// A calendar as the settings need to see it: an identifier to key on and a
/// name to match once, at first run.
///
/// Deliberately not the availability module's own calendar type. This module
/// stays independent of that one so the import check over the package's
/// sources is an allowlist of exactly one name.
public struct CalendarDescriptor: Sendable, Hashable, Codable {
  public let identifier: String
  public let name: String

  public init(identifier: String, name: String) {
    self.identifier = identifier
    self.name = name
  }
}

/// What the containing app and the extension share (R25a): which calendars are
/// excluded, and whether the timezone label is on.
public struct Settings: Sendable, Hashable, Codable {
  /// R26. Keyed on each calendar's stable identifier, so a rename does not
  /// change its state.
  public var excludedCalendarIdentifiers: Set<String>
  /// R13a. Off by default, and retained between invocations.
  public var appendsTimeZoneLabel: Bool
  /// Whether R5's one-time seed has run. Recorded rather than recomputed: a
  /// recomputed seed would re-exclude a calendar the owner deliberately
  /// re-included.
  public var hasSeededExclusions: Bool

  public init(
    excludedCalendarIdentifiers: Set<String> = [],
    appendsTimeZoneLabel: Bool = false,
    hasSeededExclusions: Bool = false
  ) {
    self.excludedCalendarIdentifiers = excludedCalendarIdentifiers
    self.appendsTimeZoneLabel = appendsTimeZoneLabel
    self.hasSeededExclusions = hasSeededExclusions
  }

  public static let `default` = Settings()

  /// R5. The one calendar excluded without being asked for.
  public static let seededCalendarName = "Supportive and Nourishing Structure"

  /// R5, R26. Matches the named calendar once and records that it happened.
  /// Name matching is confined to this call; everything after keys on the
  /// identifier.
  ///
  /// An empty list leaves the seed pending rather than spending it, for the
  /// same reason `pruned` leaves the selection alone: it means the calendars
  /// could not be read, not that the device has none. Spending it there would
  /// silently cost the owner the one exclusion they never asked for.
  public func seeding(from calendars: [CalendarDescriptor]) -> Settings {
    guard !hasSeededExclusions, !calendars.isEmpty else { return self }
    var seeded = self
    seeded.hasSeededExclusions = true
    for calendar in calendars where calendar.name == Self.seededCalendarName {
      seeded.excludedCalendarIdentifiers.insert(calendar.identifier)
    }
    return seeded
  }

  /// Drops identifiers no calendar carries any more, which a full resync can
  /// cause. That calendar reverts to blocking and the owner re-excludes it;
  /// recovering the selection by name would reintroduce the name matching the
  /// line above confines to first run.
  ///
  /// An empty list means the calendars could not be read, not that they all
  /// vanished, so it changes nothing.
  public func pruned(against calendars: [CalendarDescriptor]) -> Settings {
    guard !calendars.isEmpty else { return self }
    let known = Set(calendars.map(\.identifier))
    var pruned = self
    pruned.excludedCalendarIdentifiers.formIntersection(known)
    return pruned
  }
}
