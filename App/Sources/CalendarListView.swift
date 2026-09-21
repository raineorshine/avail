import AvailKit
import AvailShared
import SwiftUI

/// R26, R27, R27a. The calendar list, the access prompt that replaces it until
/// the grant is full, and the live preview.
@MainActor
@Observable
final class CalendarListModel {
  private let service = AvailabilityService()

  var accessState: CalendarAccessState = .absent
  var calendars: [EventCalendar] = []
  var settings: Settings = .default
  var outcome: AvailabilityOutcome?
  /// Settings writes are a read-modify-write over a shared file. Holding the
  /// in-flight one and awaiting it before starting the next keeps two quick
  /// toggles from landing out of order and dropping the later change.
  private var pendingWrite: Task<Void, Never>?

  /// R27a. Requested when the screen first appears; after that the state is
  /// only re-read, because the system prompts once.
  func appeared() async {
    accessState = service.accessState
    if accessState.canPromptInApp {
      accessState = await service.requestAccess()
    }
    await refresh()
  }

  func refresh() async {
    accessState = service.accessState
    guard accessState.allowsReading else {
      calendars = []
      outcome = .accessRequired(accessState)
      return
    }
    calendars = await service.calendars()
    // One pass: the generation reconciles the settings against the calendars
    // already fetched and hands both back, rather than fetching them again.
    let generation = await service.generate(calendars: calendars)
    settings = generation.settings
    outcome = generation.outcome
  }

  func isExcluded(_ calendar: EventCalendar) -> Bool {
    settings.excludedCalendarIdentifiers.contains(calendar.identifier)
  }

  /// AE14. Toggling re-renders the preview against the new selection, and the
  /// extension's next run matches it because both read the same stored value.
  func setExcluded(_ excluded: Bool, for calendar: EventCalendar) {
    if excluded {
      settings.excludedCalendarIdentifiers.insert(calendar.identifier)
    } else {
      settings.excludedCalendarIdentifiers.remove(calendar.identifier)
    }
    let excluded = settings.excludedCalendarIdentifiers
    let previous = pendingWrite
    pendingWrite = Task {
      await previous?.value
      await service.updateSettings { $0.excludedCalendarIdentifiers = excluded }
      await refresh()
    }
  }
}

struct CalendarListView: View {
  @State private var model = CalendarListModel()

  var body: some View {
    List {
      if model.accessState.allowsReading {
        calendarSection
        previewSection
      } else {
        accessSection
      }
    }
    .navigationTitle("Avail")
    .task { await model.appeared() }
    .refreshable { await model.refresh() }
  }

  /// R27a. The prompt replaces the list entirely until the grant is full,
  /// rather than showing an empty list that looks like an empty calendar.
  private var accessSection: some View {
    Section {
      VStack(alignment: .leading, spacing: 12) {
        Text(model.accessState.summary)
        if let remedy = model.accessState.remedy {
          Text(remedy).foregroundStyle(.secondary)
        }
        if model.accessState.canPromptInApp {
          Button("Allow calendar access") {
            Task { await model.appeared() }
          }
        }
      }
      .padding(.vertical, 4)
    }
  }

  private var calendarSection: some View {
    Section("Calendars") {
      ForEach(model.calendars, id: \.identifier) { calendar in
        Toggle(
          isOn: Binding(
            get: { !model.isExcluded(calendar) },
            set: { model.setExcluded(!$0, for: calendar) }
          )
        ) {
          VStack(alignment: .leading) {
            Text(calendar.title)
            // KTD10. Naming the calendars that cannot report free/busy is
            // what makes a surprising result explainable.
            if !calendar.supportsAvailability {
              Text("Cannot report free or busy")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
    }
  }

  private var previewSection: some View {
    Section("Preview") {
      PreviewView(outcome: model.outcome)
    }
  }
}
