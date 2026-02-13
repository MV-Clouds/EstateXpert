import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import getIntegrationDetails from '@salesforce/apex/IntegrationPopupController.getIntegrationDetails';
import revokeAWSAccess from '@salesforce/apex/IntegrationPopupController.revokeAWSAccess';
import revokeGmailAccess from '@salesforce/apex/IntegrationPopupController.revokeGmailAccess';
import revokeOutlookAccess from '@salesforce/apex/IntegrationPopupController.revokeOutlookAccess';
import revokeInstagramAccess from '@salesforce/apex/IntegrationPopupController.revokeInstagramAccess';
import getMetadataRecords from "@salesforce/apex/ControlCenterController.getMetadataRecords";
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { errorDebugger } from 'c/globalProperties';

export default class StorageIntegration extends NavigationMixin(LightningElement) {
    @track isDataLoaded = false;
    @track showIntegrationModal = false;
    @track isSpinner = true;
    @track integrationName;
    @track integrationLabel;
    @track awsData = { isValid: false, integrationData: {}, showDetails: false };
    @track gmailData = { isValid: false, integrationData: {}, showDetails: false };
    @track outlookData = { isValid: false, integrationData: {}, showDetails: false };
    @track instagramData = { isValid: false, integrationData: {}, showDetails: false };
    @track isWaterMarkUploader = false;
    @track featureAvailability = {};
    @track activeIntegrationCount = 0;
    integrationToDeactivate = null;

    @wire(getMetadataRecords)
    metadataRecords({ error, data }) {
        if (data) {
            this.featureAvailability = data.reduce((acc, record) => {
                acc[record.DeveloperName] = record.MVEX__isAvailable__c;
                return acc;
            }, {});
            setTimeout(() => {
                this.isSpinner = false;
            }, 1000);
        } else if (error) {
            console.error("Error fetching metadata records:", error);
            this.isSpinner = false;
        }
    }

    /**
    * Method Name: getRelativeTime
    * @description: Calculates relative time from timestamp.
    * @param {String} dateStr - Date string
    * @returns {String} - Relative time string
    * Created Date: 10/02/2026
    * Created By: Karan Singh
    */
    getRelativeTime(dateStr) {
        if (!dateStr) return '';
        const now = new Date();
        const past = new Date(dateStr);
        const diffMs = now - past;
        
        const diffSeconds = Math.floor(diffMs / 1000);
        const diffMinutes = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMs / 3600000);
        const diffDays = Math.floor(diffMs / 86400000);
        const diffMonths = Math.floor(diffDays / 30);
        const diffYears = Math.floor(diffDays / 365);
        
        if (diffSeconds < 60) {
            return `Last synced ${diffSeconds} second${diffSeconds !== 1 ? 's' : ''} ago`;
        } else if (diffMinutes < 60) {
            return `Last synced ${diffMinutes} minute${diffMinutes !== 1 ? 's' : ''} ago`;
        } else if (diffHours < 24) {
            return `Last synced ${diffHours} hour${diffHours !== 1 ? 's' : ''} ago`;
        } else if (diffDays < 30) {
            return `Last synced ${diffDays} day${diffDays !== 1 ? 's' : ''} ago`;
        } else if (diffMonths < 12) {
            return `Last synced ${diffMonths} month${diffMonths !== 1 ? 's' : ''} ago`;
        } else {
            return `Last synced ${diffYears} year${diffYears !== 1 ? 's' : ''} ago`;
        }
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
                let activeCount = 0;
                data.forEach(item => {
                    if (item.integrationData.CreatedDate) {
                        item.integrationData.CreatedDate = this.formatDate(item.integrationData.CreatedDate);
                    }
                    if (item.integrationData.LastModifiedDate) {
                        // Calculate relative time BEFORE formatting the date
                        item.integrationData.relativeTime = this.getRelativeTime(item.integrationData.LastModifiedDate);
                        item.integrationData.LastModifiedDate = this.formatDate(item.integrationData.LastModifiedDate);
                    }
                    
                    if (item.integrationName === 'AWS') {
                        this.awsData = { ...item, showDetails: false };
                        if (item.isValid) activeCount++;
                    } else if (item.integrationName === 'Gmail') {
                        this.gmailData = { ...item, showDetails: false };
                        if (item.isValid) activeCount++;
                    } else if (item.integrationName === 'Outlook') {
                        this.outlookData = { ...item, showDetails: false };
                        if (item.isValid) activeCount++;
                    } else if (item.integrationName === 'Instagram') {
                        this.instagramData = { ...item, showDetails: false };
                        if (item.isValid) activeCount++;
                    }
                });
                this.activeIntegrationCount = activeCount;
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

    handleDeactivateClick(event) {
        const integrationName = event.currentTarget.dataset.integration;
        this.showMessagePopup('Warning', 'Are you sure you want to deactivate this?' , `This action will revoke access to ${integrationName} and you will need to reconfigure the integration if you want to use it again.`);
        this.integrationToDeactivate = integrationName;
    }

