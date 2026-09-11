# Adoption guide: adding fault handling to a flow

This is the checklist for retrofitting an existing flow or building a new one. It assumes the core package is deployed and active.

## 1. Which elements get a fault connector

Every element that can fail at runtime:

| Element | Typical fault | Notes |
|---|---|---|
| Create / Update / Delete Records | validation rule, required field, duplicate rule, permission, row lock, trigger error | The most common source. Always. |
| Get Records | permission on object/field, malformed ID | Rare but real; also add it. |
| Apex action | any exception in the invocable | Message shape `An Apex error occurred: Type: message`. |
| Subflow | *no fault connector available* | A faulting subflow fails the parent. The subflow must handle its own faults and return a status. |
| Submit for Approval, Send Email, Post to Chatter, Quick Action | `NO_APPLICABLE_PROCESS`, invalid email, permission | Core actions have fault connectors. |
| Roll Back Records, Custom Error, Assignment, Decision, Loop, Screen | none | Nothing to wire. |

Rule of thumb for review: **an element with a fault connector option and no fault connector is a defect.**

## 2. Screen flows

Pattern: *screen → work → fault handler screen → decision → loop back or end.*

1. Add a **Subflow** element named `Handle_Fault_<Element>` (one per faulting element is simplest; it keeps the element name a literal). Flow: `FlowFaultHandlerScreen`.
2. Inputs:
   - `faultMessage` → `{!$Flow.FaultMessage}`
   - `flowApiName` → `"My_Flow_Api_Name"` (text literal; Flow has no variable for it)
   - `elementApiName` → `"Create_Case"` (the faulting element)
   - `recordId` → the record variable's Id when you have one
   - `contextDetails` → a formula such as `"AccountId=" & {!recordId} & "; Stage=" & {!Stage}`. Logged only, never shown.
   - `rollBackRecords` → leave `true` unless the earlier DML in this transaction must stand
   - `allowRetry` → `false` when there is nowhere sensible to loop back to
   - `customUserMessage` → only when the rule-derived message is wrong for this specific element
3. Outputs: store `selectedAction` in a text variable.
4. Connect every `Handle_Fault_*` element to one **Decision**: `selectedAction = "Retry"` → the screen before the failing element (use a Go To connector in auto-layout); default → end, or a "nothing was saved" screen.
5. Set the fault handler element's inputs once, then copy-paste the element for each faulting element and change `elementApiName`.

**Transaction boundary.** A screen flow's transaction ends at each Screen, Pause or Local Action. When a fault fires, everything committed *before the last screen* is already saved and will not be rolled back. Design DML to happen after the final screen where possible, or accept partial saves and say so in `customUserMessage`.

## 3. Autolaunched flows (called from Apex, REST, scheduled paths, other flows)

Use `FlowFaultHandlerCore`. It has no screen, so after it you decide:

- **Return a status.** Add output variables `isSuccess` (Boolean) and `errorMessage` (Text) to your flow, assign `false` and `{!Handle_Fault.userMessage}` on the fault path, and let the caller decide. Apex callers get the values from `Flow.Interview.getVariableValue`.
- **Fail loudly.** If the caller has no way to act, end the fault path with a **Custom Error** element? Not available in autolaunched flows; instead let the flow finish and rely on the log plus the returned status.

Because the subflow is autolaunched it also works inside **scheduled** and **platform-event-triggered** flows. There the fault is logged with `isLogged = true` and nobody sees a screen; make sure someone watches the Nebula `FlowFault` tag or add a notification flow on Nebula's `LogEntry__c`.

## 4. Record-triggered flows

Use `FlowFaultHandlerCore` on the fault path of every DML and action element (after-save flows only; before-save flows have no DML elements). Then choose per element:

- **Log and continue** (most cases): connect the subflow to End. The triggering record saves; the related update that failed is visible to admins via the log. Use when the follow-on work is not essential to the user's save.
- **Block the save with a proper message**: connect the subflow to a **Custom Error** element with the message `{!Handle_Fault.userMessage}` and, if `isUserCorrectable` is true, mention the field. Custom Error rolls back the whole transaction; the log entry survives because Nebula publishes immediately. Use when the related update is part of the same business action (e.g. creating the mandatory child record).

Bulk safety: the subflow calls one invocable action that is bulkified across the batch (tested at 200), and the sink writes once per batch.

## 5. Naming and hygiene

- `flowApiName` is a literal; when you clone a flow, update it. Reviewers: grep the flow XML for the string and compare to the file name.
- Element API names in `elementApiName` should match the canvas exactly so the log can be matched to the element.
- Do **not** show `{!$Flow.FaultMessage}` directly to users. It leaks object names, IDs and stack traces and reads as noise. Use `userMessage` / `displayMessage` / the panel.
- Do **not** route a fault connector straight to a Screen with no handler. The fault is then invisible to admins. Every fault path goes through the handler.
- Do **not** set `skipLogging` in production flows except for deliberate expected faults you already log elsewhere.
- Keep `customUserMessage` rare. If a rule's wording is wrong, fix the rule in `config/fault-rules.json` so every flow benefits.

## 6. Review checklist (paste into the merge request)

- [ ] Every element that supports a fault connector has one.
- [ ] Every fault connector reaches `FlowFaultHandlerScreen` or `FlowFaultHandlerCore`.
- [ ] `flowApiName` matches the flow's API name.
- [ ] `elementApiName` is set on each handler element and matches the element.
- [ ] Screen flows: `selectedAction` is routed; Retry lands on a screen the user can act on.
- [ ] Record-triggered flows: each fault path is a deliberate log-and-continue or Custom Error.
- [ ] No `$Flow.FaultMessage` shown directly to users.
- [ ] Ran the flow once with a forced fault (e.g. temporary validation rule) and confirmed a `[FlowFault]` entry in Nebula Logger with the reference ID shown on screen.

## 7. Reading the log

In Nebula Logger, filter Log Entries by tag `FlowFault` or search the reference ID the user quoted. The message shows: category and status code, flow and element, reference ID, rule, severity, user message, admin guidance, interview GUID, context details, handler warnings, then the full technical block including the raw `$Flow.FaultMessage` and any stack trace. The log's scenario is the flow API name, so per-flow filtering works too.
