import Foundation
import Testing

@testable import AvailKit

@Suite("Response status resolution")
struct ParticipantTests {
  struct Fake: Participant {
    var name: String?
    var isCurrentUser: Bool
    var status: ParticipantStatus

    init(_ name: String, isCurrentUser: Bool = false, status: ParticipantStatus = .unknown) {
      self.name = name
      self.isCurrentUser = isCurrentUser
      self.status = status
    }
  }

  /// KTD11, first rule. The platform surfaces participation only through the
  /// attendee list, so the attendee marked as the current user wins when there
  /// is one.
  @Test func theAttendeeMarkedAsTheCurrentUserWins() {
    let attendees: [any Participant] = [
      Fake("Someone", status: .accepted),
      Fake("Me", isCurrentUser: true, status: .declined),
      Fake("Someone else", status: .tentative),
    ]
    #expect(
      ParticipantStatus.resolve(attendees: attendees, isOrganizedByCurrentUser: false) == .declined
    )
  }

  /// KTD11, second rule. Attendee lists are commonly absent on events the
  /// owner created, and nothing documents whether an organizer appears among
  /// their own attendees.
  @Test func anOrganizerWithNoAttendeeMatchIsAccepted() {
    #expect(ParticipantStatus.resolve(attendees: nil, isOrganizedByCurrentUser: true) == .accepted)
    #expect(
      ParticipantStatus.resolve(
        attendees: [Fake("Someone", status: .accepted)], isOrganizedByCurrentUser: true
      ) == .accepted
    )
  }

  /// KTD11, last rule. Unreadable is not free: only `.declined` frees time, so
  /// an unknown status leaves the event blocking.
  @Test func anUnreadableStatusIsUnknown() {
    #expect(ParticipantStatus.resolve(attendees: nil, isOrganizedByCurrentUser: false) == .unknown)
    #expect(ParticipantStatus.resolve(attendees: [], isOrganizedByCurrentUser: false) == .unknown)
  }

  /// The whole point of the order: an event whose status cannot be read still
  /// takes time away.
  @Test func anUnknownStatusStillBlocks() throws {
    let status = ParticipantStatus.resolve(attendees: nil, isOrganizedByCurrentUser: false)
    let event = Fixture.event(from: "2017-07-11 10:00", to: "2017-07-11 11:00", responseStatus: status)
    #expect(try DeterministicAnnotator().annotate([event])[0].blocksAvailability == true)
  }
}

@Suite("Conference URL")
struct ConferenceURLTests {
  /// R22. The platform exposes no conference property, so the URL is derived
  /// from the fields that do carry one.
  @Test func theEventsOwnUrlWins() {
    let url = NormalizedEvent.conferenceURL(
      url: URL(string: "https://example.com/a")!,
      location: "https://example.com/b",
      notes: "https://example.com/c"
    )
    #expect(url?.absoluteString == "https://example.com/a")
  }

  @Test func theLocationIsReadWhenThereIsNoUrl() {
    let url = NormalizedEvent.conferenceURL(
      url: nil, location: "Join at https://example.com/b", notes: "https://example.com/c"
    )
    #expect(url?.absoluteString == "https://example.com/b")
  }

  @Test func theNotesAreTheLastResort() {
    let url = NormalizedEvent.conferenceURL(
      url: nil, location: "Conference room 3", notes: "Dial in: https://example.com/c"
    )
    #expect(url?.absoluteString == "https://example.com/c")
  }

  @Test func nothingIsDerivedWhenNoFieldCarriesALink() {
    #expect(NormalizedEvent.conferenceURL(url: nil, location: "Room 3", notes: "Bring coffee") == nil)
    #expect(NormalizedEvent.conferenceURL(url: nil, location: nil, notes: nil) == nil)
  }
}
