// swift-tools-version: 6.2
import PackageDescription

// Two Foundation-only library targets, so both run under the same headless gate.
//
// `AvailKit` is the R24 module: the availability rules, block finding and
// formatting, importing Foundation and nothing else. `AvailShared` holds the
// settings value and the app-group store the containing app and the extension
// share; it deliberately does not depend on `AvailKit`, because the module
// purity check greps every import under `Sources/` and an `import AvailKit`
// there would fail it.
let package = Package(
  name: "AvailKit",
  platforms: [.iOS(.v18), .macOS(.v14)],
  products: [
    .library(name: "AvailKit", targets: ["AvailKit"]),
    .library(name: "AvailShared", targets: ["AvailShared"]),
  ],
  targets: [
    .target(name: "AvailKit"),
    .target(name: "AvailShared"),
    .testTarget(
      name: "AvailKitTests",
      dependencies: ["AvailKit"],
      resources: [.copy("events.json")]
    ),
    .testTarget(
      name: "AvailSharedTests",
      dependencies: ["AvailShared"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
