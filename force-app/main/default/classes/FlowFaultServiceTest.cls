/**
 * FlowFaultServiceTest
 * Classification, rendering and logging policy. Rules, settings and the sink are injected so the tests do
 * not depend on org metadata, except for one test that exercises the deployed rule records.
 * DRAFT: AI-generated. Must be human-reviewed and verified before use in any client org (Steampunk AI policy).
 */
@IsTest
private class FlowFaultServiceTest {
	private static final String SUFFIX = ' You can look up ExceptionCode values in the Apex Developer Guide.';
	private static final String VALIDATION = 'This error occurred when the flow tried to create records: FIELD_CUSTOM_VALIDATION_EXCEPTION: Amount must be positive.' + SUFFIX;
	private static final String REQUIRED = 'This error occurred when the flow tried to create records: REQUIRED_FIELD_MISSING: Required fields are missing: [LastName].' + SUFFIX;
	private static final String TRIGGER_NESTED = 'This error occurred when the flow tried to update records: CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY: AccountTrigger: execution of BeforeUpdate caused by: '
		+ 'System.DmlException: Update failed. First exception on row 0; first error: FIELD_CUSTOM_VALIDATION_EXCEPTION, message: Contact must have an email: [Email] Class.X.y: line 1, column 1.' + SUFFIX;
	private static final String APEX_NPE = 'An Apex error occurred: System.NullPointerException: Attempt to de-reference a null object';
	private static final String APEX_DML = 'An Apex error occurred: System.DmlException: Insert failed. First exception on row 0; first error: FIELD_CUSTOM_VALIDATION_EXCEPTION, message: Amount must be positive: []';

	private static FlowFaultTestSinks.CapturingSink sink;

	private static void arrange() {
		sink = FlowFaultTestSinks.install();
		FlowFaultSettings.instanceOverride.adminContactText = 'the help desk';
		FlowFaultRuleProvider.rulesOverride = rules(true);
	}

	private static List<FlowFaultRuleProvider.Rule> rules(Boolean includeTrigger) {
		List<FlowFaultRuleProvider.Rule> out = new List<FlowFaultRuleProvider.Rule>();
		out.add(rule('LimitExceeded', 5, 'Regex', '(?i)Too many SOQL queries|System\\.LimitException', 'Limit', 'Too much data.', 'Limit hit: {detail}', false, false, 'ERROR'));
		out.add(rule('ValidationRule', 10, 'StatusCode', 'FIELD_CUSTOM_VALIDATION_EXCEPTION', 'Validation', '{detail}', 'Check validation rules. Fields: {fields}', true, false, 'WARN'));
		out.add(rule('RequiredFieldMissing', 20, 'StatusCode', 'REQUIRED_FIELD_MISSING', 'RequiredField', 'Required information is missing: {fields}.', 'Map required fields', true, false, 'WARN'));
		out.add(rule('RowLock', 50, 'StatusCode', 'UNABLE_TO_LOCK_ROW', 'RecordLock', 'Record busy.', 'Contention', false, true, 'WARN'));
		if (includeTrigger) { out.add(rule('TriggerError', 70, 'StatusCode', 'CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY', 'Trigger', 'An automated process failed.', 'Trigger {source} threw {exceptionType}: {detail}', false, false, 'ERROR')); }
		out.add(rule('NullPointer', 80, 'ExceptionType', 'System.NullPointerException', 'Apex', null, 'NPE in {source}: {detail}', false, false, 'ERROR'));
		out.add(rule('ApexGeneric', 89, 'Contains', 'An Apex error occurred', 'Apex', null, 'Apex threw {exceptionType}', false, false, 'ERROR'));
		out.add(rule('Default', 9999, 'Default', null, 'Unknown', null, 'Unclassified {statusCode}', false, false, 'ERROR'));
		return out;
	}

	private static FlowFaultRuleProvider.Rule rule(String name, Decimal priority, String matchType, String pattern, String category, String template, String guidance, Boolean correctable, Boolean retryable, String severity) {
		FlowFaultRuleProvider.Rule r = new FlowFaultRuleProvider.Rule();
		r.developerName = name; r.priority = priority; r.matchType = matchType; r.pattern = pattern; r.category = category;
		r.userMessageTemplate = template; r.adminGuidance = guidance; r.isUserCorrectable = correctable; r.isRetryable = retryable; r.severity = severity;
		return r;
	}

