import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import getIntegrationDetails from '@salesforce/apex/IntegrationPopupController.getIntegrationDetails';
import revokeGmailAccess from '@salesforce/apex/IntegrationPopupController.revokeGmailAccess';
import revokeOutlookAccess from '@salesforce/apex/IntegrationPopupController.revokeOutlookAccess';
import getMetadataRecords from "@salesforce/apex/ControlCenterController.getMetadataRecords";

export default class EmailIntegration extends NavigationMixin(LightningElement) {
    @track isDataLoaded = false;
    @api activeTab = 'Gmail';
    @track showIntegrationModal = false;
    @track isSpinner = true;
    @track integrationName;
    @track integrationLabel;
    @track outlookData;
    @track gmailData;
    @track isClientSecretHidden = true;
    @track featureAvailability = {};
    
    // Constants for credential placeholders
    CREDENTIAL_PLACEHOLDER = '••••••••••••••••';
    CREDENTIAL_DISPLAY_TEXT = 'Confidential Information - Hidden for Security';

    @wire(getMetadataRecords)
    metadataRecords({ error, data }) {
        if (data) {
            this.featureAvailability = data.reduce((acc, record) => {
                acc[record.DeveloperName] = record.MVEX__isAvailable__c;
                return acc;
            }, {});
            setTimeout(() => {
                this.isLoading = false;
            }, 1000);
        } else if (error) {
            console.error("Error fetching metadata records:", error);
            this.isLoading = false;
        }
    }

    /**
    * Method Name: isGmail
    * @description: Used to check if Gmail tab is active.
    * @returns {Boolean} - Returns true if Gmail tab is active.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    get isGmail() {
        return this.activeTab === 'Gmail';
    }

    /**
    * Method Name: isOutlook
    * @description: Used to check if Outlook tab is active.
    * @returns {Boolean} - Returns true if Outlook tab is active.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    get isOutlook() {
        return this.activeTab === 'Outlook';
    }

    /**
    * Method Name: gmailClass
    * @description: Used to check if Gmail tab is active.
    * @returns {Boolean} - Returns true if Gmail tab is active.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    get gmailClass() {
        return this.activeTab === 'Gmail' ? 'active' : '';
    }

    /**
    * Method Name: outlookClass
    * @description: Used to check if Outlook tab is active.
    * @returns {Boolean} - Returns true if Outlook tab is active.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    get outlookClass() {
        return this.activeTab === 'Outlook' ? 'active' : '';
    }

    /**
    * Method Name: displayedClientId
    * @description: Used to get client ID with placeholder.
    * @returns {String} - Returns placeholder for client ID.
    * Created Date: 21/01/2026
    * Created By: Karan Singh
    */
    get displayedClientId() {
        return this.CREDENTIAL_DISPLAY_TEXT;
    }

    /**
    * Method Name: displayedClientSecret
    * @description: Used to get client secret with placeholder.
    * @returns {String} - Returns placeholder for client secret.
    * Created Date: 27/12/2024
    * Updated Date: 21/01/2026
    * Created By: Karan Singh
    */
    get displayedClientSecret() {
        return this.CREDENTIAL_DISPLAY_TEXT;
    }

