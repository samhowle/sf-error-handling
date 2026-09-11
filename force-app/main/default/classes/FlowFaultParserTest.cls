/**
 * FlowFaultParserTest
 * One test per known $Flow.FaultMessage shape. When a new shape shows up in an org, paste it here first.
 * DRAFT: AI-generated. Must be human-reviewed and verified before use in any client org (Steampunk AI policy).
 */
@IsTest
private class FlowFaultParserTest {
	private static final String SUFFIX = ' You can look up ExceptionCode values in the Apex Developer Guide.';

	@IsTest
	static void parsesValidationRuleOnCreate() {
		FlowFaultParser.ParsedFault p = FlowFaultParser.parse('This error occurred when the flow tried to create records: FIELD_CUSTOM_VALIDATION_EXCEPTION: Amount must be positive.' + SUFFIX);
		Assert.areEqual(FlowFaultParser.ENVELOPE_DML, p.envelope, 'envelope');
		Assert.areEqual('Create', p.operation, 'operation');
		Assert.areEqual('FIELD_CUSTOM_VALIDATION_EXCEPTION', p.statusCode, 'status code');
		Assert.isNull(p.innerStatusCode, 'no inner code');
		Assert.areEqual('Amount must be positive', p.detail, 'validation text verbatim, boilerplate and its period removed');
		Assert.isTrue(p.fieldNames.isEmpty(), 'no fields');
		Assert.isFalse(p.cleanMessage.contains('ExceptionCode'), 'boilerplate stripped from clean message');
	}

	@IsTest
	static void parsesValidationRuleWithFieldList() {
		FlowFaultParser.ParsedFault p = FlowFaultParser.parse('This error occurred when the flow tried to update records: FIELD_CUSTOM_VALIDATION_EXCEPTION: Close date is required once Stage is Closed Won: [CloseDate].' + SUFFIX);
		Assert.areEqual('Update', p.operation, 'operation');
		Assert.areEqual('Close date is required once Stage is Closed Won', p.detail, 'detail without field list');
		Assert.areEqual(new List<String>{ 'CloseDate' }, p.fieldNames, 'field list captured');
	}

	@IsTest
	static void parsesRequiredFieldMissing() {
		FlowFaultParser.ParsedFault p = FlowFaultParser.parse('This error occurred when the flow tried to create records: REQUIRED_FIELD_MISSING: Required fields are missing: [LastName, AccountId].' + SUFFIX);
		Assert.areEqual('REQUIRED_FIELD_MISSING', p.statusCode, 'status code');
		Assert.areEqual('Required fields are missing', p.detail, 'detail');
		Assert.areEqual(new List<String>{ 'LastName', 'AccountId' }, p.fieldNames, 'two fields');
	}

	@IsTest
	static void parsesAlternateEnvelopeWithRecordIds() {
		FlowFaultParser.ParsedFault p = FlowFaultParser.parse('The flow tried to update these records: 001000000000001AAA. This error occurred: UNABLE_TO_LOCK_ROW: unable to obtain exclusive access to this record or 1 records: 001000000000001AAA.' + SUFFIX);
		Assert.areEqual(FlowFaultParser.ENVELOPE_DML, p.envelope, 'envelope');
		Assert.areEqual('Update', p.operation, 'operation');
		Assert.isTrue(p.recordIds.contains('001000000000001AAA'), 'record ids kept');
		Assert.areEqual('UNABLE_TO_LOCK_ROW', p.statusCode, 'status code');
	}

	@IsTest
	static void parsesTriggerWithNestedDmlValidation() {
		String msg = 'This error occurred when the flow tried to update records: CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY: AccountTrigger: execution of BeforeUpdate caused by: '
			+ 'System.DmlException: Update failed. First exception on row 0; first error: FIELD_CUSTOM_VALIDATION_EXCEPTION, message: Contact must have an email: [Email] '
			+ 'Class.AccountTriggerHandler.beforeUpdate: line 42, column 1 Trigger.AccountTrigger: line 5, column 1.' + SUFFIX;
		FlowFaultParser.ParsedFault p = FlowFaultParser.parse(msg);
		Assert.areEqual('CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY', p.statusCode, 'outer code');
		Assert.isTrue(p.isTriggerFault(), 'trigger fault');
		Assert.areEqual('AccountTrigger', p.sourceName, 'trigger name');
		Assert.areEqual('BeforeUpdate', p.triggerEvent, 'trigger event');
		Assert.areEqual('System.DmlException', p.exceptionType, 'exception type');
		Assert.areEqual('FIELD_CUSTOM_VALIDATION_EXCEPTION', p.innerStatusCode, 'inner code');
		Assert.areEqual('CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY', p.effectiveStatusCode(), 'outer wins as effective');
		Assert.areEqual('Contact must have an email', p.detail, 'inner validation text');
		Assert.areEqual(new List<String>{ 'Email' }, p.fieldNames, 'fields');
		Assert.isTrue(p.stackTrace.startsWith('Class.AccountTriggerHandler'), 'stack captured: ' + p.stackTrace);
	}