	private static FlowFaultService.Input input(String message) {
		FlowFaultService.Input i = new FlowFaultService.Input();
		i.faultMessage = message; i.flowApiName = 'Test_Flow'; i.elementApiName = 'Create_Record';
		return i;
	}

	private static FlowFaultService.Fault one(FlowFaultService.Input i) { return FlowFaultService.handle(new List<FlowFaultService.Input>{ i })[0]; }

	@IsTest
	static void validationRuleMessageIsShownVerbatim() {
		arrange();
		FlowFaultService.Fault f = one(input(VALIDATION));
		Assert.areEqual('Validation', f.category, 'category');
		Assert.areEqual('ValidationRule', f.ruleName, 'rule');
		Assert.areEqual('Amount must be positive', f.userMessage, 'the validation rule text, nothing else');
		Assert.isTrue(f.isUserCorrectable, 'correctable');
		Assert.areEqual(Label.FlowFaultNextStepsCorrectable, f.nextSteps, 'next steps for correctable');
		Assert.areEqual('WARN', f.severity, 'rule severity');
		Assert.areEqual('Create', f.operation, 'operation');
		Assert.isTrue(f.displayMessage.contains(f.referenceId), 'display carries reference id');
		Assert.isTrue(f.displayMessage.contains('Amount must be positive'), 'display carries message');
		Assert.isFalse(f.displayMessage.contains('Fault:'), 'technical details hidden by default');
		Assert.isTrue(f.isLogged, 'logged');
		Assert.areEqual('Capture', f.logDestination, 'destination');
		Assert.isNull(f.loggingError, 'no logging error');
		Assert.areEqual(1, sink.received.size(), 'sink got the fault');
		Assert.areEqual('Test_Flow', sink.received[0].flowApiName, 'flow name on log');
	}

	@IsTest
	static void requiredFieldTemplateRendersFieldNames() {
		arrange();
		FlowFaultService.Fault f = one(input(REQUIRED));
		Assert.areEqual('RequiredField', f.category, 'category');
		Assert.areEqual('Required information is missing: LastName.', f.userMessage, 'rendered template');
		Assert.areEqual(new List<String>{ 'LastName' }, f.fieldNames, 'fields');
		Assert.isTrue(f.technicalMessage.contains('Fields: LastName'), 'technical lists fields');
	}

	@IsTest
	static void triggerFaultPrefersOuterRuleOverNestedValidation() {
		arrange();
		FlowFaultService.Fault f = one(input(TRIGGER_NESTED));
		Assert.areEqual('Trigger', f.category, 'outer status code wins when a rule exists for it');
		Assert.areEqual('An automated process failed.', f.userMessage, 'trigger template');
		Assert.areEqual('Trigger AccountTrigger threw System.DmlException: Contact must have an email', f.adminGuidance, 'guidance placeholders rendered');
		Assert.areEqual('FIELD_CUSTOM_VALIDATION_EXCEPTION', f.innerStatusCode, 'inner code surfaced');
		Assert.isFalse(f.isUserCorrectable, 'not correctable');
	}

	@IsTest
	static void triggerFaultFallsBackToInnerCodeWhenNoOuterRule() {
		arrange();
		FlowFaultRuleProvider.rulesOverride = rules(false);
		FlowFaultService.Fault f = one(input(TRIGGER_NESTED));
		Assert.areEqual('Validation', f.category, 'second pass matched the nested validation');
		Assert.areEqual('Contact must have an email', f.userMessage, 'nested validation text shown');
	}

	@IsTest
	static void apexDmlNestedValidationIsClassifiedAsValidation() {
		arrange();
		FlowFaultService.Fault f = one(input(APEX_DML));
		Assert.areEqual('Validation', f.category, 'inner code is effective when there is no outer');
		Assert.areEqual('Amount must be positive', f.userMessage, 'validation text');
		Assert.areEqual('System.DmlException', f.exceptionType, 'exception type kept');
	}

	@IsTest
	static void apexNullPointerMatchesExceptionTypeRule() {
		arrange();
		FlowFaultService.Fault f = one(input(APEX_NPE));
		Assert.areEqual('NullPointer', f.ruleName, 'exception type rule');
		Assert.areEqual('Attempt to de-reference a null object', f.userMessage, 'no template so parsed detail is shown');
		Assert.areEqual(Label.FlowFaultNextStepsContactAdmin.replace('{0}', 'the help desk'), f.nextSteps, 'contact admin text uses setting');
	}