    handleConfirmation(event) {
        if(event.detail === true && this.integrationToDeactivate){
            switch (this.integrationToDeactivate) {
                case 'AWS':
                    this.deactivateAWS();
                    break;
                case 'Gmail':
                    this.deactivateGmail();
                    break;
                case 'Outlook':
                    this.deactivateOutlook();
                    break;
                case 'Instagram':
                    this.deactivateInstagram();
                    break;
                default:
                    break;
            }
            this.integrationToDeactivate = null;
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

    awsWatermarkUploaderMethod() {
        this.isWaterMarkUploader = true;
    }

    closeWaterMarkModal() {
        this.isWaterMarkUploader = false;
    }

    /**
    * Method Name: toggleDetails
    * @description: Toggles the details view for an integration card.
    * @param {Event} event - Click event
    * Created Date: 10/02/2026
    * Created By: Karan Singh
    */
    toggleDetails(event) {
        try {
            // Use currentTarget to get the element that has the onclick handler and data-integration attribute
            const integration = event.currentTarget.dataset.integration;
            
            // Determine the new state for the clicked card
            let shouldShow = false;
            if (integration === 'AWS') {
                shouldShow = !this.awsData.showDetails;
            } else if (integration === 'Gmail') {
                shouldShow = !this.gmailData.showDetails;
            } else if (integration === 'Outlook') {
                shouldShow = !this.outlookData.showDetails;
            } else if (integration === 'Instagram') {
                shouldShow = !this.instagramData.showDetails;
            }
            
            // Close all cards first to ensure only one is open
            this.awsData = { ...this.awsData, showDetails: false };
            this.gmailData = { ...this.gmailData, showDetails: false };
            this.outlookData = { ...this.outlookData, showDetails: false };
            this.instagramData = { ...this.instagramData, showDetails: false };
            
            // Then set the selected card to its new state
            if (integration === 'AWS') {
                this.awsData = { ...this.awsData, showDetails: shouldShow };
            } else if (integration === 'Gmail') {
                this.gmailData = { ...this.gmailData, showDetails: shouldShow };
            } else if (integration === 'Outlook') {
                this.outlookData = { ...this.outlookData, showDetails: shouldShow };
            } else if (integration === 'Instagram') {
                this.instagramData = { ...this.instagramData, showDetails: shouldShow };
            }
        } catch (error) {
            errorDebugger('StorageIntegration', 'toggleDetails', error, 'warn', 'Error occurred while toggling details');
        }
    }

    /**
    * Method Name: deactivateGmail
    * @description: Used to deactivate Gmail integration.
    * Created Date: 10/02/2026
    * Created By: Karan Singh
    */
    deactivateGmail() {
        try {
            this.isSpinner = true;
            revokeGmailAccess({ refreshToken: this.gmailData.integrationData.MVEX__Refresh_Token__c, recordId: this.gmailData.integrationData.Id })
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
                errorDebugger('StorageIntegration', 'deactivateGmail', error, 'warn', 'Error occurred while deactivating Gmail');
                this.isSpinner = false;
            });
        } catch (error) {
            errorDebugger('StorageIntegration', 'deactivateGmail', error, 'warn', 'Error occurred while deactivating Gmail');
            this.isSpinner = false;            
        }
    }

    /**
    * Method Name: deactivateOutlook
    * @description: Used to deactivate Outlook integration.
    * Created Date: 10/02/2026
    * Created By: Karan Singh
    */
    deactivateOutlook() {
        try {
            this.isSpinner = true;
            revokeOutlookAccess({ refreshToken: this.outlookData.integrationData.MVEX__Refresh_Token__c, recordId: this.outlookData.integrationData.Id })
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
                errorDebugger('StorageIntegration', 'deactivateOutlook', error, 'warn', 'Error occurred while deactivating Outlook');
                this.isSpinner = false;
            });
        } catch (error) {
            errorDebugger('StorageIntegration', 'deactivateOutlook', error, 'warn', 'Error occurred while deactivating Outlook');
            this.isSpinner = false;            
        }
    }

    /**
    * Method Name: deactivateInstagram
    * @description: Used to deactivate Instagram integration.
    * Created Date: 10/02/2026
    * Created By: Karan Singh
    */
    deactivateInstagram() {
        try {
            this.isSpinner = true;
            revokeInstagramAccess({ recordId: this.instagramData.integrationData.Id })
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
                errorDebugger('StorageIntegration', 'deactivateInstagram', error, 'warn', 'Error occurred while deactivating Instagram');
                this.isSpinner = false;
            });
        } catch (error) {
            errorDebugger('StorageIntegration', 'deactivateInstagram', error, 'warn', 'Error occurred while deactivating Instagram');
            this.isSpinner = false;            
        }
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