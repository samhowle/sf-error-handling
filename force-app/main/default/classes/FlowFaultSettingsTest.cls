/**
 * FlowFaultSettingsTest
 * DRAFT: AI-generated. Must be human-reviewed and verified before use in any client org (Steampunk AI policy).
 */
@IsTest
private class FlowFaultSettingsTest {
	@IsTest
	static void nullRecordGivesCompiledDefaults() {
		FlowFaultSettings s = FlowFaultSettings.fromMetadata(null);
		Assert.isFalse(s.loadedFromMetadata, 'not from metadata');
		Assert.areEqual(FlowFaultSettings.DEFAULT_SINK_CLASS, s.logSinkClass, 'sink');
		Assert.isTrue(s.loggingEnabled, 'logging on');
		Assert.isFalse(s.includeTechnicalDetailsForUsers, 'no technical details');
		Assert.areEqual('FLT', s.referenceIdPrefix, 'prefix');
		Assert.areEqual(4000, s.maxTechnicalMessageLength, 'max length');
		Assert.isNotNull(s.adminContactText, 'contact');
	}

	@IsTest
	static void recordValuesAreMappedAndBlanksIgnored() {
		FlowFaultSetting__mdt record = new FlowFaultSetting__mdt(
			DeveloperName = 'Default',
			LogSinkClass__c = ' MySink ',
			LoggingEnabled__c = false,
			IncludeTechnicalDetailsForUsers__c = true,
			ReferenceIdPrefix__c = '',
			AdminContactText__c = 'the help desk',
			MaxTechnicalMessageLength__c = 0
		);
		FlowFaultSettings s = FlowFaultSettings.fromMetadata(record);
		Assert.isTrue(s.loadedFromMetadata, 'from metadata');
		Assert.areEqual('MySink', s.logSinkClass, 'trimmed');
		Assert.isFalse(s.loggingEnabled, 'logging off');
		Assert.isTrue(s.includeTechnicalDetailsForUsers, 'technical on');
		Assert.areEqual('FLT', s.referenceIdPrefix, 'blank prefix keeps default');
		Assert.areEqual('the help desk', s.adminContactText, 'contact');
		Assert.areEqual(4000, s.maxTechnicalMessageLength, 'non-positive length keeps default');
	}

	@IsTest
	static void loadReturnsOverrideWhenSet() {
		FlowFaultSettings mine = new FlowFaultSettings();
		mine.referenceIdPrefix = 'X';
		FlowFaultSettings.instanceOverride = mine;
		Assert.areEqual('X', FlowFaultSettings.load().referenceIdPrefix, 'override');
	}

	@IsTest
	static void loadReadsDeployedDefaultRecord() {
		FlowFaultSettings s = FlowFaultSettings.load();
		Assert.isNotNull(s, 'settings');
		Assert.isTrue(s.loadedFromMetadata, 'Default record deployed with the package');
		Assert.isTrue(String.isNotBlank(s.logSinkClass), 'sink configured');
		Assert.areEqual(s, FlowFaultSettings.load(), 'cached instance');
	}
}
