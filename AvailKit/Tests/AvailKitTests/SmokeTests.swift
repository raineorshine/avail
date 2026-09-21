import Testing

@testable import AvailKit

@Test func moduleIsImportable() {
  #expect(AvailKit.name == "AvailKit")
}
