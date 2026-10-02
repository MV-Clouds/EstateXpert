import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import globalStyles from '@salesforce/resourceUrl/globalStyles';
import getIntegrationDetails from '@salesforce/apex/IntegrationPopupController.getIntegrationDetails';
import saveSettings from '@salesforce/apex/IntegrationPopupController.saveSettings';
import getSettings from '@salesforce/apex/IntegrationPopupController.getSettings';
import revokeAWSAccess from '@salesforce/apex/IntegrationPopupController.revokeAWSAccess';
import revokeGmailAccess from '@salesforce/apex/IntegrationPopupController.revokeGmailAccess';
import revokeInstagramAccess from '@salesforce/apex/IntegrationPopupController.revokeInstagramAccess';
import validateIntegrationCredentials from '@salesforce/apex/IntegrationPopupController.validateIntegrationCredentials';
import GMAIL_SENDING_ENDPOINT from '@salesforce/label/c.Gmail_Sending_Endpoint';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { errorDebugger } from 'c/globalProperties';
import Google_Oauth_URL from '@salesforce/label/c.Google_Oauth_URL';
import Gmail_Send_Scope from '@salesforce/label/c.Gmail_Send_Scope';
import Insta_Oauth_URL from '@salesforce/label/c.Insta_Oauth_URL';

export default class StorageIntegration extends NavigationMixin(LightningElement) {
    @track isDataLoaded = false;
    @track showIntegrationModal = false;
    @track isSpinner = true;
    @track integrationName;
    @track integrationLabel;
    @track awsData = { isValid: false, integrationData: {}, showDetails: false };
    @track gmailData = { isValid: false, integrationData: {}, showDetails: false };
    @track instagramData = { isValid: false, integrationData: {}, showDetails: false };
    @track isWaterMarkUploader = false;
    @track activeIntegrationCount = 0;

    // Card-level state for Gmail inline flow 
    @track showGmailInput = false;
    @track gmailRefreshToken = '';       // Refresh Token input

    // Card-level state for Instagram inline flow
    @track showInstagramInput = false;
    @track instagramUserId = '';          // User ID input
    @track instagramLongToken = '';       // Long-Lived Access Token input

    integrationToDeactivate = null;

    // Cached integration settings from Metadata (avoids redundant Apex getSettings calls)
    gmailSettingsData = null;
    instagramSettingsData = null;

    // Disable Save buttons until minimum required fields are filled
    get isGmailSaveDisabled() {
        return !this.gmailRefreshToken || this.gmailRefreshToken.trim() === '';
    }

