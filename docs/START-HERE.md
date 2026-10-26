# Start here: read the Health Dashboard code

You do not need to know Swift syntax to follow the numbered `FEATURE` comments. Read the explanation immediately above a block, then scan its names and user-facing text. A *view* builds a screen; a *store* holds readings that screens display; a *sample* is one Apple Health record; `nil` means unknown, not zero.

1. [App.swift](../HealthDashboard/App.swift): launch → Today cards → Trends → Settings. Start with FEATURE 03–05 to see how choices and readings meet.
2. [HealthStore.swift](../HealthDashboard/HealthStore.swift): source switch → permission → refresh → daily summaries → failures. This is where live readings enter the dashboard.
3. [HealthCore.swift](../HealthDashboard/HealthCore.swift): overlapping sleep, multiple sources and missing stages become daily values.
4. [HealthCatalog.swift](../HealthDashboard/HealthCatalog.swift) then [HealthLibrary.swift](../HealthDashboard/HealthLibrary.swift): type names → search → explicit per-type access → sample history.
5. [Notifications.swift](../HealthDashboard/Notifications.swift): Save/mute/test; generic reminders, not health monitoring.
6. [Biomarkers.swift](../HealthDashboard/Biomarkers.swift) then [BiomarkerDemoView.swift](../HealthDashboard/BiomarkerDemoView.swift): fictional report model → validation → correction history → display.
7. [Calculation tests](../Tests/HealthCoreTests/HealthCoreTests.swift) and [lab tests](../Tests/HealthCoreTests/BiomarkerTests.swift): each FEATURE states an invented scenario and the mistake it guards against.

Comments explain existing behavior, not promised features. See the [complete tracked-file checklist](CODE-COVERAGE.md) for every file, including configuration and data that cannot use ordinary source comments. This index supplements explanations inside the source.
