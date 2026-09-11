# Flow Fault Rules

Generated from `config/fault-rules.json` by `scripts/generate-rules.js`. Do not edit by hand.

Rules are evaluated in ascending priority; the first active match wins. `StatusCode` rules are tested against the outer DML status code first, then against the inner one extracted from a nested trigger or Apex DML exception.

| Priority | Rule | Match | Pattern | Category | Severity | User-correctable | Retryable | User message |
|---|---|---|---|---|---|---|---|---|
| 5 | LimitExceeded | Regex | `(?i)Too many (SOQL queries\|DML statements\|DML rows\|query rows\|callouts\|future calls\|queueable jobs)\|Apex CPU time limit\|Apex heap size\|LIMIT_EXCEEDED\|System\.LimitException\|SINGLE_EMAIL_LIMIT_EXCEEDED\|STORAGE_LIMIT_EXCEEDED` | Limit | ERROR |  |  | The system could not finish processing this request because it involved too much data. Your changes were not saved. |
| 6 | MixedDml | Contains | `MIXED_DML_OPERATION` | Configuration | ERROR |  |  | *(parsed detail, or the default label)* |
| 7 | CalloutFailure | Regex | `(?i)System\.CalloutException\|Read timed out\|Unable to tunnel\|Unauthorized endpoint\|IO Exception` | Apex | WARN |  | yes | A connected system did not respond. Your changes were not saved. Please try again in a few minutes. |
| 10 | ValidationRule | StatusCode | `FIELD_CUSTOM_VALIDATION_EXCEPTION` | Validation | WARN | yes |  | {detail} |
| 20 | RequiredFieldMissing | StatusCode | `REQUIRED_FIELD_MISSING` | RequiredField | WARN | yes |  | Required information is missing: {fields}. |
| 30 | DuplicateValue | StatusCode | `DUPLICATE_VALUE` | Duplicate | WARN | yes |  | {detail} |
| 31 | DuplicatesDetected | StatusCode | `DUPLICATES_DETECTED` | Duplicate | WARN | yes |  | A matching record already exists. {detail} |
| 40 | LookupFilter | StatusCode | `FIELD_FILTER_VALIDATION_EXCEPTION` | LookupFilter | WARN | yes |  | {detail} |
| 41 | StringTooLong | StatusCode | `STRING_TOO_LONG` | Validation | WARN | yes |  | {detail} |
| 42 | InvalidEmail | StatusCode | `INVALID_EMAIL_ADDRESS` | Validation | WARN | yes |  | {detail} |
| 43 | RestrictedPicklist | StatusCode | `INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST` | Configuration | ERROR |  |  | One of the values could not be saved because it is not an allowed option. |
| 45 | FieldIntegrity | StatusCode | `FIELD_INTEGRITY_EXCEPTION` | DataIntegrity | WARN | yes |  | {detail} |
| 46 | InvalidTypeOnField | StatusCode | `INVALID_TYPE_ON_FIELD_IN_RECORD` | Configuration | ERROR |  |  | *(parsed detail, or the default label)* |
| 50 | RowLock | StatusCode | `UNABLE_TO_LOCK_ROW` | RecordLock | WARN |  | yes | Another process is updating this record right now. |
| 60 | InsufficientAccess | StatusCode | `INSUFFICIENT_ACCESS_OR_READONLY` | Permission | ERROR |  |  | You do not have permission to make this change. |
| 61 | InsufficientAccessCrossReference | StatusCode | `INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY` | Permission | ERROR |  |  | You do not have permission to link to one of the related records. |
| 62 | InvalidCrossReference | StatusCode | `INVALID_CROSS_REFERENCE_KEY` | DataIntegrity | ERROR |  |  | A related record could not be found. |
| 63 | EntityDeleted | StatusCode | `ENTITY_IS_DELETED` | NotFound | WARN |  |  | The record no longer exists. |
| 64 | MalformedId | StatusCode | `MALFORMED_ID` | Configuration | ERROR |  |  | *(parsed detail, or the default label)* |
| 65 | InvalidField | StatusCode | `INVALID_FIELD` | Configuration | ERROR |  |  | *(parsed detail, or the default label)* |
| 66 | NoApplicableApprovalProcess | StatusCode | `NO_APPLICABLE_PROCESS` | Configuration | ERROR |  |  | This record could not be submitted for approval. |
| 67 | AlreadyInApproval | StatusCode | `ALREADY_IN_PROCESS` | Validation | WARN |  |  | This record is already waiting for approval. |
| 70 | TriggerError | StatusCode | `CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY` | Trigger | ERROR |  |  | An automated process on this record failed and your changes were not saved. |
| 80 | NullPointer | ExceptionType | `System.NullPointerException` | Apex | ERROR |  |  | *(parsed detail, or the default label)* |
| 81 | QueryException | ExceptionType | `System.QueryException` | Apex | ERROR |  |  | *(parsed detail, or the default label)* |
| 89 | ApexGeneric | Contains | `An Apex error occurred` | Apex | ERROR |  |  | *(parsed detail, or the default label)* |
| 9999 | Default | Default | — | Unknown | ERROR |  |  | *(parsed detail, or the default label)* |
