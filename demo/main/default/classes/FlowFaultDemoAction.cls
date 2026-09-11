/**
 * FlowFaultDemoAction
 * Demo only: an invocable action that fails on request so FlowFaultDemo can exercise the Apex fault path
 * with several exception shapes. Do not deploy to production.
 * DRAFT: AI-generated. Must be human-reviewed and verified before use in any client org (Steampunk AI policy).
 */
public with sharing class FlowFaultDemoAction {
	public class DemoException extends Exception {}

	@InvocableMethod(label='Flow Fault Demo: Throw Exception' description='Demo only. Throws the requested Apex exception (Custom, NullPointer, Dml, Query, Limit) or returns ok for None.' category='Error Handling')
	public static List<String> throwException(List<String> kinds) {
		List<String> out = new List<String>();
		for (String requested : kinds) {
			String kind = String.isBlank(requested) ? 'Custom' : requested.trim();
			if (kind == 'None') { out.add('ok'); continue; }
			if (kind == 'NullPointer') { String s = null; out.add(s.toUpperCase()); }
			if (kind == 'Dml') { insert new Contact(FirstName = 'Flow Fault Demo'); }
			if (kind == 'Query') { Contact c = [SELECT Id FROM Contact WHERE LastName = 'zz-no-such-contact-zz' LIMIT 1]; out.add(c.Id); }
			if (kind == 'Limit') { for (Integer i = 0; i < 101; i++) { List<User> u = [SELECT Id FROM User LIMIT 1]; } }
			throw new DemoException('Demo exception requested by the flow (' + kind + ')');
		}
		return out;
	}
}
