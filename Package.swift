// swift-tools-version: 5.9
// PURPOSE: Define the small Swift test package separately from the iPhone app.

import PackageDescription
// FEATURE 01 — Test calculation and lab rules without iPhone services
// Include HealthCore and Biomarkers plus their fictional JSON resources.
// Exclude UI, HealthKit readers and notifications because these tests exercise
// pure data rules on the Mac. A passing package test is not proof of device
// permissions, rendering or notification delivery.
let package = Package(name: "HealthCore", products: [.library(name: "HealthCore", targets: ["HealthCore"])], targets: [
    .target(name: "HealthCore", path: "HealthDashboard", exclude: ["HealthCatalog.swift", "HealthLibrary.swift", "App.swift", "BiomarkerDemoView.swift", "HealthStore.swift", "Notifications.swift", "HealthDashboard.entitlements"], sources: ["HealthCore.swift", "Biomarkers.swift"], resources: [.copy("Fixtures/biomarkers.synthetic.v1.json"), .copy("Fixtures/health.synthetic.v1.json")]),
    .testTarget(name: "HealthCoreTests", dependencies: ["HealthCore"])
])
