// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "S2Geometry",
    products: [
        .library(name: "S2Geometry", targets: ["S2Geometry"])
    ],
    dependencies: [],
    targets: [
        .target(name: "S2Geometry", dependencies: [])
    ]
)
