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

  func settings() -> Settings { store?.load() ?? .default }

  func save(_ settings: Settings) { try? store?.save(settings) }

  /// Reads, changes and writes back in one step.
  func update(_ change: (inout Settings) -> Void) {
    var settings = settings()
    change(&settings)
    save(settings)
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
    if reconciled != current { save(reconciled) }
    return reconciled
  }

  /// Runs the whole pipeline. Synchronous, and it reads EventKit, so it must
  /// not be called on the main thread: a blocked main thread in an extension
  /// is a watchdog kill. `generate()` below is the safe entry point.
  func generateSynchronously(now: Date = Date(), calendar: Calendar = .current) -> AvailabilityOutcome
  {
    let state = reader.accessState
    guard state.allowsReading else { return .accessRequired(state) }

    let settings = reconciledSettings(with: reader.calendars())
    let engine = AvailabilityEngine(calendar: calendar)
    let availability = engine.generate(
      now: now,
      excludedCalendarIdentifiers: settings.excludedCalendarIdentifiers,
      appendsTimeZoneLabel: settings.appendsTimeZoneLabel
    ) { interval in
      reader.events(in: interval, excluding: settings.excludedCalendarIdentifiers)
    }

    return availability.isEmpty ? .noOpenTime : .availability(availability)
  }

  /// The entry point both surfaces use: the EventKit read happens off the
  /// main thread, and only the result comes back to it.
  func generate(now: Date = Date()) async -> AvailabilityOutcome {
    let service = self
    return await Task.detached(priority: .userInitiated) {
      service.generateSynchronously(now: now)
    }.value
  }

  /// R26's list, off the main thread for the same reason.
  func calendars() async -> [EventCalendar] {
    let reader = reader
    return await Task.detached(priority: .userInitiated) { reader.calendars() }.value
  }
}