    get isInstagramSaveDisabled() {
        return (!this.instagramUserId   || this.instagramUserId.trim()   === '') ||
               (!this.instagramLongToken || this.instagramLongToken.trim() === '');
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
            loadStyle(this, globalStyles);
            this.getSocialMediaDataToShow();
        } catch (error) {
            errorDebugger('StorageIntegration', 'connectedCallback', error, 'warn', 'Error occurred while connectedCallback');
        }
    }

    /**
    * Method Name: getSocialMediaDataToShow
    * @description: Used to get data from all integrations.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    async getSocialMediaDataToShow() {
        this.isSpinner = true;
        try {
            const data = await getIntegrationDetails();
            let activeCount = 0;
            data.forEach(item => {
                // Guard: integrationData can be null (e.g. no CMT record found for Gmail)
                if (!item.integrationData) {
                    item.integrationData = {};
                }

                // CMT (Gmail & Instagram) doesn't expose CreatedDate/LastModifiedDate — use SystemModstamp instead
                if ((item.integrationName === 'Gmail' || item.integrationName === 'Instagram') && item.integrationData.SystemModstamp) {
                    item.integrationData.LastModifiedDate = item.integrationData.SystemModstamp;
                }

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
                    const gData = { ...item.integrationData };
                    // Email__c now exists directly on OAuth_Configuration__mdt
                    gData.EmailAddress = gData.Email__c || '';
                    // Format Connected_Date__c (stamped at first connect, cleared on revoke)
                    if (gData.Connected_Date__c) {
                        gData.ConnectedDate = this.formatDate(gData.Connected_Date__c);
                    }
                    this.gmailData = { ...item, integrationData: gData, showDetails: false };
                    if (item.isValid) activeCount++;
                } else if (item.integrationName === 'Instagram') {
                    const igData = { ...item.integrationData };
                    igData.Username__c = igData.Username__c || '';
                    igData.MVEX__User_Id__c = igData.User_Id__c || '';
                    if (igData.Connected_Date__c) {
                        igData.ConnectedDate = this.formatDate(igData.Connected_Date__c);
                        igData.CreatedDate = igData.ConnectedDate;
                    }
                    this.instagramData = { ...item, integrationData: igData, showDetails: false };
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
        } catch (error) {
            errorDebugger('StorageIntegration', 'getSocialMediaDataToShow', error, 'warn', 'Error occurred while fetching data');
        } finally {
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
    async deactivateAWS() {
        this.isSpinner = true;
        try {
            const data = await revokeAWSAccess({ recordId: this.awsData.integrationData.Id });
            if (data === 'success') {
                this.showToast('Success', 'Changes has been done successfully.', 'success');
                await this.getSocialMediaDataToShow();
            } else {
                this.showToast('Error', data, 'error');
            }
        } catch (error) {
            errorDebugger('StorageIntegration', 'deactivateAWS', error, 'warn', 'Error occurred while deactivating AWS');
        } finally {
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
    * @description: Used to open the modal (AWS only).
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
            } else if (integration === 'Instagram') {
                shouldShow = !this.instagramData.showDetails;
            }
            
            // Close all cards first to ensure only one is open
            this.awsData = { ...this.awsData, showDetails: false };
            this.gmailData = { ...this.gmailData, showDetails: false };
            this.instagramData = { ...this.instagramData, showDetails: false };
            
            // Then set the selected card to its new state
            if (integration === 'AWS') {
                this.awsData = { ...this.awsData, showDetails: shouldShow };
            } else if (integration === 'Gmail') {
                this.gmailData = { ...this.gmailData, showDetails: shouldShow };
            } else if (integration === 'Instagram') {
                this.instagramData = { ...this.instagramData, showDetails: shouldShow };
            }
        } catch (error) {
            errorDebugger('StorageIntegration', 'toggleDetails', error, 'warn', 'Error occurred while toggling details');
        }
    }

    // ══ Integration Settings Cache Helper ════════════════════════════════════

    /**
    * Method Name: getIntegrationSettings
    * @description: Retrieves integration configuration (Client ID, Secret, Redirect URI)
    *               from Apex and caches it locally so it is not re-fetched redundantly on Save.
    * @param {String} integrationType - 'Gmail' | 'Instagram'
    * @return {Promise<Object>} Cached or newly fetched settings data.
    */
    async getIntegrationSettings(integrationType) {
        if (integrationType === 'Gmail' && this.gmailSettingsData) {
            return this.gmailSettingsData;
        }
        if (integrationType === 'Instagram' && this.instagramSettingsData) {
            return this.instagramSettingsData;
        }
        const data = await getSettings({ integrationType });
        if (integrationType === 'Gmail') {
            this.gmailSettingsData = data;
        } else if (integrationType === 'Instagram') {
            this.instagramSettingsData = data;
        }
        return data;
    }

    // ══ Gmail — Connect / Input section state ═════════════════════════════════

    /**
    * Method Name: handleGmailConnect
    * @description: Shown when Gmail is inactive. Redirects to Gmail OAuth login page
    *               (same as integrationPopUp) and reveals the input section for manual token entry.
    *               Uses cached getIntegrationSettings to retrieve Client ID / Secret / Redirect URI from Custom Metadata.
    * Created Date: 16/03/2026
    * Created By: Karan Singh
    */
    async handleGmailConnect() {
        this.isSpinner = true;
        try {
            const data = await this.getIntegrationSettings('Gmail');
            if (!data || !data.objectData) {
                this.showToast('Error', 'Missing Configuration (Metadata). Please check Custom Metadata configuration.', 'error');
                return;
            }
            const fieldsData = data.objectData || {};
            const clientId = fieldsData.Client_Id__c;
            const clientSecret = fieldsData.Client_Secret__c;
            const redirectUri = fieldsData.Redirect_URI__c || data.siteUrl;
            if (!clientId || !clientSecret || !redirectUri) {
                this.showToast('Error', 'Missing Configuration (Metadata). Please check Custom Metadata configuration.', 'error');
                return;
            }
            // Show the inline input section so the user can also paste manually
            this.showGmailInput = true;
            // Redirect to Google OAuth — identical URL to integrationPopUp
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: Google_Oauth_URL + 'client_id=' + clientId +
                         '&redirect_uri=' + redirectUri +
                         '&response_type=code&access_type=offline&prompt=consent&scope=' + Gmail_Send_Scope + '%20' + GMAIL_SENDING_ENDPOINT + 'auth/userinfo.email'
                }
            });
        } catch (error) {
            errorDebugger('StorageIntegration', 'handleGmailConnect', error, 'warn', 'Error fetching Gmail settings');
            this.showToast('Error', 'Failed to load Gmail configuration.', 'error');
        } finally {
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
    async saveGmailToken() {
        const token = (this.gmailRefreshToken || '').trim();
        if (!token) {
            this.showToast('Error', 'Please enter a valid refresh token before saving.', 'error');
            return;
        }

        this.isSpinner = true;
        try {
            const data = await this.getIntegrationSettings('Gmail');
            if (!data || !data.objectData) {
                throw new Error('MISSING_CONFIG');
            }
            const fieldsData = data.objectData || {};
            const clientId = fieldsData.Client_Id__c || '';

            // Validate Gmail refresh token before saving
            const validationResult = await validateIntegrationCredentials({ integrationType: 'Gmail', credential1: token, credential2: clientId });
            if (!validationResult || !validationResult.startsWith('SUCCESS')) {
                const valError = new Error(validationResult);
                valError.isValidationError = true;
                throw valError;
            }
            // Parse email from 'SUCCESS|email@example.com'
            const parts = validationResult.split('|');
            const connectedEmail = parts.length > 1 ? parts[1] : '';

            const payload = JSON.stringify({
                Refresh_Token__c: token,
                Email__c:         connectedEmail
            });

            await saveSettings({ jsonData: payload, integrationType: 'Gmail' });
            this.gmailSettingsData = null;

            const nowFormatted = this.formatDate(new Date().toISOString());
            this.gmailData = {
                isValid: true,
                integrationName: 'Gmail',
                showDetails: true,
                integrationData: {
                    EmailAddress: connectedEmail,
                    ConnectedDate: (this.gmailData.integrationData && this.gmailData.integrationData.ConnectedDate) || nowFormatted,
                    LastModifiedDate: nowFormatted,
                    relativeTime: 'Just now'
                }
            };
            this.activeIntegrationCount = (this.awsData.isValid ? 1 : 0) + (this.instagramData.isValid ? 1 : 0) + 1;
            this.showGmailInput = false;
            this.gmailRefreshToken = '';
            this.showToast('Success', 'Gmail has been authorized successfully.', 'success');
        } catch (error) {
            if (error && error.message === 'MISSING_CONFIG') {
                this.showToast('Error', 'Missing Gmail configuration. Please check Custom Metadata.', 'error');
            } else if (error && error.isValidationError) {
                this.showToast('Error', 'Invalid credentials detected. Please check your Refresh Token and try again.', 'error');
            } else {
                errorDebugger('StorageIntegration', 'saveGmailToken', error, 'warn', 'Error saving Gmail token');
                this.showToast('Error', 'An error occurred while saving the token. Please try again.', 'error');
            }
        } finally {
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
    async handleInstagramConnect() {
        this.isSpinner = true;
        try {
            const data = await this.getIntegrationSettings('Instagram');
            if (!data || !data.objectData) {
                this.showToast('Error', 'Missing Configuration (Metadata). Please check Custom Metadata configuration.', 'error');
                return;
            }
            const fieldsData = data.objectData || {};
            // Field names support OAuth_Configuration__mdt as well as fallback
            const clientId     = fieldsData.Client_Id__c;
            const clientSecret = fieldsData.Client_Secret__c;
            const redirectUri  = fieldsData.Redirect_URI__c || data.siteUrl;
            if (!clientId || !clientSecret || !redirectUri) {
                this.showToast('Error', 'Missing Configuration (Metadata). Please check Custom Metadata configuration.', 'error');
                return;
            }
            // Show the inline input section so user can also enter manually
            this.showInstagramInput = true;
            // Redirect to Instagram OAuth — identical URL to integrationPopUp.redirectToInstagramLoginPage
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: Insta_Oauth_URL + 'client_id=' + clientId +
                         '&redirect_uri=' + redirectUri +
                         '&response_type=code&scope=business_basic%2Cbusiness_manage_messages%2Cbusiness_manage_comments%2Cbusiness_content_publish'
                }
            });
        } catch (error) {
            errorDebugger('StorageIntegration', 'handleInstagramConnect', error, 'warn', 'Error fetching Instagram settings');
            this.showToast('Error', 'Failed to load Instagram configuration.', 'error');
        } finally {
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
    async saveInstagramToken() {
        const userId    = (this.instagramUserId    || '').trim();
        const longToken = (this.instagramLongToken || '').trim();
        if (!userId || !longToken) {
            this.showToast('Error', 'Please fill in both User ID and Long-Lived Access Token.', 'error');
            return;
        }
        this.isSpinner = true;
        try {
            const data = await this.getIntegrationSettings('Instagram');
            if (!data || !data.objectData) {
                throw new Error('MISSING_CONFIG');
            }
            const fieldsData = data.objectData || {};
            const clientId     = (fieldsData.Client_Id__c || '').trim();
            const clientSecret = (fieldsData.Client_Secret__c || '').trim();
            const redirectUri  = (fieldsData.Redirect_URI__c  || data.siteUrl || '').trim();

            if (!clientId || !clientSecret || !redirectUri) {
                throw new Error('MISSING_CONFIG');
            }

            // Validate credentials with Instagram API
            const validationResult = await validateIntegrationCredentials({ integrationType: 'Instagram', credential1: userId, credential2: longToken });
            if (!validationResult || !validationResult.startsWith('SUCCESS')) {
                const valError = new Error(validationResult);
                valError.isValidationError = true;
                throw valError;
            }

            // Parse username from 'SUCCESS|username'
            const parts = validationResult.split('|');
            const username = parts.length > 1 ? parts[1] : '';

            const payload = JSON.stringify({
                Client_Id__c:               clientId,
                Client_Secret__c:           clientSecret,
                Redirect_URI__c:            redirectUri,
                User_Id__c:                 userId,
                Access_Token__c:            longToken,
                MVEX__ClientId__c:          clientId,
                MVEX__ClientSecret__c:      clientSecret,
                MVEX__Redirect_URI__c:      redirectUri,
                MVEX__User_Id__c:           userId,
                MVEX__Long_Access_Token__c: longToken,
                Username__c:          username
            });

            await saveSettings({ jsonData: payload, integrationType: 'Instagram' });
            this.instagramSettingsData = null;

            const nowFormatted = this.formatDate(new Date().toISOString());
            this.instagramData = {
                isValid: true,
                integrationName: 'Instagram',
                showDetails: true,
                integrationData: {
                    Username__c: username,
                    User_Id__c: userId,
                    MVEX__User_Id__c: userId,
                    ConnectedDate: (this.instagramData.integrationData && this.instagramData.integrationData.ConnectedDate) || nowFormatted,
                    LastModifiedDate: nowFormatted,
                    relativeTime: 'Just now'
                }
            };
            this.activeIntegrationCount = (this.awsData.isValid ? 1 : 0) + (this.gmailData.isValid ? 1 : 0) + 1;
            this.showInstagramInput = false;
            this.instagramUserId = '';
            this.instagramLongToken = '';
            this.showToast('Success', 'Instagram has been authorized successfully.', 'success');
        } catch (error) {
            if (error && error.message === 'MISSING_CONFIG') {
                this.showToast('Error', 'Missing Instagram configuration. Please check Custom Metadata.', 'error');
            } else if (error && error.isValidationError) {
                this.showToast('Error', 'Invalid credentials detected. Please check your User ID and Access Token and try again.', 'error');
            } else {
                errorDebugger('StorageIntegration', 'saveInstagramToken', error, 'warn', 'Error saving Instagram token');
                this.showToast('Error', 'An error occurred while saving the token. Please try again.', 'error');
            }
        } finally {
            this.isSpinner = false;
        }
    }

    // ══ Deactivation ══════════════════════════════════════════════════════════

    /**
    * Method Name: deactivateGmail
    * @description: Used to deactivate Gmail integration.
    * Created Date: 10/02/2026
    * Created By: Karan Singh
    */
    async deactivateGmail() {
        this.isSpinner = true;
        try {
            const refreshToken = (this.gmailData.integrationData && this.gmailData.integrationData.Refresh_Token__c) || '';
            const data = await revokeGmailAccess({ refreshToken: refreshToken, recordId: this.gmailData.integrationData.Id });
            if (data === 'success') {
                this.gmailSettingsData = null;
                this.gmailData = {
                    isValid: false,
                    integrationName: 'Gmail',
                    showDetails: false,
                    integrationData: {}
                };
                this.activeIntegrationCount = (this.awsData.isValid ? 1 : 0) + (this.instagramData.isValid ? 1 : 0);
                this.showGmailInput = false;
                this.gmailRefreshToken = '';
                this.showToast('Success', 'Gmail integration has been deactivated. Click Connect to re-authorize.', 'success');
            } else {
                this.showToast('Error', data, 'error');
            }
        } catch (error) {
            errorDebugger('StorageIntegration', 'deactivateGmail', error, 'warn', 'Error occurred while deactivating Gmail');
        } finally {
            this.isSpinner = false;
        }
    }

    /**
    * Method Name: deactivateInstagram
    * @description: Used to deactivate Instagram integration.
    * Created Date: 10/02/2026
    * Created By: Karan Singh
    */
    async deactivateInstagram() {
        this.isSpinner = true;
        try {
            const data = await revokeInstagramAccess({ recordId: this.instagramData.integrationData.Id });
            if (data === 'success') {
                this.instagramSettingsData = null;
                this.instagramData = {
                    isValid: false,
                    integrationName: 'Instagram',
                    showDetails: false,
                    integrationData: {}
                };
                this.activeIntegrationCount = (this.awsData.isValid ? 1 : 0) + (this.gmailData.isValid ? 1 : 0);
                this.showInstagramInput = false;
                this.instagramUserId = '';
                this.instagramLongToken = '';
                this.showToast('Success', 'Instagram integration has been deactivated. Click Connect to re-authorize.', 'success');
            } else {
                this.showToast('Error', data, 'error');
            }
        } catch (error) {
            errorDebugger('StorageIntegration', 'deactivateInstagram', error, 'warn', 'Error occurred while deactivating Instagram');
        } finally {
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