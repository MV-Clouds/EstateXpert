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
    @track facebookData;
    @track isClientSecretHidden = true;
    @track isWaterMarkUploader = false;
    
    // Constants for credential placeholders
    CREDENTIAL_PLACEHOLDER = '••••••••••••••••';
    CREDENTIAL_DISPLAY_TEXT = 'Confidential Information - Hidden for Security';

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
    * Method Name: displayedAccessKey
    * @description: Used to get access key with placeholder.
    * @returns {String} - Returns placeholder for access key.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    get displayedAccessKey() {
        return this.CREDENTIAL_DISPLAY_TEXT;
    }

    /**
    * Method Name: displayedClientSecret
    * @description: Used to get client secret with placeholder.
    * @returns {String} - Returns placeholder for client secret.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    get displayedClientSecret() {
        return this.CREDENTIAL_DISPLAY_TEXT;
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
            this.getSocialMediaDataToShow();
        } catch (error) {
            errorDebugger('StorageIntegration', 'connectedCallback', error, 'warn', 'Error occurred while connectedCallback');
        }
    }

    /**
    * Method Name: getSocialMediaDataToShow
    * @description: Used to get data from AWS Integration.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    getSocialMediaDataToShow(){
        try {
            this.isSpinner = true;
            getIntegrationDetails()
            .then(data => {
                data.forEach(item => {
                    if (item.integrationName === 'AWS') {
                        if (item.integrationData.CreatedDate) {
                            item.integrationData.CreatedDate = this.formatDate(item.integrationData.CreatedDate);
                        }
                        if (item.integrationData.LastModifiedDate) {
                            item.integrationData.LastModifiedDate = this.formatDate(item.integrationData.LastModifiedDate);
                        }
                        this.awsData = item;
                    }
                });
                this.isDataLoaded = true;
                this.isSpinner = false;
            })
            .catch(error => {
                errorDebugger('StorageIntegration', 'getSocialMediaDataToShow', error, 'warn', 'Error occurred while fetching data');
                this.isSpinner = false;
            });
        } catch (error) {
            errorDebugger('StorageIntegration', 'getSocialMediaDataToShow', error, 'warn', 'Error occurred while fetching data');
            this.isSpinner = false;   
        }
    }

    /**
    * Method Name: formatDate
    * @description: Used to format the date and time in user's local timezone.
    * @param {String} dateStr - Date string.
    * @return {String} - Formatted date and time.
    * Created Date: 27/12/2024
    * Updated Date: 21/01/2026
    * Created By: Karan Singh
    */
    formatDate(dateStr) {
        try {
            const date = new Date(dateStr);
            
            // Get date components
            const day = date.getDate();
            const month = date.getMonth() + 1;
            const year = date.getFullYear();
            
            // Get time components
            let hours = date.getHours();
            const minutes = date.getMinutes();
            const seconds = date.getSeconds();
            
            // Determine AM/PM
            const ampm = hours >= 12 ? 'PM' : 'AM';
            hours = hours % 12;
            hours = hours ? hours : 12; // Convert 0 to 12
            
            // Pad numbers with leading zeros
            const paddedDay = day < 10 ? `0${day}` : day;
            const paddedMonth = month < 10 ? `0${month}` : month;
            const paddedHours = hours < 10 ? `0${hours}` : hours;
            const paddedMinutes = minutes < 10 ? `0${minutes}` : minutes;
            const paddedSeconds = seconds < 10 ? `0${seconds}` : seconds;
            
            // Format: DD/MM/YYYY, HH:MM:SS AM/PM
            return `${paddedDay}/${paddedMonth}/${year}, ${paddedHours}:${paddedMinutes}:${paddedSeconds} ${ampm}`;
        } catch (error) {
            errorDebugger('StorageIntegration', 'formatDate', error, 'warn', 'Error occurred while formatting the date');
            return dateStr;
        }
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
        this.showMessagePopup('Warning', 'Are you sure you want to deactivate this?' , `This action will revoke access to ${this.activeTab} and you will need to reconfigure the integration if you want to use it again.`);
    }

    handleConfirmation(event) {
        if(event.detail === true){
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
                    this.showToast('Success', 'Changes has been done successfully.', 'success');
                    this.getSocialMediaDataToShow();
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
    handleModalSelect() {
        try {
            this.showIntegrationModal = false;
            this.getSocialMediaDataToShow();
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

    /**
    * Method Name: toggleClientSecret
    * @description: Used to toggle client secret.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    toggleClientSecret() {
        try {
            this.isClientSecretHidden = !this.isClientSecretHidden;
        } catch (error) {
            errorDebugger('StorageIntegration', 'toggleClientSecret', error, 'warn', 'Error occurred while toggling the client secret');
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