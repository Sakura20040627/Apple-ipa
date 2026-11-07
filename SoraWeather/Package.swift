// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "SoraWeatherCore", platforms: [.macOS(.v13), .iOS(.v17)], products: [.library(name: "SoraWeatherCore", targets: ["SoraWeatherCore"])], targets: [.target(name: "SoraWeatherCore", path: "Core"), .testTarget(name: "SoraWeatherCoreTests", dependencies: ["SoraWeatherCore"], path: "Tests", resources: [.copy("Fixtures")])], swiftLanguageModes: [.v5])
