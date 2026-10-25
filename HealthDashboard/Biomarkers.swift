import Foundation

// App-owned interchange model, not a provider API payload or FHIR resource.
// Raw strings preserve source precision, unknown codes/statuses, and date granularity.
struct LabCoding: Codable, Equatable, Hashable {
    let system: String
    let code: String
    let display: String?
}
struct LabIdentifier: Codable, Equatable, Hashable {
    let system: String
    let value: String
}
struct LabQuantity: Codable, Equatable {
    let decimal: String
    let comparator: String?
    let reportedUnit: String?
    let unitCoding: LabCoding?
    var numericValue: Decimal? { guard decimal.range(of: #"^[+-]?[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil else { return nil }; return Decimal(string: decimal, locale: Locale(identifier: "en_US_POSIX")) }
}
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

enum BiomarkerImportError: Error, Equatable {
    case unsupportedSchema, syntheticOnlyRequired, duplicateID, conflictingReport(String), invalidValue(String), unresolvedRevision(String)
}

enum BiomarkerImport {
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
    static func decodeSynthetic(_ data: Data) throws -> BiomarkerEnvelope {
        let envelope = try JSONDecoder().decode(BiomarkerEnvelope.self, from: data)
        try validate(envelope)
        return envelope
    }
    // Identical imports are idempotent. Changed content under the same local
    // report ID requires an explicit revision ID rather than silent replacement.
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
    static func validate(_ envelope: BiomarkerEnvelope) throws {
        guard envelope.schemaVersion == 1 else { throw BiomarkerImportError.unsupportedSchema }
        guard envelope.syntheticOnly, envelope.reports.allSatisfy({ $0.provenance.synthetic && $0.observations.allSatisfy { $0.provenance.synthetic } }) else { throw BiomarkerImportError.syntheticOnlyRequired }
        let reports = envelope.reports
        let observations = reports.flatMap(\.observations)
        guard Set(reports.map(\.id)).count == reports.count, Set(observations.map(\.id)).count == observations.count else { throw BiomarkerImportError.duplicateID }
        guard reports.allSatisfy({ !$0.id.isEmpty && !$0.subjectID.isEmpty }), observations.allSatisfy({ !$0.id.isEmpty && !$0.analyte.isEmpty }) else { throw BiomarkerImportError.invalidValue("empty identity or analyte") }
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

struct LabTrendPoint: Identifiable {
    var id: String { observation.id }
    let observation: BiomarkerObservation
    let date: Date
    let exactValue: Decimal?
}
enum BiomarkerTrends {
    // Narrow comparison: same subject, analyte system/code, raw unit, specimen
    // and method. No unit conversion, clinical inference, or missing-to-zero.
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
