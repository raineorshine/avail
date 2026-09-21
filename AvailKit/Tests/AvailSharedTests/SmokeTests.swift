import Testing

@testable import AvailShared

@Test func sharedModuleIsImportable() {
  #expect(AvailShared.name == "AvailShared")
}
