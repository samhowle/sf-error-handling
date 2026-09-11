/**
 * FlowFaultRuleProvider
 * Loads active FlowFaultRule__mdt records sorted by Priority and guarantees a Default (catch-all) rule is
 * always present, so classification can never come back empty even in an org where the rule records were
 * not deployed. Tests inject rules through rulesOverride.
 *
 * DRAFT: AI-generated. Must be human-reviewed and verified before use in any client org (Steampunk AI policy).
 * Do not run against orgs containing CUI without approval.
 */
public with sharing class FlowFaultRuleProvider {
	public static final String MATCH_STATUS_CODE = 'StatusCode';
	public static final String MATCH_EXCEPTION_TYPE = 'ExceptionType';
	public static final String MATCH_CONTAINS = 'Contains';
	public static final String MATCH_REGEX = 'Regex';
	public static final String MATCH_DEFAULT = 'Default';
	public static final String CATEGORY_UNKNOWN = 'Unknown';

	public class Rule implements Comparable {
		public String developerName;
		public String label;
		public String matchType;
		public String pattern;
		public Decimal priority = 9999;
		public String category = CATEGORY_UNKNOWN;
		public String userMessageTemplate;
		public String adminGuidance;
		public String severity = 'ERROR';
		public Boolean isUserCorrectable = false;
		public Boolean isRetryable = false;

		public Integer compareTo(Object other) {
			Decimal otherPriority = ((Rule) other).priority;
			return priority == otherPriority ? 0 : (priority < otherPriority ? -1 : 1);
		}
		public Boolean isDefault() { return matchType == MATCH_DEFAULT; }
	}

	@TestVisible private static List<Rule> rulesOverride;
	private static List<Rule> cached;

	/**
	 * Active rules in ascending priority order, always ending with a Default rule.
	 * Uses SOQL rather than getAll() because getAll()/getInstance() truncate Long Text Area fields to 255
	 * characters; custom metadata SOQL does not count against the query governor limit.
	 */
	public static List<Rule> getActiveRules() {
		if (rulesOverride != null) { return withDefault(rulesOverride); }
		if (cached == null) {
			List<Rule> rules = new List<Rule>();
			for (FlowFaultRule__mdt record : [
				SELECT DeveloperName, MasterLabel, MatchType__c, Pattern__c, Priority__c, Category__c, UserMessageTemplate__c,
					AdminGuidance__c, Severity__c, IsUserCorrectable__c, IsRetryable__c
				FROM FlowFaultRule__mdt
				WHERE IsActive__c = TRUE
				ORDER BY Priority__c ASC
			]) {
				rules.add(fromMetadata(record));
			}
			cached = withDefault(rules);
		}
		return cached;
	}

	/** Compiled catch-all used when no Default rule record exists. */
	public static Rule builtInDefault() {
		Rule r = new Rule();
		r.developerName = 'BuiltInDefault';
		r.label = 'Default (built in)';
		r.matchType = MATCH_DEFAULT;
		r.priority = 99999;
		r.category = CATEGORY_UNKNOWN;
		r.severity = 'ERROR';
		r.adminGuidance = 'Unclassified fault and no FlowFaultRule__mdt Default record was found. Deploy the rule records from config/fault-rules.json.';
		return r;
	}

	@TestVisible
	private static Rule fromMetadata(FlowFaultRule__mdt record) {
		Rule r = new Rule();
		r.developerName = record.DeveloperName;
		r.label = record.MasterLabel;
		r.matchType = record.MatchType__c;
		r.pattern = record.Pattern__c;
		if (record.Priority__c != null) { r.priority = record.Priority__c; }
		if (String.isNotBlank(record.Category__c)) { r.category = record.Category__c; }
		r.userMessageTemplate = record.UserMessageTemplate__c;
		r.adminGuidance = record.AdminGuidance__c;
		if (String.isNotBlank(record.Severity__c)) { r.severity = record.Severity__c; }
		r.isUserCorrectable = record.IsUserCorrectable__c == true;
		r.isRetryable = record.IsRetryable__c == true;
		return r;
	}

	private static List<Rule> withDefault(List<Rule> rules) {
		List<Rule> sorted = new List<Rule>(rules);
		Boolean hasDefault = false;
		for (Rule r : sorted) { if (r.isDefault()) { hasDefault = true; break; } }
		if (!hasDefault) { sorted.add(builtInDefault()); }
		sorted.sort();
		return sorted;
	}
}
