# Biomarker import research and prototype contract

Research checked 2026-10-25. This is a repository design note, not a promise of provider access. All bundled records are fictional and labeled SYNTHETIC. No account was connected, no health record was fetched, and no clinical HealthKit entitlement was added.

## Receiving results: verified distinctions

| Route | Evidence and limitations | Prototype decision |
| --- | --- | --- |
| Apple Health Records | Labcorp announced Health Records on iPhone in 2018. That historical announcement does not establish current availability for this person's account, region, or provider. Apple's HealthKit clinical-record route exposes FHIR data and requires separate clinical read permissions. Future access must inspect `fhirResource.fhirVersion` (for example DSTU2 versus R4) and read `fhirResource.data`, preserving identity from source bundle identifier, resource type and identifier. Clinical records are read-only; apps cannot save synthetic clinical records into HealthKit. | Potential later adapter, only after checking provider availability, clinical entitlement/signing eligibility and explicit consent. Ordinary HealthKit Personal Team support does not establish clinical-record capability eligibility. |
| Direct provider integration | No open consumer Labcorp API or sample payload has been verified. Labcorp's published integration offering reviewed here concerns occupational/employee testing and wellness, not a general consumer API. | No API endpoint, authentication flow, price assumption, or live connection implemented. |
| Patient-controlled report file | If the user can obtain a report/export, inspect the actual format and rights before building an adapter. A PDF, CSV, FHIR JSON, HL7 v2 message, and CDA XML are different formats; their availability from this user's provider is unverified. | Future local import preview and confirmation, preserving provenance. OCR/PDF extraction would require human review of values, units, identity, ranges and dates. CSV would need a documented column map; never infer codes or units from headings alone. |
| Bundled synthetic JSON | App-owned schema below, not a Labcorp payload, FHIR resource, or medical record export. | Implemented for demo only. No file picker or real-record import. |

