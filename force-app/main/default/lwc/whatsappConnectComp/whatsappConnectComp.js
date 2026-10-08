import { LightningElement, track } from 'lwc';
import getIntegrationConfig from '@salesforce/apex/WhatsappConnectController.getIntegrationConfig';
import unlinkAccount from '@salesforce/apex/WhatsappConnectController.unlinkAccount';
import saveManualDetails from '@salesforce/apex/WhatsappConnectController.saveManualDetails';
import saveFBLoginDetails from '@salesforce/apex/WhatsappConnectController.saveFBLoginDetails';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/leadassignmentcss';
import GlobalStylesCss from '@salesforce/resourceUrl/globalStyles';

export default class WhatsappConnectComp extends LightningElement {
    @track isLoading = false;
    @track isConnecting = false;
    @track isSubmitting = false;

    // Integration state
    @track isConnected = false;
    @track clientId = '';
    @track configurationId = '';
    @track apiVersion = '26.0';
    @track apiEndpoint = 'https://graph.facebook.com';
    @track appId = '';
    @track businessAccountId = '';
    @track phoneNumberId = '';
    @track accessToken = '';
    @track lastModifiedDate = '';

    // Setup input state
    @track appIdInput = '';
    @track errorMessage = '';
    @track isCopied = false;

    // Modals
    @track isDeactivateModalOpen = false;
    @track isManualModalOpen = false;
    @track manualErrorText = '';
    @track manualForm = {
        appId: '',
        wabaId: '',
        phoneId: '',
        accessToken: ''
    };

    get isMissingConfig() {
        return !this.clientId;
    }

    get isConnectBtnDisabled() {
        return this.isConnecting || !this.appIdInput;
    }

    async connectedCallback() {
        try {
            this.isLoading = true;
            Promise.all([
                loadStyle(this, MulishFontCss),
                loadStyle(this, GlobalStylesCss)
            ]).catch(err => {
                console.error('Error loading fonts / styles in WhatsappConnectComp:', err);
            });

            await this.loadIntegrationConfig();
            this.loadMetaSdk();
        } catch (error) {
            console.error('Error in connectedCallback of WhatsappConnectComp:', error);
        } finally {
            this.isLoading = false;
        }
    }

    // ── Fetch saved integration credentials and status ───────────────────────
    async loadIntegrationConfig() {
        try {
            const data = await getIntegrationConfig();
            if (data) {
                this.clientId = data.clientId || '';
                this.configurationId = data.configurationId || '';
                this.apiVersion = data.apiVersion || '26.0';
                this.apiEndpoint = data.apiEndpoint || 'https://graph.facebook.com';
                this.appId = data.appId || '';
                this.businessAccountId = data.businessAccountId || '';
                this.phoneNumberId = data.phoneNumberId || '';
                this.accessToken = data.accessToken || '';
                this.lastModifiedDate = data.lastModifiedDate || '';
                this.isConnected = data.isConnected || false;

                if (this.appId) {
                    this.appIdInput = this.appId;
                }
            }
        } catch (error) {
            console.error('Error fetching integration config:', error);
            this.showToast('Error', 'Unable to fetch WhatsApp configuration data.', 'error');
        }
    }

    // ── Load Meta / Facebook JS SDK ──────────────────────────────────────────
    loadMetaSdk() {
        if (window.FB) {
            this.initFbSdk();
            return;
        }

        window.fbAsyncInit = () => {
            this.initFbSdk();
        };

        // Inject Meta SDK script if not already in document
        if (!document.getElementById('facebook-jssdk')) {
            const script = document.createElement('script');
            script.id = 'facebook-jssdk';
            script.src = 'https://connect.facebook.net/en_US/sdk.js';
            script.async = true;
            script.defer = true;
            script.crossOrigin = 'anonymous';
            document.head.appendChild(script);
        }
    }

    initFbSdk() {
        try {
            if (window.FB && this.clientId) {
                window.FB.init({
                    appId: this.clientId,
                    cookie: true,
                    xfbml: true,
                    version: `v${this.apiVersion}`
                });
            }
        } catch (e) {
            console.error('Error initializing FB SDK:', e);
        }
    }

    // ── Setup Form Handlers ──────────────────────────────────────────────────
    handleAppIdInputChange(event) {
        this.appIdInput = event.target.value;
        if (this.errorMessage && this.appIdInput) {
            this.errorMessage = '';
        }
    }

    hideError() {
        this.errorMessage = '';
    }

    showError(msg) {
        this.errorMessage = msg;
    }

    launchWhatsAppSignup() {
        this.hideError();

        if (!this.appIdInput || !this.appIdInput.trim()) {
            this.showError('Please enter your Meta Application ID to proceed.');
            return;
        }

        if (!this.clientId) {
            this.showError('Could not find OAuth Tech Provider configuration. Please check Custom Metadata settings.');
            return;
        }

        if (typeof window.FB === 'undefined') {
            this.showError('Meta SDK is still initializing... please wait a few seconds and try again, or use manual configuration.');
            return;
        }

        this.isConnecting = true;

        try {
            window.FB.login((response) => {
                this.handleFbLoginResponse(response);
            }, {
                config_id: this.configurationId,
                response_type: 'code',
                override_default_response_type: true,
                extras: {
                    setup: {},
                    featureType: '',
                    sessionInfoVersion: '2'
                }
            });
        } catch (e) {
            console.error('Error initiating FB login:', e);
            this.isConnecting = false;
            this.showError('Failed to launch Meta login. You can enter credentials manually.');
        }
    }

