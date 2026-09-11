import { createElement } from 'lwc';
import FlowFaultPanel, { ACTION_RETRY, ACTION_CANCEL } from 'c/flowFaultPanel';

const flush = () => Promise.resolve();

function build(props = {}) {
	const el = createElement('c-flow-fault-panel', { is: FlowFaultPanel });
	Object.assign(el, { userMessage: 'Amount must be positive', referenceId: 'FLT-ABCDEF01', availableActions: ['NEXT'] }, props);
	document.body.appendChild(el);
	return el;
}

describe('c-flow-fault-panel', () => {
	afterEach(() => {
		while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
		jest.clearAllMocks();
	});

	it('renders message, next steps, reference id and default heading label', () => {
		const el = build({ nextSteps: 'Go back and fix it.' });
		expect(el.shadowRoot.querySelector('.fault-message').textContent).toBe('Amount must be positive');
		expect(el.shadowRoot.querySelector('.next-steps').textContent).toBe('Go back and fix it.');
		expect(el.shadowRoot.querySelector('.reference').textContent).toBe('FLT-ABCDEF01');
		expect(el.shadowRoot.querySelector('.heading').textContent).toBe('c.FlowFaultHeading');
		expect(el.shadowRoot.querySelector('.panel').classList.contains('panel_error')).toBe(true);
	});

	it('uses warning styling for user-correctable faults and a custom heading', () => {
		const el = build({ isUserCorrectable: true, heading: 'Please check your entries' });
		expect(el.shadowRoot.querySelector('.panel').classList.contains('panel_warning')).toBe(true);
		expect(el.shadowRoot.querySelector('.heading').textContent).toBe('Please check your entries');
		expect(el.shadowRoot.querySelector('lightning-icon').iconName).toBe('utility:warning');
	});

	it('hides retry when allowRetry is false and hides reference when absent', () => {
		const el = build({ allowRetry: false, referenceId: null });
		expect(el.shadowRoot.querySelector('.retry')).toBeNull();
		expect(el.shadowRoot.querySelector('.cancel')).not.toBeNull();
		expect(el.shadowRoot.querySelector('.reference')).toBeNull();
	});

	it('shows the not-logged notice only when isLogged is explicitly false', () => {
		expect(build({ isLogged: false }).shadowRoot.querySelector('.log-notice').textContent).toBe('c.FlowFaultNotLoggedNotice');
		expect(build({ isLogged: true }).shadowRoot.querySelector('.log-notice')).toBeNull();
		expect(build({}).shadowRoot.querySelector('.log-notice')).toBeNull();
	});

	it('toggles technical details with admin guidance', async () => {
		const el = build({ technicalMessage: 'Flow: X | Fault: Y', adminGuidance: 'Check rules' });
		expect(el.shadowRoot.querySelector('.technical')).toBeNull();
		el.shadowRoot.querySelector('.details-toggle').click();
		await flush();
		expect(el.shadowRoot.querySelector('.technical').textContent).toBe('Flow: X | Fault: Y');
		expect(el.shadowRoot.querySelector('.admin-guidance').textContent).toContain('Check rules');
		expect(el.shadowRoot.querySelector('.details-toggle').getAttribute('aria-expanded')).toBe('true');
	});

	it('does not render the expander when showTechnicalDetails is false', () => {
		expect(build({ technicalMessage: 'x', showTechnicalDetails: false }).shadowRoot.querySelector('.details-toggle')).toBeNull();
	});

	it('retry sets selectedAction, fires attribute change and NEXT navigation', () => {
		const el = build();
		const attr = jest.fn();
		const next = jest.fn();
		const finish = jest.fn();
		el.addEventListener('lightning__flowattributechange', attr);
		el.addEventListener('lightning__flownavigationnext', next);
		el.addEventListener('lightning__flownavigationfinish', finish);
		el.shadowRoot.querySelector('.retry').click();
		expect(el.selectedAction).toBe(ACTION_RETRY);
		expect(attr).toHaveBeenCalledTimes(1);
		expect(attr.mock.calls[0][0].detail).toEqual({ attributeName: 'selectedAction', attributeValue: ACTION_RETRY });
		expect(next).toHaveBeenCalledTimes(1);
		expect(finish).not.toHaveBeenCalled();
	});

	it('cancel falls back to FINISH when NEXT is not available', () => {
		const el = build({ availableActions: ['FINISH', 'BACK'] });
		const next = jest.fn();
		const finish = jest.fn();
		el.addEventListener('lightning__flownavigationnext', next);
		el.addEventListener('lightning__flownavigationfinish', finish);
		el.shadowRoot.querySelector('.cancel').click();
		expect(el.selectedAction).toBe(ACTION_CANCEL);
		expect(next).not.toHaveBeenCalled();
		expect(finish).toHaveBeenCalledTimes(1);
	});

	it('copies the reference id to the clipboard when available', async () => {
		const writeText = jest.fn().mockResolvedValue();
		Object.defineProperty(navigator, 'clipboard', { value: { writeText }, configurable: true });
		const el = build();
		el.shadowRoot.querySelector('.copy-reference').click();
		await flush();
		expect(writeText).toHaveBeenCalledWith('FLT-ABCDEF01');
	});
});
