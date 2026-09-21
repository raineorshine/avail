import Foundation

/// The calendar-access states R14a distinguishes, each carrying its own
/// remedy.
///
/// This is a plain value rather than a platform enum so the containing app and
/// the extension say the same thing, and so the remedies are exercised without
/// a device. The platform's own authorization status maps onto it in the
/// EventKit code outside this package.
///
/// The remedies differ because the system prompts once and the obvious guess
/// for a denied grant is the wrong one.
public enum CalendarAccessState: String, Sendable, Hashable, Codable, CaseIterable {
  /// Not yet asked. The prompt lives in the containing app.
  case absent
  /// Asked and refused. The app cannot ask again.
  case denied
  /// Blocked by device policy; neither surface can grant it.
  case restricted
  /// Granted, but for writing only. There is no read-only level to ask for.
  case writeOnly
  /// Granted.
  case full

  /// KTD9. Every fetch is gated on this, because an app holding write-only
  /// access gets a virtual calendar and empty results with nothing thrown.
  public var allowsReading: Bool { self == .full }

  /// True only for the state the containing app's prompt can still change.
  public var canPromptInApp: Bool { self == .absent }

  /// What went wrong, in the owner's terms.
  public var summary: String {
    switch self {
    case .absent: "Avail has not been given access to your calendar yet."
    case .denied: "Avail has been denied access to your calendar."
    case .restricted: "Calendar access is blocked on this device."
    case .writeOnly: "Avail can add to your calendar but cannot read it."
    case .full: "Avail can read your calendar."
    }
  }

  /// How to fix it, or `nil` when there is nothing the owner can do.
  public var remedy: String? {
    switch self {
    case .absent:
      "Open the Avail app and allow calendar access."
    case .denied:
      // Not the app: it cannot prompt a second time, so sending the owner
      // there would be a dead loop.
      "Turn it on in Settings > Privacy & Security > Calendars > Avail."
    case .writeOnly:
      "Switch Avail to Full Access in Settings > Privacy & Security > Calendars."
    case .restricted:
      // Device policy. Saying so beats offering a remedy that cannot work.
      nil
    case .full:
      nil
    }
  }
}
