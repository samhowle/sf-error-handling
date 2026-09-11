/**
 * FlowFaultSettings
 * Typed view of the FlowFaultSetting__mdt record named Default, with compiled fallbacks so the handler keeps
 * working when the record is missing. Tests inject an instance through instanceOverride.
 *
 * DRAFT: AI-generated. Must be human-reviewed and verified before use in any client org (Steampunk AI policy).
 * Do not run against orgs containing CUI without approval.
 */
public with sharing class FlowFaultSettings {
	public static final String DEFAULT_RECORD_NAME = 'Default';
	public static final String DEFAULT_SINK_CLASS = 'FlowFaultNebulaLogSink';

	public String logSinkClass = DEFAULT_SINK_CLASS;
	public Boolean loggingEnabled = true;
	public Boolean includeTechnicalDetailsForUsers = false;
	public String referenceIdPrefix = 'FLT';
	public String adminContactText = 'your Salesforce administrator';
	public Integer maxTechnicalMessageLength = 4000;
	public Boolean loadedFromMetadata = false;

	@TestVisible private static FlowFaultSettings instanceOverride;
	private static FlowFaultSettings cached;

	public static FlowFaultSettings load() {
		if (instanceOverride != null) { return instanceOverride; }
		if (cached == null) { cached = fromMetadata(FlowFaultSetting__mdt.getInstance(DEFAULT_RECORD_NAME)); }
		return cached;
	}

	@TestVisible
	private static FlowFaultSettings fromMetadata(FlowFaultSetting__mdt record) {
		FlowFaultSettings s = new FlowFaultSettings();
		if (record == null) { return s; }
		s.loadedFromMetadata = true;
		if (String.isNotBlank(record.LogSinkClass__c)) { s.logSinkClass = record.LogSinkClass__c.trim(); }
		if (record.LoggingEnabled__c != null) { s.loggingEnabled = record.LoggingEnabled__c; }
		if (record.IncludeTechnicalDetailsForUsers__c != null) { s.includeTechnicalDetailsForUsers = record.IncludeTechnicalDetailsForUsers__c; }
		if (String.isNotBlank(record.ReferenceIdPrefix__c)) { s.referenceIdPrefix = record.ReferenceIdPrefix__c.trim(); }
		if (String.isNotBlank(record.AdminContactText__c)) { s.adminContactText = record.AdminContactText__c.trim(); }
		if (record.MaxTechnicalMessageLength__c != null && record.MaxTechnicalMessageLength__c > 0) { s.maxTechnicalMessageLength = record.MaxTechnicalMessageLength__c.intValue(); }
		return s;
	}
}
