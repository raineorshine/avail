import Testing

@testable import AvailShared

@Suite("Calendar access state")
struct CalendarAccessStateTests {
  /// F4, R14a. Only full access reads events; every other state is reported
  /// rather than silently producing a falsely wide-open week.
  @Test func onlyFullAccessAllowsReading() {
    for state in CalendarAccessState.allCases {
      #expect(state.allowsReading == (state == .full))
    }
  }

  /// Each non-full state names its own remedy, because the platform prompts
  /// once and the obvious guess for a denied grant is the wrong one.
  @Test func everyRecoverableStateNamesItsOwnRemedy() {
    #expect(CalendarAccessState.absent.remedy != nil)
    #expect(CalendarAccessState.denied.remedy != nil)
    #expect(CalendarAccessState.writeOnly.remedy != nil)
    #expect(CalendarAccessState.full.remedy == nil)
  }

  /// An absent grant is fixed in the app, where the prompt lives; a denied one
  /// is not, because the app cannot prompt again and sending the owner back
  /// there is a dead loop.
  @Test func anAbsentGrantIsFixedInTheAppAndADeniedOneInSettings() {
    #expect(CalendarAccessState.absent.canPromptInApp)
    #expect(!CalendarAccessState.denied.canPromptInApp)
    #expect(CalendarAccessState.denied.remedy!.contains("Settings"))
    #expect(CalendarAccessState.writeOnly.remedy!.contains("Full Access"))
  }

  /// Device policy blocks calendar access and neither surface can grant it, so
  /// this state says so rather than offering a remedy that cannot work.
  @Test func aRestrictedGrantOffersNoRemedy() {
    #expect(CalendarAccessState.restricted.remedy == nil)
    #expect(!CalendarAccessState.restricted.canPromptInApp)
    #expect(!CalendarAccessState.restricted.allowsReading)
  }

  /// Every state has something to show, including the two with no remedy.
  @Test func everyStateExplainsItself() {
    for state in CalendarAccessState.allCases {
      #expect(!state.summary.isEmpty)
    }
  }
}
