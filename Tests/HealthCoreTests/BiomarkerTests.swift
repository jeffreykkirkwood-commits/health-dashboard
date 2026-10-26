// PURPOSE: Check the fictional lab model's import and comparison rules. No provider account or real laboratory records are used.
// READING GUIDE: Follow the numbered FEATURE sections below; see docs/START-HERE.md for the whole app.

import XCTest
@testable import HealthCore
final class BiomarkerTests: XCTestCase {
    // FEATURE 01 — Load the same fictional resource the app presents
    // A fixture is prepared test data. Sharing this loader ensures tests exercise
    // the shipped example instead of a different hand-written model.
    func fixture() throws -> BiomarkerEnvelope {
        return try BiomarkerImport.loadBundledDemo()
    }
    // FEATURE 02 — Preserve correction links and reported fields
    // Expect the revised report/result to name its predecessor and retain decimal
    // text plus collection/issue dates. Failure could hide the correction history
    // or confuse when a sample was collected with when its result was issued.
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
    // FEATURE 03 — Do not mix units or invent exact missing values
    // Select one person/test/unit/method and check the returned IDs and numbers.
    // Replaced results must disappear, while missing/less-than records cannot
    // become exact numbers or zero. This protects the meaning of the history.
    func testTrendsDoNotMixUnitsOrPlotCensoredMissingValues() throws {
        let data = try fixture()
        let first = data.reports[0].observations[0]
        let points = BiomarkerTrends.points(in: data, subjectID: "SYNTHETIC-person-001", coding: first.analyte[0], reportedUnit: "mg/dL", specimen: first.specimen?.type, method: first.method)
        XCTAssertEqual(points.map { $0.id }, ["aug", "sep-missing", "oct-v2", "censored"])
        XCTAssertEqual(points.compactMap(\.exactValue), [Decimal(88), Decimal(94)])
    }
    // FEATURE 04 — Reject unsupported formats and non-fictional envelopes
    // Changing the synthetic marker or format version must fail validation.
    // This milestone must not silently accept an unsupported real-data import.
    func testRejectsNonSyntheticEnvelopeAndUnsupportedVersion() throws {
        let f = try fixture()
        XCTAssertThrowsError(try BiomarkerImport.validate(BiomarkerEnvelope(schemaVersion: 1, syntheticOnly: false, reports: f.reports)))
        XCTAssertThrowsError(try BiomarkerImport.validate(BiomarkerEnvelope(schemaVersion: 2, syntheticOnly: true, reports: f.reports)))
    }
    // FEATURE 05 — Reject duplicate record identities
    // Appending the same report creates duplicate IDs and must fail. Otherwise
    // report lookup and correction links could point to ambiguous records.
    func testRejectsDuplicateIDs() throws {
        let f = try fixture()
        XCTAssertThrowsError(try BiomarkerImport.validate(BiomarkerEnvelope(schemaVersion: 1, syntheticOnly: true, reports: f.reports + [f.reports[0]])))
    }
    // FEATURE 06 — Repeating an import must not duplicate reports
    // Idempotent means repeatable without an extra effect. Merge the same fixture
    // with itself and expect the unchanged envelope, not twice as many reports.
    func testDuplicateImportIsIdempotent() throws {
        let f = try fixture()
        XCTAssertEqual(try BiomarkerImport.mergeSynthetic(f, f), f)
    }
    // FEATURE 07 — Writing and reading JSON must preserve reported fields
    // Encode then decode the fixture and compare it with the original. This
    // protects values and metadata from being lost during the round trip.
    func testJSONRoundTripPreservesReportedFields() throws {
        let f = try fixture()
        XCTAssertEqual(try BiomarkerImport.decodeSynthetic(JSONEncoder().encode(f)), f)
    }
}