Sources:
- [Labcorp's 2018 iPhone Health Records announcement](https://www.labcorp.com/education-events/press-releases/labcorp-enables-health-records-iphone)
- [Apple: Accessing Health Records](https://developer.apple.com/documentation/healthkit/accessing-health-records)
- [Labcorp occupational/wellness integration offering](https://www.labcorp.com/organizations/capabilities/employee-testing-wellness/it-solutions/integrated-solutions)

## FHIR-shaped information, not a FHIR claim

FHIR R4 separates individual results (`Observation`) from a contextual report (`DiagnosticReport`) that references results. Observation can represent quantities, coded/text results, absent data, source interpretation and reference ranges. Actual resource versions and profiles must be detected by a future adapter; don't assume all Health Records JSON is R4. The internal model intentionally preserves source strings and coding instead of requiring every provider to use one terminology.

- [HL7 FHIR R4 Observation](https://hl7.org/fhir/R4/observation.html)
- [HL7 FHIR R4 DiagnosticReport](https://hl7.org/fhir/R4/diagnosticreport.html)

No general FHIR decoder is included. Panels/components, document attachments, resource references, extensions, terminology translation and arbitrary revision graphs require explicit adapter work; they must not be silently discarded by a later importer.

## App-owned JSON v1

`HealthDashboard/Fixtures/biomarkers.synthetic.v1.json` is consumed by `BiomarkerImport.decodeSynthetic`. This function accepts only schema version 1 with synthetic flags on the envelope and every provenance entry. A flag is a demo guard, not proof that an arbitrary file is deidentified. Only the bundled fixture is exposed in the app.

| Field group | Requirements / preservation policy |
| --- | --- |
| Envelope | `schemaVersion: 1`, `syntheticOnly: true`, `reports` array. Future schema changes require migration/version negotiation. |
| Report identity | Unique app-local `id`; namespaced `sourceIdentifiers`; `subjectID` and optional display; report title, provider display, raw source status, issued time, optional `replacesReportID`. Never use a display name alone to match a person. |
| Result identity / analyte | Unique app-local observation `id`; original identifiers; array of `{system, code, display}` analyte codings. Preserve local codes. Real LOINC mappings need verification; demo codes deliberately use a synthetic URN. |
| Result value | Explicit `quantity`, coded `qualitative`, `text`, `missing`, or raw `unsupported` kind. Unsupported values remain raw for review and are not charted. Quantities retain decimal text, comparator, reported unit and optional unit coding. Qualitative values retain coded and/or raw text. Missing results require a source missing-reason code; missing is never zero. |
| Units | Original unit text is authoritative for display. Optional coding can later preserve UCUM system/code. No conversions or code inference implemented. |
| Ranges and flags | Preserve each source range's text, low/high quantities, applicability codes and age text. Preserve source interpretation codes/display and status; don't infer a clinical flag from a fixture range. Demo ranges/flags are illustrative and not recommendations. |
| Specimen and time | Specimen identifier/type, collection start/end, received time; observation effective time and issued time remain separate. Raw date strings retain precision/timezone. Missing timezone or partial dates must not be invented. |
| Method | Optional method coding retained so future comparability decisions can distinguish methods. |
| Revision | Keep originals and explicit replacement links. V1 reports use complete replacement snapshots, not partial patches. Validate referenced IDs, subject consistency and cycles. Do not choose latest by array order. |
| Provenance | Source name/format/document ID/locator, imported time, transformation version, synthetic flag. A real adapter would additionally preserve a protected original document/resource, FHIR version/profile, identifiers/version metadata and derivation audit trail locally; none are fetched here. |

Result `notes` preserve source annotations. Identical repeated imports retain one report; conflicting content must use an explicit revision ID.

All array fields in the Swift model are required, even when empty. Optional fields may be omitted or null. Status and date strings are preserved rather than claimed to be fully validated. Unsupported real-world value forms must be retained/reviewed by a later adapter, never coerced into this demo schema.

## Trend and amendment rules

Only final/amended/corrected observations are eligible for demo trends. Earlier report/observation revisions remain in the report history but are excluded from the active trend. The demo comparator requires the same subject, analyte system/code, raw unit, specimen type and method. No unit conversion is performed. Numeric values with a comparator such as `<` are shown in reports but not plotted as exact values. Missing measurements remain gaps. Dates that cannot be parsed as complete ISO8601 timestamps remain in reports and are omitted from this narrow demo trend.

These are conservative presentation rules, not proof of medical comparability. A production importer still needs validated normalization, version-aware source adapters, pagination/update/deletion handling, duplicate detection, subject verification, local data protection/deletion, and user-confirmed import previews.

## Fixture inventory and validation

Eight fictional reports include seven familiar biomarkers (glucose, HbA1c, total cholesterol, HDL cholesterol, LDL cholesterol, triglycerides, ferritin) across three dated draws. Additional cases cover August and October numeric results; a September missing result; an October original and amended result linked to the same collection; a qualitative result; a different-unit result that must remain separate; and a censored `<80` result that must not become exact 80, and a cancelled report. Most analytes intentionally have no source range. Identical repeated imports are idempotent; changed content under an existing report ID is rejected until assigned an explicit revision. Subject is `SYNTHETIC-person-001`; provider is `SYNTHETIC Example Laboratory — fictional`. No Labcorp branding or fabricated provider payload is used.

Six new XCTest cases cover decoding/revision retention, conservative trends, non-synthetic/schema rejection, duplicate IDs, idempotent repeated import and lossless JSON round trip. Xcode 27.1 became usable during this milestone. All six biomarker XCTest cases pass, as do the original six core cases (12 total, zero failures). The full app builds for arm64 iOS Simulator with code signing disabled. JSON fixture markers, unique IDs, amendment references, three seven-biomarker draws, and missing/cancelled/comparator/unit/range cases also passed structural checks. Interactive UI, clinical capabilities, live data, notification delivery and physical-device behavior remain unverified. No software was installed or agreement accepted by this agent.

Additional adapter references: [Apple clinical records](https://developer.apple.com/documentation/healthkit/accessing-a-user-s-clinical-records), [HealthKit capability configuration](https://developer.apple.com/documentation/xcode/configuring-healthkit-access), [FHIR Quantity](https://hl7.org/fhir/R4/datatypes.html#Quantity), [FHIR Specimen](https://hl7.org/fhir/R4/specimen.html), [FHIR observation status](https://hl7.org/fhir/R4/codesystem-observation-status.html). UCUM's system URI is `http://unitsofmeasure.org`; demo fixtures retain raw units without asserting unverified code mappings.
