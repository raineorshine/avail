import AvailKit
import AvailShared
import EventKit
import Foundation

/// Reads the device's calendars and normalizes their events into the module's
/// model.
///
/// One long-lived store per process: releasing a store while other EventKit
/// objects are alive is a documented hazard, and objects must not cross
/// stores. Fetches are synchronous and must not run on the main thread -- in
/// an extension a blocked main thread is a watchdog kill -- so every caller
/// reaches this from a detached task.
///
/// The lock keeps one fetch *sequence* -- read the calendars, build the
/// predicate against them, run it -- from interleaving with another when the
/// app's preview and a refresh overlap. It is not a claim that every touch of
/// the store is serialized: `requestAccess` cannot hold it across its await,
/// and single-flights instead.
final class CalendarReader: @unchecked Sendable {
  static let shared = CalendarReader()

  private let store = EKEventStore()
  private let lock = NSLock()
  private var isRequestingAccess = false

  private init() {}

  var accessState: CalendarAccessState { CalendarAccess.current }

  /// R27a. The prompt the containing app shows; the extension inherits its
  /// result, because the grant is recorded against the containing app's bundle
  /// identifier.
  func requestAccess() async -> CalendarAccessState {
    // A lock cannot be held across an await -- Swift 6 rejects even the
    // attempt -- so this collapses concurrent callers instead: two screens
    // appearing at once must not put two prompts up. The loser reads the
    // current state and picks the result up on its next refresh, which is
    // what the store's change notification is for.
    guard claimAccessRequest() else { return accessState }
    defer { releaseAccessRequest() }
    return await CalendarAccess.requestFullAccess(using: store)
  }

  /// Fires whenever the store changes. The store does not update in place
  /// after a grant, so the app refetches rather than trusting what it has.
  nonisolated var changes: NotificationCenter.Notifications {
    NotificationCenter.default.notifications(named: .EKEventStoreChanged)
  }

  /// Scoped rather than `lock()`/`unlock()`, which Swift 6 makes unavailable
  /// in an async context.
  private func claimAccessRequest() -> Bool {
    lock.withLock {
      guard !isRequestingAccess else { return false }
      isRequestingAccess = true
      return true
    }
  }

  private func releaseAccessRequest() {
    lock.withLock { isRequestingAccess = false }
  }

  /// R26. Every calendar on the device, with whatever the owner needs to
  /// decide about it.
  func calendars() -> [EventCalendar] {
    guard accessState.allowsReading else { return [] }
    lock.lock()
    defer { lock.unlock() }
    return store.calendars(for: .event).map(Self.normalize(_:))
  }

  /// The event provider the engine calls, at most twice per generation.
  ///
  /// The exclusion is passed to the predicate rather than filtered afterwards,
  /// so an excluded calendar is never read at all. The engine filters again on
  /// what comes back, which is what keeps R5 provable without a calendar
  /// store.
  func events(in interval: DateInterval, excluding excluded: Set<String>) -> [NormalizedEvent] {
    // KTD9. An app holding write-only access gets a virtual calendar, a
    // virtual source and empty results with nothing thrown, and its first
    // `events(matching:)` spends a one-shot implicit upgrade prompt that never
    // reappears if declined. Gating the fetch keeps that prompt available to
    // the containing app's explicit remedy path.
    guard accessState.allowsReading else { return [] }

    lock.lock()
    defer { lock.unlock() }

    let calendars = store.calendars(for: .event).filter {
      !excluded.contains($0.calendarIdentifier)
    }
    guard !calendars.isEmpty else { return [] }

    let predicate = store.predicateForEvents(
      withStart: interval.start, end: interval.end, calendars: calendars
    )

    return
      store
      .events(matching: predicate)
      .filter { $0.status != .canceled }
      .compactMap(Self.normalize(_:))
      .deduplicatedByOccurrence()
  }

  private static func normalize(_ calendar: EKCalendar) -> EventCalendar {
    EventCalendar(
      identifier: calendar.calendarIdentifier,
      title: calendar.title,
      // KTD10. Subscribed and birthday calendars cannot report free/busy. The
      // app marks them so a surprising result is explainable.
      supportsAvailability: !calendar.supportedEventAvailabilities.isEmpty
    )
  }

  private static func normalize(_ event: EKEvent) -> NormalizedEvent? {
    guard let start = event.startDate, let end = event.endDate else { return nil }
    let attendees = event.attendees?.map(EventAttendee.init)
    return NormalizedEvent(
      eventIdentifier: event.eventIdentifier ?? event.calendarItemIdentifier,
      title: event.title ?? "",
      notes: event.notes,
      location: event.location,
      url: event.url,
      conferenceURL: NormalizedEvent.conferenceURL(
        url: event.url, location: event.location, notes: event.notes
      ),
      attendees: attendees,
      calendar: normalize(event.calendar),
      start: start,
      end: end,
      isAllDay: event.isAllDay,
      responseStatus: ParticipantStatus.resolve(
        attendees: attendees,
        isOrganizedByCurrentUser: event.organizer?.isCurrentUser ?? false
      ),
      availability: EventAvailability(event.availability)
    )
  }
}
