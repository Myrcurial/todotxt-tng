// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "todotxt-tng",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "TodoTxtCore", targets: ["TodoTxtCore"]),
        .executable(name: "TodoTxtApp", targets: ["TodoTxtApp"]),
    ],
    targets: [
        .target(name: "TodoTxtCore"),
        .executableTarget(name: "TodoTxtApp", dependencies: ["TodoTxtCore"]),
        .executableTarget(name: "TodoTxtCoreChecks", dependencies: ["TodoTxtCore"]),
    ]
)
