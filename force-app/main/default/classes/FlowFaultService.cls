/**
 * FlowFaultService
 * Service layer behind the "Handle Flow Fault" invocable action. For each fault it: parses the message
 * (FlowFaultParser), picks the first matching FlowFaultRule (FlowFaultRuleProvider), renders the user
 * message, admin guidance, next steps and a rich-text display block, mints a reference ID, and writes the
 * batch through the configured FlowFaultLogSink.
 *
 * Failure policy: this is the one class in the framework allowed to degrade rather than throw, because it
 * runs on a fault path and must always hand the flow something to show. Degradation is never silent: every
 * fallback is recorded in Fault.warnings, and logging problems come back as isLogged = false plus loggingError.
 *
 * Bulk-safe: one settings load, one rule load, one sink write per invocation regardless of batch size.
 *
 * DRAFT: AI-generated. Must be human-reviewed and verified before use in any client org (Steampunk AI policy).
 * Do not run against orgs containing CUI without approval.
 */
public with sharing class FlowFaultService {
	public static final String SEVERITY_ERROR = 'ERROR';
	public static final String SEVERITY_WARN = 'WARN';
	public static final String SEVERITY_INFO = 'INFO';
	public static final Set<String> SEVERITIES = new Set<String>{ SEVERITY_ERROR, SEVERITY_WARN, SEVERITY_INFO };
	public static final String DESTINATION_DISABLED = 'Disabled';
	public static final String DESTINATION_SKIPPED = 'Skipped';
	private static final String TOKEN_MISSING = 'n/a';

	/** Carries a fault's technical text into sinks that expect an Exception (e.g. Nebula setExceptionDetails). */
	public class FlowFaultException extends Exception {}

	public class Input {
		public String faultMessage;
		public String flowApiName;
		public String elementApiName;
		public String recordId;
		public String interviewGuid;
		public String contextDetails;
		public String customUserMessage;
		public String severity;
		public Boolean skipLogging = false;
	}

	public class Fault {
		// context echoed from the flow
		public String flowApiName;
		public String elementApiName;
		public String recordId;
		public String interviewGuid;
		public String contextDetails;
		public String runningUserId;
		public Datetime occurredAt;
		// classification
		public String referenceId;
		public String ruleName;
		public String category;
		public String statusCode;
		public String innerStatusCode;
		public String exceptionType;
		public String operation;
		public String sourceName;
		public String severity;
		public List<String> fieldNames = new List<String>();
		public Boolean isUserCorrectable = false;
		public Boolean isRetryable = false;
		// messaging
		public String userMessage;
		public String adminGuidance;
		public String nextSteps;
		public String technicalMessage;
		public String displayMessage;
		public String rawFaultMessage;
		// logging outcome
		public Boolean isLogged = false;
		public String logDestination;
		public String loggingError;
		public List<String> warnings = new List<String>();
	}

	public static List<Fault> handle(List<Input> inputs) {
		List<Fault> faults = new List<Fault>();
		if (inputs == null || inputs.isEmpty()) { return faults; }
		FlowFaultSettings settings = FlowFaultSettings.load();
		List<FlowFaultRuleProvider.Rule> rules = FlowFaultRuleProvider.getActiveRules();
		List<Fault> toLog = new List<Fault>();
		for (Input input : inputs) {
			Fault f = classify(input, rules, settings);
			faults.add(f);
			if (input.skipLogging == true) { f.logDestination = DESTINATION_SKIPPED; } else { toLog.add(f); }
		}
		log(toLog, settings);
		return faults;
	}

	/** Parse, match and render one fault. No logging, no DML. */
	@TestVisible
	private static Fault classify(Input input, List<FlowFaultRuleProvider.Rule> rules, FlowFaultSettings settings) {
		Fault f = new Fault();
		f.flowApiName = blankToNull(input.flowApiName);
		f.elementApiName = blankToNull(input.elementApiName);
		f.recordId = blankToNull(input.recordId);
		f.interviewGuid = blankToNull(input.interviewGuid);
		f.contextDetails = blankToNull(input.contextDetails);
		f.runningUserId = UserInfo.getUserId();
		f.occurredAt = Datetime.now();
		f.rawFaultMessage = input.faultMessage;
		f.referenceId = newReferenceId(settings.referenceIdPrefix);
		if (f.flowApiName == null) { f.warnings.add('flowApiName was not supplied; pass the calling flow\'s API name so logs can be traced.'); }

		FlowFaultParser.ParsedFault p = FlowFaultParser.parse(input.faultMessage);
		f.statusCode = p.statusCode;
		f.innerStatusCode = p.innerStatusCode;
		f.exceptionType = p.exceptionType;
		f.operation = p.operation;
		f.sourceName = p.sourceName;
		f.fieldNames = p.fieldNames;

		FlowFaultRuleProvider.Rule rule = match(p, rules, f);
		f.ruleName = rule.developerName;
		f.category = rule.category;
		f.isUserCorrectable = rule.isUserCorrectable == true;
		f.isRetryable = rule.isRetryable == true;
		f.severity = resolveSeverity(input.severity, rule.severity, f);

		Map<String, String> tokens = tokens(p, f, settings);
		String detail = String.isBlank(p.detail) ? p.cleanMessage : p.detail;
		if (String.isNotBlank(input.customUserMessage)) {
			f.userMessage = render(input.customUserMessage, tokens);
		} else if (String.isNotBlank(rule.userMessageTemplate)) {
			f.userMessage = render(rule.userMessageTemplate, tokens);
		} else if (rule.isDefault() || String.isBlank(detail)) {
			f.userMessage = Label.FlowFaultDefaultUserMessage;
		} else {
			f.userMessage = detail;
		}
		f.adminGuidance = String.isBlank(rule.adminGuidance) ? null : render(rule.adminGuidance, tokens);
		f.nextSteps = nextSteps(f, settings);
		f.technicalMessage = truncate(technicalMessage(p, f), settings.maxTechnicalMessageLength);
		f.displayMessage = displayHtml(f, settings);
		return f;
	}

	/**
	 * First active rule that matches, in priority order. StatusCode rules compare against the outer status
	 * code (or the inner one when there is no outer). When both exist and only the Default rule matched,
	 * a second pass compares against the inner code so a nested validation message still gets classified.
	 */
	@TestVisible
	private static FlowFaultRuleProvider.Rule match(FlowFaultParser.ParsedFault p, List<FlowFaultRuleProvider.Rule> rules, Fault f) {
		FlowFaultRuleProvider.Rule first = matchWithCode(p, p.effectiveStatusCode(), rules, f);
		if (first.isDefault() && p.statusCode != null && p.innerStatusCode != null) {
			FlowFaultRuleProvider.Rule second = matchWithCode(p, p.innerStatusCode, rules, f);
			if (!second.isDefault()) { return second; }
		}
		return first;
	}

	private static FlowFaultRuleProvider.Rule matchWithCode(FlowFaultParser.ParsedFault p, String code, List<FlowFaultRuleProvider.Rule> rules, Fault f) {
		String haystack = p.cleanMessage == null ? '' : p.cleanMessage;
		for (FlowFaultRuleProvider.Rule r : rules) {
			try {
				if (matches(r, p, code, haystack)) { return r; }
			} catch (Exception e) {
				f.warnings.add('Rule ' + r.developerName + ' skipped: ' + e.getMessage());
			}
		}
		return FlowFaultRuleProvider.builtInDefault();
	}

	private static Boolean matches(FlowFaultRuleProvider.Rule r, FlowFaultParser.ParsedFault p, String code, String haystack) {
		String pattern = r.pattern == null ? '' : r.pattern.trim();
		if (r.matchType == FlowFaultRuleProvider.MATCH_DEFAULT) { return true; }
		if (String.isBlank(pattern)) { return false; }
		if (r.matchType == FlowFaultRuleProvider.MATCH_STATUS_CODE) { return code != null && code.equalsIgnoreCase(pattern); }
		if (r.matchType == FlowFaultRuleProvider.MATCH_EXCEPTION_TYPE) { return typeMatches(p.exceptionType, pattern); }
		if (r.matchType == FlowFaultRuleProvider.MATCH_CONTAINS) { return haystack.containsIgnoreCase(pattern); }
		if (r.matchType == FlowFaultRuleProvider.MATCH_REGEX) { return Pattern.compile(pattern).matcher(haystack).find(); }
		return false;
	}

	@TestVisible
	private static Boolean typeMatches(String exceptionType, String pattern) {
		if (String.isBlank(exceptionType)) { return false; }
		String t = exceptionType.toLowerCase();
		String q = pattern.toLowerCase();
		return t == q || t.endsWith('.' + q) || q.endsWith('.' + t);
	}

	private static String resolveSeverity(String requested, String fromRule, Fault f) {
		if (String.isNotBlank(requested)) {
			String s = requested.trim().toUpperCase();
			if (SEVERITIES.contains(s)) { return s; }
			f.warnings.add('Severity "' + requested + '" is not one of ' + String.join(new List<String>(SEVERITIES), ', ') + '; used the rule\'s severity.');
		}
		return String.isNotBlank(fromRule) && SEVERITIES.contains(fromRule.toUpperCase()) ? fromRule.toUpperCase() : SEVERITY_ERROR;
	}

	private static Map<String, String> tokens(FlowFaultParser.ParsedFault p, Fault f, FlowFaultSettings settings) {
		return new Map<String, String>{
			'detail' => orDefault(String.isBlank(p.detail) ? p.cleanMessage : p.detail),
			'fields' => f.fieldNames.isEmpty() ? TOKEN_MISSING : String.join(f.fieldNames, ', '),
			'statusCode' => orDefault(p.effectiveStatusCode()),
			'operation' => orDefault(p.operation),
			'source' => orDefault(p.sourceName),
			'exceptionType' => orDefault(p.exceptionType),
			'referenceId' => orDefault(f.referenceId),
			'adminContact' => orDefault(settings.adminContactText),
			'flow' => orDefault(f.flowApiName),
			'element' => orDefault(f.elementApiName)
		};
	}

	/** Replace {token} placeholders. Unknown tokens are left as typed so template typos stay visible. */
	@TestVisible
	private static String render(String template, Map<String, String> tokens) {
		String out = template;
		for (String key : tokens.keySet()) { out = out.replace('{' + key + '}', tokens.get(key)); }
		return out.trim();
	}

	private static String nextSteps(Fault f, FlowFaultSettings settings) {
		if (f.isUserCorrectable) { return Label.FlowFaultNextStepsCorrectable; }
		if (f.isRetryable) { return Label.FlowFaultNextStepsRetryable; }
		return String.format(Label.FlowFaultNextStepsContactAdmin, new List<Object>{ settings.adminContactText });
	}

	private static String technicalMessage(FlowFaultParser.ParsedFault p, Fault f) {
		List<String> lines = new List<String>();
		lines.add('Flow: ' + orDefault(f.flowApiName) + ' | Element: ' + orDefault(f.elementApiName) + ' | Operation: ' + orDefault(p.operation)
			+ ' | Status: ' + orDefault(p.statusCode) + (p.innerStatusCode != null ? ' / ' + p.innerStatusCode : '')
			+ ' | Exception: ' + orDefault(p.exceptionType) + ' | Source: ' + orDefault(p.sourceName));
		if (f.recordId != null) { lines.add('Record: ' + f.recordId); }
		if (!f.fieldNames.isEmpty()) { lines.add('Fields: ' + String.join(f.fieldNames, ', ')); }
		lines.add('Fault: ' + (String.isBlank(p.cleanMessage) ? '(empty fault message)' : p.cleanMessage));
		if (p.stackTrace != null) { lines.add('Stack: ' + p.stackTrace); }
		if (f.contextDetails != null) { lines.add('Context: ' + f.contextDetails); }
		return String.join(lines, '\n');
	}

	/** Rich text for a Flow Display Text component. All dynamic values are HTML-escaped. */
	private static String displayHtml(Fault f, FlowFaultSettings settings) {
		String html = '<p><strong>' + esc(Label.FlowFaultHeading) + '</strong></p>'
			+ '<p>' + esc(f.userMessage) + '</p>'
			+ '<p>' + esc(f.nextSteps) + '</p>'
			+ '<p>' + esc(Label.FlowFaultReferenceLabel) + ': <strong>' + esc(f.referenceId) + '</strong></p>';
		if (settings.includeTechnicalDetailsForUsers == true) {
			html += '<p><em>' + esc(Label.FlowFaultTechnicalDetailsLabel) + '</em><br/>' + esc(f.technicalMessage).replace('\n', '<br/>') + '</p>';
		}
		return html;
	}

	private static void log(List<Fault> faults, FlowFaultSettings settings) {
		if (faults.isEmpty()) { return; }
		if (settings.loggingEnabled != true) {
			for (Fault f : faults) { f.isLogged = false; f.logDestination = DESTINATION_DISABLED; }
			return;
		}
		FlowFaultSinkResolver.Resolution res = FlowFaultSinkResolver.resolve(settings.logSinkClass);
		String destination = res.sink.getDestinationName();
		try {
			res.sink.write(faults);
			for (Fault f : faults) {
				f.logDestination = destination;
				f.isLogged = res.sink.isPersistent() == true;
				if (res.warning != null) { f.loggingError = res.warning; f.warnings.add(res.warning); }
			}
		} catch (Exception e) {
			String reason = 'Log sink ' + destination + ' failed: ' + e.getTypeName() + ': ' + e.getMessage();
			System.debug(LoggingLevel.ERROR, '[FlowFault] ' + reason);
			for (Fault f : faults) {
				f.isLogged = false;
				f.logDestination = destination;
				f.loggingError = res.warning == null ? reason : res.warning + ' ' + reason;
				f.warnings.add(reason);
			}
		}
	}

	@TestVisible
	private static String newReferenceId(String prefix) {
		String hex = EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 8).toUpperCase();
		return (String.isBlank(prefix) ? 'FLT' : prefix.trim()) + '-' + hex;
	}

	private static String truncate(String s, Integer max) {
		if (s == null || max == null || max <= 0 || s.length() <= max) { return s; }
		return s.substring(0, max - 3) + '...';
	}

	private static String esc(String s) { return s == null ? '' : s.escapeHtml4(); }
	private static String orDefault(String s) { return String.isBlank(s) ? TOKEN_MISSING : s; }
	private static String blankToNull(String s) { return String.isBlank(s) ? null : s.trim(); }
}
