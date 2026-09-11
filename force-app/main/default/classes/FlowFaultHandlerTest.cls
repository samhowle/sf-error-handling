/**
 * FlowFaultHandlerTest
 * Invocable mapping and bulk behaviour at batch sizes 1, 50 and 200 (project convention).
 * DRAFT: AI-generated. Must be human-reviewed and verified before use in any client org (Steampunk AI policy).
 */
@IsTest
private class FlowFaultHandlerTest {
	private static final String VALIDATION = 'This error occurred when the flow tried to create records: FIELD_CUSTOM_VALIDATION_EXCEPTION: Amount must be positive: [Amount]. You can look up ExceptionCode values in the Apex Developer Guide.';

	private static FlowFaultTestSinks.CapturingSink arrange() { return FlowFaultTestSinks.install(); }

	private static List<FlowFaultHandler.Request> requests(Integer n) {
		List<FlowFaultHandler.Request> out = new List<FlowFaultHandler.Request>();
		for (Integer i = 0; i < n; i++) {
			FlowFaultHandler.Request r = new FlowFaultHandler.Request();
			r.faultMessage = VALIDATION;
			r.flowApiName = 'Bulk_Flow';
			r.elementApiName = 'Create_' + i;
			r.recordId = '001000000000' + String.valueOf(1000 + i).right(3) + 'AAA';
			r.contextDetails = 'i=' + i;
			out.add(r);
		}
		return out;
	}

	@IsTest
	static void mapsAllOutputsForOneRequest() {
		FlowFaultTestSinks.CapturingSink sink = arrange();
		FlowFaultHandler.Request r = requests(1)[0];
		r.severity = 'INFO';
		List<FlowFaultHandler.Result> out = FlowFaultHandler.handle(new List<FlowFaultHandler.Request>{ r });
		Assert.areEqual(1, out.size(), 'one result');
		FlowFaultHandler.Result o = out[0];
		Assert.isNotNull(o.referenceId, 'referenceId');
		Assert.areEqual('Amount must be positive', o.userMessage, 'userMessage');
		Assert.areEqual('FIELD_CUSTOM_VALIDATION_EXCEPTION', o.statusCode, 'statusCode');
		Assert.areEqual('Amount', o.fieldNames, 'fieldNames joined');
		Assert.areEqual('Create', o.operation, 'operation');
		Assert.areEqual('INFO', o.severity, 'severity override');
		Assert.isTrue(o.isUserCorrectable, 'correctable');
		Assert.isFalse(o.isRetryable, 'not retryable');
		Assert.isNotNull(o.nextSteps, 'nextSteps');
		Assert.isNotNull(o.adminGuidance, 'adminGuidance');
		Assert.isTrue(o.displayMessage.startsWith('<p>'), 'displayMessage html');
		Assert.isTrue(o.technicalMessage.contains('Element: Create_0'), 'technicalMessage');
		Assert.isTrue(o.isLogged, 'isLogged');
		Assert.areEqual('Capture', o.logDestination, 'logDestination');
		Assert.isNull(o.loggingError, 'loggingError');
		Assert.isNull(o.warnings, 'no warnings');
		Assert.areEqual(1, sink.writeCalls, 'one write');
	}

	@IsTest
	static void nullOptionalInputsAreTolerated() {
		arrange();
		FlowFaultHandler.Request r = new FlowFaultHandler.Request();
		r.faultMessage = 'An Apex error occurred: System.NullPointerException: Attempt to de-reference a null object';
		FlowFaultHandler.Result o = FlowFaultHandler.handle(new List<FlowFaultHandler.Request>{ r })[0];
		Assert.isNull(o.fieldNames, 'no fields => null, not empty string');
		Assert.isTrue(o.warnings.contains('flowApiName'), 'missing flow name warned');
		Assert.areEqual('System.NullPointerException', o.exceptionType, 'exception type mapped');
	}

	@IsTest
	static void handles50InOneSinkWrite() { assertBulk(50); }

	@IsTest
	static void handles200InOneSinkWrite() { assertBulk(200); }

	private static void assertBulk(Integer n) {
		FlowFaultTestSinks.CapturingSink sink = arrange();
		Test.startTest();
		List<FlowFaultHandler.Result> out = FlowFaultHandler.handle(requests(n));
		Test.stopTest();
		Assert.areEqual(n, out.size(), 'one result per request');
		Set<String> refs = new Set<String>();
		for (FlowFaultHandler.Result o : out) {
			refs.add(o.referenceId);
			Assert.areEqual('Validation', o.category, 'classified');
			Assert.isTrue(o.isLogged, 'logged');
		}
		Assert.areEqual(n, refs.size(), 'reference ids unique');
		Assert.areEqual(1, sink.writeCalls, 'single sink write for the batch');
		Assert.areEqual(n, sink.received.size(), 'all faults reached the sink');
		Assert.isTrue(Limits.getQueries() <= 1, 'at most one query regardless of batch size, got ' + Limits.getQueries());
	}
}
