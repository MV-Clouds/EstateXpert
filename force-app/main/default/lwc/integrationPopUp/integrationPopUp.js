import { LightningElement, track, api } from 'lwc';
import saveSettings from '@salesforce/apex/IntegrationPopupController.saveSettings';
import validateAWSCredentials from '@salesforce/apex/IntegrationPopupController.validateAWSCredentials';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';

const INTEGRATION_FIELDS = {
    AWS: [
        {
            id: 'MVEX__AWS_Secret_Access_Key__c',
            label: 'Secret Access Key',
            placeholder: 'Enter Secret Access Key',
            required: true
        },
        {
            id: 'MVEX__AWS_Access_Key__c',
            label: 'Access Key',
            placeholder: 'Enter Access Key',
            required: true
        },
        {
            id: 'MVEX__S3_Bucket_Name__c',
            label: 'S3 Bucket Name',
            placeholder: 'Enter S3 Bucket Name',
            required: true
        },
        {
            id: 'MVEX__S3_Region_Name__c',
            label: 'S3 Region Name',
            placeholder: 'Enter S3 Region Name',
            required: true
        }
    ]
};

export default class IntegrationPopUp extends NavigationMixin(LightningElement) {
    @api integrationname = '';
    @track isModalOpen = true;
    @track saveDisable = false;
    @track fieldsData = {};
    @track isLoading = false;

    /**
    * Method Name: isAWS
    * @description: Used to check integration name.
    * @returns {Boolean} - Returns true if AWS integration name.
    */
    get isAWS() {
        return this.integrationname === 'AWS';
    }

    /**
    * Method Name: formFields
    * @description: Returns dynamic list of form fields based on integration name.
    * @returns {Array} - Array of field configuration objects.
    */
    get formFields() {
        const fields = INTEGRATION_FIELDS[this.integrationname] || [];
        return fields.map(field => ({
            ...field,
            value: this.fieldsData[field.id] || ''
        }));
    }

    /**
    * Method Name : connectedCallback
    * @description : Loads font styles
    */
    connectedCallback() {
        loadStyle(this, MulishFontCss).catch(error => {
            console.error('Error loading font styles:', error);
        });
    }

    /**
    * Method Name : openModal
    * @description : show the pop-up modal
    */
    openModal() {
        this.isModalOpen = true;
    }

    /**
    * Method Name : closeModal
    * @description : close the pop-up modal
    */
    closeModal() {
        try {
            if (typeof window !== 'undefined') {
                this.dispatchEvent(new CustomEvent('closemodal', { detail: true }));
            }
        } catch (error) {
            console.error('error in closeModal -> ', error.stack);
        }
    }

    /**
    * Method Name : handleInputChange
    * @description : validate the change object as per input values
    */
    handleInputChange(event) {
        try {
            const field = event.target.dataset.id;
            const value = event.target.value;

            this.fieldsData[field] = value;
            this.saveDisable = false;

            if (/\s/.test(value)) {
                event.target.setCustomValidity('Spaces are not allowed.');
            } else {
                event.target.setCustomValidity('');
            }

            event.target.reportValidity();
        } catch (error) {
            console.error('error in handleInputChange -> ', error.stack);
        }
    }

    /**
    * Method Name : checkValidity
    * @description : check the validation for all input fields and comboboxes.
    * @param {Boolean} reportErrors - whether to display error messages on inputs
    * @returns {Boolean} allValid - true if all fields are valid
    */
    checkValidity(reportErrors = false) {
        try {
            const inputs = this.template.querySelectorAll('lightning-input');
            const comboboxes = this.template.querySelectorAll('lightning-combobox');
            let allValid = true;

            if (inputs) {
                inputs.forEach(input => {
                    if (reportErrors) {
                        input.reportValidity();
                    }
                    if (!input.checkValidity()) {
                        allValid = false;
                    }
                });
            }

            if (comboboxes) {
                comboboxes.forEach(combo => {
                    if (reportErrors) {
                        combo.reportValidity();
                    }
                    if (!combo.checkValidity()) {
                        allValid = false;
                    }
                });
            }

            return allValid;
        } catch (error) {
            console.error('error in checkValidity -> ', error.stack);
            return false;
        }
    }

    /**
    * Method Name : saveDetails
    * @description : validates credentials via Apex callout before saving to custom settings
    */
    async saveDetails() {
        try {
            if (!this.checkValidity(true)) {
                this.showToast('Error', 'Please fill out all required fields.', 'error');
                return;
            }

            this.isLoading = true;

            // If AWS integration, validate credentials via Apex server-side callout before saving
            if (this.isAWS) {
                const accessKey = this.fieldsData.MVEX__AWS_Access_Key__c;
                const secretKey = this.fieldsData.MVEX__AWS_Secret_Access_Key__c;
                const bucketName = this.fieldsData.MVEX__S3_Bucket_Name__c;
                const region = this.fieldsData.MVEX__S3_Region_Name__c;

                const validationResult = await validateAWSCredentials({
                    accessKey,
                    secretKey,
                    bucketName,
                    region
                });

                if (validationResult !== 'SUCCESS') {
                    this.isLoading = false;
                    this.showToast('AWS Verification Failed', validationResult, 'error');
                    return;
                }
            }

            const jsonData = JSON.stringify(this.fieldsData);
            saveSettings({ jsonData: jsonData, integrationType: this.integrationname })
                .then(() => {
                    this.isLoading = false;
                    this.showToast('Success', 'Credentials verified and saved successfully.', 'success');
                    this.dispatchEvent(new CustomEvent('closemodal', { detail: false }));
                })
                .catch(error => {
                    this.isLoading = false;
                    const message = error?.body?.message || error?.message || 'Error while saving settings';
                    this.showToast('Error while saving settings', message, 'error');
                });
        } catch (error) {
            console.error('error in saveDetails -> ', error.stack || error);
            this.isLoading = false;
            const message = error?.body?.message || error?.message || 'An unexpected error occurred during validation';
            this.showToast('Error', message, 'error');
        }
    }

    /**
    * Method Name : showToast
    * @description : show toast message
    * @param {String} title
    * @param {String} message
    * @param {String} variant
    */
    showToast(title, message, variant) {
        try {
            if (typeof window !== 'undefined') {
                const event = new ShowToastEvent({
                    title: title,
                    message: message,
                    variant: variant,
                });
                this.dispatchEvent(event);
            }
        } catch (error) {
            console.error('error in showToast ->', error.stack);
        }
    }
}