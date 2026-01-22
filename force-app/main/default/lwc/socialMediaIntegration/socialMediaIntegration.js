import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import getSocialMediaData from '@salesforce/apex/IntegrationPopupController.getSocialMediaData';
import revokeInstagramAccess from '@salesforce/apex/IntegrationPopupController.revokeInstagramAccess';
import unlinkAccount from '@salesforce/apex/WhatsappConfigController.unlinkAccount';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import FacebookSdk from '@salesforce/resourceUrl/FacebookSdk';

export default class SocialMediaIntegration extends NavigationMixin(LightningElement) {
    @api c__status = '';
    @api redirectto = '';
    @track isDataLoaded = false;
    @track isVfLoaded = false;
    @track activeTab = 'WhatsApp';
    @track showIntegrationModal = false;
    @track isSpinner = true;
    @track integrationName;
    @track integrationLabel;
    @track instagramData;
    @track isClientSecretHidden = true;
    @track whatsappUrl = `/apex/MVEX__facebookSDK?source=lwc&t=${Date.now()}`;
    lastClickTime = 0;
    debounceDelay = 500;
    CREDENTIAL_DISPLAY_TEXT = 'Confidential Information - Hidden for Security';

    get isWhatsApp() {
        return this.activeTab === 'WhatsApp';
    }

    get isInstagram() {
        return this.activeTab === 'Instagram';
    }

    get whatsappClass() {
        return this.activeTab === 'WhatsApp' ? 'active' : '';
    }

    get instagramClass() {
        return this.activeTab === 'Instagram' ? 'active' : '';
    }

    get displayedClientId() {
        return this.CREDENTIAL_DISPLAY_TEXT;
    }

    get displayedClientSecret() {
        return this.CREDENTIAL_DISPLAY_TEXT;
    }

    get displayedAccessToken() {
        return this.CREDENTIAL_DISPLAY_TEXT;
    }

    get displayedLongAccessToken() {
        return this.CREDENTIAL_DISPLAY_TEXT;
    }

    connectedCallback() {
        loadStyle(this, MulishFontCss)
            .then(() => {
                console.log('CSS loaded successfully');
            })
            .catch(error => {
                console.error('Error loading style:', error);
            });

        loadScript(this, FacebookSdk)
            .then(() => {
                console.log('Facebook SDK loaded successfully');
            })
            .catch(error => {
                console.error('Error loading Facebook SDK:', error);
            });

        this.getSocialMediaDataToShow();

        if (this.c__status === 'success') {
            this.showToast('Success', 'Permanent access token generated successfully!', 'success');
        } else if (this.c__status === 'fail') {
            this.showToast('Error', 'Failed to generate access token.', 'error');
        }

        if (this.redirectto === 'instagramPost') {
            this.activeTab = 'Instagram';
        }

        window.addEventListener('message', this.handleVfPageLoaded.bind(this));
    }

    disconnectedCallback() {
        window.removeEventListener('message', this.handleVfPageLoaded.bind(this));
    }

    handleVfPageLoaded(event) {
        if (event.data === 'vfPageLoaded' && event.source === this.template.querySelector('iframe.whatsapp-iframe')?.contentWindow) {
            this.isVfLoaded = true;
        } else if (event.data === 'reloadVF') {
            this.isVfLoaded = false;
            this.whatsappUrl = `/apex/MVEX__facebookSDK?source=lwc&t=${Date.now()}`;
        } else if (event.data === 'triggerUnlink') {
            this.showMessagePopup('Warning','Delete Integration','Are you sure you want to delete this integration? This action cannot be undone.');
        }
    }

    handleUnlink() {
        this.isSpinner = true;
        unlinkAccount()
            .then(result => {
                this.isSpinner = false;
                if (result) {
                    this.template.querySelector('iframe.whatsapp-iframe').contentWindow.postMessage('unlinkSuccess', '*');
                    this.showToast('Success', 'WhatsApp account unlinked successfully.', 'success');
                } else {
                    this.template.querySelector('iframe.whatsapp-iframe').contentWindow.postMessage('unlinkError', '*');
                    this.showToast('Error', 'Failed to unlink WhatsApp account.', 'error');
                }
            })
            .catch(error => {
                this.isSpinner = false;
                console.error('Error unlinking WhatsApp:', error);
                this.template.querySelector('iframe.whatsapp-iframe').contentWindow.postMessage('unlinkError', '*');
                this.showToast('Error', 'Error unlinking WhatsApp account: ' + error.body?.message || 'Unknown error', 'error');
            });
    }

    getSocialMediaDataToShow() {
        this.isSpinner = true;
        getSocialMediaData()
            .then(data => {
                data.forEach(item => {
                    if (item.integraName === 'Instagram') {
                        if (item.integrationData && item.integrationData.CreatedDate) {
                            item.integrationData.CreatedDate = this.formatDate(item.integrationData.CreatedDate);
                        }
                        if (item.integrationData && item.integrationData.LastModifiedDate) {
                            item.integrationData.LastModifiedDate = this.formatDate(item.integrationData.LastModifiedDate);
                        }
                        this.instagramData = item;
                    }
                });
                this.isDataLoaded = true;
                this.isSpinner = false;
            })
            .catch(error => {
                console.error('Error fetching data:', error);
                this.isSpinner = false;
                this.showToast('Error', 'Failed to load social media data.', 'error');
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

    handleWhatsAppClick() {
        const now = Date.now();
        if (now - this.lastClickTime < this.debounceDelay) {
            return;
        }
        this.lastClickTime = now;

        if (this.activeTab !== 'WhatsApp') {
            this.activeTab = 'WhatsApp';
            this.isVfLoaded = false;
            this.whatsappUrl = `/apex/MVEX__facebookSDK?source=lwc&t=${Date.now()}`;
        }
    }

    handleInstagramClick() {
        const now = Date.now();
        if (now - this.lastClickTime < this.debounceDelay) {
            return;
        }
        this.lastClickTime = now;
        this.activeTab = 'Instagram';
    }

    deactivateInstagram() {
        this.showMessagePopup('Warning','Delete Integration','Are you sure you want to delete this integration? This action cannot be undone.');
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
            console.error('Navigation error:', error);
        }
    }

    newIntegrationModal(event) {
        const integrationName = event.target.dataset.name;
        this.integrationName = integrationName;
        this.integrationLabel = integrationName;
        this.showIntegrationModal = true;
    }

    handleModalSelect() {
        this.showIntegrationModal = false;
        this.getSocialMediaDataToShow();
    }

    toggleClientSecret() {
        this.isClientSecretHidden = !this.isClientSecretHidden;
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

    handleConfirmation(event) {
        if(event.detail === true){
            switch (this.activeTab) {
                case 'WhatsApp':
                    this.handleUnlink();
                    break;
                case 'Instagram':
                    this.deleteInstagram();
                    break;
                default:
                    break;
            }
        }
    }

    deleteInstagram() {
        this.isSpinner = true;
        revokeInstagramAccess({ recordId: this.instagramData.integrationData.Id })
            .then(data => {
                if (data === 'success') {
                    this.showToast('Success', 'Changes have been done successfully.', 'success');
                    this.getSocialMediaDataToShow();
                } else {
                    this.showToast('Error', data, 'error');
                }
            })
            .catch(error => {
                console.error('Error deactivating Instagram:', error);
                this.isSpinner = false;
                this.showToast('Error', 'Failed to deactivate Instagram.', 'error');
            });
    }
}