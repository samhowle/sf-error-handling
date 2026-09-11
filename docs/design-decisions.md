# Design decisions

Recorded so the next person (or the next phase) does not relitigate them without new information.

## 1. Nebula Logger behind a sink interface, not a custom object

Nebula Logger is already installed in the target orgs, MIT-licensed and policy-compliant, and its `LogEntryEvent__e` is published immediately, which is exactly the durability a fault log needs (see §5). Building `FlowFaultLog__c` would duplicate it. But the core must not *depend* on Nebula: an org without it, or with the managed namespace, must still compile and run. Hence `FlowFaultLogSink` resolved by class name from `FlowFaultSetting__mdt`, with `FlowFaultNebulaLogSink` in its own package directory and `FlowFaultDebugLogSink` as the non-persistent fallback.

Revisit when: admins need fault history beyond Nebula's retention, typed report fields, or a "fault console" list view. Add a second sink; do not replace the first.

## 2. Rules in Custom Metadata, generated from JSON

Classification is data, not code: which status codes are user-correctable, what wording to use, what admins should check. Custom Metadata gives admins in-org editing and packages cleanly. The JSON file plus generator gives version control, validation (unique priorities, picklist values, regex compiles), a generated docs table, and a `--check` mode for CI. The generator has no dependencies. The Apex keeps exactly one compiled rule (the built-in Default) so classification can never come back empty.

Long text fields are read with SOQL because `getAll()`/`getInstance()` truncate them to 255 characters; custom metadata SOQL does not count against limits.

## 3. Two-pass matching for nested status codes

A trigger that fails on a nested DML produces two codes: outer `CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY` and inner `FIELD_CUSTOM_VALIDATION_EXCEPTION`. Showing the nested validation text as "correctable" is usually wrong (the user cannot fix record B's rule from record A's form), so the outer code wins when a rule exists for it. When no outer rule matches, a second pass on the inner code still yields something better than Unknown. When there is no outer code at all (Apex action doing DML), the inner code is primary, so a validation rule hit inside an invocable action reads exactly like one hit by Create Records.

## 4. The handler degrades but never hides it

The fault handler runs on fault paths; if it throws, the user gets the platform's raw error page and the fault is lost. So `FlowFaultService` is the one class allowed to catch broadly. Every catch writes to `Fault.warnings`, and logging problems come back as `isLogged = false` plus `loggingError`. The LWC shows a notice when `isLogged` is false. The core subflow adds one more layer: the Apex action's own fault connector produces fallback outputs carrying both the original fault and the handler's fault. This is the direct answer to the AT4DX critique in `salesforce-sandbox-data/docs/framework-analysis` about frameworks that swallow exceptions into debug logs.

## 5. Log before roll back; rely on publish-immediately

In `FlowFaultHandlerScreen` the order is: core subflow (publishes the log event) → Roll Back Records → screen. A `LogEntryEvent__e` with publish-immediately behaviour is not part of the transaction, so the roll back, a later Custom Error, or an unhandled fault does not remove it. A custom-object sink written with plain DML would *not* survive the roll back; if one is added it must publish a platform event too.

## 6. Reference ID instead of a log record ID

Logging is asynchronous (event → trigger → `LogEntry__c`), so the flow cannot get the log record's ID. A short random code (`FLT-` + 8 hex chars from `Crypto.generateAesKey`) is shown to the user and written into the log message, so support can search it. Collisions are astronomically unlikely at this volume and would only make a search return two rows.

## 7. LWC panel, with Display Text as the escape hatch

Sam chose the LWC. It gives consistent styling, a copy button for the reference ID, a collapsible technical block, and buttons that drive navigation so the screen footer can be hidden. It also becomes the shared error surface for the LWC and Apex phases. `displayMessage` (rich text) is still produced so a flow can use a plain Display Text component where an LWC is not wanted.

## 8. Callers type the flow API name

Flow exposes `$Flow.InterviewGuid`, `$Flow.CurrentRecord` and `$Flow.FaultMessage` but not the flow's own API name, and invocable Apex cannot see its caller. The subflow therefore requires `flowApiName` as input, and the handler warns when it is missing. The adoption guide makes it a review item.

## 9. Package layout

Three package directories: `force-app` (core), `nebula-adapter` (depends on core and on Nebula), `demo` (never production). Fits the unlocked-package, GitLab CI environment assumed in the sandbox-data framework analysis, and lets the adapter be swapped for a managed-namespace variant without touching the core.

## 10. Conventions applied

- API names without separator underscores (`FlowFaultRule__mdt`, `FlowFaultHandlerCore`), per Sam's convention in the Performance Testing notes.
- Apex and JavaScript use tabs (kernel.md); Salesforce XML uses four spaces because that is what Flow Builder and retrieves emit, and mixing would make every retrieve a diff.
- Invocable → service (fflib assessment recommendation), `with sharing`, `Assert` class, `<Class>Test` naming, bulk tests at 1 / 50 / 200.
- AI-draft / human-review banner on every class; no CUI; no org aliases or real metadata in the repo.

## 11. Deferred

- Admin notification (Custom Notification or email on high-severity categories). Cheap to add as a record-triggered flow on Nebula's `LogEntry__c` filtered by tag; left out to keep phase 1 focused.
- Per-profile settings (hierarchy custom setting) for showing technical details to admins only. The LWC's expander covers most of the need.
- Automatic retry for `isRetryable` faults (row locks). Flow can loop, but a blind retry inside the same transaction rarely helps; left to the calling flow.
