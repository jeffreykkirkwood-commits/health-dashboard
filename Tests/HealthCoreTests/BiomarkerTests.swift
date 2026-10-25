import XCTest
@testable import HealthCore
final class BiomarkerTests: XCTestCase {
    func fixture() throws -> BiomarkerEnvelope {
        return try BiomarkerImport.loadBundledDemo()
    }
    func testFixturePreservesAmendmentsAndRawPrecision() throws {
        let data = try fixture()
        XCTAssertEqual(data.reports.count, 8)
        let revised = try XCTUnwrap(data.reports.first { $0.id == "report-oct-v2" })
        XCTAssertEqual(revised.replacesReportID, "report-oct-v1")
        XCTAssertEqual(revised.observations[0].replacesObservationID, "oct-v1")
        XCTAssertEqual(revised.observations[0].value.quantity?.decimal, "94")
        XCTAssertEqual(revised.observations[0].specimen?.collectionStart, "2026-10-01T08:00:00Z")
        XCTAssertEqual(revised.observations[0].issuedAt, "2026-10-02T10:00:00Z")
    }
    func testTrendsDoNotMixUnitsOrPlotCensoredMissingValues() throws {
        let data = try fixture()
        let first = data.reports[0].observations[0]
        let points = BiomarkerTrends.points(in: data, subjectID: "SYNTHETIC-person-001", coding: first.analyte[0], reportedUnit: "mg/dL", specimen: first.specimen?.type, method: first.method)
        XCTAssertEqual(points.map { $0.id }, ["aug", "sep-missing", "oct-v2", "censored"])
        XCTAssertEqual(points.compactMap(\.exactValue), [Decimal(88), Decimal(94)])
    }
    func testRejectsNonSyntheticEnvelopeAndUnsupportedVersion() throws {
        let f = try fixture()
        XCTAssertThrowsError(try BiomarkerImport.validate(BiomarkerEnvelope(schemaVersion: 1, syntheticOnly: false, reports: f.reports)))
        XCTAssertThrowsError(try BiomarkerImport.validate(BiomarkerEnvelope(schemaVersion: 2, syntheticOnly: true, reports: f.reports)))
    }
    func testRejectsDuplicateIDs() throws {
        let f = try fixture()
        XCTAssertThrowsError(try BiomarkerImport.validate(BiomarkerEnvelope(schemaVersion: 1, syntheticOnly: true, reports: f.reports + [f.reports[0]])))
    }
    func testDuplicateImportIsIdempotent() throws {
        let f = try fixture()
        XCTAssertEqual(try BiomarkerImport.mergeSynthetic(f, f), f)
    }
    func testJSONRoundTripPreservesReportedFields() throws {
        let f = try fixture()
        XCTAssertEqual(try BiomarkerImport.decodeSynthetic(JSONEncoder().encode(f)), f)
    }
}
