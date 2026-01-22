import { LightningElement, api } from 'lwc';

export default class IntegrationErrorComponent extends LightningElement {
    @api errorMessage;
    @api showBackButton = false;
    @api showSetupButton = false;

    get hasErrorMessages() {
        return this.errorMessage && this.errorMessage.length > 0;
    }

    get errorMessages() {
        return this.errorMessage || [];
    }

    handleBackToControlCenter() {
        // Dispatch custom event for back to control center action
        this.dispatchEvent(new CustomEvent('backtocontrolcenter'));
    }

    handleGoToSetup() {
        // Dispatch custom event for go to setup action
        this.dispatchEvent(new CustomEvent('gotosetup'));
    }
}