import Foundation

/// The strings both surfaces show, so the preview keeps its promise that it
/// says what the extension will say.
public enum AvailabilityMessage {
  /// R2b permits a run with nothing to show. Neither surface offers an empty
  /// string as availability.
  public static let noOpenTime = "No open time in the next few weeks."

  public static let insertionFailed =
    "Could not insert the text. Copy it from the Avail app instead."

  /// The app group did not resolve, so the two processes cannot share a
  /// setting. Said plainly rather than shown as a control that will not stay
  /// where it is put.
  public static let settingsUnavailable =
    "Avail cannot reach its shared settings, so the time zone switch will not stick. Reinstalling the app usually fixes it."
}
