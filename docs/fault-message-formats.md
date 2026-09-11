# `$Flow.FaultMessage` formats the parser understands

Every shape below has a test in `FlowFaultParserTest`. When you meet a new one in an org, paste it here and add a test first; the parser is a pure function so this is cheap.

Salesforce appends `You can look up ExceptionCode values in the Apex Developer Guide.` to DML faults and inserts a period before it. The parser strips the sentence and at most one period, so a validation message keeps its own punctuation but never gains one.

| # | Shape (abridged) | Envelope | Status code | Inner code | Exception type | Detail | Fields |
|---|---|---|---|---|---|---|---|
| 1 | `This error occurred when the flow tried to create records: FIELD_CUSTOM_VALIDATION_EXCEPTION: Amount must be positive. You can look up…` | Dml / Create | FIELD_CUSTOM_VALIDATION_EXCEPTION | | | `Amount must be positive` | |
| 2 | `…update records: FIELD_CUSTOM_VALIDATION_EXCEPTION: Close date required: [CloseDate]. You can…` | Dml / Update | FIELD_CUSTOM_VALIDATION_EXCEPTION | | | `Close date required` | CloseDate |
| 3 | `…create records: REQUIRED_FIELD_MISSING: Required fields are missing: [LastName, AccountId]. You can…` | Dml / Create | REQUIRED_FIELD_MISSING | | | `Required fields are missing` | LastName, AccountId |
| 4 | `The flow tried to update these records: 001…AAA. This error occurred: UNABLE_TO_LOCK_ROW: unable to obtain exclusive access… You can…` | Dml / Update (alternate envelope, record IDs captured) | UNABLE_TO_LOCK_ROW | | | `unable to obtain exclusive access…` | |
| 5 | `…update records: CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY: AccountTrigger: execution of BeforeUpdate caused by: System.DmlException: Update failed. First exception on row 0; first error: FIELD_CUSTOM_VALIDATION_EXCEPTION, message: Contact must have an email: [Email] Class.AccountTriggerHandler.beforeUpdate: line 42, column 1 Trigger.AccountTrigger: line 5, column 1. You can…` | Dml / Update | CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY | FIELD_CUSTOM_VALIDATION_EXCEPTION | System.DmlException | `Contact must have an email` (source `AccountTrigger`, event `BeforeUpdate`, stack captured) | Email |
| 6 | `…CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY: CaseTrigger: execution of AfterInsert caused by: CaseService.CaseServiceException: No owner found Class.CaseService.assign: line 12…` | Dml / Update | CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY | | CaseService.CaseServiceException | `No owner found` | |
| 7 | `An Apex error occurred: System.NullPointerException: Attempt to de-reference a null object` | Apex | | | System.NullPointerException | `Attempt to de-reference a null object` | |
| 8 | `An Apex error occurred: FlowFaultDemoAction.DemoException: Boom` | Apex | | | FlowFaultDemoAction.DemoException | `Boom` | |
| 9 | `An Apex error occurred: System.DmlException: Insert failed. First exception on row 0; first error: FIELD_CUSTOM_VALIDATION_EXCEPTION, message: Amount must be positive: []` | Apex | | FIELD_CUSTOM_VALIDATION_EXCEPTION | System.DmlException | `Amount must be positive` | |
| 10 | `An Apex error occurred: System.LimitException: Too many SOQL queries: 101` | Apex | | | System.LimitException | `Too many SOQL queries: 101` | |
| 11 | anything else, e.g. `Something odd happened` | None | | | | the cleaned text | |
| 12 | null / blank | None | | | | `` | |

## How the parts are used

- **Effective status code** = outer code, else inner code. `StatusCode` rules compare against it. When both exist (shape 5) and only the Default rule matches the outer code, a second pass compares against the inner code, so a nested validation message still gets classified when the org has no trigger rule.
- **Detail** is what `{detail}` renders in templates. For validation rules it is the rule's error text verbatim (the field list is removed and exposed separately as `{fields}`).
- **Exception type** feeds `ExceptionType` rules, which match with or without namespace (`NullPointerException` matches `System.NullPointerException`).
- **Contains** and **Regex** rules run against the whole cleaned message, so they catch limits and callout failures wherever they are nested.
- **Stack trace** is removed from the detail only when an exception type or trigger was recognised, and kept in `technicalMessage`.

## Shapes still to confirm in an org

These are believed to exist but have not been captured verbatim yet. Capture, add a test, update this table.

- Get Records fault (permission denied, malformed ID): does it use the `This error occurred when the flow tried to look up records:` envelope?
- Delete Records fault: `DELETE_FAILED` with a nested reason.
- Submit for Approval: `NO_APPLICABLE_PROCESS` and `ALREADY_IN_PROCESS` envelopes.
- Send Email: `SendEmail failed. First exception on row 0; first error: INVALID_EMAIL_ADDRESS, message: …` (the `first error:` extraction should already handle it).
- Multiple records failing in one Update Records: whether Salesforce concatenates several `STATUS: message` segments.
- Duplicate Rules with Block action: `DUPLICATES_DETECTED: You're creating a duplicate record…`
