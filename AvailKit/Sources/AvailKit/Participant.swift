import Foundation

/// One participant of an event, as much of one as R7's rule needs.
///
/// The protocol exists so the resolution order below is reachable by a test:
/// the platform's own participant type cannot be constructed and an event's
/// attendee list is read-only, which would otherwise leave the rule that
/// decides whether an event blocks time with nothing to exercise it. The
/// EventKit adapter lives outside this module.
public protocol Participant: Sendable {
  var name: String? { get }
  var isCurrentUser: Bool { get }
  var status: ParticipantStatus { get }
}

extension ParticipantStatus {
  /// KTD11. The owner's own response, in a fixed order: the attendee marked as
  /// the current user, else `.accepted` when the owner is the organizer, else
  /// `.unknown`.
  ///
  /// Attendee lists can be absent on any calendar and are commonly absent on
  /// events the owner created, and nothing documents whether an organizer
  /// appears among their own attendees. Only `.declined` frees time, so an
  /// unreadable status leaves the event blocking.
  public static func resolve(
    attendees: [any Participant]?, isOrganizedByCurrentUser: Bool
  ) -> ParticipantStatus {
    if let mine = attendees?.first(where: \.isCurrentUser) { return mine.status }
    if isOrganizedByCurrentUser { return .accepted }
    return .unknown
  }
}

extension NormalizedEvent {
  /// R22. The conferencing URL, derived from the event's url, location and
  /// notes in that order, since the platform exposes no conference property of
  /// its own.
  public static func conferenceURL(url: URL?, location: String?, notes: String?) -> URL? {
    if let url { return url }
    return [location, notes].compactMap { $0 }.lazy.compactMap(firstLink(in:)).first
  }

  /// Built once. `NSDataDetector` wraps a compiled regular expression, is
  /// documented as expensive to construct and safe to reuse, and this runs
  /// for the location and then the notes of every event in a horizon that
  /// reaches forty days.
  private static let linkDetector = try? NSDataDetector(
    types: NSTextCheckingResult.CheckingType.link.rawValue
  )

  private static func firstLink(in text: String) -> URL? {
    guard let detector = linkDetector else { return nil }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return detector.firstMatch(in: text, range: range)?.url
  }
}
