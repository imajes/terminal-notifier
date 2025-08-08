// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "terminal-notifier",
  platforms: [.macOS(.v13)],
  products: [
    .executable(name: "tn", targets: ["tn"]),
    .library(name: "TNCore", targets: ["TNCore"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
    .package(url: "https://github.com/apple/swift-log", from: "1.5.0")
  ],
  targets: [
    .executableTarget(
      name: "tn",
      dependencies: [
        "TNCore",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Logging", package: "swift-log")
      ]
    ),
    .target(
      name: "TNCore",
      dependencies: [
        .product(name: "Logging", package: "swift-log")
      ]
    ),
    .testTarget(
      name: "TNCoreTests",
      dependencies: ["TNCore"]
    )
  ]
)
