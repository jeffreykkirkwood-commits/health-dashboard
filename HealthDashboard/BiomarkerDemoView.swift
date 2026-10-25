import SwiftUI

struct BiomarkerDemoView: View {
    @State private var envelope: BiomarkerEnvelope?
    @State private var error: String?
    var body: some View {
        List {
            Section {
                Label("SYNTHETIC · FICTIONAL LABORATORY", systemImage: "testtube.2").font(.caption.bold())
                Text("Sample Person and every result, report, provider, range, and flag are fictional. This is an app demo format, not a Labcorp export or medical guidance.").font(.callout)
            }
            if let error { Section { Text(error) } }
            if let envelope {
                Section("Comparable glucose demo history") {
                    let coding = LabCoding(system: "urn:health-dashboard:synthetic:analytes", code: "glucose-demo", display: nil)
                    let specimen = LabCoding(system: coding.system, code: "serum", display: "SYNTHETIC serum specimen")
                    let method = LabCoding(system: coding.system, code: "method-demo", display: "SYNTHETIC demo method")
                    let points = BiomarkerTrends.points(in: envelope, subjectID: "SYNTHETIC-person-001", coding: coding, reportedUnit: "mg/dL", specimen: specimen, method: method)
                    ForEach(points) { point in
                        VStack(alignment: .leading) {
                            Text(point.date, format: .dateTime.year().month().day()).font(.headline)
                            Text(point.observation.value.rawText ?? "No reported value")
                            if point.exactValue == nil { Text("No exact numeric trend point").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    Text("Amended results replace earlier versions in this history. Different units stay separate; missing and comparator results are not treated as zero or exact values.").font(.caption)
                }
                Section("Reports · includes revision history") {
                    ForEach(envelope.reports) { report in
                        DisclosureGroup {
                            Text(report.providerDisplay).font(.caption)
                            Text("Report ID: \(report.id)").font(.caption)
                            if let prior = report.replacesReportID { Text("Amends: \(prior)").font(.caption) }
                            ForEach(report.observations) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.analyte.first?.display ?? "Unlabelled analyte").font(.headline)
                                    Text(item.value.rawText ?? "No reported value")
                                    Text("Collected: \(item.specimen?.collectionStart ?? "Unknown")").font(.caption)
                                    Text("Issued: \(item.issuedAt ?? "Unknown")").font(.caption)
                                    ForEach(Array(item.referenceRanges.enumerated()), id: \.offset) { _, range in Text(range.rawText ?? "No range text").font(.caption) }
                                    ForEach(item.interpretation, id: \.self) { flag in Text(flag.display ?? flag.code).font(.caption) }
                                }
                            }
                        } label: { Text("\(report.id) · \(report.status)") }
                    }
                }
            }
        }
        .navigationTitle("Biomarkers demo")
        .task {
            do {
                envelope = try BiomarkerImport.loadBundledDemo()
            } catch { self.error = "The synthetic fixture could not be validated. No provider connection was attempted." }
        }
    }
}
