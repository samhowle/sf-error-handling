/**
 * FlowFaultTestSinks
 * Test doubles for FlowFaultLogSink shared by the framework's test classes. Public so other @IsTest classes
 * (including ones in the nebula-adapter and demo package directories) can reuse them.
 * DRAFT: AI-generated. Must be human-reviewed and verified before use in any client org (Steampunk AI policy).
 */
@IsTest
public class FlowFaultTestSinks {
	/** Records everything it receives and reports itself as persistent. */
	public class CapturingSink implements FlowFaultLogSink {
		public List<FlowFaultService.Fault> received = new List<FlowFaultService.Fault>();
		public Integer writeCalls = 0;
		public String getDestinationName() { return 'Capture'; }
		public Boolean isPersistent() { return true; }
		public void write(List<FlowFaultService.Fault> faults) { writeCalls++; received.addAll(faults); }
	}

	/** Always fails, to prove the service reports sink failures instead of hiding them. */
	public class ThrowingSink implements FlowFaultLogSink {
		public String getDestinationName() { return 'Broken'; }
		public Boolean isPersistent() { return true; }
		public void write(List<FlowFaultService.Fault> faults) { throw new FlowFaultService.FlowFaultException('disk full'); }
	}

	/** Installs a CapturingSink and plain settings; returns the sink for assertions. */
	public static CapturingSink install() {
		CapturingSink sink = new CapturingSink();
		FlowFaultSinkResolver.sinkOverride = sink;
		FlowFaultSettings.instanceOverride = new FlowFaultSettings();
		return sink;
	}
}
