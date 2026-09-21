import AvailKit
import AvailShared
import Foundation

/// What one generation can end as.
///
/// The extension and the containing app render the same three outcomes, which
/// is why they are decided here rather than twice.
enum AvailabilityOutcome: Sendable {
  case availability(Availability)
  /// R2b permits a run with nothing to show. It is not an empty string.
  case noOpenTime
  /// R14a. Which state applies, so the surface can name its remedy.
  case accessRequired(CalendarAccessState)
}

/// Wires the reader, the shared settings and the availability module together.
///
/// The containing app's preview and the extension's insertion call this same
/// function, which is what makes the preview honest about what the next
/// invocation will produce.
struct AvailabilityService: Sendable {
  static let appGroupIdentifier = "group.com.raineorshine.avail"

  let reader: CalendarReader
  let store: SettingsStore?

  init(
    reader: CalendarReader = .shared,
    store: SettingsStore? = SettingsStore(appGroupIdentifier: AvailabilityService.appGroupIdentifier)
  ) {
    self.reader = reader
    self.store = store
  }

  var accessState: CalendarAccessState { reader.accessState }

  /// R27a. The prompt lives in the containing app; the extension inherits its
  /// result. Routed through the facade so no caller reaches past it for the
  /// reader.
  func requestAccess() async -> CalendarAccessState { await reader.requestAccess() }

  func settings() -> Settings { store?.load() ?? .default }

  /// An unresolved app-group container, which is what an entitlement that did
  /// not make it into the build looks like.
  struct SettingsUnavailable: Error {}

  func save(_ settings: Settings) throws {
    guard let store else { throw SettingsUnavailable() }
    try store.save(settings)
  }

  /// Reads, changes and writes back in one step.
  func update(_ change: (inout Settings) -> Void) throws {
    guard let store else { throw SettingsUnavailable() }
    _ = try store.update(change)
  }

  /// The same, off the main thread, reporting whether the write landed.
  ///
  /// Small as the app-group file is, reading and writing it is blocking I/O
  /// and the extension's main thread is watchdog-constrained. The caller needs
  /// the result because it re-reads the settings to render them: a write that
  /// failed silently shows up as a control that snapped back on its own.
  func updateSettings(_ change: @Sendable @escaping (inout Settings) -> Void) async -> Bool {
    await offMainThread { service in
      do {
        try service.update(change)
        return true
      } catch {
        return false
      }
    }
  }

  /// R5, R26. Seeds the named exclusion once and drops identifiers that no
  /// longer resolve, persisting the result so the extension sees the same
  /// selection.
  func reconciledSettings(with calendars: [EventCalendar]) -> Settings {
    let descriptors = calendars.map {
      CalendarDescriptor(identifier: $0.identifier, name: $0.title)
    }
    let current = settings()
    let reconciled = current.seeding(from: descriptors).pruned(against: descriptors)
    // A failed write here costs only the persistence of a reconciliation that
    // recomputes identically next time, so it does not reach the owner.
    if reconciled != current { try? save(reconciled) }
    return reconciled
  }

  /// The settings a generation resolved, beside its outcome.
  ///
  /// Both surfaces need both, and the reconciliation is a calendar fetch plus
  /// a file read; returning them together is what keeps a refresh to one pass.
  struct Generation: Sendable {
    let settings: Settings
    let outcome: AvailabilityOutcome
  }

  /// Runs the whole pipeline. Synchronous, and it reads EventKit, so it must
  /// not be called on the main thread: a blocked main thread in an extension
  /// is a watchdog kill. `generate` below is the safe entry point.
  ///
  /// - Parameter calendars: the calendar list, when the caller already has it.
  ///   The app's list screen does, and re-reading it here would fetch from the
  ///   store twice per refresh.
  func generateSynchronously(
    now: Date = Date(),
    calendar: Calendar = .current,
    calendars: [EventCalendar]? = nil
  ) -> Generation {
    let state = reader.accessState
    guard state.allowsReading else {
      return Generation(settings: settings(), outcome: .accessRequired(state))
    }

    let settings = reconciledSettings(with: calendars ?? reader.calendars())
    let engine = AvailabilityEngine(calendar: calendar)
    let availability = engine.generate(
      now: now,
      excludedCalendarIdentifiers: settings.excludedCalendarIdentifiers,
      appendsTimeZoneLabel: settings.appendsTimeZoneLabel
    ) { interval in
      reader.events(in: interval, excluding: settings.excludedCalendarIdentifiers)
    }

    return Generation(
      settings: settings,
      outcome: availability.isEmpty ? .noOpenTime : .availability(availability)
    )
  }

  /// The entry point both surfaces use: the EventKit read happens off the
  /// main thread, and only the result comes back to it.
  func generate(now: Date = Date(), calendars: [EventCalendar]? = nil) async -> Generation {
    await offMainThread { $0.generateSynchronously(now: now, calendars: calendars) }
  }

  /// R26's list, off the main thread for the same reason.
  func calendars() async -> [EventCalendar] {
    await offMainThread { $0.reader.calendars() }
  }

  /// Runs `work` off the main thread, handing it this service.
  ///
  /// Both kinds of I/O here are blocking and synchronous -- the EventKit fetch
  /// and the app-group file -- and a main thread blocked on either is what the
  /// extension's watchdog kills.
  private func offMainThread<T: Sendable>(_ work: @Sendable @escaping (Self) -> T) async -> T {
    let service = self
    return await Task.detached(priority: .userInitiated) { work(service) }.value
  }
}
