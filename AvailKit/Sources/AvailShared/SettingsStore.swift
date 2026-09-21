import Foundation

/// The settings, as a JSON file in the app group container (KTD5).
///
/// Not `UserDefaults(suiteName:)`: an unentitled or misresolved suite returns
/// a live, usable object whose writes silently never reach the other process,
/// where a missing container URL is `nil` and fails immediately. The file is
/// also readable straight off the simulator's filesystem when the extension
/// and the app disagree about what the settings say.
public struct SettingsStore: Sendable {
  public let url: URL

  public init(directory: URL) {
    url = directory.appendingPathComponent("settings.json", isDirectory: false)
  }

  /// `nil` when the container does not resolve, which is what an entitlement
  /// that did not make it into the build looks like.
  public init?(appGroupIdentifier: String) {
    guard
      let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupIdentifier
      )
    else { return nil }
    self.init(directory: container)
  }

  /// The stored settings, or the defaults.
  ///
  /// A missing file is the ordinary first-run case, and unreadable contents
  /// are not worth throwing into an extension that has seconds to render
  /// something.
  public func load() -> Settings {
    guard
      let data = try? Data(contentsOf: url),
      let settings = try? JSONDecoder().decode(Settings.self, from: data)
    else { return .default }
    return settings
  }

  public func save(_ settings: Settings) throws {
    let directory = url.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(settings).write(to: url, options: .atomic)
  }

  /// Loads, applies `change`, and writes the result back.
  ///
  /// The write error propagates. A swallowed one is invisible in exactly the
  /// way that matters: the caller re-reads the settings to render them, sees
  /// the old value, and shows a control that silently snapped back.
  @discardableResult
  public func update(_ change: (inout Settings) -> Void) throws -> Settings {
    var settings = load()
    change(&settings)
    try save(settings)
    return settings
  }
}