	@IsTest
	static void parsesTriggerWithCustomException() {
		String msg = 'This error occurred when the flow tried to update records: CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY: CaseTrigger: execution of AfterInsert caused by: '
			+ 'CaseService.CaseServiceException: No owner found for region EMEA Class.CaseService.assign: line 12, column 1 Trigger.CaseTrigger: line 3, column 1.' + SUFFIX;
		FlowFaultParser.ParsedFault p = FlowFaultParser.parse(msg);
		Assert.areEqual('CaseTrigger', p.sourceName, 'source');
		Assert.areEqual('CaseService.CaseServiceException', p.exceptionType, 'custom exception type');
		Assert.isNull(p.innerStatusCode, 'no nested DML code');
		Assert.areEqual('No owner found for region EMEA', p.detail, 'detail');
		Assert.isTrue(p.stackTrace.startsWith('Class.CaseService.assign'), 'stack');
	}

	@IsTest
	static void parsesApexActionNullPointer() {
		FlowFaultParser.ParsedFault p = FlowFaultParser.parse('An Apex error occurred: System.NullPointerException: Attempt to de-reference a null object');
		Assert.areEqual(FlowFaultParser.ENVELOPE_APEX, p.envelope, 'envelope');
		Assert.areEqual('Apex', p.operation, 'operation');
		Assert.isNull(p.statusCode, 'no DML code');
		Assert.areEqual('System.NullPointerException', p.exceptionType, 'type');
		Assert.areEqual('Attempt to de-reference a null object', p.detail, 'detail');
	}

	@IsTest
	static void parsesApexActionCustomException() {
		FlowFaultParser.ParsedFault p = FlowFaultParser.parse('An Apex error occurred: FlowFaultDemoAction.DemoException: Boom');
		Assert.areEqual('FlowFaultDemoAction.DemoException', p.exceptionType, 'type');
		Assert.areEqual('Boom', p.detail, 'detail');
	}

	@IsTest
	static void parsesApexDmlExceptionWithNestedValidation() {
		FlowFaultParser.ParsedFault p = FlowFaultParser.parse('An Apex error occurred: System.DmlException: Insert failed. First exception on row 0; first error: FIELD_CUSTOM_VALIDATION_EXCEPTION, message: Amount must be positive: []');
		Assert.areEqual('System.DmlException', p.exceptionType, 'type');
		Assert.isNull(p.statusCode, 'no outer code');
		Assert.areEqual('FIELD_CUSTOM_VALIDATION_EXCEPTION', p.innerStatusCode, 'inner code');
		Assert.areEqual('FIELD_CUSTOM_VALIDATION_EXCEPTION', p.effectiveStatusCode(), 'inner is effective when no outer');
		Assert.areEqual('Amount must be positive', p.detail, 'detail');
		Assert.isTrue(p.fieldNames.isEmpty(), 'empty bracket list yields no fields');
	}

	@IsTest
	static void parsesLimitException() {
		FlowFaultParser.ParsedFault p = FlowFaultParser.parse('An Apex error occurred: System.LimitException: Too many SOQL queries: 101');
		Assert.areEqual('System.LimitException', p.exceptionType, 'type');
		Assert.areEqual('Too many SOQL queries: 101', p.detail, 'detail keeps the count');
	}

	@IsTest
	static void unknownTextPassesThrough() {
		FlowFaultParser.ParsedFault p = FlowFaultParser.parse('  Something odd happened  ');
		Assert.areEqual(FlowFaultParser.ENVELOPE_NONE, p.envelope, 'envelope');
		Assert.areEqual('Unknown', p.operation, 'operation');
		Assert.isNull(p.statusCode, 'no code');
		Assert.areEqual('Something odd happened', p.detail, 'trimmed text as detail');
		Assert.areEqual('Something odd happened', p.cleanMessage, 'clean message');
	}

	@IsTest
	static void blankAndNullNeverThrow() {
		FlowFaultParser.ParsedFault p = FlowFaultParser.parse(null);
		Assert.areEqual('', p.cleanMessage, 'null clean');
		Assert.areEqual('', p.detail, 'null detail');
		p = FlowFaultParser.parse('   ');
		Assert.areEqual('', p.detail, 'blank detail');
		Assert.isNull(p.statusCode, 'no code');
		p = FlowFaultParser.parse('This error occurred when the flow tried to create records: FIELD_CUSTOM_VALIDATION_EXCEPTION: Error: amount is required.' + SUFFIX);
		Assert.isNull(p.exceptionType, 'validation text starting with "Error:" is not an exception type');
		Assert.areEqual('Error: amount is required', p.detail, 'kept verbatim');
	}

	@IsTest
	static void collapsesWhitespaceInDetailOnly() {
		FlowFaultParser.ParsedFault p = FlowFaultParser.parse('This error occurred when the flow tried to delete records: DELETE_FAILED: Your attempt to delete\n  this record   could not be completed.' + SUFFIX);
		Assert.areEqual('Delete', p.operation, 'operation');
		Assert.areEqual('Your attempt to delete this record could not be completed', p.detail, 'whitespace collapsed');
		Assert.isTrue(p.cleanMessage.contains('\n'), 'clean message keeps original whitespace');
	}
}
