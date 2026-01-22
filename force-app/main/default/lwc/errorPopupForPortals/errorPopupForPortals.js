import { LightningElement, api, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { errorDebugger } from 'c/globalProperties';

export default class ErrorPopupForPortals extends LightningElement {

    @api jsonbody;
    @api portalname;
    @api type; // 'publish' or 'delete'
    @track firstHeader;
    @track secondHeader;
    @track errors = [];

    /**
    * Method Name: connectedCallback
    * @description: Used to set the header and errors.
    * Created Date: 09/07/2024
    * Last Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    connectedCallback() {
        try {
            loadStyle(this, MulishFontCss);
            this.errors = JSON.parse(this.jsonbody);
            if (this.portalname === 'Zoopla') {
                this.firstHeader = 'Error Message';
                this.secondHeader = 'Path';
            } else if (this.portalname === 'Rightmove' || this.portalname === 'Rightmove Overseas') {
                this.firstHeader = 'Error Message';
                this.secondHeader = 'Value';
            } else if (this.portalname === 'Property Finder') {
                this.firstHeader = 'Error Message';
                this.secondHeader = 'Pointer';
            }
        } catch (error) {
            errorDebugger('ErrorPopupForPortals', 'connectedCallback', error.stack, 'warn', 'Error while loading css and fetching data');
        }
    }
    
    /**
    * Method Name: handleCloseModal
    * @description: Used to close the popup.
    * Created Date: 09/07/2024
    * Last Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    handleCloseModal() {
        try {
            let custEvent = new CustomEvent('hidepopup', {
                detail: false
            });
            this.dispatchEvent(custEvent);
        } catch (error) {
            errorDebugger('ErrorPopupForPortals', 'handleCloseModal', error.stack, 'warn', 'Error while closing the popup');
        }
    }
}