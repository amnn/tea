// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "Coffee",
  platforms: [.macOS(.v13)],
  products: [.executable(name: "Coffee", targets: ["Coffee"])],
  targets: [.executableTarget(name: "Coffee")]
)
