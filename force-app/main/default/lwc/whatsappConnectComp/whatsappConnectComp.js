import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getIntegrationConfig from '@salesforce/apex/WhatsappConnectController.getIntegrationConfig';
import unlinkAccount from '@salesforce/apex/WhatsappConnectController.unlinkAccount';
import getContactObjectConfig from '@salesforce/apex/WhatsappConnectController.getContactObjectConfig';
import saveContactObjectConfig from '@salesforce/apex/WhatsappConnectController.saveContactObjectConfig';
import getRecordName from '@salesforce/apex/WhatsappConnectController.getRecordName';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';
import GlobalStylesCss from '@salesforce/resourceUrl/globalStyles';

export default class WhatsappConnectComp extends NavigationMixin(LightningElement) {
    @track isLoading = false;
    @track isSubmitting = false;
    @track isConnected = false;
    @track appId = '';
    @track businessAccountId = '';
    @track phoneNumberId = '';
    @track accessToken = '';
    @track lastModifiedDate = '';
    @track isCopied = false;
    @track isDeactivateModalOpen = false;
    @track isContactEditMode = false;
    @track isContactDirty = false;
    @track activeSections = [];
    @track phoneFields = [];
    @track selectedPhoneFieldVal = '';
    @track selectedPhoneFieldLabel = '';
    @track chatWindowRows = [];
    @track requiredFields = [];
    originalStateSnapshot = null;
    currentPageRef;

    @wire(CurrentPageReference)
    wirePageRef(pageRef) {
        this.currentPageRef = pageRef;
        this.extractUrlParameters();
    }

    extractUrlParameters() {
        let wabaId = '';
        let appId = '';
        let lastEdited = '';

        if (this.currentPageRef && this.currentPageRef.state) {
            const state = this.currentPageRef.state;
            wabaId = state.c__businessAccountId || state.c__wabaId || '';
            appId = state.c__applicationId || state.c__appId || '';
            lastEdited = state.c__lastEdited || state.c__lastModifiedDate || '';
        }

        if (!wabaId || !appId || !lastEdited) {
            try {
                const searchParams = new URLSearchParams(window.location.search);
                if (!wabaId) {
                    wabaId = searchParams.get('c__businessAccountId') || searchParams.get('c__wabaId') || '';
                }
                if (!appId) {
                    appId = searchParams.get('c__applicationId') || searchParams.get('c__appId') || '';
                }
                if (!lastEdited) {
                    lastEdited = searchParams.get('c__lastEdited') || searchParams.get('c__lastModifiedDate') || '';
                }
            } catch (e) {
                // Ignore window.location access issues
            }
        }

        if (wabaId && !this.businessAccountId) {
            this.businessAccountId = wabaId;
            this.isConnected = true;
        }
        if (appId && !this.appId) {
            this.appId = appId;
        }
        if (lastEdited && !this.lastModifiedDate) {
            this.lastModifiedDate = lastEdited;
        }
    }

    get isChatSectionOpen() {
        return this.activeSections.includes('chatWindowConfig');
    }

    get isWebhookSectionOpen() {
        return this.activeSections.includes('webhookConfig');
    }

    get chatSectionClass() {
        return `accordion-item ${this.isChatSectionOpen ? 'open' : ''}`;
    }

    get webhookSectionClass() {
        return `accordion-item ${this.isWebhookSectionOpen ? 'open' : ''}`;
    }

    get webhookPhoneFieldOptions() {
        return this.phoneFields || [];
    }

    get isContactSaveDisabled() {
        return !this.isContactDirty || this.isSubmitting;
    }

    async connectedCallback() {
        try {
            this.isLoading = true;
            this.extractUrlParameters();
            loadStyle(this, GlobalStylesCss);

            await this.loadIntegration();
            await this.loadContactConfiguration();
        } catch (error) {
            console.error('Error initializing WhatsappConnectComp:', error);
        } finally {
            this.isLoading = false;
        }
    }

