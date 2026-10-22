# salesforce-error-handling

Reusable, config-driven error handling for Salesforce. **Phase 1 (this release): Flow fault handling.** Later phases add LWC and Apex error handling on the same service, rules and log sink.

**Status:** Phase 1 built, not yet deployed to an org. Apex compiles, flows activate and the LWC renders only in theory until the verification steps below have been run. See *Constraints and caveats*.

> DRAFT: AI-generated with Claude Code. Every artifact must be human-reviewed and verified before use in any client org (Steampunk AI policy). Contains no customer data, org aliases or CUI. Nebula Logger (MIT) is the only third-party dependency and is optional.

## What it does

![Architecture](docs/images/architecture.png)

When a Flow element faults, the fault connector hands `$Flow.FaultMessage` to one reusable subflow. The subflow:

1. **Parses** the message: DML operation, status code (outer and, for trigger or Apex DML failures, inner), Apex exception type, originating trigger or class, the human-readable detail, the bracketed field list and any stack trace.
2. **Classifies** it against `FlowFaultRule__mdt` records (first active match by priority): Validation, RequiredField, Duplicate, Permission, RecordLock, LookupFilter, DataIntegrity, NotFound, Trigger, Apex, Limit, Configuration or Unknown.
3. **Renders** a user-safe message (a validation rule's own text, verbatim), next steps, admin guidance, a technical block and a ready-made rich-text display block, plus a reference ID like `FLT-3F9A2C1B`.
4. **Logs** the batch through a pluggable sink. Default: Nebula Logger, tagged `FlowFault`, scenario = flow API name, linked to the record. Nebula publishes platform events immediately, so the entry survives a Roll Back Records element or a later unhandled fault.
5. In screen flows, **rolls back** uncommitted records, shows the standard error panel with **Try again / Cancel**, and returns the choice so the caller can loop back.

The handler is the one place in the framework allowed to degrade instead of throwing, and it never degrades silently: every fallback is reported back to the flow as `isLogged = false`, `loggingError` and `warnings`.

## Contents

| Path | What |
|---|---|
| `force-app/` (core, no Nebula dependency) | |
| `classes/FlowFaultHandler.cls` | Invocable action **Handle Flow Fault**. Thin wrapper over the service. |
| `classes/FlowFaultService.cls` | Service layer: parse, match, render, log. Bulk-safe. |
| `classes/FlowFaultParser.cls` | Pure parser for `$Flow.FaultMessage` shapes. |
| `classes/FlowFaultRuleProvider.cls`, `FlowFaultSettings.cls` | Typed access to the two Custom Metadata Types, with test injection. |
| `classes/FlowFaultLogSink.cls`, `FlowFaultSinkResolver.cls`, `FlowFaultDebugLogSink.cls` | Persistence seam, resolution by class name, debug-log fallback. |
| `flows/FlowFaultHandlerCore` | Autolaunched subflow. Use anywhere, including record-triggered flows. |
| `flows/FlowFaultHandlerScreen` | Screen subflow: core + Roll Back Records + standard error screen + Retry/Cancel. |
| `lwc/flowFaultPanel` | Flow screen component that renders the panel and drives navigation. |
| `objects/FlowFaultRule__mdt`, `objects/FlowFaultSetting__mdt` | Rules and org-wide settings. |
| `customMetadata/` | 27 generated rule records plus the `Default` settings record. |
| `labels/CustomLabels` | All user-facing boilerplate, translatable. |
| `nebula-adapter/` | `FlowFaultNebulaLogSink` and its test. Deploy only where Nebula Logger is installed. |
| `demo/` | `FlowFaultDemo` screen flow and `FlowFaultDemoAction`. Sandboxes and scratch orgs only. |
| `config/fault-rules.json` | **Source of truth for rules.** Edit, then `npm run rules:generate`. |
| `scripts/generate-rules.js` | Generates the rule records and `docs/fault-rules.md`. Node stdlib only. |
| `scripts/apex/simulate-faults.apex` | In-org smoke test without building a flow. |
| `docs/` | Adoption guide, fault message catalogue, design decisions, generated rules table. |
| `docs/demo-guide.md`, `docs/images/` | Presenter runbook for the demo, plus architecture and demo-flow diagrams and fault panel images for training. Rebuild the PNGs with `node scripts/render-doc-images.js`. |

## Quick start

Authenticate to a sandbox or scratch org that has Nebula Logger (unlocked package) installed, then:

```bash
# 1. core
sf project deploy start --source-dir force-app --target-org <alias>
# 2. Nebula adapter (skip in orgs without Nebula; the core falls back to the debug log and says so)
sf project deploy start --source-dir nebula-adapter --target-org <alias>
# 3. demo (sandbox / scratch only)
sf project deploy start --source-dir demo --target-org <alias>

# tests
sf apex run test --test-level RunSpecifiedTests --class-names FlowFaultParserTest,FlowFaultServiceTest,FlowFaultHandlerTest,FlowFaultSinkResolverTest,FlowFaultSettingsTest,FlowFaultRuleProviderTest,FlowFaultNebulaLogSinkTest,FlowFaultDemoActionTest --target-org <alias> --wait 10 --code-coverage

# smoke test parsing + logging against the org's rules
sf apex run --file scripts/apex/simulate-faults.apex --target-org <alias>
```

Then open the **Flow Fault Demo** flow (Setup → Flows → Run) and pick a scenario. To present it, follow [docs/demo-guide.md](docs/demo-guide.md).

If the org's *Process Automation Settings → Deploy processes and flows as active* is off, the three flows deploy as Draft; activate `FlowFaultHandlerCore` first, then `FlowFaultHandlerScreen`, then `FlowFaultDemo`.

## Adding it to a flow

Short version; the full walkthrough with screenshots-in-words is in [docs/adoption-guide.md](docs/adoption-guide.md).

1. On every Create / Update / Delete / Get Records, Apex action, Submit for Approval, Send Email or Post to Chatter element, add a **fault connector**.
2. Point it at a **Subflow** element calling `FlowFaultHandlerScreen` (screen flows) or `FlowFaultHandlerCore` (everything else). Set:
   - `faultMessage` = `{!$Flow.FaultMessage}`
   - `flowApiName` = your flow's API name, typed as text (Flow has no variable for it)
   - `elementApiName` = the element whose fault connector this is
   - optionally `recordId`, `contextDetails` (a formula concatenating useful variable values), `customUserMessage`
3. Screen flows: route on the subflow's `selectedAction` output. `Retry` → go back to the screen before the failing element; `Cancel` → end or a summary screen.
4. Record-triggered flows: after `FlowFaultHandlerCore`, either end (log and let the record save) or add a **Custom Error** element with `{!Handle_Fault.userMessage}` to block the save with a proper message.

## Configuration

- **Rules** live in `config/fault-rules.json`. Regenerate records with `node scripts/generate-rules.js`; CI can run `--check`. Admins can also edit `FlowFaultRule__mdt` records in Setup, but the JSON is the source of truth for deployments. Placeholders: `{detail} {fields} {statusCode} {operation} {source} {exceptionType} {referenceId} {adminContact} {flow} {element}`.
- **Settings** are the `FlowFaultSetting__mdt.Default` record: sink class, logging on/off, technical details for users, reference ID prefix, admin contact text, technical message cap.
- **Wording** is in Custom Labels (`FlowFault*`), translatable via Translation Workbench.
- **Sink**: set `LogSinkClass__c` to any class implementing `FlowFaultLogSink`. Managed Nebula? Change `Logger` to `Nebula.Logger` in `FlowFaultNebulaLogSink.cls` (same fork as `BenchmarkHarness.cls`).

## Testing

- Apex: eight test classes, bulk tests at 1 / 50 / 200, one sink write per batch, `Assert` class throughout. Rules, settings and sinks are injected via `@TestVisible` overrides; two tests deliberately hit the deployed metadata.
- LWC: Jest suite in `lwc/flowFaultPanel/__tests__`. Requires `npm install` first (devDependencies only, all MIT/Apache-2.0). **Installing tooling on this laptop needs CIO approval per Handbook §4.22.3; nothing has been installed.**
- Rules: `node scripts/generate-rules.js --check` validates the JSON and confirms generated files are current. Runs without dependencies.

## Constraints and caveats

- **Nothing has been deployed.** The Flow XML, LWC flow-screen contract and Nebula API calls were written from documentation and experience, not round-tripped through an org. Expect a first-deploy fix cycle. Highest-risk items: element ordering in the Flow XML, `Roll Back Records` inside a screen subflow (should roll back the parent's uncommitted DML because it is the same transaction; verify), and the `Logger.newEntry` / `addTags` / `setRecord` signatures against the installed Nebula version.
- **Flow API name must be typed by the caller.** There is no `$Flow` variable for it. The adoption guide makes this the first checklist item.
- **`$Flow.FaultMessage` formats vary** by element type and release. Unrecognised shapes are not lost: the raw text always reaches admins in `technicalMessage`, the user sees the generic label, and the Default rule's guidance says to add a rule. Paste new shapes into `FlowFaultParserTest` and `docs/fault-message-formats.md`.
- **Retention is Nebula's.** Nebula purge jobs delete old entries. If admins need long-lived fault history or typed reporting, add a second sink that writes a custom object; the seam exists for exactly that.
- **Apex class access.** Flows call invocable Apex in system context, so users need no access to `FlowFaultHandler`. Nebula Logger's own `LoggerSettings__c` must enable logging for the running user or entries are dropped.
- **Long text in Custom Metadata.** `getAll()` truncates long text fields to 255 characters, so rules are read with SOQL (does not count against limits).

## Roadmap

1. Deploy to a scratch org, run the tests, walk the demo, fix what breaks, record verified `$Flow.FaultMessage` shapes.
2. Phase 2: LWC error handling. `reduceErrors`-style utility that normalises `error.body` / `FieldErrors` / `pageErrors` and posts to the same service via an `@AuraEnabled` method; `flowFaultPanel` already renders the shape.
3. Phase 3: Apex. `ErrorHandler.handle(Exception, context)` wrapping the same service and sink for services, triggers, batch and queueable jobs.
4. Optional: `FlowFaultLog__c` sink with list views and retention for admin-facing fault history; admin notification flow on high-severity categories.
