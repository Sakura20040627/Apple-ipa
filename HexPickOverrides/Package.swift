// swift-tools-version: 6.0
import PackageDescription
#if os(Linux)
let cryptoPackages: [Package.Dependency] = [.package(url: "https://github.com/apple/swift-crypto.git", exact: "3.9.0")]
let cryptoTargets: [Target.Dependency] = [.product(name: "Crypto", package: "swift-crypto")]
#else
let cryptoPackages: [Package.Dependency] = []
let cryptoTargets: [Target.Dependency] = []
#endif
let package = Package(
    name: "HexPickCore",
    platforms: [.iOS("26.0"), .macOS(.v13)],
    products: [.library(name: "HexPickCore", targets: ["HexPickCore"])],
    dependencies: cryptoPackages,
    targets: [
        .target(name: "HexPickCore", dependencies: cryptoTargets, resources: [.copy("Seed")]),
        .testTarget(name: "HexPickCoreTests", dependencies: ["HexPickCore"])
    ]
)