    async loadIntegration() {
        try {
            this.extractUrlParameters();

            const data = await getIntegrationConfig();
            if (data) {
                this.appId = data.appId || this.appId || '';
                this.businessAccountId = data.businessAccountId || this.businessAccountId || '';
                this.phoneNumberId = data.phoneNumberId || this.phoneNumberId || '';
                this.accessToken = data.accessToken || this.accessToken || '';
                this.lastModifiedDate = data.lastModifiedDate || this.lastModifiedDate || '';
                this.isConnected = data.isConnected || !!this.businessAccountId;

                if (!this.isConnected) {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__webPage',
                        attributes: {
                            url: '/apex/WhatsappConnectSDK'
                        }
                    });
                }
            } else if (!this.isConnected) {
                this[NavigationMixin.Navigate]({
                    type: 'standard__webPage',
                    attributes: {
                        url: '/apex/WhatsappConnectSDK'
                    }
                });
            }
        } catch (error) {
            console.error('Error fetching integration config:', error);
            if (!this.isConnected) {
                this[NavigationMixin.Navigate]({
                    type: 'standard__webPage',
                    attributes: {
                        url: '/apex/WhatsappConnectSDK'
                    }
                });
            }
        }
    }

    async loadContactConfiguration() {
        try {
            const res = await getContactObjectConfig();
            if (res && res.success) {
                this.phoneFields = res.phoneFields || [];
                const rawRequiredFields = res.requiredFields || [];
                const savedConfig = res.savedConfig || {};

                // Parse Chat Window config
                let savedChatField = '';
                try {
                    const parsedChat = JSON.parse(savedConfig.ChatWindowConfigInfo || '{}');
                    if (parsedChat && parsedChat.Contact) {
                        savedChatField = parsedChat.Contact;
                    }
                } catch (e) {
                    console.error('Error parsing ChatWindowConfigInfo:', e);
                }

                // Chat window rows (always Contact)
                this.chatWindowRows = [{
                    id: 'chat_row_contact',
                    selectedObject: 'Contact',
                    selectedPhoneField: savedChatField || (this.phoneFields.length ? this.phoneFields[0].value : ''),
                    phoneFieldOptions: this.phoneFields
                }];

                // Parse Webhook config
                let savedWebhookPhone = '';
                let savedFieldValues = {};
                try {
                    const parsedWebhook = JSON.parse(savedConfig.ObjectConfigInfo || '{}');
                    if (parsedWebhook && parsedWebhook.phoneField) {
                        savedWebhookPhone = parsedWebhook.phoneField;
                    }
                    if (parsedWebhook && parsedWebhook.requiredFields) {
                        parsedWebhook.requiredFields.forEach(f => {
                            savedFieldValues[f.name] = f.value;
                        });
                    }
                } catch (e) {
                    console.error('Error parsing ObjectConfigInfo:', e);
                }

                this.selectedPhoneFieldVal = savedWebhookPhone || (this.phoneFields.length ? this.phoneFields[0].value : '');
                this.updatePhoneFieldLabel();

                // Build rich required fields with type flags and default values
                const processedFields = await Promise.all(rawRequiredFields.map(async field => {
                    const savedVal = savedFieldValues[field.name];
                    const val = savedVal !== undefined ? savedVal : (field.value || '');
                    let recordName = '';

                    if (field.type === 'REFERENCE' && val && field.relatedObject) {
                        try {
                            recordName = await getRecordName({ objectApiName: field.relatedObject, recordId: val });
                        } catch (e) {
                            console.error('Error fetching record name:', e);
                        }
                    }

                    return {
                        name: field.name,
                        label: field.label,
                        type: field.type,
                        value: val,
                        relatedObject: field.relatedObject || '',
                        relatedRecordName: recordName,
                        picklistValues: field.picklistValues || [],
                        isString: field.type === 'STRING' || field.type === 'URL' || field.type === 'EMAIL' || field.type === 'PHONE',
                        isNumber: field.type === 'INTEGER' || field.type === 'DOUBLE' || field.type === 'CURRENCY' || field.type === 'PERCENT',
                        isDate: field.type === 'DATE',
                        isDateTime: field.type === 'DATETIME',
                        isReference: field.type === 'REFERENCE',
                        isTextArea: field.type === 'TEXTAREA',
                        isPicklist: field.type === 'PICKLIST',
                        isBoolean: field.type === 'BOOLEAN'
                    };
                }));

                this.requiredFields = processedFields;
            }
        } catch (error) {
            console.error('Error loading contact configuration:', error);
        }
    }

    updatePhoneFieldLabel() {
        const match = this.phoneFields.find(p => p.value === this.selectedPhoneFieldVal);
        this.selectedPhoneFieldLabel = match ? match.label : this.selectedPhoneFieldVal;
    }

    handleToggleSection(event) {
        const section = event.currentTarget.dataset.section;
        if (!section) return;

        if (this.activeSections.includes(section)) {
            this.activeSections = this.activeSections.filter(s => s !== section);
        } else {
            this.activeSections = [...this.activeSections, section];
        }
    }

    handleContactEdit() {
        this.originalStateSnapshot = {
            chatWindowRows: JSON.parse(JSON.stringify(this.chatWindowRows)),
            requiredFields: JSON.parse(JSON.stringify(this.requiredFields)),
            selectedPhoneFieldVal: this.selectedPhoneFieldVal,
            selectedPhoneFieldLabel: this.selectedPhoneFieldLabel
        };
        this.isContactEditMode = true;
        this.isContactDirty = false;
        // Open both accordions if both or either is closed
        this.activeSections = ['chatWindowConfig', 'webhookConfig'];
    }

    handleContactCancel() {
        if (this.originalStateSnapshot) {
            this.chatWindowRows = this.originalStateSnapshot.chatWindowRows;
            this.requiredFields = this.originalStateSnapshot.requiredFields;
            this.selectedPhoneFieldVal = this.originalStateSnapshot.selectedPhoneFieldVal;
            this.selectedPhoneFieldLabel = this.originalStateSnapshot.selectedPhoneFieldLabel;
        }
        this.isContactEditMode = false;
        this.isContactDirty = false;
    }

    async handleContactSave() {
        try {
            this.isSubmitting = true;
            this.isLoading = true;

            // Build webhook config JSON
            const webhookConfig = {
                object: 'Contact',
                phoneField: this.selectedPhoneFieldVal,
                requiredFields: this.requiredFields.map(f => ({
                    name: f.name,
                    value: f.value !== undefined ? f.value : ''
                }))
            };

            // Build chat window config JSON
            const chatConfig = {};
            this.chatWindowRows.forEach(row => {
                chatConfig[row.selectedObject] = row.selectedPhoneField;
            });

            const res = await saveContactObjectConfig({
                webhookJson: JSON.stringify(webhookConfig),
                chatJson: JSON.stringify(chatConfig)
            });

            if (res === 'Success') {
                this.showToast('Success', 'Contact configuration saved successfully!', 'success');
                this.isContactEditMode = false;
                this.isContactDirty = false;
                this.updatePhoneFieldLabel();
                // Allow metadata deployment to settle and refresh
                setTimeout(async () => {
                    await this.loadContactConfiguration();
                    this.isLoading = false;
                }, 1200);
            } else {
                this.showToast('Error', res || 'Failed to save configuration.', 'error');
                this.isLoading = false;
            }
        } catch (error) {
            console.error('Error saving contact configuration:', error);
            this.showToast('Error', error.body?.message || error.message || 'Error saving contact configuration.', 'error');
            this.isLoading = false;
        } finally {
            this.isSubmitting = false;
        }
    }

    handleChatPhoneFieldChange(event) {
        const val = event.detail.value;
        this.chatWindowRows = this.chatWindowRows.map(row => ({
            ...row,
            selectedPhoneField: val
        }));
        this.isContactDirty = true;
    }

    handleWebhookPhoneComboChange(event) {
        this.selectedPhoneFieldVal = event.detail.value;
        this.updatePhoneFieldLabel();
        this.isContactDirty = true;
    }

    handleRequiredFieldChange(event) {
        const fieldName = event.target.dataset.field;
        const val = event.target.value;
        this.updateRequiredFieldValue(fieldName, val);
    }

    handleRequiredCheckboxChange(event) {
        const fieldName = event.target.dataset.field;
        const checked = event.target.checked;
        this.updateRequiredFieldValue(fieldName, checked);
    }

    async handleRecordPickerSelection(event) {
        const fieldName = event.target.dataset.field;
        const recordId = event.detail.recordId;
        const field = this.requiredFields.find(f => f.name === fieldName);
        let recordName = '';

        if (recordId && field && field.relatedObject) {
            try {
                recordName = await getRecordName({ objectApiName: field.relatedObject, recordId });
            } catch (e) {
                console.error('Error retrieving record name:', e);
            }
        }

        this.requiredFields = this.requiredFields.map(f => {
            if (f.name === fieldName) {
                return { ...f, value: recordId || '', relatedRecordName: recordName };
            }
            return f;
        });
        this.isContactDirty = true;
    }

    updateRequiredFieldValue(fieldName, value) {
        this.requiredFields = this.requiredFields.map(f => {
            if (f.name === fieldName) {
                return { ...f, value };
            }
            return f;
        });
        this.isContactDirty = true;
    }

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
                this.showToast('Disconnected', 'WhatsApp integration deactivated successfully.', 'success');
                this.dispatchEvent(new CustomEvent('whatsappdeactivated'));
                // Navigate immediately to the VF page to connect again
                this[NavigationMixin.Navigate]({
                    type: 'standard__webPage',
                    attributes: {
                        url: '/apex/WhatsappConnectSDK'
                    }
                });
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

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
}
