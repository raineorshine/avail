import Foundation

/// What an event's Show As field says about the time it occupies.
///
/// `notSupported` is distinct from `free` on purpose: subscribed and birthday
/// calendars do not carry the field and report it for every event, and the
/// deterministic rule set treats it as busy (KTD10).
public enum EventAvailability: String, Sendable, Hashable, Codable, CaseIterable {
  case busy
  case free
  case tentative
  case unavailable
  case notSupported
}

/// A participant's response to an invitation.
///
/// Only `declined` frees time, so an unreadable status leaves the event
/// blocking (KTD11).
public enum ParticipantStatus: String, Sendable, Hashable, Codable, CaseIterable {
  case unknown
  case pending
  case accepted
  case declined
  case tentative
  case delegated
  case completed
  case inProcess
}

/// One participant of an event, flattened out of whatever the platform's
/// participant type happens to be.
public struct EventAttendee: Sendable, Hashable, Codable {
  public let name: String?
  public let isCurrentUser: Bool
  public let isOrganizer: Bool
  public let status: ParticipantStatus

  public init(
    name: String? = nil,
    isCurrentUser: Bool = false,
    isOrganizer: Bool = false,
    status: ParticipantStatus = .unknown
  ) {
    self.name = name
    self.isCurrentUser = isCurrentUser
    self.isOrganizer = isOrganizer
    self.status = status
  }
}

/// The calendar an event sits on, as much of it as the rules need.
public struct EventCalendar: Sendable, Hashable, Codable {
  /// The platform's stable identifier, which the calendar selection is keyed on
  /// so a rename does not change a calendar's blocking state (R26).
  public let identifier: String
  public let title: String
  /// False for the calendars that cannot report free/busy. The containing app
  /// marks these, so a surprising result is explainable rather than mysterious
  /// (KTD10).
  public let supportsAvailability: Bool

  public init(identifier: String, title: String, supportsAvailability: Bool = true) {
    self.identifier = identifier
    self.title = title
    self.supportsAvailability = supportsAvailability
  }
}

/// The full event record the rules run on (R22), carrying no platform types.
///
/// Everything downstream of the annotation stage is a pure function of these
/// values, which is what lets the module be exercised over fixtures with no
/// calendar access and no simulator.
public struct NormalizedEvent: Sendable, Hashable, Identifiable {
  /// One occurrence of a series.
  ///
  /// `eventIdentifier` is shared across every occurrence of a recurring event,
  /// so the start date is part of the key; deduplicating on the identifier
  /// alone would collapse a weekly meeting into one entry and hand back a week
  /// that looks open (KTD12).
  public struct ID: Sendable, Hashable {
    public let eventIdentifier: String
    public let start: Date

    public init(eventIdentifier: String, start: Date) {
      self.eventIdentifier = eventIdentifier
      self.start = start
    }
  }

  public let eventIdentifier: String
  public let title: String
  public let notes: String?
  public let location: String?
  public let url: URL?
  /// Derived from the event's url, location and notes, since the platform
  /// exposes no conference property of its own.
  public let conferenceURL: URL?
  /// `nil` when the account did not supply one, which is common for events the
  /// owner organized and is why KTD11 has a fallback order at all.
  public let attendees: [EventAttendee]?
  public let calendar: EventCalendar
  public let start: Date
  public let end: Date
  public let isAllDay: Bool
  /// The owner's own response, already resolved in the KTD11 order.
  public let responseStatus: ParticipantStatus
  public let availability: EventAvailability

  public var id: ID { ID(eventIdentifier: eventIdentifier, start: start) }

  public var interval: DateInterval { DateInterval(start: start, end: max(start, end)) }

  public init(
    eventIdentifier: String,
    title: String,
    notes: String? = nil,
    location: String? = nil,
    url: URL? = nil,
    conferenceURL: URL? = nil,
    attendees: [EventAttendee]? = nil,
    calendar: EventCalendar,
    start: Date,
    end: Date,
    isAllDay: Bool = false,
    responseStatus: ParticipantStatus = .unknown,
    availability: EventAvailability = .busy
  ) {
    self.eventIdentifier = eventIdentifier
    self.title = title
    self.notes = notes
    self.location = location
    self.url = url
    self.conferenceURL = conferenceURL
    self.attendees = attendees
    self.calendar = calendar
    self.start = start
    self.end = end
    self.isAllDay = isAllDay
    self.responseStatus = responseStatus
    self.availability = availability
  }
}
