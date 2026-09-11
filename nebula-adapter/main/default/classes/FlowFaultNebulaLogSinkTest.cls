/**
 * FlowFaultNebulaLogSinkTest
 * Requires Nebula Logger in the org. Assertions on persisted LogEntry__c records are deliberately modest
 * because Nebula's schema differs across versions; message content and record linkage are stable.
 * DRAFT: AI-generated. Must be human-reviewed and verified before use in any client org (Steampunk AI policy).
 */
@IsTest
private class FlowFaultNebulaLogSinkTest {
	private static FlowFaultService.Fault fault(Integer i, String flow, String severity) {
		FlowFaultService.Fault f = new FlowFaultService.Fault();
		f.flowApiName = flow;
		f.elementApiName = 'Create_Record_' + i;
		f.referenceId = 'FLT-TEST' + String.valueOf(1000 + i).right(4);
		f.category = 'Validation';
		f.statusCode = 'FIELD_CUSTOM_VALIDATION_EXCEPTION';
		f.ruleName = 'ValidationRule';
		f.severity = severity;
		f.isUserCorrectable = true;
		f.userMessage = 'Amount must be positive';
		f.adminGuidance = 'Check validation rules.';
		f.technicalMessage = 'Flow: ' + flow + ' | Fault: FIELD_CUSTOM_VALIDATION_EXCEPTION: Amount must be positive';
		f.recordId = UserInfo.getUserId();
		f.warnings.add('sample warning');
		return f;
	}

	@IsTest
	static void describesItself() {
		FlowFaultNebulaLogSink sink = new FlowFaultNebulaLogSink();
		Assert.areEqual(FlowFaultNebulaLogSink.DESTINATION, sink.getDestinationName(), 'name');
		Assert.isTrue(sink.isPersistent(), 'persistent');
	}

	@IsTest
	static void mapsSeverityToLoggingLevel() {
		Assert.areEqual(LoggingLevel.ERROR, FlowFaultNebulaLogSink.toLoggingLevel('ERROR'), 'error');
		Assert.areEqual(LoggingLevel.WARN, FlowFaultNebulaLogSink.toLoggingLevel('warn'), 'warn, case-insensitive');
		Assert.areEqual(LoggingLevel.INFO, FlowFaultNebulaLogSink.toLoggingLevel('INFO'), 'info');
		Assert.areEqual(LoggingLevel.ERROR, FlowFaultNebulaLogSink.toLoggingLevel(null), 'null defaults to error');
	}

	@IsTest
	static void buildsMessageAndTags() {
		FlowFaultService.Fault f = fault(1, 'My_Flow', 'WARN');
		String msg = FlowFaultNebulaLogSink.buildMessage(f);
		Assert.isTrue(msg.startsWith('[FlowFault] Validation (FIELD_CUSTOM_VALIDATION_EXCEPTION) in My_Flow @ Create_Record_1'), msg);
		Assert.isTrue(msg.contains('Reference ID: FLT-TEST1001'), 'reference id');
		Assert.isTrue(msg.contains('Admin guidance: Check validation rules.'), 'guidance');
		Assert.isTrue(msg.contains('Handler warnings: sample warning'), 'warnings');
		Assert.isTrue(msg.endsWith(f.technicalMessage), 'technical last');
		Assert.areEqual(new List<String>{ 'FlowFault', 'FlowFault:Validation', 'FIELD_CUSTOM_VALIDATION_EXCEPTION' }, FlowFaultNebulaLogSink.tags(f), 'tags');
		Assert.isNull(FlowFaultNebulaLogSink.asId('not an id'), 'bad id ignored');
		Assert.areEqual(UserInfo.getUserId(), FlowFaultNebulaLogSink.asId(' ' + UserInfo.getUserId() + ' '), 'good id trimmed');
	}

	@IsTest
	static void writesOneEntryPerFaultAcrossFlows() {
		List<FlowFaultService.Fault> faults = new List<FlowFaultService.Fault>();
		for (Integer i = 0; i < 3; i++) { faults.add(fault(i, 'Flow_A', 'WARN')); }
		faults.add(fault(9, 'Flow_B', 'ERROR'));
		FlowFaultService.Fault noFlow = fault(10, null, 'INFO');
		noFlow.recordId = 'not-an-id';
		faults.add(noFlow);

		Test.startTest();
		new FlowFaultNebulaLogSink().write(faults);
		Test.stopTest();
		Test.getEventBus().deliver();

		List<LogEntry__c> entries = [SELECT Message__c, LoggingLevel__c, RecordId__c FROM LogEntry__c WHERE Message__c LIKE '[FlowFault]%'];
		Assert.areEqual(5, entries.size(), 'one entry per fault. If 0, check LoggerSettings__c is enabled for the running user.');
		Integer linked = 0;
		Set<String> levels = new Set<String>();
		for (LogEntry__c e : entries) {
			levels.add(e.LoggingLevel__c);
			if (e.RecordId__c == UserInfo.getUserId()) { linked++; }
			Assert.isTrue(e.Message__c.contains('Reference ID: FLT-TEST'), 'reference id in message');
		}
		Assert.areEqual(4, linked, 'valid record ids linked, invalid one skipped');
		Assert.isTrue(levels.contains('WARN') && levels.contains('ERROR') && levels.contains('INFO'), 'levels mapped: ' + levels);
	}

	@IsTest
	static void handles200FaultsInOneCall() {
		List<FlowFaultService.Fault> faults = new List<FlowFaultService.Fault>();
		for (Integer i = 0; i < 200; i++) { faults.add(fault(i, 'Bulk_Flow', 'WARN')); }
		Test.startTest();
		new FlowFaultNebulaLogSink().write(faults);
		Integer publishes = Limits.getDmlStatements();
		Test.stopTest();
		Assert.isTrue(publishes <= 5, 'batch publish, not one per fault: ' + publishes);
	}
}
