import AvailKit
import AvailShared
import SwiftUI
import UIKit

/// R27. The exact text the extension would produce at this moment, copied to
/// the pasteboard in one tap.
///
/// It carries the extension's own no-open-time state for a zero-line result,
/// with copying disabled, rather than offering an empty string as
/// availability.
struct PreviewView: View {
  let outcome: AvailabilityOutcome?

  var body: some View {
    switch outcome {
    case .availability(let availability):
      Text(availability.text)
        .font(.body.monospaced())
        .textSelection(.enabled)
      Button("Copy") { UIPasteboard.general.string = availability.text }
    case .noOpenTime:
      Text(AvailabilityMessage.noOpenTime).foregroundStyle(.secondary)
      Button("Copy") {}.disabled(true)
    case .accessRequired(let state):
      Text(state.summary).foregroundStyle(.secondary)
      if let remedy = state.remedy {
        Text(remedy).font(.caption).foregroundStyle(.secondary)
      }
    case nil:
      ProgressView()
    }
  }
}
