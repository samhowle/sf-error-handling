/**
 * FlowFaultDemoActionTest
 * DRAFT: AI-generated. Must be human-reviewed and verified before use in any client org (Steampunk AI policy).
 */
@IsTest
private class FlowFaultDemoActionTest {
	private static String typeOf(String kind) {
		try {
			FlowFaultDemoAction.throwException(new List<String>{ kind });
			return null;
		} catch (Exception e) {
			return e.getTypeName();
		}
	}

	@IsTest
	static void noneReturnsOk() {
		Assert.areEqual(new List<String>{ 'ok' }, FlowFaultDemoAction.throwException(new List<String>{ 'None' }), 'ok');
	}

	@IsTest
	static void throwsRequestedKinds() {
		Assert.areEqual('FlowFaultDemoAction.DemoException', typeOf('Custom'), 'custom');
		Assert.areEqual('FlowFaultDemoAction.DemoException', typeOf(null), 'blank defaults to custom');
		Assert.areEqual('System.NullPointerException', typeOf('NullPointer'), 'null pointer');
		Assert.areEqual('System.DmlException', typeOf('Dml'), 'dml (required field missing)');
		Assert.areEqual('System.QueryException', typeOf('Query'), 'query');
	}

	@IsTest
	static void dmlKindCarriesRequiredFieldMissing() {
		try {
			FlowFaultDemoAction.throwException(new List<String>{ 'Dml' });
			Assert.fail('expected DmlException');
		} catch (DmlException e) {
			Assert.areEqual(StatusCode.REQUIRED_FIELD_MISSING, e.getDmlType(0), 'status code');
		}
	}
}
