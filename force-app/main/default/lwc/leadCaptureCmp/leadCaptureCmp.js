import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import getSocialMediaData from '@salesforce/apex/IntegrationPopupController.getGoogleData';
import revokeGoogleAccess from '@salesforce/apex/IntegrationPopupController.revokeGoogleAccess';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class LeadCaptureCmp extends NavigationMixin(LightningElement) {
    @track isDataLoaded = false;
    @track showIntegrationModal = false;
    @track isSpinner = true;
    @track integrationName;
    @track integrationLabel;
    @track GoogleData = { isValid: false, integrationData: {}, showDetails: false };
    @track MetaData = { isValid: false, integrationData: {}, showDetails: false };
    @track metaVerificationStatus = 'Checking...';
    @track appReviewStatus = 'Checking...';
    @track connectionDetails = {};
    integrationToDeactivate = null;

    get reviewClass() {
        return this.appReviewStatus === 'Verified' ? 'status-success' : 'status-warning';
    }

    get statusClass() {
        return this.metaVerificationStatus === 'Connected' ? 'status-success' : 'status-error';
    }

    get activeIntegrationCount() {
        let count = 0;
        if (this.MetaData.isValid) count++;
        if (this.GoogleData.isValid) count++;
        return count;
    }

    // Helpers for UI display
    get appName() { return this.connectionDetails.application || 'Meta Integration'; }
    get appType() { return this.connectionDetails.type || 'Page Integration'; }
    get tokenExpires() { 
        return this.connectionDetails.data_access_expires_at 
            ? new Date(this.connectionDetails.data_access_expires_at * 1000).toLocaleDateString() 
            : 'Never'; 
    }

    connectedCallback() {
        loadStyle(this, MulishFontCss)
            .then(() => {
                console.log('Css loaded successfully');
            })
            .catch(error => {
                console.log('Error loading style:', error);
            });
        this.getSocialMediaDataToShow();
    }

    getSocialMediaDataToShow() {
        this.isSpinner = true;
        getSocialMediaData({integrationName: ''})
            .then(data => {
                console.log('data-->', data);
                data.forEach(item => {
                    if (item.integrationName === 'GoogleAds') {
                        if (item.integrationData && item.integrationData.CreatedDate) {
                            item.integrationData.CreatedDate = this.formatDate(item.integrationData.CreatedDate);
                        }
                        if (item.integrationData && item.integrationData.LastModifiedDate) {
                            item.integrationData.relativeTime = this.getRelativeTime(item.integrationData.LastModifiedDate);
                            item.integrationData.LastModifiedDate = this.formatDate(item.integrationData.LastModifiedDate);
                        }
                        this.GoogleData = { ...item, showDetails: false };
                    } else if (item.integrationName === 'Meta') {
                        if (item.integrationData && item.integrationData.CreatedDate) {
                            item.integrationData.CreatedDate = this.formatDate(item.integrationData.CreatedDate);
                        }
                        if (item.integrationData && item.integrationData.LastModifiedDate) {
                            item.integrationData.relativeTime = this.getRelativeTime(item.integrationData.LastModifiedDate);
                            item.integrationData.LastModifiedDate = this.formatDate(item.integrationData.LastModifiedDate);
                        }
                        this.MetaData = { ...item, showDetails: false };
                        
                        // NEW LOGIC: Check status if token exists
                        if (item.isValid && item.integrationData.MVEX__ACCESS_TOKEN__c) {
                            this.checkMetaStatus(item.integrationData.MVEX__ACCESS_TOKEN__c);
                        }
                    }
                });
                this.isDataLoaded = true;
                this.isSpinner = false;
            })
            .catch(error => {
                console.log('Error in fetching data -->', error.stack);
                this.isSpinner = false;
            });
    }

    checkMetaStatus(accessToken) {
        // 1. Check Connection Status (Page Token Validity)
        fetch(`https://graph.facebook.com/debug_token?input_token=${accessToken}&access_token=${accessToken}`)
            .then(response => response.json())
            .then(result => {
                if (result.data) {
                    const data = result.data;
                    this.connectionDetails = data;
                    
                    // Update Connection Status based on token validity
                    this.metaVerificationStatus = data.is_valid ? 'Connected' : 'Expired or Invalid';

                    // 2. Check Real App Review Status
                    // Scopes in the token only mean the USER granted it. To see if META approved it, 
                    // we must query the app permissions using the App Secret.
                    const appId = this.MetaData.integrationData.MVEX__APP_ID__c;
                    const appSecret = this.MetaData.integrationData.MVEX__APP_SECRET__c;
                    console.log('App ID:', appId, 'App Secret:', appSecret);
                    
                    if (appId && appSecret) {
                        console.log('Checking App Review Status for App ID:', appId);
                        this.checkAppRealStatus(appId, appSecret);
                    } else {
                         this.appReviewStatus = 'Pending / In-Review';
                    }
                }
            })
            .catch(err => {
                console.error('Meta Status Error:', err);
                this.metaVerificationStatus = 'Connection Error';
                this.appReviewStatus = 'Unknown';
            });
    }

    checkAppRealStatus(appId, appSecret) {
        // Construct an App Access Token to query the Platform Status directly
        const appAccessToken = `${appId}|${appSecret}`;
        console.log('App Access Token:', appAccessToken);
        
        fetch(`https://graph.facebook.com/v21.0/${appId}/permissions?access_token=${appAccessToken}`)
            .then(response => response.json())
            .then(result => {

                console.log('App Permissions Result:', JSON.stringify(result));
                
                if (result.data) {
                    // Check if 'leads_retrieval' is explicitly GRANTED by Meta in the App Review
                    const leadPerm = result.data.find(p => p.permission === 'leads_retrieval');
                    
                    if (leadPerm) {
                         this.appReviewStatus = 'Verified';
                    } else {
                         // If missing or 'declined', the review is not complete
                         this.appReviewStatus = 'Pending / In-Review';
                    }
                } else {
                    console.error('Permission Fetch Error:', result);
                    this.appReviewStatus = 'Check Failed';
                }
            })
            .catch(err => {
                console.error('Network Error:', err);
                this.appReviewStatus = 'Network Error';
            });
    }

    formatDate(dateStr) {
        const date = new Date(dateStr);
        const day = date.getDate();
        const month = date.getMonth() + 1;
        const year = date.getFullYear();
        let hours = date.getHours();
        const minutes = date.getMinutes();
        const seconds = date.getSeconds();
        const ampm = hours >= 12 ? 'PM' : 'AM';
        hours = hours % 12;
        hours = hours ? hours : 12;
        const paddedDay = day < 10 ? `0${day}` : day;
        const paddedMonth = month < 10 ? `0${month}` : month;
        const paddedHours = hours < 10 ? `0${hours}` : hours;
        const paddedMinutes = minutes < 10 ? `0${minutes}` : minutes;
        const paddedSeconds = seconds < 10 ? `0${seconds}` : seconds;
        return `${paddedDay}/${paddedMonth}/${year}, ${paddedHours}:${paddedMinutes}:${paddedSeconds} ${ampm}`;
    }

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

    toggleDetails(event) {
        try {
            const integration = event.currentTarget.dataset.integration;
            
            let shouldShow = false;
            if (integration === 'Meta') {
                shouldShow = !this.MetaData.showDetails;
            } else if (integration === 'Google') {
                shouldShow = !this.GoogleData.showDetails;
            }
            
            // Close all cards first
            this.MetaData = { ...this.MetaData, showDetails: false };
            this.GoogleData = { ...this.GoogleData, showDetails: false };
            
            // Then set the selected card to its new state
            if (integration === 'Meta') {
                this.MetaData = { ...this.MetaData, showDetails: shouldShow };
            } else if (integration === 'Google') {
                this.GoogleData = { ...this.GoogleData, showDetails: shouldShow };
            }
        } catch (error) {
            console.log('Error in toggleDetails:', error);
        }
    }

    handleDeactivateClick(event) {
        const integrationName = event.currentTarget.dataset.integration;
        this.showMessagePopup('Warning', 'Are you sure you want to deactivate this?' , `This action will revoke access to ${integrationName} and you will need to reconfigure the integration if you want to use it again.`);
        this.integrationToDeactivate = integrationName;
    }

    handleConfirmation(event){
        if(event.detail === true && this.integrationToDeactivate){
            switch (this.integrationToDeactivate) {
                case 'Google':
                    this.deactivateGoogle();
                    break;
                case 'Meta':
                    this.deactivateMeta();
                    break;
                default:
                    this.showToast('Error', 'Deactivation not supported for this integration.', 'error');
                    break;
            }
            this.integrationToDeactivate = null;
        }
    }

    deactivateGoogle() {
        this.isSpinner = true;
        revokeGoogleAccess({ recordId: this.GoogleData.integrationData.Id, integrationType: this.activeTab })
            .then(data => {
                if (data === 'success') {
                    this.showToast('Success', 'Changes has been done successfully.', 'success');
                    this.getSocialMediaDataToShow();
                } else {
                    this.showToast('Error', data, 'error');
                }
                this.isSpinner = false;
            });
    }

    deactivateMeta() {
        this.isSpinner = true;
        revokeGoogleAccess({ recordId: this.MetaData.integrationData.Id, integrationType: this.activeTab })
            .then(data => {
                if (data === 'success') {
                    this.showToast('Success', 'Meta integration deactivated successfully.', 'success');
                    this.getSocialMediaDataToShow();
                } else {
                    this.showToast('Error', data, 'error');
                }
                this.isSpinner = false;
            });
    }

    handleModalSelect() {
        this.showIntegrationModal = false;
        this.getSocialMediaDataToShow();
    }

    newIntegrationModal(event) {
        const integrationName = event.target.dataset.name;
        this.integrationName = integrationName;
        this.integrationLabel = integrationName;
        this.showIntegrationModal = true;
    }

   configureMapping(event) {
        try {
            const integrationName = event.target.dataset.name;
            const integrationType = integrationName === 'GoogleAds' ? 'Google' : 'Meta';
            let componentDef = {
                componentDef: "MVEX:googleLeadFieldMapping",
                attributes: {
                    integrationType: integrationType
                }
            };
            let encodedComponentDef = btoa(JSON.stringify(componentDef));
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/one/one.app#' + encodedComponentDef
                }
            });
        } catch (error) {
            console.log('Error in configureMapping:', error);
        }
    }

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

    showToast(title, message, variant) {
        if (typeof window !== "undefined") {
            const event = new ShowToastEvent({
                title: title,
                message: message,
                variant: variant,
            });
            this.dispatchEvent(event);
        }
    }
}