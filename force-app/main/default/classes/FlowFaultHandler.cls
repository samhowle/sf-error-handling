/**
 * FlowFaultHandler
 * Invocable action "Handle Flow Fault". Thin adapter: maps Flow inputs to FlowFaultService.Input, delegates,
 * and maps FlowFaultService.Fault back to Flow-friendly outputs. Keep logic in the service so LWC and Apex
 * callers can share it later.
 *
 * Wire it from a fault connector: Fault Message = {!$Flow.FaultMessage}, Flow API Name = the calling flow's
 * API name (there is no system variable for it), Element API Name = the element whose fault path you are on.
 * Prefer calling the FlowFaultHandlerCore or FlowFaultHandlerScreen subflows, which wrap this action and add
 * a fallback if the action itself faults.
 *
 * DRAFT: AI-generated. Must be human-reviewed and verified before use in any client org (Steampunk AI policy).
 * Do not run against orgs containing CUI without approval.
 */
public with sharing class FlowFaultHandler {
	@InvocableMethod(
		label='Handle Flow Fault'
		description='Parses $Flow.FaultMessage into a user-safe message, admin guidance, next steps and a reference ID, classifies it with Flow Fault Rules, and logs it through the configured sink. Never throws.'
		category='Error Handling'
		iconName='slds:utility:error'
	)
	public static List<Result> handle(List<Request> requests) {
		List<FlowFaultService.Input> inputs = new List<FlowFaultService.Input>();
		for (Request r : requests) { inputs.add(toInput(r)); }
		List<Result> results = new List<Result>();
		for (FlowFaultService.Fault f : FlowFaultService.handle(inputs)) { results.add(toResult(f)); }
		return results;
	}

	private static FlowFaultService.Input toInput(Request r) {
		FlowFaultService.Input i = new FlowFaultService.Input();
		i.faultMessage = r.faultMessage;
		i.flowApiName = r.flowApiName;
		i.elementApiName = r.elementApiName;
		i.recordId = r.recordId;
		i.interviewGuid = r.interviewGuid;
		i.contextDetails = r.contextDetails;
		i.customUserMessage = r.customUserMessage;
		i.severity = r.severity;
		i.skipLogging = r.skipLogging == true;
		return i;
	}

	private static Result toResult(FlowFaultService.Fault f) {
		Result o = new Result();
		o.referenceId = f.referenceId;
		o.category = f.category;
		o.ruleName = f.ruleName;
		o.statusCode = f.statusCode;
		o.innerStatusCode = f.innerStatusCode;
		o.exceptionType = f.exceptionType;
		o.operation = f.operation;
		o.sourceName = f.sourceName;
		o.severity = f.severity;
		o.fieldNames = f.fieldNames.isEmpty() ? null : String.join(f.fieldNames, ', ');
		o.isUserCorrectable = f.isUserCorrectable;
		o.isRetryable = f.isRetryable;
		o.userMessage = f.userMessage;
		o.adminGuidance = f.adminGuidance;
		o.nextSteps = f.nextSteps;
		o.technicalMessage = f.technicalMessage;
		o.displayMessage = f.displayMessage;
		o.isLogged = f.isLogged;
		o.logDestination = f.logDestination;
		o.loggingError = f.loggingError;
		o.warnings = f.warnings.isEmpty() ? null : String.join(f.warnings, ' | ');
		return o;
	}

	public class Request {
		@InvocableVariable(label='Fault Message' description='Pass {!$Flow.FaultMessage}. Only populated on a fault path.' required=true)
		public String faultMessage;
		@InvocableVariable(label='Flow API Name' description='API name of the calling flow. Flow has no system variable for this; type it as a text constant.' required=true)
		public String flowApiName;
		@InvocableVariable(label='Element API Name' description='API name of the element whose fault connector led here, e.g. Create_Case.')
		public String elementApiName;
		@InvocableVariable(label='Record ID' description='ID of the record being processed, if known. Logged and attached to the log entry.')
		public String recordId;
		@InvocableVariable(label='Interview GUID' description='Pass {!$Flow.InterviewGuid} to correlate with flow debug logs. The subflows pass this automatically.')
		public String interviewGuid;
		@InvocableVariable(label='Context Details' description='Free text for troubleshooting, e.g. a formula concatenating key variable values. Logged, never shown to users.')
		public String contextDetails;
		@InvocableVariable(label='Custom User Message' description='Overrides the rule-derived user message. Supports the same {placeholders} as rule templates.')
		public String customUserMessage;
		@InvocableVariable(label='Severity' description='ERROR, WARN or INFO. Overrides the matched rule\'s severity for logging.')
		public String severity;
		@InvocableVariable(label='Skip Logging' description='True to classify only and not write to the log sink.')
		public Boolean skipLogging;
	}

	public class Result {
		@InvocableVariable(label='Reference ID' description='Short code shown to the user and written to the log, e.g. FLT-3F9A2C1B.')
		public String referenceId;
		@InvocableVariable(label='Category' description='Validation, RequiredField, Duplicate, Permission, RecordLock, LookupFilter, DataIntegrity, NotFound, Trigger, Apex, Limit, Configuration or Unknown.')
		public String category;
		@InvocableVariable(label='Rule Name' description='DeveloperName of the Flow Fault Rule that matched.')
		public String ruleName;
		@InvocableVariable(label='Status Code' description='Outer DML status code, e.g. FIELD_CUSTOM_VALIDATION_EXCEPTION.')
		public String statusCode;
		@InvocableVariable(label='Inner Status Code' description='Status code nested inside a trigger or Apex DML failure, if any.')
		public String innerStatusCode;
		@InvocableVariable(label='Exception Type' description='Apex exception type when an Apex action or trigger failed.')
		public String exceptionType;
		@InvocableVariable(label='Operation' description='Create, Update, Delete, Lookup, Approval, Email, Apex or Unknown.')
		public String operation;
		@InvocableVariable(label='Source Name' description='Trigger or Apex class that raised the error, when present.')
		public String sourceName;
		@InvocableVariable(label='Severity' description='Severity used for logging.')
		public String severity;
		@InvocableVariable(label='Field Names' description='Comma-separated field API names Salesforce attached to the error.')
		public String fieldNames;
		@InvocableVariable(label='Is User Correctable' description='True when the user can fix the problem by changing input (validation, required field, duplicate).')
		public Boolean isUserCorrectable;
		@InvocableVariable(label='Is Retryable' description='True when retrying the same operation may succeed (row lock, callout timeout).')
		public Boolean isRetryable;
		@InvocableVariable(label='User Message' description='Plain-text message safe to show the user. For validation rules this is the rule\'s own text.')
		public String userMessage;
		@InvocableVariable(label='Admin Guidance' description='What an admin should check. Logged; show to users only if appropriate.')
		public String adminGuidance;
		@InvocableVariable(label='Next Steps' description='Plain-text instruction for the user derived from correctable/retryable flags.')
		public String nextSteps;
		@InvocableVariable(label='Technical Message' description='Structured technical text including the raw fault. For admins and the technical-details expander.')
		public String technicalMessage;
		@InvocableVariable(label='Display Message' description='Ready-to-use rich text (heading, message, next steps, reference ID) for a Display Text component.')
		public String displayMessage;
		@InvocableVariable(label='Is Logged' description='True when a persistent sink accepted the fault. False for debug-log fallback, disabled logging, or sink failure.')
		public Boolean isLogged;
		@InvocableVariable(label='Log Destination' description='Sink name that handled the fault, e.g. NebulaLogger, DebugLog, Disabled, Skipped.')
		public String logDestination;
		@InvocableVariable(label='Logging Error' description='Why logging did not persist, when Is Logged is false.')
		public String loggingError;
		@InvocableVariable(label='Warnings' description='Pipe-separated handler warnings (missing flow name, skipped rule, sink fallback).')
		public String warnings;
	}
}
