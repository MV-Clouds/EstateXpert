import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import getIntegrationDetails from '@salesforce/apex/IntegrationPopupController.getIntegrationDetails';
import saveSettings from '@salesforce/apex/IntegrationPopupController.saveSettings';
import getSettings from '@salesforce/apex/IntegrationPopupController.getSettings';
import saveCustomTempData from '@salesforce/apex/IntegrationPopupController.saveCustomTempData';
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

    // Card-level state for Gmail inline flow 
    @track showGmailInput = false;
    @track gmailRefreshToken = '';       // Refresh Token input

    // Card-level state for Instagram inline flow
    @track showInstagramInput = false;
    @track instagramUserId = '';          // User ID input
    @track instagramLongToken = '';       // Long-Lived Access Token input

    integrationToDeactivate = null;

    // Disable Save buttons until minimum required fields are filled
    get isGmailSaveDisabled() {
        return !this.gmailRefreshToken || this.gmailRefreshToken.trim() === '';
    }

    get isInstagramSaveDisabled() {
        return (!this.instagramUserId   || this.instagramUserId.trim()   === '') ||
               (!this.instagramLongToken || this.instagramLongToken.trim() === '');
    }

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
                // Reset inline states after data refresh
                this.showGmailInput = false;
                this.gmailRefreshToken = '';
                this.showInstagramInput = false;
                this.instagramUserId = '';
                this.instagramLongToken = '';
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
            hours = hours % 12 || 12;
            const pad = n => n < 10 ? `0${n}` : n;
            return `${pad(day)}/${pad(month)}/${year}, ${pad(hours)}:${pad(minutes)}:${pad(seconds)} ${ampm}`;
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
    * @description: Used to open the modal (AWS and Outlook only).
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

    // ══ Gmail — Connect / Input section state ═════════════════════════════════

    /**
    * Method Name: handleGmailConnect
    * @description: Shown when Gmail is inactive. Redirects to Gmail OAuth login page
    *               (same as integrationPopUp) and reveals the input section for manual token entry.
    *               Uses getSettings to retrieve Client ID / Secret / Redirect URI from Custom Metadata.
    * Created Date: 16/03/2026
    * Created By: Karan Singh
    */
    handleGmailConnect() {
        try {
            this.isSpinner = true;
            getSettings({ integrationType: 'Gmail' })
                .then(data => {
                    this.isSpinner = false;
                    if (!data || !data.objectData) {
                        this.showToast('Error', 'Missing Configuration (Metadata). Please check Custom Metadata configuration.', 'error');
                        return;
                    }
                    const fieldsData = data.objectData;
                    const requiredFields = ['MVEX__Redirect_URI__c', 'MVEX__Client_ID__c', 'MVEX__Client_Secret__c'];
                    for (const field of requiredFields) {
                        if (!fieldsData[field]) {
                            this.showToast('Error', 'Missing Configuration (Metadata). Please check Custom Metadata configuration.', 'error');
                            return;
                        }
                    }
                    // Show the inline input section so the user can also paste manually
                    this.showGmailInput = true;
                    // Save temp data for the OAuth callback
                    this.saveTempData(fieldsData.MVEX__Client_ID__c, fieldsData.MVEX__Client_Secret__c, fieldsData.MVEX__Redirect_URI__c);
                    // Redirect to Google OAuth — identical URL to integrationPopUp
                    this[NavigationMixin.Navigate]({
                        type: 'standard__webPage',
                        attributes: {
                            url: 'https://accounts.google.com/o/oauth2/auth?client_id=' + fieldsData.MVEX__Client_ID__c +
                                 '&redirect_uri=' + fieldsData.MVEX__Redirect_URI__c +
                                 '&response_type=code&access_type=offline&prompt=consent&scope=https://www.googleapis.com/auth/gmail.send'
                        }
                    });
                })
                .catch(error => {
                    errorDebugger('StorageIntegration', 'handleGmailConnect', error, 'warn', 'Error fetching Gmail settings');
                    this.showToast('Error', 'Failed to load Gmail configuration.', 'error');
                    this.isSpinner = false;
                });
        } catch (error) {
            errorDebugger('StorageIntegration', 'handleGmailConnect', error, 'warn', 'Error in handleGmailConnect');
            this.isSpinner = false;
        }
    }

    /** Cancel Gmail inline input — reset to Connect button state */
    handleGmailCancel() {
        this.showGmailInput = false;
        this.gmailRefreshToken = '';
    }

    /** Capture Gmail Refresh Token from textarea */
    handleGmailTokenChange(event) {
        this.gmailRefreshToken = event.target.value;
    }

    /**
    * Method Name: saveGmailToken
    * @description: Saves the Gmail refresh token together with Client ID, Client Secret and Redirect URI
    *               fetched from Custom Metadata. All four fields are required by getIntegrationDetails.isValid.
    *               Mirrors the full save pattern used in integrationPopUp.saveDetails.
    * Created Date: 16/03/2026
    * Created By: Karan Singh
    */
    saveGmailToken() {
        try {
            const token = (this.gmailRefreshToken || '').trim();
            if (!token) {
                this.showToast('Error', 'Please enter a valid refresh token before saving.', 'error');
                return;
            }
            this.isSpinner = true;
            getSettings({ integrationType: 'Gmail' })
                .then(data => {
                    if (!data || !data.objectData) {
                        // Throw so the .catch() handles spinner + toast
                        throw new Error('MISSING_CONFIG');
                    }
                    const fieldsData = data.objectData;
                    const payload = JSON.stringify({
                        MVEX__Client_ID__c:     fieldsData.MVEX__Client_ID__c     || '',
                        MVEX__Client_Secret__c: fieldsData.MVEX__Client_Secret__c || '',
                        MVEX__Redirect_URI__c:  fieldsData.MVEX__Redirect_URI__c  || '',
                        MVEX__Refresh_Token__c: token
                    });
                    return saveSettings({ jsonData: payload, integrationType: 'Gmail' });
                })
                .then(() => {
                    // Reaches here only when saveSettings resolves successfully
                    this.showToast('Success', 'Gmail has been authorized successfully.', 'success');
                    this.getSocialMediaDataToShow();
                })
                .catch(error => {
                    if (error && error.message === 'MISSING_CONFIG') {
                        this.showToast('Error', 'Missing Gmail configuration. Please check Custom Metadata.', 'error');
                    } else {
                        errorDebugger('StorageIntegration', 'saveGmailToken', error, 'warn', 'Error saving Gmail token');
                        this.showToast('Error', 'An error occurred while saving the token. Please try again.', 'error');
                    }
                    this.isSpinner = false;
                });
        } catch (error) {
            errorDebugger('StorageIntegration', 'saveGmailToken', error, 'warn', 'Error saving Gmail token');
            this.isSpinner = false;
        }
    }

    // ══ Instagram — Connect / Input section state ═════════════════════════════

    /**
    * Method Name: handleInstagramConnect
    * @description: Shown when Instagram is inactive. Redirects to Instagram OAuth login page
    *               (same as integrationPopUp) and reveals the input section.
    *               Uses getSettings to retrieve Client ID / Secret / Redirect URI from Custom Metadata.
    *               Field names mirror integrationPopUp.redirectToInstagramLoginPage: MVEX__ClientId__c (lowercase d).
    * Created Date: 16/03/2026
    * Created By: Karan Singh
    */
    handleInstagramConnect() {
        try {
            this.isSpinner = true;
            getSettings({ integrationType: 'Instagram' })
                .then(data => {
                    this.isSpinner = false;
                    if (!data || !data.objectData) {
                        this.showToast('Error', 'Missing Configuration (Metadata). Please check Custom Metadata configuration.', 'error');
                        return;
                    }
                    const fieldsData = data.objectData;
                    // Field names must match what integrationPopUp uses (MVEX__ClientId__c, MVEX__ClientSecret__c)
                    const clientId     = fieldsData.MVEX__ClientId__c     || fieldsData.MVEX__ClientID__c;
                    const clientSecret = fieldsData.MVEX__ClientSecret__c || fieldsData.MVEX__ClientSecret__c;
                    const redirectUri  = fieldsData.MVEX__Redirect_URI__c || data.siteUrl;
                    if (!clientId || !clientSecret || !redirectUri) {
                        this.showToast('Error', 'Missing Configuration (Metadata). Please check Custom Metadata configuration.', 'error');
                        return;
                    }
                    // Show the inline input section so user can also enter manually
                    this.showInstagramInput = true;
                    // Save temp data for the OAuth callback
                    this.saveTempData(clientId, clientSecret, redirectUri);
                    // Redirect to Instagram OAuth — identical URL to integrationPopUp.redirectToInstagramLoginPage
                    this[NavigationMixin.Navigate]({
                        type: 'standard__webPage',
                        attributes: {
                            url: 'https://www.instagram.com/oauth/authorize?client_id=' + clientId +
                                 '&redirect_uri=' + redirectUri +
                                 '&response_type=code&scope=business_basic%2Cbusiness_manage_messages%2Cbusiness_manage_comments%2Cbusiness_content_publish'
                        }
                    });
                })
                .catch(error => {
                    errorDebugger('StorageIntegration', 'handleInstagramConnect', error, 'warn', 'Error fetching Instagram settings');
                    this.showToast('Error', 'Failed to load Instagram configuration.', 'error');
                    this.isSpinner = false;
                });
        } catch (error) {
            errorDebugger('StorageIntegration', 'handleInstagramConnect', error, 'warn', 'Error in handleInstagramConnect');
            this.isSpinner = false;
        }
    }

    /** Cancel Instagram inline input — reset to Connect button state */
    handleInstagramCancel() {
        this.showInstagramInput = false;
        this.instagramUserId = '';
        this.instagramLongToken = '';
    }

    /** Capture Instagram User ID from input */
    handleInstagramUserIdChange(event) {
        this.instagramUserId = event.target.value;
    }

    /** Capture Instagram Long-Lived Access Token from textarea */
    handleInstagramLongTokenChange(event) {
        this.instagramLongToken = event.target.value;
    }

    /**
    * Method Name: saveInstagramToken
    * @description: Saves Instagram User ID + Long-Lived Access Token together with Client ID and
    *               Client Secret fetched from Custom Metadata. All four fields are required by
    *               getIntegrationDetails.isValid (checks ClientId__c and ClientSecret__c).
    * Created Date: 16/03/2026
    * Created By: Karan Singh
    */
    saveInstagramToken() {
        try {
            const userId    = (this.instagramUserId    || '').trim();
            const longToken = (this.instagramLongToken || '').trim();
            if (!userId || !longToken) {
                this.showToast('Error', 'Please fill in both User ID and Long-Lived Access Token.', 'error');
                return;
            }
            this.isSpinner = true;
            getSettings({ integrationType: 'Instagram' })
                .then(data => {
                    if (!data || !data.objectData) {
                        // Throw so the .catch() handles spinner + toast
                        throw new Error('MISSING_CONFIG');
                    }
                    const fieldsData = data.objectData;
                    const clientId     = fieldsData.MVEX__ClientId__c     || fieldsData.MVEX__ClientID__c     || '';
                    const clientSecret = fieldsData.MVEX__ClientSecret__c || '';
                    const redirectUri  = fieldsData.MVEX__Redirect_URI__c  || data.siteUrl || '';
                    const payload = JSON.stringify({
                        MVEX__ClientId__c:          clientId,
                        MVEX__ClientSecret__c:      clientSecret,
                        MVEX__Redirect_URI__c:      redirectUri,
                        MVEX__User_Id__c:           userId,
                        MVEX__Long_Access_Token__c: longToken
                    });
                    return saveSettings({ jsonData: payload, integrationType: 'Instagram' });
                })
                .then(() => {
                    // Reaches here only when saveSettings resolves successfully
                    this.showToast('Success', 'Instagram has been authorized successfully.', 'success');
                    this.getSocialMediaDataToShow();
                })
                .catch(error => {
                    if (error && error.message === 'MISSING_CONFIG') {
                        this.showToast('Error', 'Missing Instagram configuration. Please check Custom Metadata.', 'error');
                    } else {
                        errorDebugger('StorageIntegration', 'saveInstagramToken', error, 'warn', 'Error saving Instagram token');
                        this.showToast('Error', 'An error occurred while saving the token. Please try again.', 'error');
                    }
                    this.isSpinner = false;
                });
        } catch (error) {
            errorDebugger('StorageIntegration', 'saveInstagramToken', error, 'warn', 'Error saving Instagram token');
            this.isSpinner = false;
        }
    }

    // ══ Shared OAuth helper ═══════════════════════════════════════════════════

    /**
    * Method Name: saveTempData
    * @description: Saves OAuth credentials to TempData__c custom setting before redirecting.
    *               Mirrors the same method in integrationPopUp.
    * Created Date: 16/03/2026
    * Created By: Karan Singh
    */
    saveTempData(clientId, clientSecret, redirectURI) {
        try {
            saveCustomTempData({ clientId, clientSecret, redirectURI })
                .then(() => { console.log('Temp data saved successfully.'); })
                .catch(error => { console.log('Failed to save temp data:', error); });
        } catch (error) {
            console.log('Error in saveTempData:', error);
        }
    }

    // ══ Deactivation ══════════════════════════════════════════════════════════

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
                    this.showToast('Success', 'Gmail integration has been deactivated. Click Connect to re-authorize.', 'success');
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
                    this.showToast('Success', 'Instagram integration has been deactivated. Click Connect to re-authorize.', 'success');
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
        const messageContainer = this.template.querySelector('c-message-popup');
        if (messageContainer) {
            messageContainer.showMessagePopup({
                status: Status,
                title: Title,
                message: Message,
            });
        }
    }
}