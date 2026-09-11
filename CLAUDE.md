# salesforce-error-handling

Reusable Salesforce error-handling framework. Phase 1 is Flow fault handling: invocable Apex + service, two subflows, an LWC fault panel, Custom Metadata rules, and a pluggable log sink with a Nebula Logger adapter. See `README.md` and `docs/`.

## Invariants

- **The handler never throws and never hides.** `FlowFaultService` is the only class allowed to catch broadly; every fallback lands in `Fault.warnings`, and logging failures return `isLogged = false` with `loggingError`. Sinks throw on failure; they do not swallow.
- **Rules come from `config/fault-rules.json`.** Never hand-edit `customMetadata/FlowFaultRule.*`; edit the JSON and run `node scripts/generate-rules.js`. `--check` must pass before commit.
- **Core has no Nebula dependency.** Anything that references `Logger` lives in `nebula-adapter/`.
- **No org data.** No aliases, credentials, real object or field names from client orgs, or CUI. Commands use `<alias>`.

## Conventions

- API names without separator underscores: `FlowFaultRule__mdt`, not `Flow_Fault_Rule__mdt`. Flow element names may use underscores (Flow Builder convention).
- Apex and JavaScript: tabs, printWidth 120, compact-readable. Salesforce XML: 4 spaces, elements in the order Flow Builder emits (alphabetical by element type; `description`, `name`, `label`, `locationX`, `locationY` first inside an element).
- Tests: `<ClassName>Test`, `@IsTest private`, `Assert` class with a message on every assertion, bulk at 1 / 50 / 200, inject rules/settings/sink via the `@TestVisible` overrides. Shared doubles in `FlowFaultTestSinks`.
- Every Apex class carries the AI-draft / human-review header.
- Dependencies: MIT / Apache-2.0 / BSD only. Never AGPL, GPL, LGPL, EUPL, CDDL, MPL, CPL, SSPLv1. Do not `npm install` or `sf plugins install` without saying so first.

## Commands

```bash
node scripts/generate-rules.js            # regenerate rule records + docs/fault-rules.md
node scripts/generate-rules.js --check    # CI gate
sf project deploy start --source-dir force-app --target-org <alias>
sf project deploy start --source-dir nebula-adapter --target-org <alias>
sf project deploy start --source-dir demo --target-org <alias>
sf apex run test --test-level RunSpecifiedTests --class-names FlowFaultParserTest,FlowFaultServiceTest,FlowFaultHandlerTest,FlowFaultSinkResolverTest,FlowFaultSettingsTest,FlowFaultRuleProviderTest --target-org <alias> --wait 10
sf apex run --file scripts/apex/simulate-faults.apex --target-org <alias>
```

## Where things go

- New `$Flow.FaultMessage` shape → test in `FlowFaultParserTest`, row in `docs/fault-message-formats.md`, then parser change if needed.
- New classification → rule in `config/fault-rules.json`.
- New wording → Custom Label in `labels/CustomLabels.labels-meta.xml`.
- New persistence → class implementing `FlowFaultLogSink` in its own package directory; point `FlowFaultSetting__mdt.Default.LogSinkClass__c` at it.
- Design changes → append to `docs/design-decisions.md`; do not rewrite history.
