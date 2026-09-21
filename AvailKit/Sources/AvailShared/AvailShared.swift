/// Namespace marker for the shared settings module.
///
/// `AvailShared` carries the calendar selection and the timezone toggle between
/// the containing app and the iMessage extension. Like `AvailKit` it imports
/// Foundation and nothing else, so it runs under the same headless gate; unlike
/// `AvailKit` it is not the availability module, and it deliberately does not
/// depend on it.
public enum AvailShared {
  /// The module's name, present so the smoke test has something real to assert.
  public static let name = "AvailShared"
}