	@IsTest
	static void exceptionTypeMatchingToleratesNamespace() {
		Assert.isTrue(FlowFaultService.typeMatches('System.NullPointerException', 'NullPointerException'), 'pattern without namespace');
		Assert.isTrue(FlowFaultService.typeMatches('NullPointerException', 'System.NullPointerException'), 'type without namespace');
		Assert.isTrue(FlowFaultService.typeMatches('ns.Svc.MyException', 'svc.myexception'), 'case-insensitive suffix');
		Assert.isFalse(FlowFaultService.typeMatches('System.QueryException', 'System.NullPointerException'), 'different types');
		Assert.isFalse(FlowFaultService.typeMatches(null, 'x'), 'null type');
	}

	@IsTest
	static void customUserMessageOverridesAndRendersPlaceholders() {
		arrange();
		FlowFaultService.Input i = input(VALIDATION);
		i.customUserMessage = 'Ref {referenceId}: {detail} ({unknownToken})';
		FlowFaultService.Fault f = one(i);
		Assert.areEqual('Ref ' + f.referenceId + ': Amount must be positive ({unknownToken})', f.userMessage, 'override rendered, unknown token left visible');
	}

	@IsTest
	static void unknownFaultUsesDefaultRuleAndLabel() {
		arrange();
		FlowFaultService.Fault f = one(input('Something odd happened'));
		Assert.areEqual('Unknown', f.category, 'category');
		Assert.areEqual('Default', f.ruleName, 'default rule');
		Assert.areEqual(Label.FlowFaultDefaultUserMessage, f.userMessage, 'generic label');
		Assert.areEqual('Unclassified n/a', f.adminGuidance, 'missing token renders n/a');
		Assert.isTrue(f.nextSteps.contains('the help desk'), 'contact admin');
		Assert.isTrue(f.technicalMessage.contains('Something odd happened'), 'raw text preserved for admins');
	}

	@IsTest
	static void severityOverrideIsValidated() {
		arrange();
		FlowFaultService.Input i = input(VALIDATION);
		i.severity = 'info';
		Assert.areEqual('INFO', one(i).severity, 'valid override normalised');
		i.severity = 'bogus';
		FlowFaultService.Fault f = one(i);
		Assert.areEqual('WARN', f.severity, 'falls back to rule severity');
		Assert.areEqual(1, f.warnings.size(), 'one warning');
		Assert.isTrue(f.warnings[0].contains('bogus'), 'warning names the bad value');
	}

	@IsTest
	static void badRegexRuleIsSkippedWithWarningNotThrown() {
		arrange();
		List<FlowFaultRuleProvider.Rule> r = rules(true);
		r.add(0, rule('Broken', 1, 'Regex', '(unclosed', 'Limit', 'x', 'y', false, false, 'ERROR'));
		FlowFaultRuleProvider.rulesOverride = r;
		FlowFaultService.Fault f = one(input(VALIDATION));
		Assert.areEqual('Validation', f.category, 'later rule still matched');
		Assert.isTrue(String.join(f.warnings, ' ').contains('Broken'), 'skipped rule reported: ' + f.warnings);
	}

	@IsTest
	static void loggingDisabledIsReported() {
		arrange();
		FlowFaultSettings.instanceOverride.loggingEnabled = false;
		FlowFaultService.Fault f = one(input(VALIDATION));
		Assert.isFalse(f.isLogged, 'not logged');
		Assert.areEqual(FlowFaultService.DESTINATION_DISABLED, f.logDestination, 'destination');
		Assert.areEqual(0, sink.writeCalls, 'sink untouched');
	}

	@IsTest
	static void skipLoggingIsPerInput() {
		arrange();
		FlowFaultService.Input skip = input(VALIDATION);
		skip.skipLogging = true;
		List<FlowFaultService.Fault> out = FlowFaultService.handle(new List<FlowFaultService.Input>{ skip, input(REQUIRED) });
		Assert.areEqual(FlowFaultService.DESTINATION_SKIPPED, out[0].logDestination, 'skipped');
		Assert.isFalse(out[0].isLogged, 'skipped not logged');
		Assert.isTrue(out[1].isLogged, 'other logged');
		Assert.areEqual(1, sink.received.size(), 'only one reached the sink');
		Assert.areEqual(1, sink.writeCalls, 'single write');
	}

