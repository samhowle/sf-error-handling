/**
 * FlowFaultDebugLogSink
 * Fallback sink used when the configured sink class cannot be resolved. Writes each fault to the Apex debug
 * log as JSON. Not persistent: the service reports isLogged = false so nobody mistakes this for real logging.
 *
 * DRAFT: AI-generated. Must be human-reviewed and verified before use in any client org (Steampunk AI policy).
 */
public with sharing class FlowFaultDebugLogSink implements FlowFaultLogSink {
	public static final String DESTINATION = 'DebugLog';

	public String getDestinationName() { return DESTINATION; }
	public Boolean isPersistent() { return false; }

	public void write(List<FlowFaultService.Fault> faults) {
		for (FlowFaultService.Fault f : faults) {
			System.debug(LoggingLevel.ERROR, '[FlowFault] ' + JSON.serializePretty(f));
		}
	}
}
