import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import getSocialMediaData from '@salesforce/apex/IntegrationPopupController.getGoogleData';
import revokeGoogleAccess from '@salesforce/apex/IntegrationPopupController.revokeGoogleAccess';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class LeadCaptureCmp extends NavigationMixin(LightningElement) {
    @api integrationType = 'Meta';
    @track isDataLoaded = false;
    @track activeTab = 'Meta';
    @track showIntegrationModal = false;
    @track isSpinner = true;
    @track integrationName = 'GoogleAds';
    @track integrationLabel;
    @track GoogleData = {};
    @track MetaData = {};
    @track isClientSecretHidden = true;
    CREDENTIAL_DISPLAY_TEXT = 'Confidential Information - Hidden for Security';
    @track metaVerificationStatus = 'Checking...';
    @track appReviewStatus = 'Checking...';
    @track connectionDetails = {};

    get isGoogle() {
        return this.activeTab === 'Google';
    }

    get isMeta() {
        return this.activeTab === 'Meta';
    }

    get GoogleClass() {
        return this.activeTab === 'Google' ? 'active' : '';
    }

    get MetaClass() {
        return this.activeTab === 'Meta' ? 'active' : '';
    }

    get displayedAccessToken() {
        return this.CREDENTIAL_DISPLAY_TEXT;
    }

    get reviewClass() {
        return this.appReviewStatus === 'Verified' ? 'status-success' : 'status-warning';
    }

    get statusClass() {
        return this.metaVerificationStatus === 'Connected' ? 'status-success' : 'status-error';
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
        this.activeTab = this.integrationType;
        this.integrationName = this.integrationType === 'Google' ? 'GoogleAds' : 'Meta';
        this.getSocialMediaDataToShow();
    }

    getSocialMediaDataToShow() {
        this.isSpinner = true;
        getSocialMediaData({integrationName:this.integrationName})
            .then(data => {
                console.log('data-->', data);
                data.forEach(item => {
                    if (item.integrationName === 'GoogleAds') {
                        if (item.integrationData && item.integrationData.CreatedDate) {
                            item.integrationData.CreatedDate = this.formatDate(item.integrationData.CreatedDate);
                        }
                        if (item.integrationData && item.integrationData.LastModifiedDate) {
                            item.integrationData.LastModifiedDate = this.formatDate(item.integrationData.LastModifiedDate);
                        }
                        this.integrationName = 'GoogleAds';
                        this.GoogleData = item;
                    } else if (item.integrationName === 'Meta') {
                        if (item.integrationData && item.integrationData.CreatedDate) {
                            item.integrationData.CreatedDate = this.formatDate(item.integrationData.CreatedDate);
                        }
                        if (item.integrationData && item.integrationData.LastModifiedDate) {
                            item.integrationData.LastModifiedDate = this.formatDate(item.integrationData.LastModifiedDate);
                        }
                        this.integrationName = 'Meta';
                        this.MetaData = item;
                        
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

    handleGoogleClick() {
        this.activeTab = 'Google';
        this.integrationName = 'GoogleAds';
        this.getSocialMediaDataToShow();
    }

    handleMetaClick() {
        this.activeTab = 'Meta';
        this.integrationName = 'Meta';
        this.getSocialMediaDataToShow();
    }

    handleDeactivateProcess() {
        this.showMessagePopup('Warning', 'Do you want to deactive this?', `This will remove the integration and all associated data.`);
    }

    handleConfirmation(event){
        if(event.detail === true){
            switch (this.activeTab) {
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

    toggleClientSecret() {
        this.isClientSecretHidden = !this.isClientSecretHidden;
    }

   configureMapping() {
        try {
            let componentDef = {
                componentDef: "MVEX:googleLeadFieldMapping",
                attributes: {
                    integrationType: this.activeTab // Pass 'Google' or 'Meta'
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

    // configureMetaMapping() {
    //     // Reuse the same component for Meta Ads
    //     this.configureMapping(); // Meta context is handled by activeTab
    // }

    // configureMetaMapping() {
    //     try {
    //         let componentDef = {
    //             componentDef: "MVEXP:metaLeadFieldMapping"
    //         };
    //         let encodedComponentDef = btoa(JSON.stringify(componentDef));
    //         this[NavigationMixin.Navigate]({
    //             type: 'standard__webPage',
    //             attributes: {
    //                 url: '/one/one.app#' + encodedComponentDef
    //             }
    //         });
    //     } catch (error) {
    //         console.log('Error in configureMetaMapping:', error);
    //     }
    // }

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