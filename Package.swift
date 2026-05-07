// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "Tea",
  platforms: [.macOS(.v13)],
  products: [.executable(name: "Tea", targets: ["Tea"])],
  targets: [.executableTarget(name: "Tea")]
)
