/**
 * FlowFaultRuleProviderTest
 * DRAFT: AI-generated. Must be human-reviewed and verified before use in any client org (Steampunk AI policy).
 */
@IsTest
private class FlowFaultRuleProviderTest {
	@IsTest
	static void mapsMetadataRecord() {
		FlowFaultRule__mdt record = new FlowFaultRule__mdt(
			DeveloperName = 'RowLock', MasterLabel = 'Record locked', MatchType__c = 'StatusCode', Pattern__c = 'UNABLE_TO_LOCK_ROW',
			Priority__c = 50, Category__c = 'RecordLock', UserMessageTemplate__c = 'Busy.', AdminGuidance__c = 'Contention.',
			Severity__c = 'WARN', IsUserCorrectable__c = false, IsRetryable__c = true, IsActive__c = true
		);
		FlowFaultRuleProvider.Rule r = FlowFaultRuleProvider.fromMetadata(record);
		Assert.areEqual('RowLock', r.developerName, 'name');
		Assert.areEqual('Record locked', r.label, 'label');
		Assert.areEqual('StatusCode', r.matchType, 'match type');
		Assert.areEqual('UNABLE_TO_LOCK_ROW', r.pattern, 'pattern');
		Assert.areEqual(50, r.priority.intValue(), 'priority');
		Assert.areEqual('RecordLock', r.category, 'category');
		Assert.areEqual('Busy.', r.userMessageTemplate, 'template');
		Assert.areEqual('Contention.', r.adminGuidance, 'guidance');
		Assert.areEqual('WARN', r.severity, 'severity');
		Assert.isFalse(r.isUserCorrectable, 'correctable');
		Assert.isTrue(r.isRetryable, 'retryable');
		Assert.isFalse(r.isDefault(), 'not default');
	}

	@IsTest
	static void nullMetadataFieldsFallBackToDefaults() {
		FlowFaultRuleProvider.Rule r = FlowFaultRuleProvider.fromMetadata(new FlowFaultRule__mdt(DeveloperName = 'Bare', MasterLabel = 'Bare', MatchType__c = 'Contains', Pattern__c = 'x'));
		Assert.areEqual(9999, r.priority.intValue(), 'default priority');
		Assert.areEqual(FlowFaultRuleProvider.CATEGORY_UNKNOWN, r.category, 'default category');
		Assert.areEqual('ERROR', r.severity, 'default severity');
		Assert.isFalse(r.isUserCorrectable, 'default correctable');
		Assert.isFalse(r.isRetryable, 'default retryable');
	}

	@IsTest
	static void overrideIsSortedAndGetsBuiltInDefaultAppended() {
		FlowFaultRuleProvider.Rule late = new FlowFaultRuleProvider.Rule();
		late.developerName = 'Late'; late.matchType = 'Contains'; late.pattern = 'z'; late.priority = 200;
		FlowFaultRuleProvider.Rule early = new FlowFaultRuleProvider.Rule();
		early.developerName = 'Early'; early.matchType = 'Contains'; early.pattern = 'a'; early.priority = 10;
		FlowFaultRuleProvider.rulesOverride = new List<FlowFaultRuleProvider.Rule>{ late, early };
		List<FlowFaultRuleProvider.Rule> rules = FlowFaultRuleProvider.getActiveRules();
		Assert.areEqual(3, rules.size(), 'two plus built-in default');
		Assert.areEqual('Early', rules[0].developerName, 'sorted ascending');
		Assert.areEqual('Late', rules[1].developerName, 'sorted ascending');
		Assert.isTrue(rules[2].isDefault(), 'default last');
		Assert.areEqual('BuiltInDefault', rules[2].developerName, 'built-in default');
	}

	@IsTest
	static void overrideWithDefaultDoesNotDuplicateIt() {
		FlowFaultRuleProvider.Rule d = new FlowFaultRuleProvider.Rule();
		d.developerName = 'Default'; d.matchType = FlowFaultRuleProvider.MATCH_DEFAULT; d.priority = 9999;
		FlowFaultRuleProvider.rulesOverride = new List<FlowFaultRuleProvider.Rule>{ d };
		List<FlowFaultRuleProvider.Rule> rules = FlowFaultRuleProvider.getActiveRules();
		Assert.areEqual(1, rules.size(), 'no built-in appended');
		Assert.areEqual('Default', rules[0].developerName, 'the supplied default');
	}

	@IsTest
	static void deployedRulesAreSortedAndEndWithDefault() {
		List<FlowFaultRuleProvider.Rule> rules = FlowFaultRuleProvider.getActiveRules();
		Assert.isTrue(rules.size() >= 2, 'rule records deployed');
		Decimal previous = -1;
		Set<String> names = new Set<String>();
		for (FlowFaultRuleProvider.Rule r : rules) {
			Assert.isTrue(r.priority >= previous, 'ascending priority at ' + r.developerName);
			previous = r.priority;
			names.add(r.developerName);
		}
		Assert.isTrue(rules[rules.size() - 1].isDefault(), 'last is default');
		Assert.isTrue(names.contains('ValidationRule'), 'ValidationRule deployed');
		Assert.isTrue(names.contains('Default'), 'Default record deployed, built-in not needed');
		Assert.isTrue(rules[0].adminGuidance == null || rules[0].adminGuidance.length() <= 32768, 'long text readable via SOQL');
		Assert.areEqual(rules, FlowFaultRuleProvider.getActiveRules(), 'cached');
	}
}
