import AvailKit
import AvailShared
import EventKit
import Foundation

/// Maps EventKit's authorization status onto the states R14a distinguishes,
/// and owns the one request that can still change it.
enum CalendarAccess {
  static var current: CalendarAccessState {
    state(of: EKEventStore.authorizationStatus(for: .event))
  }

  static func state(of status: EKAuthorizationStatus) -> CalendarAccessState {
    switch status {
    case .notDetermined: .absent
    case .restricted: .restricted
    case .denied: .denied
    case .writeOnly: .writeOnly
    case .fullAccess: .full
    // An unrecognized status is not an invitation to read the calendar.
    @unknown default: .denied
    }
  }

  /// KTD8. `requestFullAccessToEvents()`, not the deprecated
  /// `requestAccess(to:completion:)`, which no longer prompts at all when
  /// linked against the current SDK. There is no read-only level to ask for,
  /// so an app that only reads still has to ask for full access, and the
  /// Info.plist must carry `NSCalendarsFullAccessUsageDescription` rather than
  /// the legacy key -- a bundle carrying only the legacy key is denied
  /// automatically.
  ///
  /// The system prompts once. After a refusal this returns `.denied` and the
  /// remedy moves to Settings.
  static func requestFullAccess(using store: EKEventStore) async -> CalendarAccessState {
    _ = try? await store.requestFullAccessToEvents()
    return current
  }
}

extension EventAttendee {
  /// The one place EventKit's participant meets the module's.
  ///
  /// `EKParticipant` cannot be constructed and `EKEvent.attendees` is
  /// read-only, so the response rule is written against the Foundation-only
  /// `Participant` protocol that `EventAttendee` conforms to; without that
  /// seam the rule deciding whether an event blocks time would have no
  /// reachable test.
  init(_ participant: EKParticipant) {
    self.init(
      name: participant.name,
      isCurrentUser: participant.isCurrentUser,
      status: ParticipantStatus(participant.participantStatus)
    )
  }
}

extension ParticipantStatus {
  init(_ status: EKParticipantStatus) {
    switch status {
    case .unknown: self = .unknown
    case .pending: self = .pending
    case .accepted: self = .accepted
    case .declined: self = .declined
    case .tentative: self = .tentative
    case .delegated: self = .delegated
    case .completed: self = .completed
    case .inProcess: self = .inProcess
    // Unreadable is not free: only `.declined` frees time.
    @unknown default: self = .unknown
    }
  }
}

extension EventAvailability {
  init(_ availability: EKEventAvailability) {
    switch availability {
    case .notSupported: self = .notSupported
    case .busy: self = .busy
    case .free: self = .free
    case .tentative: self = .tentative
    case .unavailable: self = .unavailable
    @unknown default: self = .busy
    }
  }
}
