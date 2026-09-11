/**
 * flowFaultPanel
 * Flow screen component that renders the outputs of the FlowFaultHandlerCore subflow in a consistent way and
 * drives navigation itself (hide the screen footer). Clicking Try again or Cancel sets the selectedAction
 * output and fires NEXT, or FINISH when NEXT is not available.
 *
 * DRAFT: AI-generated. Must be human-reviewed and verified before use in any client org (Steampunk AI policy).
 */
import { LightningElement, api } from 'lwc';
import { FlowAttributeChangeEvent, FlowNavigationNextEvent, FlowNavigationFinishEvent } from 'lightning/flowSupport';
import LABEL_HEADING from '@salesforce/label/c.FlowFaultHeading';
import LABEL_REFERENCE from '@salesforce/label/c.FlowFaultReferenceLabel';
import LABEL_TECHNICAL from '@salesforce/label/c.FlowFaultTechnicalDetailsLabel';
import LABEL_TRY_AGAIN from '@salesforce/label/c.FlowFaultTryAgain';
import LABEL_CANCEL from '@salesforce/label/c.FlowFaultCancel';
import LABEL_COPY_REFERENCE from '@salesforce/label/c.FlowFaultCopyReference';
import LABEL_COPY_DETAILS from '@salesforce/label/c.FlowFaultCopyDetails';
import LABEL_ADMIN_GUIDANCE from '@salesforce/label/c.FlowFaultAdminGuidanceLabel';
import LABEL_NOT_LOGGED from '@salesforce/label/c.FlowFaultNotLoggedNotice';

export const ACTION_RETRY = 'Retry';
export const ACTION_CANCEL = 'Cancel';
const COPIED_RESET_MS = 2000;

export default class FlowFaultPanel extends LightningElement {
	@api heading;
	@api userMessage;
	@api nextSteps;
	@api referenceId;
	@api technicalMessage;
	@api adminGuidance;
	@api category;
	@api isUserCorrectable = false;
	@api isRetryable = false;
	@api isLogged;
	@api showTechnicalDetails = true;
	@api allowRetry = true;
	@api retryLabel;
	@api cancelLabel;
	@api availableActions = [];

	_selectedAction;
	@api get selectedAction() { return this._selectedAction; }
	set selectedAction(value) { this._selectedAction = value; }

	detailsOpen = false;
	copiedReference = false;
	copiedDetails = false;

	labels = { copyReference: LABEL_COPY_REFERENCE, copyDetails: LABEL_COPY_DETAILS, adminGuidance: LABEL_ADMIN_GUIDANCE };

	get headingText() { return this.heading || LABEL_HEADING; }
	get referenceLabel() { return LABEL_REFERENCE; }
	get technicalLabel() { return LABEL_TECHNICAL; }
	get retryText() { return this.retryLabel || LABEL_TRY_AGAIN; }
	get cancelText() { return this.cancelLabel || LABEL_CANCEL; }
	get hasReference() { return Boolean(this.referenceId); }
	get hasTechnical() { return this.showTechnicalDetails !== false && Boolean(this.technicalMessage); }
	get hasAdminGuidance() { return Boolean(this.adminGuidance); }
	get showRetry() { return this.allowRetry !== false; }
	get logNotice() { return this.isLogged === false ? LABEL_NOT_LOGGED : null; }
	get containerClass() { return 'panel ' + (this.isUserCorrectable ? 'panel_warning' : 'panel_error'); }
	get iconName() { return this.isUserCorrectable ? 'utility:warning' : 'utility:error'; }
	get iconVariant() { return this.isUserCorrectable ? 'warning' : 'error'; }
	get detailsIcon() { return this.detailsOpen ? 'utility:chevrondown' : 'utility:chevronright'; }
	get detailsExpanded() { return this.detailsOpen ? 'true' : 'false'; }
	get referenceCopyIcon() { return this.copiedReference ? 'utility:check' : 'utility:copy'; }
	get detailsCopyLabel() { return this.copiedDetails ? '✓' : this.labels.copyDetails; }

	toggleDetails() { this.detailsOpen = !this.detailsOpen; }

	async copyReference() {
		if (await this.copyToClipboard(this.referenceId)) {
			this.copiedReference = true;
			this.resetLater(() => { this.copiedReference = false; });
		}
	}

	async copyDetails() {
		const text = [this.referenceLabel + ': ' + (this.referenceId || ''), this.userMessage, this.adminGuidance ? this.labels.adminGuidance + ': ' + this.adminGuidance : null, this.technicalMessage]
			.filter(Boolean).join('\n');
		if (await this.copyToClipboard(text)) {
			this.copiedDetails = true;
			this.resetLater(() => { this.copiedDetails = false; });
		}
	}

	async copyToClipboard(text) {
		if (!text) return false;
		try {
			if (navigator.clipboard && navigator.clipboard.writeText) {
				await navigator.clipboard.writeText(text);
				return true;
			}
		} catch (e) {
			// Clipboard blocked (permissions, insecure context). The text stays visible on screen, so nothing else to do.
		}
		return false;
	}

	resetLater(fn) {
		// eslint-disable-next-line @lwc/lwc/no-async-operation
		setTimeout(fn, COPIED_RESET_MS);
	}

	handleRetry() { this.select(ACTION_RETRY); }
	handleCancel() { this.select(ACTION_CANCEL); }

	select(action) {
		this._selectedAction = action;
		this.dispatchEvent(new FlowAttributeChangeEvent('selectedAction', action));
		this.navigate();
	}

	navigate() {
		const actions = this.availableActions || [];
		if (actions.includes('NEXT')) {
			this.dispatchEvent(new FlowNavigationNextEvent());
		} else if (actions.includes('FINISH')) {
			this.dispatchEvent(new FlowNavigationFinishEvent());
		}
	}
}
