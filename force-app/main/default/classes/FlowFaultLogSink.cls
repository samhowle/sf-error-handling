/**
 * FlowFaultLogSink
 * Persistence seam for the Flow fault handler. The core package has no dependency on any logging product;
 * FlowFaultSetting__mdt.LogSinkClass__c names an implementation, which FlowFaultSinkResolver instantiates by
 * name. Ships with FlowFaultDebugLogSink (fallback) here and FlowFaultNebulaLogSink in the nebula-adapter
 * package directory.
 *
 * Contract: write() must either persist every fault or throw. Do not catch and swallow inside a sink; the
 * service reports the failure back to the flow as isLogged = false with loggingError populated.
 *
 * DRAFT: AI-generated. Must be human-reviewed and verified before use in any client org (Steampunk AI policy).
 */
public interface FlowFaultLogSink {
	/** Short name reported back to the flow, e.g. NebulaLogger or DebugLog. */
	String getDestinationName();
	/** False when the sink only writes to a transient location such as the Apex debug log. */
	Boolean isPersistent();
	/** Persist the faults. Throw on failure. */
	void write(List<FlowFaultService.Fault> faults);
}
