// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TopChrome",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "TopChrome", targets: ["TopChrome"])],
    targets: [
        .target(name: "TopChromeCore"),
        .executableTarget(name: "TopChrome", dependencies: ["TopChromeCore"],
                          linkerSettings: [.linkedFramework("Carbon")]),
        .executableTarget(name: "TopChromeChecks", dependencies: ["TopChromeCore"], path: "Tests/TopChromeChecks")
    ],
    swiftLanguageModes: [.v5]
)
