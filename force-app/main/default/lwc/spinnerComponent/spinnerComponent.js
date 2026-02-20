import { LightningElement, api } from 'lwc';

export default class SpinnerComponent extends LightningElement {
    @api isAbsolute = false;

    get containerClass() {
        return this.isAbsolute ? 'spinner-main-div absolute-spinner' : 'spinner-main-div fixed-spinner';
    }
}