	@IsTest
	static void sinkFailureIsReportedNotSwallowed() {
		arrange();
		FlowFaultSinkResolver.sinkOverride = new FlowFaultTestSinks.ThrowingSink();
		FlowFaultService.Fault f = one(input(VALIDATION));
		Assert.isFalse(f.isLogged, 'not logged');
		Assert.areEqual('Broken', f.logDestination, 'destination named');
		Assert.isTrue(f.loggingError.contains('disk full'), 'reason surfaced: ' + f.loggingError);
		Assert.isTrue(String.join(f.warnings, ' ').contains('disk full'), 'also in warnings');
		Assert.areEqual('Amount must be positive', f.userMessage, 'user message unaffected');
	}

	@IsTest
	static void unresolvableSinkFallsBackToDebugLogAndSaysSo() {
		arrange();
		FlowFaultSinkResolver.sinkOverride = null;
		FlowFaultSettings.instanceOverride.logSinkClass = 'NoSuchSinkClass';
		FlowFaultService.Fault f = one(input(VALIDATION));
		Assert.isFalse(f.isLogged, 'debug log is not persistent');
		Assert.areEqual(FlowFaultDebugLogSink.DESTINATION, f.logDestination, 'fallback destination');
		Assert.isTrue(f.loggingError.contains('NoSuchSinkClass'), 'names the missing class: ' + f.loggingError);
	}

	@IsTest
	static void technicalMessageIsTruncatedToSetting() {
		arrange();
		FlowFaultSettings.instanceOverride.maxTechnicalMessageLength = 50;
		FlowFaultService.Fault f = one(input(TRIGGER_NESTED));
		Assert.areEqual(50, f.technicalMessage.length(), 'length');
		Assert.isTrue(f.technicalMessage.endsWith('...'), 'ellipsis');
	}

	@IsTest
	static void referenceIdUsesPrefixAndHex() {
		arrange();
		FlowFaultSettings.instanceOverride.referenceIdPrefix = 'ERR';
		FlowFaultService.Fault f = one(input(VALIDATION));
		Assert.isTrue(Pattern.matches('ERR-[0-9A-F]{8}', f.referenceId), 'format: ' + f.referenceId);
		Assert.isTrue(Pattern.matches('FLT-[0-9A-F]{8}', FlowFaultService.newReferenceId(null)), 'null prefix defaults to FLT');
	}

	@IsTest
	static void displayMessageEscapesHtmlAndCanIncludeTechnicalDetails() {
		arrange();
		FlowFaultService.Fault f = one(input('This error occurred when the flow tried to create records: FIELD_CUSTOM_VALIDATION_EXCEPTION: Use <b>bold</b> & care.' + SUFFIX));
		Assert.isTrue(f.displayMessage.contains('&lt;b&gt;bold&lt;/b&gt; &amp; care'), 'escaped: ' + f.displayMessage);
		FlowFaultSettings.instanceOverride.includeTechnicalDetailsForUsers = true;
		f = one(input(VALIDATION));
		Assert.isTrue(f.displayMessage.contains('Fault:'), 'technical block included when enabled');
	}

	@IsTest
	static void missingFlowNameProducesWarningNotFailure() {
		arrange();
		FlowFaultService.Input i = input(VALIDATION);
		i.flowApiName = ' ';
		FlowFaultService.Fault f = one(i);
		Assert.isNull(f.flowApiName, 'blank normalised to null');
		Assert.isTrue(String.join(f.warnings, ' ').contains('flowApiName'), 'warned');
		Assert.isTrue(f.technicalMessage.startsWith('Flow: n/a'), 'technical shows n/a');
	}

	@IsTest
	static void emptyInputListReturnsEmpty() {
		arrange();
		Assert.areEqual(0, FlowFaultService.handle(new List<FlowFaultService.Input>()).size(), 'empty');
		Assert.areEqual(0, FlowFaultService.handle(null).size(), 'null');
		Assert.areEqual(0, sink.writeCalls, 'no write');
	}

	@IsTest
	static void deployedRuleRecordsClassifyValidationAndHaveDefault() {
		arrange();
		FlowFaultRuleProvider.rulesOverride = null;
		FlowFaultService.Fault f = one(input(VALIDATION));
		Assert.areEqual('Validation', f.category, 'deployed rules classify a validation rule');
		Assert.areEqual('Amount must be positive', f.userMessage, 'verbatim');
		FlowFaultService.Fault unknown = one(input('garbage'));
		Assert.areEqual('Default', unknown.ruleName, 'deployed Default record present (not the built-in)');
	}
}