    async handleFbLoginResponse(response) {
        try {
            if (response && response.authResponse && response.authResponse.accessToken) {
                this.isLoading = true;
                const token = response.authResponse.accessToken;
                // Callback details from FB window message or response
                const result = await saveFBLoginDetails({
                    sAccessToken: token,
                    phoneId: this.phoneNumberId || '',
                    wabaId: this.businessAccountId || '',
                    appId: this.appIdInput.trim()
                });

                if (result && result !== 'Failure') {
                    this.showToast('Success', 'WhatsApp Business connected successfully!', 'success');
                    await this.loadIntegrationConfig();
                } else {
                    this.showError('Error connecting account via Meta SDK. Please try manual entry.');
                }
            } else {
                console.log('User cancelled FB login or authorization failed.');
            }
        } catch (error) {
            console.error('Error processing login response:', error);
            this.showError('Failed to exchange login token with Salesforce.');
        } finally {
            this.isConnecting = false;
            this.isLoading = false;
        }
    }

    // ── Copy WABA ID ─────────────────────────────────────────────────────────
    copyWabaId() {
        if (!this.businessAccountId) return;
        try {
            if (navigator && navigator.clipboard) {
                navigator.clipboard.writeText(this.businessAccountId).then(() => {
                    this.isCopied = true;
                    setTimeout(() => {
                        this.isCopied = false;
                    }, 2000);
                });
            } else {
                const tempInput = document.createElement('input');
                tempInput.value = this.businessAccountId;
                document.body.appendChild(tempInput);
                tempInput.select();
                document.execCommand('copy');
                document.body.removeChild(tempInput);
                this.isCopied = true;
                setTimeout(() => {
                    this.isCopied = false;
                }, 2000);
            }
            this.showToast('Copied', 'WhatsApp Business Account ID copied to clipboard.', 'success');
        } catch (e) {
            console.error('Clipboard copy failed:', e);
        }
    }

    // ── Deactivate Modal ─────────────────────────────────────────────────────
    openDeactivateModal() {
        this.isDeactivateModalOpen = true;
    }

    closeDeactivateModal() {
        this.isDeactivateModalOpen = false;
    }

    async confirmDeactivate() {
        try {
            this.isSubmitting = true;
            this.isLoading = true;
            const success = await unlinkAccount();
            if (success) {
                this.closeDeactivateModal();
                this.showToast('Disconnected', 'WhatsApp integration disconnected successfully.', 'success');
                await this.loadIntegrationConfig();
            } else {
                this.showToast('Error', 'Failed to deactivate WhatsApp integration. Please try again.', 'error');
            }
        } catch (error) {
            console.error('Error during deactivation:', error);
            this.showToast('Error', error.body?.message || error.message || 'Error deactivating account.', 'error');
        } finally {
            this.isSubmitting = false;
            this.isLoading = false;
        }
    }

    // ── Manual Configuration Modal ───────────────────────────────────────────
    openManualConfigModal() {
        this.manualForm = {
            appId: this.appId || this.appIdInput || '',
            wabaId: this.businessAccountId || '',
            phoneId: this.phoneNumberId || '',
            accessToken: this.accessToken || ''
        };
        this.manualErrorText = '';
        this.isManualModalOpen = true;
    }

    closeManualConfigModal() {
        this.isManualModalOpen = false;
        this.manualErrorText = '';
    }

    handleManualFieldChange(event) {
        const field = event.target.dataset.field;
        if (field) {
            this.manualForm[field] = event.target.value;
            if (this.manualErrorText) {
                this.manualErrorText = '';
            }
        }
    }

    async saveManualConfig() {
        const { appId, wabaId, phoneId, accessToken } = this.manualForm;

        if (!appId || !appId.trim() || !wabaId || !wabaId.trim() || !phoneId || !phoneId.trim() || !accessToken || !accessToken.trim()) {
            this.manualErrorText = 'Please fill in all required fields to continue.';
            return;
        }

        try {
            this.isSubmitting = true;
            this.isLoading = true;
            const success = await saveManualDetails({
                accessToken: accessToken.trim(),
                phoneId: phoneId.trim(),
                wabaId: wabaId.trim(),
                appId: appId.trim()
            });

            if (success) {
                this.closeManualConfigModal();
                this.showToast('Success', 'WhatsApp credentials saved successfully!', 'success');
                // Allow metadata deployment a moment to process
                setTimeout(async () => {
                    await this.loadIntegrationConfig();
                    this.isLoading = false;
                }, 1500);
            } else {
                this.manualErrorText = 'Failed to save configuration. Please verify credentials.';
                this.isLoading = false;
            }
        } catch (error) {
            console.error('Error saving manual config:', error);
            this.manualErrorText = error.body?.message || error.message || 'Error saving credentials.';
            this.isLoading = false;
        } finally {
            this.isSubmitting = false;
        }
    }

    // ── Toast Helper ─────────────────────────────────────────────────────────
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
}
