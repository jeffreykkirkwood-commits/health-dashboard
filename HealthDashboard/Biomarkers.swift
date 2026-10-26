// PURPOSE: Describe and validate fictional lab reports loaded from the bundled JSON file. No real lab provider or clinical-record importer is connected.
// READING GUIDE: Follow the numbered FEATURE sections below; see docs/START-HERE.md for the whole app.

import Foundation

// App-owned interchange model, not a provider API payload or FHIR resource.
// Raw strings preserve source precision, unknown codes/statuses, and date granularity.
// FEATURE 01 — Retain the source's meaning and identifiers
// A coding is a system/code pair plus an optional readable label. Identifiers
// name records in their source system. Keeping both avoids confusing equal
// labels from different systems; these small models do not fetch anything.
struct LabCoding: Codable, Equatable, Hashable {
    let system: String
    let code: String
    let display: String?
}
struct LabIdentifier: Codable, Equatable, Hashable {
    let system: String
    let value: String
}
// FEATURE 02 — Preserve exactly how a result was reported
// Store the decimal as text, its unit and any comparator such as less-than.
// numericValue accepts only a plain decimal string before parsing it. This
// keeps raw precision/text available rather than silently guessing a number.
struct LabQuantity: Codable, Equatable {
    let decimal: String
    let comparator: String?
    let reportedUnit: String?
    let unitCoding: LabCoding?
    var numericValue: Decimal? { guard decimal.range(of: #"^[+-]?[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil else { return nil }; return Decimal(string: decimal, locale: Locale(identifier: "en_US_POSIX")) }
}
// FEATURE 03 — Distinguish numbers, words and missing results
// kind says how to interpret the accompanying fields: a quantity, qualitative
// code, text, missing reason or unsupported text. A missing result is not zero.
// Reference ranges retain source wording/bounds and who the range applies to.
struct LabValue: Codable, Equatable {
    enum Kind: String, Codable { case quantity, qualitative, text, missing, unsupported }
    let kind: Kind
    let rawText: String?
    let quantity: LabQuantity?
    let qualitative: LabCoding?
    let missingReason: LabCoding?
}
struct LabReferenceRange: Codable, Equatable {
    let rawText: String?
    let low: LabQuantity?
    let high: LabQuantity?
    let appliesTo: [LabCoding]
    let ageText: String?
}
// FEATURE 04 — Keep collection context separate from result time
// A specimen describes what was collected and when. Provenance means the
// record's origin: source document, import time, transformation version and
// synthetic marker. These fields help explain where a displayed value came from.
struct LabSpecimen: Codable, Equatable {
    let identifier: LabIdentifier?
    let type: LabCoding?
    let collectionStart: String?
    let collectionEnd: String?
    let receivedAt: String?
}
struct LabProvenance: Codable, Equatable {
    let sourceName: String
    let sourceFormat: String
    let sourceDocumentID: String
    let sourceLocator: String?
    let importedAt: String
    let transformationVersion: String
    let synthetic: Bool
}
// FEATURE 05 — Represent one result without recalculating source flags
// An analyte is what the test measures. The observation keeps its value,
// reference ranges, source interpretation, dates and optional replaced-result
// ID. Flags remain the source's flags, not a diagnosis invented by this app.
struct BiomarkerObservation: Codable, Equatable, Identifiable {
    let id: String // app-local ID, not a provider identifier
    let sourceIdentifiers: [LabIdentifier]
    let analyte: [LabCoding]
    let value: LabValue
    let referenceRanges: [LabReferenceRange]
    let interpretation: [LabCoding] // source flags only; never recomputed
    let notes: [String]
    let status: String // retain unknown source values
    let specimen: LabSpecimen?
    let effectiveAt: String?
    let issuedAt: String?
    let method: LabCoding?
    let replacesObservationID: String?
    let provenance: LabProvenance
}
// FEATURE 06 — Group results into a report and an import envelope
// A report names its subject and observations and may replace an older report.
// The envelope wraps reports with a format version and synthetic-only marker.
// These are app-owned structures, not a promise of compatibility with FHIR,
// the clinical data exchange standard, or a provider's export format.
struct BiomarkerReport: Codable, Equatable, Identifiable {
    let id: String
    let sourceIdentifiers: [LabIdentifier]
    let subjectID: String
    let subjectDisplay: String?
    let title: String
    let providerDisplay: String
    let status: String
    let issuedAt: String?
    let replacesReportID: String?
    let observations: [BiomarkerObservation]
    let provenance: LabProvenance
}
struct BiomarkerEnvelope: Codable, Equatable {
    let schemaVersion: Int
    let syntheticOnly: Bool
    let reports: [BiomarkerReport]
}

// FEATURE 07 — Name the reasons a fixture can be rejected
// Errors distinguish unsupported format, non-fictional input, duplicate IDs,
// conflicting replacements and invalid values. Callers show failure instead
// of displaying partly trusted results.
enum BiomarkerImportError: Error, Equatable {
    case unsupportedSchema, syntheticOnlyRequired, duplicateID, conflictingReport(String), invalidValue(String), unresolvedRevision(String)
}

enum BiomarkerImport {
    // FEATURE 08 — Load the fictional file shipped with the app
    // Choose the test-package bundle or app bundle, locate the JSON fixture and
    // pass its bytes through validation. A missing file throws an error. This
    // reads a local bundled resource; it does not contact a laboratory.
    static func loadBundledDemo() throws -> BiomarkerEnvelope {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "biomarkers.synthetic.v1", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try decodeSynthetic(Data(contentsOf: url))
    }
    // Deliberately accepts only fictional fixtures in this milestone.
    // FEATURE 09 — Decode the file before allowing it onto the screen
    // JSONDecoder turns structured JSON text into the models above. validate then
    // checks the format and safety rules. A parse or validation error stops the load.
    static func decodeSynthetic(_ data: Data) throws -> BiomarkerEnvelope {
        let envelope = try JSONDecoder().decode(BiomarkerEnvelope.self, from: data)
        try validate(envelope)
        return envelope
    }
    // Identical imports are idempotent. Changed content under the same local
    // report ID requires an explicit revision ID rather than silent replacement.
    // FEATURE 10 — Make a repeated import harmless
    // Idempotency means repeating the same instruction has no extra effect.
    // Identical report IDs with identical content are kept once. Different content
    // under the same ID is rejected; a correction needs a new linked revision.
    // Validate the combined result too, so merges cannot create ambiguous history.
    static func mergeSynthetic(_ existing: BiomarkerEnvelope, _ incoming: BiomarkerEnvelope) throws -> BiomarkerEnvelope {
        try validate(existing); try validate(incoming)
        var reports = existing.reports
        for item in incoming.reports {
            if let prior = reports.first(where: { $0.id == item.id }) {
                guard prior == item else { throw BiomarkerImportError.conflictingReport(item.id) }
            } else { reports.append(item) }
        }
        let combined = BiomarkerEnvelope(schemaVersion: 1, syntheticOnly: true, reports: reports)
        try validate(combined)
        return combined
    }
    // FEATURE 11 — Check identity, fictional status and result shape
    // Require version 1 and synthetic markers on the envelope, reports and results.
    // Require unique/nonempty identities and a named analyte. A number must have a
    // parseable quantity, a missing result needs a reason, and conflicting value
    // forms are rejected rather than guessed.
    static func validate(_ envelope: BiomarkerEnvelope) throws {
        guard envelope.schemaVersion == 1 else { throw BiomarkerImportError.unsupportedSchema }
        guard envelope.syntheticOnly, envelope.reports.allSatisfy({ $0.provenance.synthetic && $0.observations.allSatisfy { $0.provenance.synthetic } }) else { throw BiomarkerImportError.syntheticOnlyRequired }
        let reports = envelope.reports
        let observations = reports.flatMap(\.observations)
        guard Set(reports.map(\.id)).count == reports.count, Set(observations.map(\.id)).count == observations.count else { throw BiomarkerImportError.duplicateID }
        guard reports.allSatisfy({ !$0.id.isEmpty && !$0.subjectID.isEmpty }), observations.allSatisfy({ !$0.id.isEmpty && !$0.analyte.isEmpty }) else { throw BiomarkerImportError.invalidValue("empty identity or analyte") }
        // FEATURE 12 — Check that corrections form an understandable history
        // A replacement must refer to an existing different record for the same person;
        // a result correction must share an analyte code. Reject competing replacements
        // and loops, because there would be no unambiguous newest result to display.
        let reportRevisions = reports.compactMap(\.replacesReportID)
        let observationRevisions = observations.compactMap(\.replacesObservationID)
        guard Set(reportRevisions).count == reportRevisions.count, Set(observationRevisions).count == observationRevisions.count else { throw BiomarkerImportError.unresolvedRevision("ambiguous revision fork") }
        let byReport = Dictionary(uniqueKeysWithValues: reports.map { ($0.id, $0) })
        let byObservation = Dictionary(uniqueKeysWithValues: observations.map { ($0.id, $0) })
        let subjects = Dictionary(uniqueKeysWithValues: reports.flatMap { report in report.observations.map { ($0.id, report.subjectID) } })
        for report in reports {
            if let previous = report.replacesReportID {
                guard previous != report.id, let prior = byReport[previous], prior.subjectID == report.subjectID else { throw BiomarkerImportError.unresolvedRevision(report.id) }
            }
            for observation in report.observations {
                let value = observation.value
                switch value.kind {
                case .quantity:
                    guard let quantity = value.quantity, quantity.numericValue != nil, value.qualitative == nil, value.missingReason == nil else { throw BiomarkerImportError.invalidValue(observation.id) }
                case .qualitative:
                    guard value.quantity == nil, value.missingReason == nil, value.qualitative != nil || !(value.rawText ?? "").isEmpty else { throw BiomarkerImportError.invalidValue(observation.id) }
                case .text, .unsupported:
                    guard value.quantity == nil, value.qualitative == nil, value.missingReason == nil, !(value.rawText ?? "").isEmpty else { throw BiomarkerImportError.invalidValue(observation.id) }
                case .missing:
                    guard value.quantity == nil, value.qualitative == nil, value.missingReason != nil else { throw BiomarkerImportError.invalidValue(observation.id) }
                }
                if let previous = observation.replacesObservationID {
                    guard previous != observation.id, let prior = byObservation[previous], subjects[previous] == report.subjectID, prior.analyte.contains(where: { old in observation.analyte.contains { $0.system == old.system && $0.code == old.code } }) else { throw BiomarkerImportError.unresolvedRevision(observation.id) }
                }
            }
        }
        // Reject cycles rather than picking an arbitrary latest revision.
        for report in reports {
            var seen = Set<String>(); var cursor: BiomarkerReport? = report
            while let item = cursor { guard seen.insert(item.id).inserted else { throw BiomarkerImportError.unresolvedRevision(report.id) }; cursor = item.replacesReportID.flatMap { byReport[$0] } }
        }
        for observation in observations {
            var seen = Set<String>(); var cursor: BiomarkerObservation? = observation
            while let item = cursor { guard seen.insert(item.id).inserted else { throw BiomarkerImportError.unresolvedRevision(observation.id) }; cursor = item.replacesObservationID.flatMap { byObservation[$0] } }
        }
    }
}

// FEATURE 13 — Represent a dated comparable result
// A trend point keeps the original observation alongside its date. exactValue
// can be absent even with text present: less-than results and missing results
// must not be plotted as exact measurements.
struct LabTrendPoint: Identifiable {
    var id: String { observation.id }
    let observation: BiomarkerObservation
    let date: Date
    let exactValue: Decimal?
}
enum BiomarkerTrends {
    // Narrow comparison: same subject, analyte system/code, raw unit, specimen
    // and method. No unit conversion, clinical inference, or missing-to-zero.
    // FEATURE 14 — Choose only genuinely comparable history
    // Select the same person, analyte code/system, raw unit, specimen and method.
    // Use final/amended/corrected records and omit versions replaced by later ones.
    // A usable timestamp is required. Missing and comparator results keep no exact
    // number. Sort by date without converting units or making clinical inferences.
    static func points(in envelope: BiomarkerEnvelope, subjectID: String, coding: LabCoding,
                       reportedUnit: String, specimen: LabCoding?, method: LabCoding?) -> [LabTrendPoint] {
        let replacedReports = Set(envelope.reports.compactMap(\.replacesReportID))
        let replacedObservations = Set(envelope.reports.flatMap(\.observations).compactMap(\.replacesObservationID))
        let dates = ISO8601DateFormatter()
        return envelope.reports.filter { $0.subjectID == subjectID && ["final", "amended", "corrected"].contains($0.status) && !replacedReports.contains($0.id) }
            .flatMap(\.observations).filter { observation in
                !replacedObservations.contains(observation.id) && ["final", "amended", "corrected"].contains(observation.status)
                && observation.analyte.contains { $0.system == coding.system && $0.code == coding.code }
                && observation.specimen?.type == specimen && observation.method == method
                && (observation.value.kind == .missing || observation.value.quantity?.reportedUnit == reportedUnit)
            }.compactMap { observation in
                guard let raw = observation.effectiveAt ?? observation.specimen?.collectionStart,
                      let date = dates.date(from: raw) else { return nil }
                let exact = observation.value.quantity.flatMap { $0.comparator == nil ? $0.numericValue : nil }
                return LabTrendPoint(observation: observation, date: date, exactValue: exact)
            }.sorted { $0.date < $1.date }
    }
}
