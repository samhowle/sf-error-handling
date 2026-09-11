/**
 * FlowFaultSinkResolverTest
 * DRAFT: AI-generated. Must be human-reviewed and verified before use in any client org (Steampunk AI policy).
 */
@IsTest
private class FlowFaultSinkResolverTest {
	@IsTest
	static void resolvesClassByName() {
		FlowFaultSinkResolver.Resolution r = FlowFaultSinkResolver.resolve(' FlowFaultDebugLogSink ');
		Assert.isTrue(r.sink instanceof FlowFaultDebugLogSink, 'instance');
		Assert.isFalse(r.isFallback, 'not a fallback');
		Assert.isNull(r.warning, 'no warning');
	}

	@IsTest
	static void blankNameFallsBack() {
		FlowFaultSinkResolver.Resolution r = FlowFaultSinkResolver.resolve('  ');
		Assert.isTrue(r.isFallback, 'fallback');
		Assert.isTrue(r.sink instanceof FlowFaultDebugLogSink, 'debug sink');
		Assert.isTrue(r.warning.contains('blank'), r.warning);
	}

	@IsTest
	static void missingClassFallsBack() {
		FlowFaultSinkResolver.Resolution r = FlowFaultSinkResolver.resolve('NoSuchClassAnywhere');
		Assert.isTrue(r.isFallback, 'fallback');
		Assert.isTrue(r.warning.contains('not found'), r.warning);
		Assert.isTrue(r.warning.contains('NoSuchClassAnywhere'), 'names the class');
	}

	@IsTest
	static void classWithoutInterfaceFallsBack() {
		FlowFaultSinkResolver.Resolution r = FlowFaultSinkResolver.resolve('FlowFaultSettings');
		Assert.isTrue(r.isFallback, 'fallback');
		Assert.isTrue(r.warning.contains('does not implement'), r.warning);
	}

	@IsTest
	static void dottedNameTriesNamespaceThenInnerClass() {
		FlowFaultSinkResolver.Resolution r = FlowFaultSinkResolver.resolve('FlowFaultService.FlowFaultException');
		Assert.isTrue(r.isFallback, 'inner class resolved but is not a sink');
		Assert.isTrue(r.warning.contains('does not implement') || r.warning.contains('instantiated'), r.warning);
	}

	@IsTest
	static void overrideWins() {
		FlowFaultDebugLogSink mine = new FlowFaultDebugLogSink();
		FlowFaultSinkResolver.sinkOverride = mine;
		FlowFaultSinkResolver.Resolution r = FlowFaultSinkResolver.resolve('NoSuchClassAnywhere');
		Assert.areEqual(mine, r.sink, 'override returned');
		Assert.isFalse(r.isFallback, 'not fallback');
	}

	@IsTest
	static void debugSinkWritesWithoutThrowing() {
		FlowFaultService.Fault f = new FlowFaultService.Fault();
		f.referenceId = 'FLT-TEST0001';
		new FlowFaultDebugLogSink().write(new List<FlowFaultService.Fault>{ f });
		Assert.areEqual(FlowFaultDebugLogSink.DESTINATION, new FlowFaultDebugLogSink().getDestinationName(), 'name');
		Assert.isFalse(new FlowFaultDebugLogSink().isPersistent(), 'not persistent');
	}
}
