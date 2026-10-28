// PURPOSE: List supported Apple Health record types and friendly names. This is a catalog of definitions, not collected personal data.

import Foundation
import HealthKit

// FEATURE 01 — Describe a type the user can browse
// A definition contains Apple's identifier, display name, group, kind and
// minimum supported iOS version. Quantity means a measured number; category
// means a recorded label/code; workouts are activity sessions.
struct HealthMetricDefinition: Identifiable {
    let id: String
    let title: String
    let group: String
    let kind: String
    let minimumMajor: Int
    let minimumMinor: Int
    let categoryLabels: [Int: String]
    // FEATURE 02 — Hide types this iPhone cannot request
    // Check the OS version first and ask Apple for the corresponding sample type.
    // Unknown kinds return nil. The library filters these out instead of offering
    // a Connect action for a type this device cannot represent.
    var sampleType: HKSampleType? {
        guard ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: minimumMajor, minorVersion: minimumMinor, patchVersion: 0)) else { return nil }
        switch kind {
        case "quantity": return HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: id))
        case "category": return HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier(rawValue: id))
        case "workout": return HKObjectType.workoutType()
        default: return nil
        }
    }
}
enum HealthCatalog {
    // Public iOS 27.1 SDK quantity/category identifiers; older devices filter by availability.
    // FEATURE 03 — Build the readable library catalog
    // Each row maps an SDK identifier to a title/group and required OS version.
    // The list includes quantities, then category events, then workouts. Category
    // label dictionaries translate stored numbers into text; unknown sample codes
    // are preserved by HealthLibrary. These rows do not grant read permission.
    static let definitions: [HealthMetricDefinition] = {
        var result: [HealthMetricDefinition] = []
        result.append(.init(id: HKQuantityTypeIdentifier.appleSleepingWristTemperature.rawValue, title: "Sleeping wrist temperature", group: "Body Measurements", kind: "quantity", minimumMajor: 16, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.bodyFatPercentage.rawValue, title: "Body Fat Percentage", group: "Body Measurements", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.bodyMass.rawValue, title: "Body Mass", group: "Body Measurements", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.bodyMassIndex.rawValue, title: "Body Mass Index", group: "Body Measurements", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.electrodermalActivity.rawValue, title: "Electrodermal Activity", group: "Body Measurements", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.height.rawValue, title: "Height", group: "Body Measurements", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.leanBodyMass.rawValue, title: "Lean Body Mass", group: "Body Measurements", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.waistCircumference.rawValue, title: "Waist Circumference", group: "Body Measurements", kind: "quantity", minimumMajor: 11, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.activeEnergyBurned.rawValue, title: "Active Energy Burned", group: "Fitness", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.appleExerciseTime.rawValue, title: "Exercise Time", group: "Fitness", kind: "quantity", minimumMajor: 9, minimumMinor: 3, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.appleMoveTime.rawValue, title: "Move Time", group: "Fitness", kind: "quantity", minimumMajor: 14, minimumMinor: 5, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.appleStandTime.rawValue, title: "Stand Time", group: "Fitness", kind: "quantity", minimumMajor: 13, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.basalEnergyBurned.rawValue, title: "Basal Energy Burned", group: "Fitness", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        if #available(iOS 18.0, *) { result.append(.init(id: HKQuantityTypeIdentifier.crossCountrySkiingSpeed.rawValue, title: "Cross Country Skiing Speed", group: "Fitness", kind: "quantity", minimumMajor: 18, minimumMinor: 0, categoryLabels: [:])) }
        result.append(.init(id: HKQuantityTypeIdentifier.cyclingCadence.rawValue, title: "Cycling Cadence", group: "Fitness", kind: "quantity", minimumMajor: 17, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.cyclingFunctionalThresholdPower.rawValue, title: "Cycling Functional Threshold Power", group: "Fitness", kind: "quantity", minimumMajor: 17, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.cyclingPower.rawValue, title: "Cycling Power", group: "Fitness", kind: "quantity", minimumMajor: 17, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.cyclingSpeed.rawValue, title: "Cycling Speed", group: "Fitness", kind: "quantity", minimumMajor: 17, minimumMinor: 0, categoryLabels: [:]))
        if #available(iOS 18.0, *) { result.append(.init(id: HKQuantityTypeIdentifier.distanceCrossCountrySkiing.rawValue, title: "Distance Cross Country Skiing", group: "Fitness", kind: "quantity", minimumMajor: 18, minimumMinor: 0, categoryLabels: [:])) }
        result.append(.init(id: HKQuantityTypeIdentifier.distanceCycling.rawValue, title: "Distance Cycling", group: "Fitness", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.distanceDownhillSnowSports.rawValue, title: "Distance Downhill Snow Sports", group: "Fitness", kind: "quantity", minimumMajor: 11, minimumMinor: 2, categoryLabels: [:]))
        if #available(iOS 18.0, *) { result.append(.init(id: HKQuantityTypeIdentifier.distancePaddleSports.rawValue, title: "Distance Paddle Sports", group: "Fitness", kind: "quantity", minimumMajor: 18, minimumMinor: 0, categoryLabels: [:])) }
        if #available(iOS 18.0, *) { result.append(.init(id: HKQuantityTypeIdentifier.distanceRowing.rawValue, title: "Distance Rowing", group: "Fitness", kind: "quantity", minimumMajor: 18, minimumMinor: 0, categoryLabels: [:])) }
        if #available(iOS 18.0, *) { result.append(.init(id: HKQuantityTypeIdentifier.distanceSkatingSports.rawValue, title: "Distance Skating Sports", group: "Fitness", kind: "quantity", minimumMajor: 18, minimumMinor: 0, categoryLabels: [:])) }
        result.append(.init(id: HKQuantityTypeIdentifier.distanceSwimming.rawValue, title: "Distance Swimming", group: "Fitness", kind: "quantity", minimumMajor: 10, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue, title: "Distance Walking Running", group: "Fitness", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.distanceWheelchair.rawValue, title: "Distance Wheelchair", group: "Fitness", kind: "quantity", minimumMajor: 10, minimumMinor: 0, categoryLabels: [:]))
        if #available(iOS 18.0, *) { result.append(.init(id: HKQuantityTypeIdentifier.estimatedWorkoutEffortScore.rawValue, title: "Estimated Workout Effort Score", group: "Fitness", kind: "quantity", minimumMajor: 18, minimumMinor: 0, categoryLabels: [:])) }
        result.append(.init(id: HKQuantityTypeIdentifier.flightsClimbed.rawValue, title: "Flights Climbed", group: "Fitness", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.nikeFuel.rawValue, title: "Nike Fuel", group: "Fitness", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        if #available(iOS 18.0, *) { result.append(.init(id: HKQuantityTypeIdentifier.paddleSportsSpeed.rawValue, title: "Paddle Sports Speed", group: "Fitness", kind: "quantity", minimumMajor: 18, minimumMinor: 0, categoryLabels: [:])) }
        result.append(.init(id: HKQuantityTypeIdentifier.physicalEffort.rawValue, title: "Physical Effort", group: "Fitness", kind: "quantity", minimumMajor: 17, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.pushCount.rawValue, title: "Push Count", group: "Fitness", kind: "quantity", minimumMajor: 10, minimumMinor: 0, categoryLabels: [:]))
        if #available(iOS 18.0, *) { result.append(.init(id: HKQuantityTypeIdentifier.rowingSpeed.rawValue, title: "Rowing Speed", group: "Fitness", kind: "quantity", minimumMajor: 18, minimumMinor: 0, categoryLabels: [:])) }
        result.append(.init(id: HKQuantityTypeIdentifier.runningPower.rawValue, title: "Running Power", group: "Fitness", kind: "quantity", minimumMajor: 16, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.runningSpeed.rawValue, title: "Running Speed", group: "Fitness", kind: "quantity", minimumMajor: 16, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.stepCount.rawValue, title: "Steps", group: "Fitness", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.swimmingStrokeCount.rawValue, title: "Swimming Stroke Count", group: "Fitness", kind: "quantity", minimumMajor: 10, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.underwaterDepth.rawValue, title: "Underwater Depth", group: "Fitness", kind: "quantity", minimumMajor: 16, minimumMinor: 0, categoryLabels: [:]))
        if #available(iOS 18.0, *) { result.append(.init(id: HKQuantityTypeIdentifier.workoutEffortScore.rawValue, title: "Workout Effort Score", group: "Fitness", kind: "quantity", minimumMajor: 18, minimumMinor: 0, categoryLabels: [:])) }
        result.append(.init(id: HKQuantityTypeIdentifier.environmentalAudioExposure.rawValue, title: "Environmental Audio Exposure", group: "Hearing Health", kind: "quantity", minimumMajor: 13, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.environmentalSoundReduction.rawValue, title: "Environmental Sound Reduction", group: "Hearing Health", kind: "quantity", minimumMajor: 16, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.headphoneAudioExposure.rawValue, title: "Headphone Audio Exposure", group: "Hearing Health", kind: "quantity", minimumMajor: 13, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.atrialFibrillationBurden.rawValue, title: "Atrial Fibrillation Burden", group: "Heart", kind: "quantity", minimumMajor: 16, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.heartRate.rawValue, title: "Heart Rate", group: "Heart", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.heartRateRecoveryOneMinute.rawValue, title: "Heart Rate Recovery One Minute", group: "Heart", kind: "quantity", minimumMajor: 16, minimumMinor: 0, categoryLabels: [:]))
        #if compiler(>=6.4)  // the name only exists in the iOS 27 SDK (Xcode 27, Swift 6.4); Xcode 26 cannot compile it (#33)
        if #available(iOS 27.0, *) { result.append(.init(id: HKQuantityTypeIdentifier.heartRateVariabilityRMSSD.rawValue, title: "Heart Rate Variability RMSSD", group: "Heart", kind: "quantity", minimumMajor: 27, minimumMinor: 0, categoryLabels: [:])) }
        #endif
        result.append(.init(id: HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue, title: "Heart rate variability (SDNN)", group: "Heart", kind: "quantity", minimumMajor: 11, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.peripheralPerfusionIndex.rawValue, title: "Peripheral Perfusion Index", group: "Heart", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.restingHeartRate.rawValue, title: "Resting Heart Rate", group: "Heart", kind: "quantity", minimumMajor: 11, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.vo2Max.rawValue, title: "Cardio fitness (VO₂ max)", group: "Heart", kind: "quantity", minimumMajor: 11, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.walkingHeartRateAverage.rawValue, title: "Walking Heart Rate Average", group: "Heart", kind: "quantity", minimumMajor: 11, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.appleWalkingSteadiness.rawValue, title: "Walking Steadiness", group: "Mobility", kind: "quantity", minimumMajor: 15, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.runningGroundContactTime.rawValue, title: "Running Ground Contact Time", group: "Mobility", kind: "quantity", minimumMajor: 16, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.runningStrideLength.rawValue, title: "Running Stride Length", group: "Mobility", kind: "quantity", minimumMajor: 16, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.runningVerticalOscillation.rawValue, title: "Running Vertical Oscillation", group: "Mobility", kind: "quantity", minimumMajor: 16, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.sixMinuteWalkTestDistance.rawValue, title: "Six Minute Walk Test Distance", group: "Mobility", kind: "quantity", minimumMajor: 14, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.stairAscentSpeed.rawValue, title: "Stair Ascent Speed", group: "Mobility", kind: "quantity", minimumMajor: 14, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.stairDescentSpeed.rawValue, title: "Stair Descent Speed", group: "Mobility", kind: "quantity", minimumMajor: 14, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.walkingAsymmetryPercentage.rawValue, title: "Walking Asymmetry Percentage", group: "Mobility", kind: "quantity", minimumMajor: 14, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.walkingDoubleSupportPercentage.rawValue, title: "Walking Double Support Percentage", group: "Mobility", kind: "quantity", minimumMajor: 14, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.walkingSpeed.rawValue, title: "Walking Speed", group: "Mobility", kind: "quantity", minimumMajor: 14, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.walkingStepLength.rawValue, title: "Walking Step Length", group: "Mobility", kind: "quantity", minimumMajor: 14, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryBiotin.rawValue, title: "Biotin", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryCaffeine.rawValue, title: "Caffeine", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryCalcium.rawValue, title: "Calcium", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryCarbohydrates.rawValue, title: "Carbohydrates", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryChloride.rawValue, title: "Chloride", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryCholesterol.rawValue, title: "Cholesterol", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryChromium.rawValue, title: "Chromium", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryCopper.rawValue, title: "Copper", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryEnergyConsumed.rawValue, title: "Energy Consumed", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryFatMonounsaturated.rawValue, title: "Fat Monounsaturated", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryFatPolyunsaturated.rawValue, title: "Fat Polyunsaturated", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryFatSaturated.rawValue, title: "Fat Saturated", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryFatTotal.rawValue, title: "Fat Total", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryFiber.rawValue, title: "Fiber", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryFolate.rawValue, title: "Folate", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryIodine.rawValue, title: "Iodine", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryIron.rawValue, title: "Iron", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryMagnesium.rawValue, title: "Magnesium", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryManganese.rawValue, title: "Manganese", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryMolybdenum.rawValue, title: "Molybdenum", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryNiacin.rawValue, title: "Niacin", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryPantothenicAcid.rawValue, title: "Pantothenic Acid", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryPhosphorus.rawValue, title: "Phosphorus", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryPotassium.rawValue, title: "Potassium", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryProtein.rawValue, title: "Protein", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryRiboflavin.rawValue, title: "Riboflavin", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietarySelenium.rawValue, title: "Selenium", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietarySodium.rawValue, title: "Sodium", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietarySugar.rawValue, title: "Sugar", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryThiamin.rawValue, title: "Thiamin", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryVitaminA.rawValue, title: "Vitamin A", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryVitaminB12.rawValue, title: "Vitamin B12", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryVitaminB6.rawValue, title: "Vitamin B6", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryVitaminC.rawValue, title: "Vitamin C", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryVitaminD.rawValue, title: "Vitamin D", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryVitaminE.rawValue, title: "Vitamin E", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryVitaminK.rawValue, title: "Vitamin K", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryWater.rawValue, title: "Water", group: "Nutrition", kind: "quantity", minimumMajor: 9, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.dietaryZinc.rawValue, title: "Zinc", group: "Nutrition", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.bloodAlcoholContent.rawValue, title: "Blood Alcohol Content", group: "Other", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.bloodPressureDiastolic.rawValue, title: "Blood Pressure Diastolic", group: "Other", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.bloodPressureSystolic.rawValue, title: "Blood Pressure Systolic", group: "Other", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.insulinDelivery.rawValue, title: "Insulin Delivery", group: "Other", kind: "quantity", minimumMajor: 11, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.numberOfAlcoholicBeverages.rawValue, title: "Number Of Alcoholic Beverages", group: "Other", kind: "quantity", minimumMajor: 15, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.numberOfTimesFallen.rawValue, title: "Number Of Times Fallen", group: "Other", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.timeInDaylight.rawValue, title: "Time In Daylight", group: "Other", kind: "quantity", minimumMajor: 17, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.uvExposure.rawValue, title: "UV Exposure", group: "Other", kind: "quantity", minimumMajor: 9, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.waterTemperature.rawValue, title: "Water Temperature", group: "Other", kind: "quantity", minimumMajor: 16, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.basalBodyTemperature.rawValue, title: "Basal Body Temperature", group: "Reproductive Health", kind: "quantity", minimumMajor: 9, minimumMinor: 0, categoryLabels: [:]))
        if #available(iOS 18.0, *) { result.append(.init(id: HKQuantityTypeIdentifier.appleSleepingBreathingDisturbances.rawValue, title: "Sleeping Breathing Disturbances", group: "Respiratory", kind: "quantity", minimumMajor: 18, minimumMinor: 0, categoryLabels: [:])) }
        result.append(.init(id: HKQuantityTypeIdentifier.forcedExpiratoryVolume1.rawValue, title: "Forced Expiratory Volume1", group: "Respiratory", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.forcedVitalCapacity.rawValue, title: "Forced Vital Capacity", group: "Respiratory", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.inhalerUsage.rawValue, title: "Inhaler Usage", group: "Respiratory", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.oxygenSaturation.rawValue, title: "Blood oxygen", group: "Respiratory", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.peakExpiratoryFlowRate.rawValue, title: "Peak Expiratory Flow Rate", group: "Respiratory", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.respiratoryRate.rawValue, title: "Respiratory Rate", group: "Respiratory", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.bloodGlucose.rawValue, title: "Blood Glucose", group: "Vital Signs", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKQuantityTypeIdentifier.bodyTemperature.rawValue, title: "Body Temperature", group: "Vital Signs", kind: "quantity", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        result.append(.init(id: HKCategoryTypeIdentifier.appleStandHour.rawValue, title: "Stand Hour", group: "Fitness", kind: "category", minimumMajor: 9, minimumMinor: 0, categoryLabels: [0: "Stood", 1: "Idle"]))
        result.append(.init(id: HKCategoryTypeIdentifier.environmentalAudioExposureEvent.rawValue, title: "Environmental Audio Exposure Event", group: "Hearing Health", kind: "category", minimumMajor: 14, minimumMinor: 0, categoryLabels: [1: "Momentary Limit"]))
        result.append(.init(id: HKCategoryTypeIdentifier.headphoneAudioExposureEvent.rawValue, title: "Headphone Audio Exposure Event", group: "Hearing Health", kind: "category", minimumMajor: 14, minimumMinor: 2, categoryLabels: [1: "Seven Day Limit"]))
        result.append(.init(id: HKCategoryTypeIdentifier.highHeartRateEvent.rawValue, title: "High Heart Rate Event", group: "Heart", kind: "category", minimumMajor: 12, minimumMinor: 2, categoryLabels: [0: "Not Applicable"]))
        if #available(iOS 26.2, *) { result.append(.init(id: HKCategoryTypeIdentifier.hypertensionEvent.rawValue, title: "Hypertension Event", group: "Heart", kind: "category", minimumMajor: 26, minimumMinor: 2, categoryLabels: [0: "Not Applicable"])) }
        result.append(.init(id: HKCategoryTypeIdentifier.irregularHeartRhythmEvent.rawValue, title: "Irregular Heart Rhythm Event", group: "Heart", kind: "category", minimumMajor: 12, minimumMinor: 2, categoryLabels: [0: "Not Applicable"]))
        result.append(.init(id: HKCategoryTypeIdentifier.lowCardioFitnessEvent.rawValue, title: "Low Cardio Fitness Event", group: "Heart", kind: "category", minimumMajor: 14, minimumMinor: 3, categoryLabels: [1: "Low Fitness"]))
        result.append(.init(id: HKCategoryTypeIdentifier.lowHeartRateEvent.rawValue, title: "Low Heart Rate Event", group: "Heart", kind: "category", minimumMajor: 12, minimumMinor: 2, categoryLabels: [0: "Not Applicable"]))
        result.append(.init(id: HKCategoryTypeIdentifier.mindfulSession.rawValue, title: "Mindful Session", group: "Mental Wellbeing", kind: "category", minimumMajor: 10, minimumMinor: 0, categoryLabels: [0: "Not Applicable"]))
        result.append(.init(id: HKCategoryTypeIdentifier.appleWalkingSteadinessEvent.rawValue, title: "Walking Steadiness Event", group: "Mobility", kind: "category", minimumMajor: 15, minimumMinor: 0, categoryLabels: [1: "Initial Low", 2: "Initial Very Low", 3: "Repeat Low", 4: "Repeat Very Low"]))
        result.append(.init(id: HKCategoryTypeIdentifier.handwashingEvent.rawValue, title: "Handwashing Event", group: "Other", kind: "category", minimumMajor: 14, minimumMinor: 0, categoryLabels: [0: "Not Applicable"]))
        result.append(.init(id: HKCategoryTypeIdentifier.toothbrushingEvent.rawValue, title: "Toothbrushing Event", group: "Other", kind: "category", minimumMajor: 13, minimumMinor: 0, categoryLabels: [0: "Not Applicable"]))
        #if compiler(>=6.4)  // iOS 27 SDK only (#33)
        if #available(iOS 27.0, *) { result.append(.init(id: HKCategoryTypeIdentifier.bleedingAfterMenopause.rawValue, title: "Bleeding After Menopause", group: "Reproductive Health", kind: "category", minimumMajor: 27, minimumMinor: 0, categoryLabels: [1: "Unspecified", 2: "Light", 3: "Medium", 4: "Heavy", 5: "None"])) }
        #endif
        if #available(iOS 18.0, *) { result.append(.init(id: HKCategoryTypeIdentifier.bleedingAfterPregnancy.rawValue, title: "Bleeding After Pregnancy", group: "Reproductive Health", kind: "category", minimumMajor: 18, minimumMinor: 0, categoryLabels: [1: "Unspecified", 2: "Light", 3: "Medium", 4: "Heavy", 5: "None"])) }
        if #available(iOS 18.0, *) { result.append(.init(id: HKCategoryTypeIdentifier.bleedingDuringPregnancy.rawValue, title: "Bleeding During Pregnancy", group: "Reproductive Health", kind: "category", minimumMajor: 18, minimumMinor: 0, categoryLabels: [1: "Unspecified", 2: "Light", 3: "Medium", 4: "Heavy", 5: "None"])) }
        result.append(.init(id: HKCategoryTypeIdentifier.cervicalMucusQuality.rawValue, title: "Cervical Mucus Quality", group: "Reproductive Health", kind: "category", minimumMajor: 9, minimumMinor: 0, categoryLabels: [1: "Dry", 2: "Sticky", 3: "Creamy", 4: "Watery", 5: "Egg White"]))
        result.append(.init(id: HKCategoryTypeIdentifier.contraceptive.rawValue, title: "Contraceptive", group: "Reproductive Health", kind: "category", minimumMajor: 14, minimumMinor: 3, categoryLabels: [1: "Unspecified", 2: "Implant", 3: "Injection", 4: "Intrauterine Device", 5: "Intravaginal Ring", 6: "Oral", 7: "Patch"]))
        result.append(.init(id: HKCategoryTypeIdentifier.infrequentMenstrualCycles.rawValue, title: "Infrequent Menstrual Cycles", group: "Reproductive Health", kind: "category", minimumMajor: 16, minimumMinor: 0, categoryLabels: [0: "Not Applicable"]))
        result.append(.init(id: HKCategoryTypeIdentifier.intermenstrualBleeding.rawValue, title: "Intermenstrual Bleeding", group: "Reproductive Health", kind: "category", minimumMajor: 9, minimumMinor: 0, categoryLabels: [0: "Not Applicable"]))
        result.append(.init(id: HKCategoryTypeIdentifier.irregularMenstrualCycles.rawValue, title: "Irregular Menstrual Cycles", group: "Reproductive Health", kind: "category", minimumMajor: 16, minimumMinor: 0, categoryLabels: [0: "Not Applicable"]))
        result.append(.init(id: HKCategoryTypeIdentifier.lactation.rawValue, title: "Lactation", group: "Reproductive Health", kind: "category", minimumMajor: 14, minimumMinor: 3, categoryLabels: [0: "Not Applicable"]))
        #if compiler(>=6.4)  // iOS 27 SDK only (#33)
        if #available(iOS 27.0, *) { result.append(.init(id: HKCategoryTypeIdentifier.menopausalState.rawValue, title: "Menopausal State", group: "Reproductive Health", kind: "category", minimumMajor: 27, minimumMinor: 0, categoryLabels: [1: "Menopause", 2: "Perimenopause", 3: "None"])) }
        #endif
        result.append(.init(id: HKCategoryTypeIdentifier.menstrualFlow.rawValue, title: "Menstrual Flow", group: "Reproductive Health", kind: "category", minimumMajor: 9, minimumMinor: 0, categoryLabels: [1: "Unspecified", 2: "Light", 3: "Medium", 4: "Heavy", 5: "None"]))
        result.append(.init(id: HKCategoryTypeIdentifier.ovulationTestResult.rawValue, title: "Ovulation Test Result", group: "Reproductive Health", kind: "category", minimumMajor: 9, minimumMinor: 0, categoryLabels: [1: "Negative", 3: "Indeterminate"]))
        result.append(.init(id: HKCategoryTypeIdentifier.persistentIntermenstrualBleeding.rawValue, title: "Persistent Intermenstrual Bleeding", group: "Reproductive Health", kind: "category", minimumMajor: 16, minimumMinor: 0, categoryLabels: [0: "Not Applicable"]))
        result.append(.init(id: HKCategoryTypeIdentifier.pregnancy.rawValue, title: "Pregnancy", group: "Reproductive Health", kind: "category", minimumMajor: 14, minimumMinor: 3, categoryLabels: [0: "Not Applicable"]))
        result.append(.init(id: HKCategoryTypeIdentifier.pregnancyTestResult.rawValue, title: "Pregnancy Test Result", group: "Reproductive Health", kind: "category", minimumMajor: 15, minimumMinor: 0, categoryLabels: [1: "Negative", 2: "Positive", 3: "Indeterminate"]))
        result.append(.init(id: HKCategoryTypeIdentifier.progesteroneTestResult.rawValue, title: "Progesterone Test Result", group: "Reproductive Health", kind: "category", minimumMajor: 15, minimumMinor: 0, categoryLabels: [1: "Negative", 2: "Positive", 3: "Indeterminate"]))
        result.append(.init(id: HKCategoryTypeIdentifier.prolongedMenstrualPeriods.rawValue, title: "Prolonged Menstrual Periods", group: "Reproductive Health", kind: "category", minimumMajor: 16, minimumMinor: 0, categoryLabels: [0: "Not Applicable"]))
        result.append(.init(id: HKCategoryTypeIdentifier.sexualActivity.rawValue, title: "Sexual Activity", group: "Reproductive Health", kind: "category", minimumMajor: 9, minimumMinor: 0, categoryLabels: [0: "Not Applicable"]))
        if #available(iOS 18.0, *) { result.append(.init(id: HKCategoryTypeIdentifier.sleepApneaEvent.rawValue, title: "Sleep Apnea Event", group: "Respiratory", kind: "category", minimumMajor: 18, minimumMinor: 0, categoryLabels: [0: "Not Applicable"])) }
        result.append(.init(id: HKCategoryTypeIdentifier.sleepAnalysis.rawValue, title: "Sleep stages", group: "Sleep", kind: "category", minimumMajor: 8, minimumMinor: 0, categoryLabels: [0: "In Bed"]))
        result.append(.init(id: HKCategoryTypeIdentifier.abdominalCramps.rawValue, title: "Abdominal Cramps", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.acne.rawValue, title: "Acne", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.appetiteChanges.rawValue, title: "Appetite Changes", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "No Change", 2: "Decreased", 3: "Increased"]))
        result.append(.init(id: HKCategoryTypeIdentifier.bladderIncontinence.rawValue, title: "Bladder Incontinence", group: "Symptoms", kind: "category", minimumMajor: 14, minimumMinor: 0, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.bloating.rawValue, title: "Bloating", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.breastPain.rawValue, title: "Breast Pain", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.chestTightnessOrPain.rawValue, title: "Chest Tightness Or Pain", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.chills.rawValue, title: "Chills", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.constipation.rawValue, title: "Constipation", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.coughing.rawValue, title: "Coughing", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.diarrhea.rawValue, title: "Diarrhea", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.dizziness.rawValue, title: "Dizziness", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.drySkin.rawValue, title: "Dry Skin", group: "Symptoms", kind: "category", minimumMajor: 14, minimumMinor: 0, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.fainting.rawValue, title: "Fainting", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.fatigue.rawValue, title: "Fatigue", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.fever.rawValue, title: "Fever", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.generalizedBodyAche.rawValue, title: "Generalized Body Ache", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.hairLoss.rawValue, title: "Hair Loss", group: "Symptoms", kind: "category", minimumMajor: 14, minimumMinor: 0, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.headache.rawValue, title: "Headache", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.heartburn.rawValue, title: "Heartburn", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.hotFlashes.rawValue, title: "Hot Flashes", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.lossOfSmell.rawValue, title: "Loss Of Smell", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.lossOfTaste.rawValue, title: "Loss Of Taste", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.lowerBackPain.rawValue, title: "Lower Back Pain", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.memoryLapse.rawValue, title: "Memory Lapse", group: "Symptoms", kind: "category", minimumMajor: 14, minimumMinor: 0, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.moodChanges.rawValue, title: "Mood Changes", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Present", 1: "Not Present"]))
        result.append(.init(id: HKCategoryTypeIdentifier.nausea.rawValue, title: "Nausea", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.nightSweats.rawValue, title: "Night Sweats", group: "Symptoms", kind: "category", minimumMajor: 14, minimumMinor: 0, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.pelvicPain.rawValue, title: "Pelvic Pain", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.rapidPoundingOrFlutteringHeartbeat.rawValue, title: "Rapid Pounding Or Fluttering Heartbeat", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.runnyNose.rawValue, title: "Runny Nose", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.shortnessOfBreath.rawValue, title: "Shortness Of Breath", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.sinusCongestion.rawValue, title: "Sinus Congestion", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.skippedHeartbeat.rawValue, title: "Skipped Heartbeat", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.sleepChanges.rawValue, title: "Sleep Changes", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Present", 1: "Not Present"]))
        result.append(.init(id: HKCategoryTypeIdentifier.soreThroat.rawValue, title: "Sore Throat", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.vaginalDryness.rawValue, title: "Vaginal Dryness", group: "Symptoms", kind: "category", minimumMajor: 14, minimumMinor: 0, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.vomiting.rawValue, title: "Vomiting", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKCategoryTypeIdentifier.wheezing.rawValue, title: "Wheezing", group: "Symptoms", kind: "category", minimumMajor: 13, minimumMinor: 6, categoryLabels: [0: "Unspecified", 1: "Not Present", 2: "Mild", 3: "Moderate", 4: "Severe"]))
        result.append(.init(id: HKObjectType.workoutType().identifier, title: "Workouts", group: "Fitness", kind: "workout", minimumMajor: 8, minimumMinor: 0, categoryLabels: [:]))
        return result
    }()
    // FEATURE 04 — Expose only available definitions
    // Keep rows whose sample type exists on this OS. The resulting count describes
    // software support only; it says nothing about permission or saved health history.
    static var available: [HealthMetricDefinition] { definitions.filter { $0.sampleType != nil } }
}
