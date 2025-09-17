import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import getIntegrationDetails from '@salesforce/apex/IntegrationPopupController.getIntegrationDetails';
import revokeAWSAccess from '@salesforce/apex/IntegrationPopupController.revokeAWSAccess';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { errorDebugger } from 'c/globalProperties';

export default class StorageIntegration extends NavigationMixin(LightningElement) {
    @track isDataLoaded = false;
    @track activeTab = 'AWS';
    @track showIntegrationModal = false;
    @track isSpinner = true;
    @track integrationName;
    @track integrationLabel;
    @track awsData;

    /**
    * Method Name: isAWS
    * @description: Used to check if AWS tab is active.
    * @returns {Boolean} - Returns true if AWS tab is active.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    get isAWS() {
        return this.activeTab === 'AWS';
    }

    /**
    * Method Name: awsClass
    * @description: Used to check if AWS tab is active.
    * @returns {Boolean} - Returns true if AWS tab is active.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    get awsClass() {
        return this.activeTab === 'AWS' ? 'active' : '';
    }

    /**
    * Method Name: connectedCallback
    * @description: Used to load css and fetch data.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    connectedCallback(){
        try {
            loadStyle(this, MulishFontCss);
            this.getIntegrationDataToShow();
        } catch (error) {
            errorDebugger('StorageIntegration', 'connectedCallback', error, 'warn', 'Error occurred while connectedCallback');
        }
    }

    /**
    * Method Name: getIntegrationDataToShow
    * @description: Used to get data from AWS Integration.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    getIntegrationDataToShow(){
        try {
            this.isSpinner = true;
            getIntegrationDetails()
            .then(data => {
                data.forEach(item => {
                    if (item?.integrationName === 'AWS' && item?.isValid) {
                        item.integrationData.CreatedDate = this.formatDate(item.integrationData.CreatedDate);
                        item.integrationData.LastModifiedDate = this.formatDate(item.integrationData.LastModifiedDate);
                        item.integrationData.SensitiveData = '[SENSITIVE_DATA_MASKED]';
                        this.awsData = item;
                    } else {
                        this.awsData = { isValid: false };
                    }
                });
                
                this.isDataLoaded = true;
                this.isSpinner = false;
            })
            .catch(error => {
                errorDebugger('StorageIntegration', 'getIntegrationDataToShow', error, 'warn', 'Error occurred while fetching data');
                this.isSpinner = false;
            });
        } catch (error) {
            errorDebugger('StorageIntegration', 'getIntegrationDataToShow', error, 'warn', 'Error occurred while fetching data');
            this.isSpinner = false;   
        }
    }

    /**
    * Method Name: formatDate
    * @description: Used to format the date.
    * @param {String} dateStr - Date string.
    * @return {String} - Formatted date.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    formatDate(date) {
        const options = { 
            year: 'numeric', 
            month: 'long', 
            day: 'numeric', 
            hour: '2-digit', 
            minute: '2-digit', 
            hour12: true // Use 12-hour format
        };
        return new Date(date).toLocaleString('en-US', options); // Include time in the formatted string
    }

    /**
    * Method Name: handleAWSClick
    * @description: Used to set active tab.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    handleAWSClick() {
        this.activeTab = 'AWS';
    }

    handleDeactivateClick() {
        this.showMessagePopup('Warning', 'Are you sure you want to deactivate this?', `This action will revoke access to ${this.activeTab} and you will need to reconfigure the integration if you want to use it again.`);
    }

    handleConfirmation(event) {
        if (event.detail === true) {
            switch (this.activeTab) {
                case 'AWS':
                    this.deactivateAWS();
                    break;
                default:
                    break;
            }
        }
    }

    /**
    * Method Name: deactivateAWS
    * @description: Used to deactivate AWS.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    deactivateAWS() {
        try {
            this.isSpinner = true;
            revokeAWSAccess({ recordId: this.awsData.integrationData.Id })
            .then(data => {
                if (data === 'success') {
                    this.showToast('Success', 'Credentials have been revoked successfully.', 'success');
                    this.getIntegrationDataToShow();
                } else {
                    this.showToast('Error', data, 'error');
                }
                this.isSpinner = false;
            })
            .catch(error => {
                errorDebugger('StorageIntegration', 'deactivateAWS', error, 'warn', 'Error occurred while fetching data');
                this.isSpinner = false;
            });
        } catch (error) {
            errorDebugger('StorageIntegration', 'deactivateAWS', error, 'warn', 'Error occurred while fetching data');
            this.isSpinner = false;            
        }
    }

    /**
    * Method Name: backToControlCenter
    * @description: Used to navigate to Control Center.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    backToControlCenter(event) {
        try {
            event.preventDefault();
            this[NavigationMixin.Navigate]({
                type: "standard__navItemPage",
                attributes: {
                    apiName: "MVEX__Control_Center",
                },
            });
        } catch (error) {
            errorDebugger('StorageIntegration', 'backToControlCenter', error, 'warn', 'Error occurred while navigating to Control Center');
        }
    }

    /**
    * Method Name: handleModalSelect
    * @description: Used to close the modal.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    handleModalSelect(event) {
        try {
            const isCancel = event.detail;
            if (isCancel) {
                this.showIntegrationModal = false;
            } else {
                this.showIntegrationModal = false;
                this.getIntegrationDataToShow();
            }
        } catch (error) {
            errorDebugger('StorageIntegration', 'handleModalSelect', error, 'warn', 'Error occurred while closing the modal');
        }
    }

    /**
    * Method Name: newIntegrationModal
    * @description: Used to open the modal.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    newIntegrationModal(event) {
        try {
            const integrationName = event.target.dataset.name;
            this.integrationName = integrationName;
            this.integrationLabel = integrationName;
            this.showIntegrationModal = true;
        } catch (error) {
            errorDebugger('StorageIntegration', 'newIntegrationModal', error, 'warn', 'Error occurred while opening the modal');
        }
    }

    /**
    * Method Name: showToast
    * @description: Used to show toast.
    * @param {string} title - Title of toast.
    * @param {string} message - Description of toast.
    * @param {string} variant - Variant of toast.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
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
            errorDebugger('StorageIntegration', 'showToast', error, 'warn', 'Error occurred while showing the toast');
        }
    }

    awsWatermarkUploaderMethod() {
        this.isWaterMarkUploader = true;
    }

    closeWaterMarkModal() {
        this.isWaterMarkUploader = false;
    }

    showMessagePopup(Status, Title, Message) {
        const messageContainer = this.template.querySelector('c-message-popup')
        if (messageContainer) {
            messageContainer.showMessagePopup({
                status: Status,
                title: Title,
                message: Message,
            });
        }
    }
}