/**
 * FlowFaultSinkResolver
 * Instantiates the FlowFaultLogSink named in settings via Type.forName, accepting "ClassName" or
 * "Namespace.ClassName". Falls back to FlowFaultDebugLogSink and returns a warning string explaining why,
 * so the caller can surface the degradation instead of hiding it. Tests inject a sink through sinkOverride.
 *
 * DRAFT: AI-generated. Must be human-reviewed and verified before use in any client org (Steampunk AI policy).
 */
public with sharing class FlowFaultSinkResolver {
	public class Resolution {
		public FlowFaultLogSink sink;
		public String warning;
		public Boolean isFallback = false;
	}

	@TestVisible private static FlowFaultLogSink sinkOverride;

	public static Resolution resolve(String className) {
		Resolution r = new Resolution();
		if (sinkOverride != null) { r.sink = sinkOverride; return r; }

		String name = className == null ? '' : className.trim();
		if (String.isBlank(name)) { return fallback(r, 'FlowFaultSetting__mdt.LogSinkClass__c is blank'); }

		Type t = null;
		try {
			Integer dot = name.indexOf('.');
			t = dot > 0 ? Type.forName(name.substring(0, dot), name.substring(dot + 1)) : Type.forName(name);
			if (t == null && dot > 0) { t = Type.forName(name); } // inner class of a top-level class, e.g. Outer.Inner
		} catch (Exception e) {
			return fallback(r, 'Log sink class ' + name + ' could not be loaded: ' + e.getMessage());
		}
		if (t == null) { return fallback(r, 'Log sink class ' + name + ' was not found. Deploy the nebula-adapter package directory or point LogSinkClass__c at another FlowFaultLogSink implementation.'); }

		Object instance;
		try {
			instance = t.newInstance();
		} catch (Exception e) {
			return fallback(r, 'Log sink class ' + name + ' could not be instantiated: ' + e.getMessage());
		}
		if (!(instance instanceof FlowFaultLogSink)) { return fallback(r, 'Log sink class ' + name + ' does not implement FlowFaultLogSink'); }
		r.sink = (FlowFaultLogSink) instance;
		return r;
	}

	private static Resolution fallback(Resolution r, String reason) {
		r.sink = new FlowFaultDebugLogSink();
		r.isFallback = true;
		r.warning = reason + '. Faults were written to the Apex debug log only.';
		return r;
	}
}