    /**
    * Method Name: displayedRefreshToken
    * @description: Used to get refresh token with placeholder.
    * @returns {String} - Returns placeholder for refresh token.
    * Created Date: 21/01/2026
    * Created By: Karan Singh
    */
    get displayedRefreshToken() {
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
            loadStyle(this, MulishFontCss)
            .then(() => {
                console.log('Css loaded successfully');
            })
            .catch(error => {
                console.log('Error loading style:', error);
            });
            this.getSocialMediaDataToShow();
        } catch (error) {
            console.log('Error in connectedCallback:', error);
        }
    }

    /**
    * Method Name: getSocialMediaDataToShow
    * @description: Used to get data from social media integration.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    getSocialMediaDataToShow(){
        try {
            this.isDataLoaded = false;
            this.isSpinner = true;
            getIntegrationDetails()
            .then(data => {
                data.forEach(item => {
                    if (item.integrationName === 'Outlook') {
                        if (item.integrationData && item.integrationData.CreatedDate) {
                            item.integrationData.CreatedDate = this.formatDate(item.integrationData.CreatedDate);
                        }
                        if (item.integrationData && item.integrationData.LastModifiedDate) {
                            item.integrationData.LastModifiedDate = this.formatDate(item.integrationData.LastModifiedDate);
                        }
                        this.outlookData = item;
                    } 
                    
                    if (item.integrationName === 'Gmail') {
                        if (item.integrationData && item.integrationData.CreatedDate) {
                            item.integrationData.CreatedDate = this.formatDate(item.integrationData.CreatedDate);
                        }
                        if (item.integrationData && item.integrationData.LastModifiedDate) {
                            item.integrationData.LastModifiedDate = this.formatDate(item.integrationData.LastModifiedDate);
                        }
                        this.gmailData = item;
                    }
                });
                this.isDataLoaded = true;
                this.isSpinner = false;
            })
            .catch(error => {
                console.log('Error in fetching data -->', error.stack);
                this.isSpinner = false;
            });
        } catch (error) {
            console.log('error--> ',error);
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
            console.log('error in formatDate:', error);
            return dateStr;
        }
    }

    /**
    * Method Name: handleGmailClick
    * @description: Used to set active tab.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    handleGmailClick() {
        try {
            this.activeTab = 'Gmail';
        } catch (error) {
            console.log('Error in handleGmailClick:', error);
        }
    }

    /**
    * Method Name: handleOutlookClick
    * @description: Used to set active tab.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    handleOutlookClick() {
        try {
            this.activeTab = 'Outlook';   
        } catch (error) {
            console.log('Error in handleOutlookClick:', error);
        }
    }

    /**
    * Method Name: deactivateGmail
    * @description: Used to deactivate Gmail.
    * Created Date: 27/12/2024
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
                console.log('Error in fetching data -->', error);
                this.isSpinner = false;
            });
        } catch (error) {
            console.log('Error in deactivateGmail:', error);  
            this.isSpinner = false;
        }
    }

    handleDeactivateClick() {
        this.showMessagePopup('Warning','Deactivate Integration','Are you sure you want to deactivate this integration? This action cannot be undone.');
    }

    handleConfirmation(event) {
        if(event.detail === true){
            switch (this.activeTab) {
                case 'Gmail':
                    this.deactivateGmail();
                    break;
                case 'Outlook':
                    this.deactivateOutlook();
                    break;
                default:
                    break;
            }
        }
    }

    /**
    * Method Name: deactivateOutlook
    * @description: Used to deactivate Outlook.
    * Created Date: 27/12/2024
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
                console.log('Error in fetching data -->', error);
                this.isSpinner = false;
            });
        } catch (error) {
            console.log('Error in deactivateOutlook:', error);    
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
            console.log('error--> ',error);
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
            console.error('Error in handleModalSelect:', error); 
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
            console.error('Error in newIntegrationModal:', error); 
        }
    }

    handleAWSClick(event) {
        event.preventDefault();
        let componentDef = {
            componentDef: "MVEX:storageIntegration"
        };

        let encodedComponentDef = btoa(JSON.stringify(componentDef));
        this[NavigationMixin.Navigate]({
            type: "standard__webPage",
            attributes: {
                url: "/one/one.app#" + encodedComponentDef
            }
        });
    }

    handleInstagramClick(event) {
        event.preventDefault();
        let componentDef = {
            componentDef: "MVEX:socialMediaIntegration"
        };

        let encodedComponentDef = btoa(JSON.stringify(componentDef));
        this[NavigationMixin.Navigate]({
            type: "standard__webPage",
            attributes: {
                url: "/one/one.app#" + encodedComponentDef
            }
        });
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
        if (typeof window !== 'undefined') {
            const event = new ShowToastEvent({
                title: title,
                message: message,
                variant: variant,
            });
            this.dispatchEvent(event);
        }
    }

    /**
    * Method Name: toggleClientSecret
    * @description: Used to toggle client secret.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    toggleClientSecret() {
        this.isClientSecretHidden = !this.isClientSecretHidden;
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