// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "InputSwitch",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "InputSwitch", targets: ["InputSwitch"]),
        .executable(name: "InputSwitchTests", targets: ["InputSwitchTests"])
    ],
    targets: [
        .target(name: "InputSwitchCore"),
        .executableTarget(name: "InputSwitch", dependencies: ["InputSwitchCore"]),
        .executableTarget(
            name: "InputSwitchTests",
            dependencies: ["InputSwitchCore"],
            path: "Tests/InputSwitchTests"
        )
    ]
)
