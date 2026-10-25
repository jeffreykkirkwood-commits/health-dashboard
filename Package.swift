// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "HealthCore", products: [.library(name: "HealthCore", targets: ["HealthCore"])], targets: [
    .target(name: "HealthCore", path: "HealthDashboard", exclude: ["App.swift", "BiomarkerDemoView.swift", "HealthStore.swift", "Notifications.swift", "HealthDashboard.entitlements"], sources: ["HealthCore.swift", "Biomarkers.swift"], resources: [.copy("Fixtures/biomarkers.synthetic.v1.json")]),
    .testTarget(name: "HealthCoreTests", dependencies: ["HealthCore"])
])
