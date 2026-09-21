import SwiftUI

/// The containing app. It holds the extension, owns the calendar-access
/// prompt, and carries the calendar selection and the preview (R26, R27).
///
/// The access prompt lives here because the grant is recorded against this
/// bundle's identifier and the extension inherits it.
@main
struct AvailApp: App {
  var body: some Scene {
    WindowGroup {
      NavigationStack {
        CalendarListView()
      }
    }
  }
}
