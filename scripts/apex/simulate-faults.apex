// Smoke test for the fault handler against the org's deployed rules and sink, without building a flow.
// Run:  sf apex run --file scripts/apex/simulate-faults.apex --target-org <alias>
// Then: look for "[FlowFault]" entries in Nebula Logger (Log Entries tab) or, if the sink fell back, in this debug log.
// Set skipLogging = true below to classify only.
Boolean skipLogging = false;
String suffix = ' You can look up ExceptionCode values in the Apex Developer Guide.';
Map<String, String> samples = new Map<String, String>{
	'validation' => 'This error occurred when the flow tried to create records: FIELD_CUSTOM_VALIDATION_EXCEPTION: Amount must be positive: [Amount].' + suffix,
	'requiredField' => 'This error occurred when the flow tried to create records: REQUIRED_FIELD_MISSING: Required fields are missing: [LastName].' + suffix,
	'rowLock' => 'The flow tried to update these records: 001000000000001AAA. This error occurred: UNABLE_TO_LOCK_ROW: unable to obtain exclusive access to this record.' + suffix,
	'permission' => 'This error occurred when the flow tried to update records: INSUFFICIENT_ACCESS_OR_READONLY: insufficient access rights on object id.' + suffix,
	'triggerNested' => 'This error occurred when the flow tried to update records: CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY: AccountTrigger: execution of BeforeUpdate caused by: System.DmlException: Update failed. First exception on row 0; first error: FIELD_CUSTOM_VALIDATION_EXCEPTION, message: Contact must have an email: [Email] Class.AccountTriggerHandler.beforeUpdate: line 42, column 1 Trigger.AccountTrigger: line 5, column 1.' + suffix,
	'apexNullPointer' => 'An Apex error occurred: System.NullPointerException: Attempt to de-reference a null object',
	'apexDml' => 'An Apex error occurred: System.DmlException: Insert failed. First exception on row 0; first error: FIELD_CUSTOM_VALIDATION_EXCEPTION, message: Amount must be positive: []',
	'limit' => 'An Apex error occurred: System.LimitException: Too many SOQL queries: 101',
	'unknown' => 'Something nobody has seen before'
};
List<FlowFaultService.Input> inputs = new List<FlowFaultService.Input>();
for (String key : samples.keySet()) {
	FlowFaultService.Input i = new FlowFaultService.Input();
	i.faultMessage = samples.get(key);
	i.flowApiName = 'SimulateFaults';
	i.elementApiName = key;
	i.contextDetails = 'anonymous apex smoke test';
	i.skipLogging = skipLogging;
	inputs.add(i);
}
for (FlowFaultService.Fault f : FlowFaultService.handle(inputs)) {
	System.debug(LoggingLevel.INFO, '=== ' + f.elementApiName + ' => ' + f.category + ' / ' + f.ruleName + ' / ' + f.referenceId
		+ '\n  user:      ' + f.userMessage
		+ '\n  next:      ' + f.nextSteps
		+ '\n  admin:     ' + f.adminGuidance
		+ '\n  logged:    ' + f.isLogged + ' via ' + f.logDestination + (f.loggingError == null ? '' : ' (' + f.loggingError + ')')
		+ (f.warnings.isEmpty() ? '' : '\n  warnings:  ' + String.join(f.warnings, ' | ')));
}
