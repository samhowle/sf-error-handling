// Jest stand-in for lightning/flowSupport. Each event records its type so tests can assert on navigation.
export class FlowAttributeChangeEvent extends CustomEvent {
	constructor(attributeName, attributeValue) {
		super('lightning__flowattributechange', { bubbles: true, composed: true, cancelable: true, detail: { attributeName, attributeValue } });
	}
}
export class FlowNavigationNextEvent extends CustomEvent {
	constructor() { super('lightning__flownavigationnext', { bubbles: true, composed: true, cancelable: true }); }
}
export class FlowNavigationBackEvent extends CustomEvent {
	constructor() { super('lightning__flownavigationback', { bubbles: true, composed: true, cancelable: true }); }
}
export class FlowNavigationFinishEvent extends CustomEvent {
	constructor() { super('lightning__flownavigationfinish', { bubbles: true, composed: true, cancelable: true }); }
}
export class FlowNavigationPauseEvent extends CustomEvent {
	constructor() { super('lightning__flownavigationpause', { bubbles: true, composed: true, cancelable: true }); }
}
