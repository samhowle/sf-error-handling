/**
 * FlowFaultNebulaLogSink
 * FlowFaultLogSink implementation backed by Nebula Logger (MIT, https://github.com/jongpie/NebulaLogger).
 * Writes one log entry per fault, grouped by flow so Logger.setScenario() carries the flow API name, tagged
 * with FlowFault plus the category and status code, and linked to the record when an ID was supplied.
 * Nebula publishes LogEntryEvent__e with "publish immediately" semantics, so the entry survives a later
 * Roll Back Records element, a Custom Error element, or an unhandled fault in the same transaction.
 *
 * Namespace note: this file targets the unlocked (no-namespace) Nebula Logger package, where the API class
 * is `Logger`. If the org has the managed package instead, replace `Logger` with `Nebula.Logger` and
 * `LogEntryEventBuilder` with `Nebula.LogEntryEventBuilder`. Same fork as BenchmarkHarness.cls.
 *
 * Deploy this package directory only in orgs that have Nebula Logger; the core package has no dependency on it.
 *
 * DRAFT: AI-generated. Must be human-reviewed and verified before use in any client org (Steampunk AI policy).
 * Do not run against orgs containing CUI without approval.
 */
public with sharing class FlowFaultNebulaLogSink implements FlowFaultLogSink {
	public static final String DESTINATION = 'NebulaLogger';
	public static final String TAG = 'FlowFault';
	private static final String UNKNOWN_FLOW = 'UnknownFlow';

	public String getDestinationName() { return DESTINATION; }
	public Boolean isPersistent() { return true; }

	public void write(List<FlowFaultService.Fault> faults) {
		Map<String, List<FlowFaultService.Fault>> byFlow = new Map<String, List<FlowFaultService.Fault>>();
		for (FlowFaultService.Fault f : faults) {
			String key = String.isBlank(f.flowApiName) ? UNKNOWN_FLOW : f.flowApiName;
			if (!byFlow.containsKey(key)) { byFlow.put(key, new List<FlowFaultService.Fault>()); }
			byFlow.get(key).add(f);
		}
		for (String flowApiName : byFlow.keySet()) {
			Logger.setScenario(flowApiName);
			for (FlowFaultService.Fault f : byFlow.get(flowApiName)) {
				LogEntryEventBuilder entry = Logger.newEntry(toLoggingLevel(f.severity), buildMessage(f));
				entry.addTags(tags(f));
				Id recordId = asId(f.recordId);
				if (recordId != null) { entry.setRecord(recordId); }
			}
			Logger.saveLog();
		}
	}

	@TestVisible
	private static String buildMessage(FlowFaultService.Fault f) {
		List<String> lines = new List<String>();
		lines.add('[' + TAG + '] ' + orDash(f.category) + ' (' + orDash(f.statusCode != null ? f.statusCode : f.exceptionType) + ') in ' + orDash(f.flowApiName) + ' @ ' + orDash(f.elementApiName));
		lines.add('Reference ID: ' + orDash(f.referenceId));
		lines.add('Rule: ' + orDash(f.ruleName) + ' | Severity: ' + orDash(f.severity) + ' | User correctable: ' + f.isUserCorrectable + ' | Retryable: ' + f.isRetryable);
		lines.add('User message: ' + orDash(f.userMessage));
		if (f.adminGuidance != null) { lines.add('Admin guidance: ' + f.adminGuidance); }
		if (f.interviewGuid != null) { lines.add('Interview GUID: ' + f.interviewGuid); }
		if (f.contextDetails != null) { lines.add('Context: ' + f.contextDetails); }
		if (!f.warnings.isEmpty()) { lines.add('Handler warnings: ' + String.join(f.warnings, ' | ')); }
		lines.add('---');
		lines.add(orDash(f.technicalMessage));
		return String.join(lines, '\n');
	}

	@TestVisible
	private static List<String> tags(FlowFaultService.Fault f) {
		List<String> tags = new List<String>{ TAG };
		if (String.isNotBlank(f.category)) { tags.add(TAG + ':' + f.category); }
		if (String.isNotBlank(f.statusCode)) { tags.add(f.statusCode); }
		return tags;
	}

	@TestVisible
	private static LoggingLevel toLoggingLevel(String severity) {
		String s = severity == null ? '' : severity.toUpperCase();
		if (s == FlowFaultService.SEVERITY_WARN) { return LoggingLevel.WARN; }
		if (s == FlowFaultService.SEVERITY_INFO) { return LoggingLevel.INFO; }
		return LoggingLevel.ERROR;
	}

	@TestVisible
	private static Id asId(String value) {
		if (String.isBlank(value)) { return null; }
		try { return Id.valueOf(value.trim()); } catch (Exception e) { return null; }
	}

	private static String orDash(String s) { return String.isBlank(s) ? '-' : s; }
}
