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