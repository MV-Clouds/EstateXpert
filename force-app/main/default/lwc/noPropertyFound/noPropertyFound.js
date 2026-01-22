import { LightningElement, api } from 'lwc';

export default class NoPropertyFound extends LightningElement {
    @api showError = false;
    @api errorMessage = 'We couldn’t find any properties matching your search criteria.';
}