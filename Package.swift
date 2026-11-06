// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Mork",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Mork", targets: ["Mork"]),
        .library(name: "MorkDomain", targets: ["MorkDomain"]),
        .library(name: "MorkData", targets: ["MorkData"]),
        .library(name: "MorkPresentation", targets: ["MorkPresentation"]),
        .library(name: "MorkTerminal", targets: ["MorkTerminal"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", exact: "1.20.0")
    ],
    targets: [
        .target(name: "MorkDomain"),
        .target(name: "MorkData", dependencies: ["MorkDomain"]),
        .target(name: "MorkPresentation", dependencies: ["MorkDomain"]),
        .target(name: "MorkTerminal", dependencies: [.product(name: "SwiftTerm", package: "SwiftTerm")]),
        .executableTarget(name: "Mork", dependencies: ["MorkDomain", "MorkData", "MorkPresentation", "MorkTerminal"])
    ]
)
