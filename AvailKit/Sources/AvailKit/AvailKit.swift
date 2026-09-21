/// Namespace marker for the pure availability module.
///
/// `AvailKit` imports Foundation and nothing else. The EventKit read, the
/// compose-field insertion, and the app-group settings file all live outside
/// it, so the rules, block finding, and formatting are exercised by unit tests
/// with no device, no calendar access, and no simulator.
public enum AvailKit {
  /// The module's version marker, present so the smoke test has something real
  /// to assert before the rest of the module exists.
  public static let name = "AvailKit"
}
