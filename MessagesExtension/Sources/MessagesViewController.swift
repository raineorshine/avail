import AvailKit
import AvailShared
import Messages
import UIKit

/// The `+` menu entry: one tap computes availability and inserts it into the
/// compose field (R14, R15).
///
/// Work starts in `willBecomeActive(with:)` using the conversation handed in
/// there rather than `activeConversation`, which can be `nil` that early, and
/// the view stays compact: the presentation *context* is what `insertText`
/// requires, and `MSSupportedPresentationContexts` pins it.
final class MessagesViewController: MSMessagesAppViewController {
  /// The view has four terminal states, not two. A zero-line result is one of
  /// them: R2b permits it, and offering an empty string instead would put a
  /// blank message in the compose field.
  enum State {
    case working
    case rendered(Availability)
    case noOpenTime
    case accessRequired(CalendarAccessState)
    case inserted
    case insertionFailed
  }

  private let service = AvailabilityService()
  private var conversation: MSConversation?
  private var state: State = .working { didSet { render() } }

  private let textView = UITextView()
  private let spinner = UIActivityIndicatorView(style: .medium)
  private let timeZoneLabel = UILabel()
  private let timeZoneSwitch = UISwitch()
  private let insertButton = UIButton(configuration: .borderedProminent())

  override func viewDidLoad() {
    super.viewDidLoad()
    buildLayout()
  }

  override func willBecomeActive(with conversation: MSConversation) {
    super.willBecomeActive(with: conversation)
    self.conversation = conversation
    // R13a. The toggle keeps its last state between invocations.
    timeZoneSwitch.isOn = service.settings().appendsTimeZoneLabel
    generate()
  }

  // MARK: - Generation

  /// R16a. The indicator shows from the moment the extension is tapped until
  /// the lines replace it, so the view is never blank.
  private func generate() {
    state = .working
    Task { [service] in
      let outcome = await service.generate()
      // The read ran off the main thread; only the result comes back to it.
      await MainActor.run { self.apply(outcome) }
    }
  }

  private func apply(_ outcome: AvailabilityOutcome) {
    switch outcome {
    case .availability(let availability): state = .rendered(availability)
    case .noOpenTime: state = .noOpenTime
    case .accessRequired(let access): state = .accessRequired(access)
    }
  }

  // MARK: - Actions

  @objc private func timeZoneToggled() {
    let isOn = timeZoneSwitch.isOn
    service.update { $0.appendsTimeZoneLabel = isOn }
    generate()
  }

  /// R15. `insertText` puts the text in the compose field and stops there. The
  /// owner reviews, edits and sends.
  @objc private func insertTapped() {
    guard case .rendered(let availability) = state, let conversation else { return }
    insertButton.isEnabled = false
    conversation.insertText(availability.text) { [weak self] error in
      // The completion fires on an arbitrary background queue.
      Task { @MainActor in
        guard let self else { return }
        // Replacing the control with a confirmation also removes the
        // second-tap question: what `insertText` does to a compose field that
        // already has text in it is undocumented.
        self.state = error == nil ? .inserted : .insertionFailed
      }
    }
  }

  // MARK: - Rendering

  private func render() {
    switch state {
    case .working:
      spinner.startAnimating()
      textView.text = ""
      insertButton.isEnabled = false
    case .rendered(let availability):
      spinner.stopAnimating()
      textView.text = availability.text
      insertButton.isEnabled = true
      insertButton.setTitle("Insert", for: .normal)
    case .noOpenTime:
      spinner.stopAnimating()
      textView.text = AvailabilityMessage.noOpenTime
      insertButton.isEnabled = false
    case .accessRequired(let access):
      spinner.stopAnimating()
      textView.text = [access.summary, access.remedy].compactMap { $0 }.joined(separator: "\n\n")
      insertButton.isEnabled = false
    case .inserted:
      spinner.stopAnimating()
      insertButton.isEnabled = false
      insertButton.setTitle("Inserted", for: .normal)
    case .insertionFailed:
      spinner.stopAnimating()
      textView.text = AvailabilityMessage.insertionFailed
      insertButton.isEnabled = false
    }
    timeZoneSwitch.isEnabled = !isAccessRequired
  }

  private var isAccessRequired: Bool {
    if case .accessRequired = state { return true }
    return false
  }

  /// The compact presentation is keyboard-height, so the bottom row is pinned
  /// and only the text scrolls. A layout that lets five lines push Insert
  /// off-screen makes the two-tap objective unreachable.
  private func buildLayout() {
    view.backgroundColor = .clear

    textView.isEditable = false
    textView.font = .monospacedSystemFont(ofSize: UIFont.smallSystemFontSize, weight: .regular)
    textView.adjustsFontForContentSizeCategory = true
    textView.backgroundColor = .clear

    timeZoneLabel.text = "Time zone"
    timeZoneLabel.font = .preferredFont(forTextStyle: .footnote)
    timeZoneLabel.adjustsFontForContentSizeCategory = true

    timeZoneSwitch.addTarget(self, action: #selector(timeZoneToggled), for: .valueChanged)

    insertButton.setTitle("Insert", for: .normal)
    insertButton.addTarget(self, action: #selector(insertTapped), for: .touchUpInside)
    insertButton.setContentCompressionResistancePriority(.required, for: .horizontal)

    let row = UIStackView(arrangedSubviews: [timeZoneLabel, timeZoneSwitch, UIView(), insertButton])
    row.axis = .horizontal
    row.spacing = 8
    row.alignment = .center

    for subview in [textView, spinner, row] as [UIView] {
      subview.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(subview)
    }

    let margins = view.layoutMarginsGuide
    NSLayoutConstraint.activate([
      textView.topAnchor.constraint(equalTo: margins.topAnchor),
      textView.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
      textView.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
      textView.bottomAnchor.constraint(equalTo: row.topAnchor, constant: -8),

      spinner.centerXAnchor.constraint(equalTo: textView.centerXAnchor),
      spinner.centerYAnchor.constraint(equalTo: textView.centerYAnchor),

      row.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
      row.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
      row.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
    ])

    spinner.hidesWhenStopped = true
  }
}
