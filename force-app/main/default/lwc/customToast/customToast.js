import { LightningElement, api } from 'lwc';

export default class CustomToast extends LightningElement {
    @api message;
    @api type;
    @api show;

    get toastClass() {
        return `toast toast-${this.type}`;
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}