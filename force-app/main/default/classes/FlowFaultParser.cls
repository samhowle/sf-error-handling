/**
 * FlowFaultParser
 * Turns the text of {!$Flow.FaultMessage} into structured parts: the DML operation, the status code
 * (outer and, for trigger or Apex DML failures, inner), the Apex exception type, the originating trigger
 * or class, the human-readable detail (for a validation rule this is the rule's own error text), the field
 * list Salesforce appends in brackets, and any trailing stack trace.
 *
 * Pure function: no SOQL, no DML, never throws. Anything it cannot recognise comes back with rawMessage and
 * cleanMessage populated and detail equal to the cleaned text, so callers always have something to show.
 * Known message shapes are catalogued in docs/fault-message-formats.md; add a test there when a new one appears.
 *
 * DRAFT: AI-generated. Must be human-reviewed and verified before use in any client org (Steampunk AI policy).
 * Do not run against orgs containing CUI without approval.
 */
public with sharing class FlowFaultParser {
	public static final String ENVELOPE_DML = 'Dml';
	public static final String ENVELOPE_APEX = 'Apex';
	public static final String ENVELOPE_NONE = 'None';
	public static final String TRIGGER_STATUS_CODE = 'CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY';

	// Salesforce appends this sentence to every DML fault message, with a period it adds itself.
	private static final Pattern BOILERPLATE = Pattern.compile('(?is)\\.?\\s*You can look up ExceptionCode values in the Apex Developer Guide\\.?');
	// "This error occurred when the flow tried to create records: STATUS: message"
	private static final Pattern DML_ENVELOPE = Pattern.compile('(?is)^This error occurred when the flow tried to ([a-z ]+?) records?\\s*:\\s*(.*)$');
	// "The flow tried to update these records: 001... This error occurred: STATUS: message"
	private static final Pattern DML_ENVELOPE_ALT = Pattern.compile('(?is)^The flow tried to ([a-z ]+?) (?:these|this) records?\\s*:\\s*(.*?)\\.?\\s*This error occurred:\\s*(.*)$');
	// "An Apex error occurred: Type.Of.Exception: message"
	private static final Pattern APEX_ENVELOPE = Pattern.compile('(?is)^An Apex error occurred:\\s*(.*)$');
	private static final Pattern STATUS_CODE = Pattern.compile('(?s)^([A-Z][A-Z0-9_]{2,}):\\s*(.*)$');
	// "AccountTrigger: execution of BeforeUpdate caused by: System.DmlException: ..."
	private static final Pattern TRIGGER_CAUSE = Pattern.compile('(?s)^([\\w.]+):\\s*execution of (\\w+)\\s+caused by:\\s*(.*)$');
	// "Insert failed. First exception on row 0; first error: STATUS, message: text: [Field__c]"
	private static final Pattern FIRST_ERROR = Pattern.compile('(?s)first error:\\s*([A-Z][A-Z0-9_]{2,}),\\s*message:\\s*(.*)$');
	// Apex exception class names always end in "Exception", which keeps validation text like "Error: ..." from being misread.
	private static final Pattern EXCEPTION_PREFIX = Pattern.compile('(?s)^([A-Za-z_][\\w.]*Exception):\\s*(.*)$');
	private static final Pattern STACK_START = Pattern.compile('(?:^|\\s|\\()(?:Class\\.|Trigger\\.|AnonymousBlock:|External entry point)');
	// Trailing "...: [Field1__c, Field2__c]" or ": []" that DML errors carry.
	private static final Pattern FIELD_LIST = Pattern.compile('(?s)^(.*?)\\s*:?\\s*\\[([^\\]]*)\\]\\s*\\.?\\s*$');

	public class ParsedFault {
		public String rawMessage;          // exactly what the flow passed in
		public String cleanMessage;        // raw text minus Salesforce boilerplate, trimmed
		public String envelope;            // Dml | Apex | None
		public String operation;           // Create | Update | Delete | Lookup | Approval | Email | Apex | Unknown
		public String recordIds;           // record IDs quoted by the alternate DML envelope, when present
		public String statusCode;          // outer DML status code, e.g. FIELD_CUSTOM_VALIDATION_EXCEPTION
		public String innerStatusCode;     // status code nested inside a trigger or Apex DmlException
		public String exceptionType;       // Apex exception type, e.g. System.NullPointerException
		public String sourceName;          // trigger or class that raised it, when present
		public String triggerEvent;        // BeforeInsert, AfterUpdate, ...
		public String detail;              // human-readable message body
		public String stackTrace;          // trailing Class./Trigger. lines, when present
		public List<String> fieldNames = new List<String>();

		/** Outer status code when present, otherwise the nested one. */
		public String effectiveStatusCode() { return statusCode != null ? statusCode : innerStatusCode; }
		public Boolean isTriggerFault() { return statusCode == TRIGGER_STATUS_CODE; }
	}

	public static ParsedFault parse(String faultMessage) {
		ParsedFault p = new ParsedFault();
		p.rawMessage = faultMessage;
		p.envelope = ENVELOPE_NONE;
		p.operation = 'Unknown';
		if (String.isBlank(faultMessage)) { p.cleanMessage = ''; p.detail = ''; return p; }

		String text = BOILERPLATE.matcher(faultMessage.trim()).replaceAll('').trim();
		p.cleanMessage = text;
		String body = text;

		Matcher m = DML_ENVELOPE.matcher(text);
		Matcher alt = DML_ENVELOPE_ALT.matcher(text);
		Matcher apex = APEX_ENVELOPE.matcher(text);
		if (m.matches()) {
			p.envelope = ENVELOPE_DML; p.operation = mapOperation(m.group(1)); body = m.group(2).trim();
		} else if (alt.matches()) {
			p.envelope = ENVELOPE_DML; p.operation = mapOperation(alt.group(1)); p.recordIds = blankToNull(alt.group(2)); body = alt.group(3).trim();
		} else if (apex.matches()) {
			p.envelope = ENVELOPE_APEX; p.operation = 'Apex'; body = apex.group(1).trim();
		}

		m = STATUS_CODE.matcher(body);
		if (m.matches()) { p.statusCode = m.group(1); body = m.group(2).trim(); }

		if (p.isTriggerFault()) {
			m = TRIGGER_CAUSE.matcher(body);
			if (m.matches()) { p.sourceName = m.group(1); p.triggerEvent = m.group(2); body = m.group(3).trim(); }
		}

		m = EXCEPTION_PREFIX.matcher(body);
		if (m.matches()) { p.exceptionType = m.group(1); body = m.group(2).trim(); }

		m = FIRST_ERROR.matcher(body);
		if (m.find()) { p.innerStatusCode = m.group(1); body = m.group(2).trim(); }

		if (p.exceptionType != null || p.sourceName != null) {
			m = STACK_START.matcher(body);
			if (m.find()) { p.stackTrace = blankToNull(body.substring(m.start()).trim()); body = body.substring(0, m.start()).trim(); }
		}

		m = FIELD_LIST.matcher(body);
		if (m.matches()) {
			body = m.group(1).trim();
			for (String f : m.group(2).split(',')) { if (String.isNotBlank(f)) { p.fieldNames.add(f.trim()); } }
		}

		p.detail = body.replaceAll('\\s+', ' ').trim();
		return p;
	}

	private static String mapOperation(String phrase) {
		String s = phrase == null ? '' : phrase.toLowerCase().trim();
		if (s.startsWith('create')) { return 'Create'; }
		if (s.startsWith('update')) { return 'Update'; }
		if (s.startsWith('delete')) { return 'Delete'; }
		if (s.contains('look up') || s.startsWith('get') || s.startsWith('find')) { return 'Lookup'; }
		if (s.contains('approval')) { return 'Approval'; }
		if (s.contains('email')) { return 'Email'; }
		return String.isBlank(s) ? 'Unknown' : s.substring(0, 1).toUpperCase() + s.substring(1);
	}

	private static String blankToNull(String s) { return String.isBlank(s) ? null : s; }
}
