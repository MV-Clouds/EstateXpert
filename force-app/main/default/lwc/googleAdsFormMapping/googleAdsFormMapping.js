import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';

import getGoogleAuthUrl from '@salesforce/apex/GoogleAdsFormMappingController.getGoogleAuthUrl';
import saveRefreshToken from '@salesforce/apex/GoogleAdsFormMappingController.saveRefreshToken';
import getConnection from '@salesforce/apex/GoogleAdsFormMappingController.getConnection';
import getFormsForAccount from '@salesforce/apex/GoogleAdsFormMappingController.getFormsForAccount';
import getExistingMappings from '@salesforce/apex/GoogleAdsFormMappingController.getExistingMappings';
import getSalesforceLeadFields from '@salesforce/apex/GoogleAdsFormMappingController.getSalesforceLeadFields';
import saveMapping from '@salesforce/apex/GoogleAdsFormMappingController.saveMapping';
import deleteMapping from '@salesforce/apex/GoogleAdsFormMappingController.deleteMapping';
import disconnectGoogleAds from '@salesforce/apex/GoogleAdsFormMappingController.disconnectGoogleAds';
import getFailedLeads from '@salesforce/apex/GoogleAdsFormMappingController.getFailedLeads';
import retryFailedLeads from '@salesforce/apex/GoogleAdsFormMappingController.retryFailedLeads';
import discardFailedLeads from '@salesforce/apex/GoogleAdsFormMappingController.discardFailedLeads';
import getActiveSites from '@salesforce/apex/GoogleAdsFormMappingController.getActiveSites';
import getWebhookUrl from '@salesforce/apex/GoogleAdsFormMappingController.getWebhookUrl';
import saveWebhookUrl from '@salesforce/apex/GoogleAdsFormMappingController.saveWebhookUrl';
import GlobalStyles from '@salesforce/resourceUrl/globalStyles';

const SOURCE_GOOGLE = 'google';
const SOURCE_CUSTOM = 'custom';

const SOURCE_OPTIONS = [
    { label: 'Do Not Map', value: '' },
    { label: 'Google Form Field', value: SOURCE_GOOGLE },
    { label: 'Custom Value', value: SOURCE_CUSTOM }
];

const DEFAULT_SALESFORCE_FIELDS = ['FirstName', 'LastName', 'Email', 'Phone', 'Company', 'AccountId'];

const DEFAULT_ERROR_MESSAGE = 'An unexpected error occurred.';

const CLOSED_CONFIRMATION = {
    isOpen: false,
    title: '',
    message: '',
    confirmLabel: 'Confirm',
    cancelLabel: 'Cancel',
    isDanger: false,
    action: null
};

const NOTICE_DISCONNECTED = 'Google Ads was disconnected. Salesforce clears the saved token in the background, so wait about a minute before connecting again.';
const NOTICE_WEBHOOK_SAVED = 'Webhook site saved. Salesforce applies this change in the background and it can take up to a minute, so wait before creating a mapping.';

export default class GoogleAdsConnection extends LightningElement {

    // ---------- UI state ----------
    isLoading = true;
    hasLoaded = false;          // first load finished (prevents the connect card flashing before data arrives)
    isModalOpen = false;
    isEditMode = false;
    isWebhookModalOpen = false;
    isFailedModalOpen = false;
    showForms = false;
    showAddField = false;
    showTokenInput = false;     // connection card: token paste step
    isConnectionPending = false; // token saved, waiting for the async metadata deployment
    syncNotice = '';            // banner shown after operations that finish asynchronously

    // ---------- data ----------
    accounts = [];
    forms = [];
    currentFormFields = [];
    googleOptions = [];
    salesforceLeadFields = [];
    tableData = [];
    failedLeads = [];
    siteOptions = [];
    sourceOptions = SOURCE_OPTIONS;

    selectedAccount = '';
    selectedFormId = '';
    selectedAdditionalField = '';
    selectedSite = '';
    webhookUrl = '';
    refreshToken = '';

    failedContext = { accountId: '', formId: '', formName: '' };
    pendingRetryIds = [];   // set while the wizard is used from "Edit Mapping & Retry"
    confirmation = { ...CLOSED_CONFIRMATION };

    // Canonical mapping structure returned from Apex.
    fullMappingJson = {};
    isMappingDataLoaded = false;

    /**
     * Method Name: connectedCallback
     * @description: Loads the global styles and the initial connection and mapping data.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    connectedCallback() {
        loadStyle(this, GlobalStyles).catch(error => console.error('Error loading globalStyles', error));
        this.loadInitialData();
    }

    // ===================== Generic helpers =====================

    /**
     * Method Name: withLoading
     * @description: Runs a task with the spinner on and shows an error toast on failure. Never throws.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    async withLoading(task, onError) {
        this.isLoading = true;
        try {
            return await task();
        } catch (error) {
            console.error(error);
            this.showToast('Error', this.getErrorMessage(error), 'error');
            if (onError) {
                onError(error);
            }
        } finally {
            this.isLoading = false;
        }
        return undefined;
    }

    /**
     * Method Name: showToast
     * @description: Dispatches a toast message with the given title, message and variant.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    /**
     * Method Name: getErrorMessage
     * @description: Extracts a readable message from Apex errors (body message, array body, pageErrors) or JS errors.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    getErrorMessage(error) {
        const body = error?.body;
        if (Array.isArray(body)) {
            const joined = body.map(item => item?.message).filter(Boolean).join(', ');
            return joined || DEFAULT_ERROR_MESSAGE;
        }
        return body?.message || body?.pageErrors?.[0]?.message || error?.message || DEFAULT_ERROR_MESSAGE;
    }

    /**
     * Method Name: parseJson
     * @description: Safely parses a JSON string and returns an empty object when it is blank or invalid.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    parseJson(value) {
        if (!value) {
            return {};
        }
        try {
            return typeof value === 'string' ? JSON.parse(value) : value;
        } catch (error) {
            console.error('Invalid mapping JSON', error);
            return {};
        }
    }

    /**
     * Method Name: clone
     * @description: Returns a deep copy of the given value.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    clone(value) {
        return JSON.parse(JSON.stringify(value || {}));
    }

    /**
     * Method Name: formatFieldLabel
     * @description: Converts an API-style name (first_name) into a readable label (First Name).
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    formatFieldLabel(value) {
        return value ? String(value).replace(/_/g, ' ').replace(/\b\w/g, char => char.toUpperCase()) : '';
    }

    /**
     * Method Name: getAccount
     * @description: Finds a loaded Google Ads account by Id.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    getAccount(accountId) {
        return this.accounts.find(account => String(account.id) === String(accountId));
    }

    /**
     * Method Name: getAccountName
     * @description: Returns the account name, or a fallback label when the account is not loaded.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    getAccountName(accountId) {
        return this.getAccount(accountId)?.descriptiveName || `Google Ads Account ${accountId}`;
    }

    /**
     * Method Name: findFormRow
     * @description: Finds a form row and its parent account row in the mapping table by row Id.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    findFormRow(rowId) {
        for (const accountRow of this.tableData) {
            const formRow = accountRow.forms.find(form => form.id === rowId);
            if (formRow) {
                return { accountRow, formRow };
            }
        }
        return null;
    }

    // ===================== Initial load / connection =====================

    /**
     * Method Name: loadInitialData
     * @description: Loads the connection and mapping data on first render, then marks the component as loaded.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    async loadInitialData() {
        await this.withLoading(async () => {
            await this.loadConnection();
            await this.loadMappingData();
        });
        this.hasLoaded = true;
    }

    /**
     * Method Name: loadMappingData
     * @description: Loads saved mappings, Salesforce fields and the webhook URL, then builds the mapping table.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    async loadMappingData() {
        const [existingMappings, salesforceFields, webhookUrl] = await Promise.all([
            getExistingMappings(),
            getSalesforceLeadFields(),
            getWebhookUrl()
        ]);
        this.fullMappingJson = this.parseJson(existingMappings);
        this.salesforceLeadFields = salesforceFields || [];
        this.webhookUrl = webhookUrl || '';
        this.buildTableData();
        this.isMappingDataLoaded = true;
    }

    /**
     * Method Name: ensureMappingData
     * @description: Loads the mapping data only if it has not been loaded yet.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    async ensureMappingData() {
        if (!this.isMappingDataLoaded) {
            await this.loadMappingData();
        }
    }

    /**
     * Method Name: loadConnection
     * @description: Retrieves the connected Google Ads accounts; clears them and rethrows on failure.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    async loadConnection() {
        try {
            this.accounts = (await getConnection()) || [];
        } catch (error) {
            this.accounts = [];
            throw error;
        }
    }

    /**
     * Method Name: hasConnection
     * @description: Getter to check if at least one Google Ads account is connected.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get hasConnection() {
        return this.accounts.length > 0;
    }

    /**
     * Method Name: accountOptions
     * @description: Getter to build the account combobox options.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get accountOptions() {
        return this.accounts.map(account => ({
            label: account.descriptiveName ? `${account.descriptiveName} (${account.id})` : String(account.id),
            value: String(account.id)
        }));
    }

    // ---------- connection card ----------

    /**
     * Method Name: showConnectionScreen
     * @description: Getter to show the connect card once loading finished and no account is connected.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get showConnectionScreen() {
        return this.hasLoaded && !this.hasConnection;
    }

    /**
     * Method Name: showConnectIntro
     * @description: Getter to show the intro step of the connect card.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get showConnectIntro() {
        return !this.showTokenInput && !this.isConnectionPending;
    }

    /**
     * Method Name: showTokenForm
     * @description: Getter to show the refresh token input step.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get showTokenForm() {
        return this.showTokenInput && !this.isConnectionPending;
    }

    /**
     * Method Name: connectionStatusLabel
     * @description: Getter for the connection status text.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get connectionStatusLabel() {
        return this.isConnectionPending ? 'Connection pending' : 'Not Connected';
    }

    /**
     * Method Name: connectionStatusClass
     * @description: Getter for the connection status CSS classes.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get connectionStatusClass() {
        return this.isConnectionPending ? 'connection-status connection-status--pending' : 'connection-status';
    }

    /**
     * Method Name: login
     * @description: Opens the Google consent screen in a new tab and reveals the refresh token field.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    login() {
        return this.withLoading(async () => {
            const url = await getGoogleAuthUrl();
            if (!url) {
                throw new Error('Google authorization URL was not returned.');
            }
            const popup = window.open(url, '_blank');
            if (!popup) {
                this.showToast('Warning', 'The Google sign-in window was blocked. Allow pop-ups for this site and try again.', 'warning');
            }
            this.showTokenInput = true;
        });
    }

    /**
     * Method Name: handleShowTokenInput
     * @description: Shows the refresh token input.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    handleShowTokenInput() {
        this.showTokenInput = true;
    }

    /**
     * Method Name: handleCancelConnection
     * @description: Clears the entered token and hides the token input.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    handleCancelConnection() {
        this.refreshToken = '';
        this.showTokenInput = false;
    }

    /**
     * Method Name: handleChangeToken
     * @description: Leaves the pending state and shows the token input again.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    handleChangeToken() {
        this.isConnectionPending = false;
        this.showTokenInput = true;
    }

    /**
     * Method Name: handleChange
     * @description: Stores the refresh token typed by the user.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    handleChange(event) {
        this.refreshToken = event.target.value || '';
    }

    /**
     * Method Name: saveConnection
     * @description: Saves the refresh token and checks the connection. The token is stored through an async
     * deployment, so a failed check keeps the pending state instead of showing a save error.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    saveConnection() {
        if (!this.refreshToken.trim()) {
            this.showToast('Validation Error', 'Please paste a Google refresh token.', 'error');
            return undefined;
        }
        return this.withLoading(async () => {
            await saveRefreshToken({ refreshToken: this.refreshToken.trim() });
            this.refreshToken = '';
            this.showTokenInput = false;
            this.syncNotice = '';
            this.isConnectionPending = true;

            try {
                await this.loadConnection();
            } catch (error) {
                console.error('Connection check failed after saving the token', error);
            }

            if (this.hasConnection) {
                this.isConnectionPending = false;
                await this.ensureMappingData();
                this.showToast('Success', 'Google Ads connection saved successfully.', 'success');
            } else {
                this.showToast('Success', 'Token saved. It can take up to a minute to take effect.', 'success');
            }
        });
    }

    /**
     * Method Name: checkConnectionStatus
     * @description: Re-checks whether the saved token is active and loads the mapping data once connected.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    checkConnectionStatus() {
        return this.withLoading(async () => {
            await this.loadConnection();
            if (this.hasConnection) {
                this.isConnectionPending = false;
                await this.ensureMappingData();
                this.showToast('Success', 'Google Ads is connected.', 'success');
            } else {
                this.showToast('Info', 'The connection is still being applied. Please check again in a few moments.', 'info');
            }
        });
    }

    /**
     * Method Name: handleDisconnectClick
     * @description: Opens the confirmation dialog for disconnecting Google Ads.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    handleDisconnectClick() {
        this.openConfirmation({
            title: 'Disconnect Google Ads',
            message: 'Are you sure you want to disconnect Google Ads? This will remove Google Ads webhook subscriptions for all mapped forms, revoke the Google OAuth connection, and delete the saved Google Ads mappings.',
            confirmLabel: 'Disconnect',
            isDanger: true,
            action: () => this.confirmDisconnect()
        });
    }

    /**
     * Method Name: confirmDisconnect
     * @description: Disconnects Google Ads and resets the component state.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    confirmDisconnect() {
        return this.withLoading(async () => {
            const result = await disconnectGoogleAds();
            if (!result?.success) {
                throw new Error(result?.message || 'Failed to disconnect Google Ads.');
            }
            this.accounts = [];
            this.resetWizard();
            this.tableData = [];
            this.fullMappingJson = {};
            this.showTokenInput = false;
            this.isConnectionPending = false;
            this.syncNotice = NOTICE_DISCONNECTED;
            this.showToast('Success', 'Google Ads disconnected successfully.', 'success');
        });
    }

    /**
     * Method Name: dismissSyncNotice
     * @description: Closes the background-sync banner.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    dismissSyncNotice() {
        this.syncNotice = '';
    }

    /**
     * Method Name: hasSyncNotice
     * @description: Getter to check if the background-sync banner should be shown.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get hasSyncNotice() {
        return !!this.syncNotice;
    }

    // ===================== Wizard open / close =====================

    /**
     * Method Name: openWizard
     * @description: Resets the wizard and opens the mapping modal.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    openWizard() {
        this.pendingRetryIds = [];
        this.resetWizard();
        this.isModalOpen = true;
    }

    /**
     * Method Name: openNewMappingModal
     * @description: Opens the mapping modal for a new mapping; requires a webhook site to be selected first.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    openNewMappingModal() {
        if (!this.hasWebhookUrl) {
            this.showToast('Error', 'Select a Force.com webhook site before creating a mapping.', 'error');
            return;
        }
        this.openWizard();
    }

    /**
     * Method Name: resetWizard
     * @description: Clears the account, form and field selections of the mapping wizard.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    resetWizard() {
        this.refreshToken = '';
        this.selectedAccount = '';
        this.selectedFormId = '';
        this.forms = [];
        this.showForms = false;
        this.currentFormFields = [];
        this.isEditMode = false;
    }

    /**
     * Method Name: closeModal
     * @description: Closes the mapping modal; in retry mode it returns to the failed leads list.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    closeModal() {
        if (this.isLoading) {
            return;
        }
        this.isModalOpen = false;
        this.isEditMode = false;
        this.restoreFailedModal();
    }

    // ===================== Account / forms =====================

    /**
     * Method Name: handleAccountChange
     * @description: Stores the selected account, clears the form selection and loads its lead forms.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    handleAccountChange(event) {
        this.selectedAccount = event.detail.value;
        this.selectedFormId = '';
        this.forms = [];
        this.currentFormFields = [];
        this.showForms = false;

        if (this.selectedAccount) {
            this.fetchForms();
        }
    }

    /**
     * Method Name: fetchForms
     * @description: Loads the unmapped lead forms of the selected account.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    async fetchForms() {
        await this.withLoading(
            async () => {
                this.forms = await this.loadFormsForAccount(this.selectedAccount);
            },
            () => {
                this.forms = [];
            }
        );
        this.showForms = true;
    }

    /**
     * Method Name: loadFormsForAccount
     * @description: Retrieves lead forms for an account and hides already mapped ones (except the one being edited).
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    async loadFormsForAccount(accountId, includeMappedFormId = null) {
        const account = this.getAccount(accountId);
        if (!account) {
            throw new Error('Google Ads account could not be found.');
        }

        const result = await getFormsForAccount({ accountString: JSON.stringify(account) });
        const mappedFormIds = new Set(Object.keys(this.fullMappingJson?.[accountId]?.forms || {}));
        const keepId = String(includeMappedFormId);

        return (result || [])
            .filter(form => !mappedFormIds.has(String(form.id)) || String(form.id) === keepId)
            .map(form => {
                const isSelected = String(form.id) === keepId;
                return {
                    ...form,
                    fieldCount: this.getGoogleFields(form).length,
                    isSelected,
                    ariaPressed: String(isSelected)
                };
            });
    }

    /**
     * Method Name: getGoogleFields
     * @description: Combines the standard fields and custom questions of a form into option objects.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    getGoogleFields(form) {
        return [...(form?.fields || []), ...(form?.customQuestions || [])].map(name => ({
            value: String(name),
            label: this.formatFieldLabel(name)
        }));
    }

    /**
     * Method Name: selectFormCard
     * @description: Selects a lead form card and prepares its mapping rows; locked while fixing a mapping for retry.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    selectFormCard(event) {
        if (this.hasPendingRetry) {
            return;
        }
        this.selectedFormId = event.currentTarget.dataset.id;
        this.forms = this.forms.map(form => {
            const isSelected = String(form.id) === String(this.selectedFormId);
            return { ...form, isSelected, ariaPressed: String(isSelected) };
        });
        this.prepareFormFields();
    }

    /**
     * Method Name: handleFormCardKeydown
     * @description: Allows selecting a form card with the Enter or Space key.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    handleFormCardKeydown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.selectFormCard(event);
        }
    }

    /**
     * Method Name: formStepBadgeClass
     * @description: Getter for the form step badge CSS classes.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get formStepBadgeClass() {
        return this.isFormSectionDisabled ? 'wizard-step-badge wizard-step-badge--disabled' : 'wizard-step-badge';
    }

    // ===================== Mapping rows =====================

    /**
     * Method Name: prepareFormFields
     * @description: Builds the Salesforce field rows (required, default and already saved fields) for the selected form.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    prepareFormFields(savedMapping = {}) {
        const form = this.forms.find(item => String(item.id) === String(this.selectedFormId));
        this.googleOptions = this.getGoogleFields(form);

        this.currentFormFields = this.salesforceLeadFields
            .filter(field =>
                this.isRequiredField(field) ||
                DEFAULT_SALESFORCE_FIELDS.includes(field.value) ||
                Object.prototype.hasOwnProperty.call(savedMapping, field.value)
            )
            .map(field => this.buildFieldRow(field, savedMapping[field.value]));

        this.handleCancelAddField();
    }

    /**
     * Method Name: isRequiredField
     * @description: Checks if a Salesforce field is required.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    isRequiredField(field) {
        return String(field?.required) === 'true';
    }

    /**
     * Method Name: buildFieldRow
     * @description: Builds one mapping row for a Salesforce field, prefilled from the saved mapping if present.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    buildFieldRow(salesforceField, saved = {}) {
        return this.decorate({
            key: salesforceField.value,
            label: salesforceField.label || this.formatFieldLabel(salesforceField.value),
            required: this.isRequiredField(salesforceField),
            referenceTo: salesforceField.referenceTo || '',
            isReferenceField: !!salesforceField.referenceTo,
            sourceType: saved.sourceType || '',
            googleField: saved.googleField || '',
            customValue: saved.customValue || '',
            showRequiredError: false
        });
    }

    /**
     * Method Name: decorate
     * @description: Adds the derived template flags and row CSS classes; recomputed whenever a row changes.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    decorate(field) {
        return {
            ...field,
            isGoogleField: field.sourceType === SOURCE_GOOGLE,
            isCustomValue: field.sourceType === SOURCE_CUSTOM,
            rowClass: [
                'mapping-row',
                field.required && 'mapping-row--required',
                field.showRequiredError && 'mapping-row--error'
            ].filter(Boolean).join(' ')
        };
    }

    /**
     * Method Name: updateField
     * @description: Applies changes to one mapping row and clears its required error.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    updateField(key, patch) {
        this.currentFormFields = this.currentFormFields.map(field =>
            field.key === key ? this.decorate({ ...field, showRequiredError: false, ...patch }) : field
        );
    }

    /**
     * Method Name: handleSourceTypeChange
     * @description: Updates the source type of a row and clears its previous value.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    handleSourceTypeChange(event) {
        this.updateField(event.target.dataset.key, {
            sourceType: event.detail.value,
            googleField: '',
            customValue: ''
        });
    }

    /**
     * Method Name: handleGoogleFieldChange
     * @description: Updates the Google form field selected for a row.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    handleGoogleFieldChange(event) {
        this.updateField(event.target.dataset.key, { googleField: event.detail.value });
    }

    /**
     * Method Name: handleCustomValueChange
     * @description: Updates the custom value entered for a row.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    handleCustomValueChange(event) {
        this.updateField(event.target.dataset.key, { customValue: event.target.value || '' });
    }

    /**
     * Method Name: handleReferenceChange
     * @description: Updates the record Id picked for a lookup field row.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    handleReferenceChange(event) {
        this.updateField(event.target.dataset.key, { customValue: event.detail.recordId || '' });
    }

    // ---------- add extra Salesforce field ----------

    /**
     * Method Name: handleShowAddField
     * @description: Shows the picker for adding an extra Salesforce field.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    handleShowAddField() {
        this.showAddField = true;
    }

    /**
     * Method Name: handleCancelAddField
     * @description: Hides the extra field picker and clears its selection.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    handleCancelAddField() {
        this.selectedAdditionalField = '';
        this.showAddField = false;
    }

    /**
     * Method Name: handleAdditionalFieldChange
     * @description: Stores the extra Salesforce field selected in the picker.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    handleAdditionalFieldChange(event) {
        this.selectedAdditionalField = event.detail.value;
    }

    /**
     * Method Name: handleAddField
     * @description: Adds the selected extra Salesforce field as a new mapping row.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    handleAddField() {
        const salesforceField = this.salesforceLeadFields.find(field => field.value === this.selectedAdditionalField);
        if (!salesforceField) {
            return;
        }
        this.currentFormFields = [...this.currentFormFields, this.buildFieldRow(salesforceField)];
        this.handleCancelAddField();
    }

    // ===================== Save mapping =====================

    /**
     * Method Name: isMapped
     * @description: Checks if a row has a Google field or a custom value mapped.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    isMapped(field) {
        return (field.sourceType === SOURCE_GOOGLE && !!field.googleField) ||
            (field.sourceType === SOURCE_CUSTOM && !!field.customValue?.trim());
    }

    /**
     * Method Name: validateMappings
     * @description: Validates that all required fields and at least one field are mapped.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    validateMappings() {
        const missingRequired = this.currentFormFields.filter(field => field.required && !this.isMapped(field)).map(field => field.label);

        if (missingRequired.length) {
            this.markRequiredErrors();
            return { valid: false, message: 'Missing required Salesforce fields: ' + missingRequired.join(', ') };
        }
        if (!this.currentFormFields.some(field => this.isMapped(field))) {
            return { valid: false, message: 'Please map at least one Salesforce field.' };
        }
        return { valid: true };
    }

    /**
     * Method Name: markRequiredErrors
     * @description: Highlights the required rows that are not mapped.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    markRequiredErrors() {
        this.currentFormFields = this.currentFormFields.map(field =>
            field.required ? this.decorate({ ...field, showRequiredError: !this.isMapped(field) }) : field
        );
    }

    /**
     * Method Name: buildCurrentMapping
     * @description: Builds the field mapping object from the mapped rows.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    buildCurrentMapping() {
        const mapping = {};
        this.currentFormFields.filter(field => this.isMapped(field)).forEach(field => {
            mapping[field.key] = field.sourceType === SOURCE_GOOGLE
                ? { sourceType: SOURCE_GOOGLE, googleField: field.googleField }
                : { sourceType: SOURCE_CUSTOM, customValue: field.customValue.trim() };
        });
        return mapping;
    }

    /**
     * Method Name: buildUpdatedMappingJson
     * @description: Merges the current form mapping into a copy of the full saved mapping structure.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    buildUpdatedMappingJson(account, form, mapping) {
        const mappingJson = this.clone(this.fullMappingJson);
        const accountId = String(this.selectedAccount);
        const accountEntry = mappingJson[accountId] || (mappingJson[accountId] = {});

        accountEntry.forms = accountEntry.forms || {};
        accountEntry.loginCustomerId = account.loginCustomerId;
        accountEntry.accountName = account.descriptiveName || account.id || accountId;
        accountEntry.forms[this.selectedFormId] = {
            formName: form.name || form.headline || `Form ID: ${this.selectedFormId}`,
            mappings: mapping
        };
        return mappingJson;
    }

    /**
     * Method Name: saveMapping
     * @description: Validates the wizard and opens the save confirmation dialog.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    saveMapping() {
        if (!this.selectedAccount) {
            this.showToast('Validation Error', 'Please select a Google Ads account.', 'error');
            return;
        }
        if (!this.selectedFormId) {
            this.showToast('Validation Error', 'Please select a lead form.', 'error');
            return;
        }

        const validation = this.validateMappings();
        if (!validation.valid) {
            this.showToast('Validation Error', validation.message, 'error');
            return;
        }

        const account = this.getAccount(this.selectedAccount);
        const form = this.forms.find(item => String(item.id) === String(this.selectedFormId));
        if (!account || !form) {
            this.showToast('Error', 'Unable to resolve the selected Google Ads account or form.', 'error');
            return;
        }

        const mappingJson = JSON.stringify(this.buildUpdatedMappingJson(account, form, this.buildCurrentMapping()));
        const baseMessage = 'Are you sure you want to save this Google Ads form mapping? This will stop any webhook/automation on your Google Lead form to connect form with your org.';

        this.openConfirmation({
            title: 'Confirm Save',
            message: this.hasPendingRetry
                ? `${baseMessage} The ${this.pendingRetryIds.length} selected failed lead(s) will then be retried with this mapping.`
                : baseMessage,
            confirmLabel: this.hasPendingRetry ? 'Save & Retry' : 'Save',
            action: () => this.confirmSaveMapping(mappingJson)
        });
    }

    /**
     * Method Name: confirmSaveMapping
     * @description: Saves the mapping, then retries pending failed leads separately so a retry problem is
     * never reported as a failed save.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    async confirmSaveMapping(mappingJson) {
        const retryIds = [...this.pendingRetryIds];

        const saved = await this.withLoading(async () => {
            const result = await saveMapping({ mappingJson });
            if (!result?.success) {
                throw new Error(result?.message || 'Failed to save mapping.');
            }

            this.fullMappingJson = JSON.parse(mappingJson);
            this.buildTableData();
            this.isModalOpen = false;
            this.showToast('Success', 'Google Ads form mapping saved successfully.', 'success');
            return true;
        });

        if (saved && retryIds.length) {
            this.pendingRetryIds = [];
            this.isFailedModalOpen = true;
            await this.runRetry(retryIds);
        }
    }

    // ===================== Mapping table =====================

    /**
     * Method Name: buildTableData
     * @description: Builds the account and form rows of the mapping table, keeping expanded rows open.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    buildTableData() {
        const expandedIds = new Set(this.tableData.filter(row => row.isExpanded).map(row => row.id));

        this.tableData = Object.entries(this.fullMappingJson || {}).map(([accountId, accountObj], accountIdx) => {
            const forms = Object.entries(accountObj?.forms || {}).map(([formId, form], formIdx) => {
                const mappings = form?.mappings || {};
                return {
                    index: formIdx + 1,
                    id: `${accountId}_${formId}`,
                    formId,
                    formName: form?.formName || `Form ID: ${formId}`,
                    mappedCount: Object.keys(mappings).length,
                    mappings
                };
            });

            return {
                index: accountIdx + 1,
                id: accountId,
                accountId,
                accountName: accountObj?.accountName || this.getAccountName(accountId),
                forms,
                isExpanded: expandedIds.has(accountId),
                accordionId: `${accountId}_accordion`
            };
        });
    }

    /**
     * Method Name: handleToggleRow
     * @description: Expands or collapses an account row in the mapping table.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    handleToggleRow(event) {
        const rowId = event.currentTarget.dataset.id;
        this.tableData = this.tableData.map(row => ({
            ...row,
            isExpanded: row.id === rowId ? !row.isExpanded : row.isExpanded
        }));
    }

    /**
     * Method Name: handleEditRow
     * @description: Opens the wizard to edit the mapping of the clicked form row.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    handleEditRow(event) {
        const hit = this.findFormRow(event.currentTarget.dataset.id);
        if (hit) {
            this.editRow(hit.formRow, hit.accountRow.accountId);
        }
    }

    /**
     * Method Name: editRow
     * @description: Opens the wizard prefilled with the saved mapping of a form; closes it again on failure.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    async editRow(row, accountId) {
        this.resetWizard();
        this.isEditMode = true;
        this.selectedAccount = accountId;
        this.selectedFormId = row.formId;
        this.isModalOpen = true;

        await this.withLoading(
            async () => {
                this.forms = await this.loadFormsForAccount(accountId, row.formId);
                this.showForms = true;
                this.prepareFormFields(this.fullMappingJson?.[accountId]?.forms?.[row.formId]?.mappings || {});
            },
            () => {
                this.isModalOpen = false;
                this.restoreFailedModal();
            }
        );
    }

    /**
     * Method Name: handleDeleteRow
     * @description: Opens the confirmation dialog for deleting a form mapping.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    handleDeleteRow(event) {
        const hit = this.findFormRow(event.currentTarget.dataset.id);
        if (!hit) {
            return;
        }
        this.openConfirmation({
            title: 'Confirm Delete',
            message: 'Are you sure you want to delete this mapping?',
            confirmLabel: 'Delete',
            isDanger: true,
            action: () => this.confirmDeleteMapping(hit.formRow, hit.accountRow.accountId)
        });
    }

    /**
     * Method Name: confirmDeleteMapping
     * @description: Deletes the form mapping and its webhook subscription, then updates the table.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    confirmDeleteMapping(targetRow, accountId) {
        return this.withLoading(async () => {
            const account = this.getAccount(accountId);
            if (!account) {
                throw new Error('Google Ads account could not be found.');
            }

            const result = await deleteMapping({
                accountId: account.id,
                loginCustomerId: account.loginCustomerId,
                formId: targetRow.formId
            });
            if (!result?.success) {
                throw new Error(result?.message || 'Failed to delete mapping.');
            }

            const mapping = this.clone(this.fullMappingJson);
            const accountMapping = mapping[accountId];
            if (accountMapping?.forms) {
                delete accountMapping.forms[targetRow.formId];
                if (!Object.keys(accountMapping.forms).length) {
                    delete mapping[accountId];
                }
            }

            this.fullMappingJson = mapping;
            this.buildTableData();
            this.showToast('Success', 'Mapping deleted successfully.', 'success');
        });
    }

    /**
     * Method Name: hasMappings
     * @description: Getter to check if at least one mapping exists.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get hasMappings() {
        return this.tableData.length > 0;
    }

    // ===================== Failed leads =====================

    /**
     * Method Name: handleFailedLeadsClick
     * @description: Opens the failed leads modal for the clicked form and loads its failed leads.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    handleFailedLeadsClick(event) {
        const hit = this.findFormRow(event.currentTarget.dataset.id);
        if (!hit) {
            return;
        }
        this.failedContext = {
            accountId: hit.accountRow.accountId,
            formId: hit.formRow.formId,
            formName: hit.formRow.formName
        };
        this.failedLeads = [];
        this.isFailedModalOpen = true;
        this.withLoading(
            () => this.refreshFailedLeads(),
            () => {
                this.isFailedModalOpen = false;
            }
        );
    }

    /**
     * Method Name: refreshFailedLeads
     * @description: Reloads the failed leads of the current form into the table.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    async refreshFailedLeads() {
        const result = await getFailedLeads({ formId: this.failedContext.formId });
        this.failedLeads = (result || []).map((lead, i) => ({
            ...lead,
            index: i + 1,
            leadId: lead.leadId || '-',
            receivedOnLabel: lead.receivedOn ? new Date(lead.receivedOn).toLocaleString() : '',
            isSelected: false
        }));
    }

    /**
     * Method Name: refreshFailedLeadsSafely
     * @description: Refreshes the failed leads after a retry or discard; a refresh failure only shows a warning
     * because the action itself already succeeded.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    async refreshFailedLeadsSafely() {
        try {
            await this.refreshFailedLeads();
        } catch (error) {
            console.error('Failed to refresh failed leads', error);
            this.showToast('Warning', 'The action completed, but the failed leads list could not be refreshed. Please reopen it.', 'warning');
        }
    }

    /**
     * Method Name: closeFailedModal
     * @description: Closes the failed leads modal and clears its list.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    closeFailedModal() {
        if (this.isLoading) {
            return;
        }
        this.isFailedModalOpen = false;
        this.failedLeads = [];
    }

    /**
     * Method Name: restoreFailedModal
     * @description: Reopens the failed leads modal (selection kept) after leaving the wizard in retry mode.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    restoreFailedModal() {
        if (this.pendingRetryIds.length) {
            this.pendingRetryIds = [];
            this.isFailedModalOpen = true;
        }
    }

    /**
     * Method Name: handleFailedLeadSelect
     * @description: Selects or unselects one failed lead.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    handleFailedLeadSelect(event) {
        const { id } = event.target.dataset;
        const checked = event.target.checked;
        this.failedLeads = this.failedLeads.map(lead => (lead.id === id ? { ...lead, isSelected: checked } : lead));
    }

    /**
     * Method Name: handleSelectAllFailed
     * @description: Selects or unselects all failed leads.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    handleSelectAllFailed(event) {
        const checked = event.target.checked;
        this.failedLeads = this.failedLeads.map(lead => ({ ...lead, isSelected: checked }));
    }

    /**
     * Method Name: handleRetrySelected
     * @description: Retries the selected failed leads with the saved mapping.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    handleRetrySelected() {
        return this.runRetry(this.selectedFailedIds);
    }

    /**
     * Method Name: handleEditMappingAndRetry
     * @description: Opens the wizard to fix the mapping; the selected leads are retried after saving.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    async handleEditMappingAndRetry() {
        const ids = this.selectedFailedIds;
        if (!ids.length) {
            return;
        }
        const { accountId, formId } = this.failedContext;
        this.pendingRetryIds = ids;
        this.isFailedModalOpen = false;
        await this.editRow({ formId }, accountId);
    }

    /**
     * Method Name: runRetry
     * @description: Retries the given failed leads and shows a success, warning or error toast with the result.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    async runRetry(ids) {
        if (!ids?.length) {
            return;
        }
        await this.withLoading(async () => {
            const results = (await retryFailedLeads({ errorIds: ids })) || [];
            const succeeded = results.filter(r => r.success).length;
            const failed = results.length - succeeded;

            await this.refreshFailedLeadsSafely();

            if (failed === 0) {
                this.showToast('Success', `${succeeded} failed lead(s) processed successfully.`, 'success');
            } else if (succeeded === 0) {
                const firstError = results.find(r => !r.success)?.message || '';
                this.showToast('Error', `${failed} lead(s) failed again. ${firstError}`, 'error');
            } else {
                this.showToast('Warning', `${succeeded} processed, ${failed} failed again. See the reason column.`, 'warning');
            }
        });
    }

    /**
     * Method Name: handleDiscardSelected
     * @description: Opens the confirmation dialog for discarding the selected failed leads.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    handleDiscardSelected() {
        const ids = this.selectedFailedIds;
        if (!ids.length) {
            return;
        }
        this.openConfirmation({
            title: 'Discard Failed Leads',
            message: `Discard ${ids.length} failed lead(s)? They will be removed permanently and will not be created in Salesforce.`,
            confirmLabel: 'Discard',
            isDanger: true,
            action: () => this.confirmDiscard(ids)
        });
    }

    /**
     * Method Name: confirmDiscard
     * @description: Permanently deletes the selected failed leads and refreshes the list.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    confirmDiscard(ids) {
        return this.withLoading(async () => {
            const count = await discardFailedLeads({ errorIds: ids });
            await this.refreshFailedLeadsSafely();
            this.showToast('Success', `${count} failed lead(s) discarded.`, 'success');
        });
    }

    // ===================== Webhook site =====================

    /**
     * Method Name: openWebhookModal
     * @description: Opens the webhook site modal and loads the active Force.com sites.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    openWebhookModal() {
        this.selectedSite = '';
        this.siteOptions = [];
        this.isWebhookModalOpen = true;

        return this.withLoading(
            async () => {
                const sites = await getActiveSites();
                this.siteOptions = (sites || []).map(({ label, value }) => ({ label, value }));
                this.selectedSite = this.siteOptions.some(option => option.value === this.webhookUrl) ? this.webhookUrl : '';
            },
            () => {
                this.isWebhookModalOpen = false;
            }
        );
    }

    /**
     * Method Name: closeWebhookModal
     * @description: Closes the webhook site modal.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    closeWebhookModal() {
        if (!this.isLoading) {
            this.isWebhookModalOpen = false;
        }
    }

    /**
     * Method Name: handleSiteChange
     * @description: Stores the selected Force.com site.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    handleSiteChange(event) {
        this.selectedSite = event.detail.value;
    }

    /**
     * Method Name: saveWebhookSite
     * @description: Validates the selected site and opens the save confirmation dialog.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    saveWebhookSite() {
        if (!this.selectedSite) {
            this.showToast('Validation Error', 'Please select a Force.com site.', 'error');
            return;
        }
        const siteUrl = this.selectedSite;
        this.openConfirmation({
            title: 'Confirm Webhook Site',
            message: 'Google lead form webhooks will be delivered to this site. Once a mapping exists this cannot be changed. Do you want to continue?',
            confirmLabel: 'Save',
            action: () => this.confirmSaveWebhook(siteUrl)
        });
    }

    /**
     * Method Name: confirmSaveWebhook
     * @description: Saves the selected webhook site and shows the background-sync notice.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    confirmSaveWebhook(siteUrl) {
        return this.withLoading(async () => {
            await saveWebhookUrl({ siteUrl });
            this.webhookUrl = siteUrl;
            this.isWebhookModalOpen = false;
            this.syncNotice = NOTICE_WEBHOOK_SAVED;
            this.showToast('Success', 'Webhook site saved. It may take a few moments to take effect.', 'success');
        });
    }

    // ===================== Confirmation dialog =====================

    /**
     * Method Name: openConfirmation
     * @description: Opens the confirmation dialog with the given texts and the action to run on confirm.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    openConfirmation({ title, message, confirmLabel = 'Confirm', cancelLabel = 'Cancel', isDanger = false, action }) {
        this.confirmation = { isOpen: true, title, message, confirmLabel, cancelLabel, isDanger, action };
    }

    /**
     * Method Name: cancelConfirmation
     * @description: Closes the confirmation dialog without running the action.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    cancelConfirmation() {
        this.confirmation = { ...CLOSED_CONFIRMATION };
    }

    /**
     * Method Name: confirmAction
     * @description: Closes the dialog and runs the confirmed action; an unexpected error shows a toast.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    async confirmAction() {
        const { action } = this.confirmation;
        this.cancelConfirmation();
        if (typeof action !== 'function') {
            return;
        }
        try {
            await action();
        } catch (error) {
            console.error(error);
            this.isLoading = false;
            this.showToast('Error', this.getErrorMessage(error), 'error');
        }
    }

    /**
     * Method Name: confirmButtonClass
     * @description: Getter for the confirm button CSS class (red for dangerous actions).
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get confirmButtonClass() {
        return this.confirmation.isDanger ? 'exp-red-btn-css' : 'exp-blue-btn-css';
    }

    // ===================== Getters =====================

    /**
     * Method Name: hasFailedLeads
     * @description: Getter to check if there are failed leads to show.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get hasFailedLeads() {
        return this.failedLeads.length > 0;
    }

    /**
     * Method Name: selectedFailedIds
     * @description: Getter for the Ids of the selected failed leads.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get selectedFailedIds() {
        return this.failedLeads.filter(lead => lead.isSelected).map(lead => lead.id);
    }

    /**
     * Method Name: isAllFailedSelected
     * @description: Getter to check if every failed lead is selected.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get isAllFailedSelected() {
        return this.failedLeads.length > 0 && this.failedLeads.every(lead => lead.isSelected);
    }

    /**
     * Method Name: isFailedActionDisabled
     * @description: Getter to disable retry and discard buttons while loading or when nothing is selected.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get isFailedActionDisabled() {
        return this.isLoading || this.selectedFailedIds.length === 0;
    }

    /**
     * Method Name: failedModalTitle
     * @description: Getter for the failed leads modal title.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get failedModalTitle() {
        return `Failed Leads - ${this.failedContext.formName}`;
    }

    /**
     * Method Name: failedSummary
     * @description: Getter for the failed and selected lead count text.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get failedSummary() {
        return `${this.failedLeads.length} failed lead(s), ${this.selectedFailedIds.length} selected`;
    }

    /**
     * Method Name: hasPendingRetry
     * @description: Getter to check if the wizard is open to fix a mapping before retrying failed leads.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get hasPendingRetry() {
        return this.pendingRetryIds.length > 0;
    }

    /**
     * Method Name: isAccountLocked
     * @description: Getter to lock the account selection while loading or in retry mode.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get isAccountLocked() {
        return this.isLoading || this.hasPendingRetry;
    }

    /**
     * Method Name: saveButtonLabel
     * @description: Getter for the wizard save button label.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get saveButtonLabel() {
        return this.hasPendingRetry ? `Save & Retry (${this.pendingRetryIds.length})` : 'Save Mapping';
    }

    /**
     * Method Name: retryBannerText
     * @description: Getter for the banner text shown while fixing a mapping for retry.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get retryBannerText() {
        return `Fixing the mapping for "${this.failedContext.formName}". After you save, ${this.pendingRetryIds.length} selected failed lead(s) will be retried automatically.`;
    }

    /**
     * Method Name: hasWebhookUrl
     * @description: Getter to check if a webhook site is configured.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get hasWebhookUrl() {
        return !!this.webhookUrl;
    }

    /**
     * Method Name: showWebhookHint
     * @description: Getter to show the hint asking to select a webhook site once connected.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get showWebhookHint() {
        return this.hasConnection && !this.hasWebhookUrl;
    }

    /**
     * Method Name: isWebhookLocked
     * @description: Getter to check if the webhook site is locked because mappings exist.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get isWebhookLocked() {
        return this.hasMappings && this.hasWebhookUrl;
    }

    /**
     * Method Name: webhookButtonTitle
     * @description: Getter for the webhook button tooltip.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get webhookButtonTitle() {
        return this.isWebhookLocked ? 'The webhook site cannot be changed while mappings exist. Delete all mappings to change it.' : 'Select the Force.com site that receives Google leads';
    }

    /**
     * Method Name: hasSiteOptions
     * @description: Getter to check if any active site is available.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get hasSiteOptions() {
        return this.siteOptions.length > 0;
    }

    /**
     * Method Name: isSaveWebhookDisabled
     * @description: Getter to disable saving when no new site is selected or while loading.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get isSaveWebhookDisabled() {
        return !this.selectedSite || this.selectedSite === this.webhookUrl || this.isLoading;
    }

    /**
     * Method Name: webhookEndpointPreview
     * @description: Getter for the full webhook endpoint of the selected site.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get webhookEndpointPreview() {
        return this.selectedSite ? `${this.selectedSite.replace(/\/+$/, '')}/services/apexrest/Lead` : '';
    }

    /**
     * Method Name: editAccountName
     * @description: Getter for the account name shown in edit mode.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get editAccountName() {
        return this.fullMappingJson?.[this.selectedAccount]?.accountName || this.getAccountName(this.selectedAccount);
    }

    /**
     * Method Name: editFormName
     * @description: Getter for the form name shown in edit mode.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get editFormName() {
        return this.fullMappingJson?.[this.selectedAccount]?.forms?.[this.selectedFormId]?.formName || `Form ID: ${this.selectedFormId}`;
    }

    /**
     * Method Name: isFormSectionDisabled
     * @description: Getter to disable the form section until an account is selected.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get isFormSectionDisabled() {
        return !this.selectedAccount;
    }

    /**
     * Method Name: isSaveDisabled
     * @description: Getter to disable the wizard save button until a connection, account and form exist.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get isSaveDisabled() {
        return !this.hasConnection || !this.selectedAccount || !this.selectedFormId || this.isLoading;
    }

    /**
     * Method Name: isSaveConnectionDisabled
     * @description: Getter to disable saving the token when it is blank or while loading.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get isSaveConnectionDisabled() {
        return !this.refreshToken?.trim() || this.isLoading;
    }

    /**
     * Method Name: additionalFieldOptions
     * @description: Getter for the Salesforce fields not yet added as mapping rows.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get additionalFieldOptions() {
        const used = new Set(this.currentFormFields.map(field => field.key));
        return this.salesforceLeadFields.filter(field => !used.has(field.value)).map(field => ({ label: field.label || this.formatFieldLabel(field.value), value: field.value }));
    }

    /**
     * Method Name: hasAdditionalFieldOptions
     * @description: Getter to check if any extra Salesforce field can still be added.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get hasAdditionalFieldOptions() {
        return this.additionalFieldOptions.length > 0;
    }

    /**
     * Method Name: isAddFieldDisabled
     * @description: Getter to disable the add button until an extra field is selected.
     * Date: 05/10/2026
     * Created By: Salmanhaider Aghariya
     */
    get isAddFieldDisabled() {
        return !this.selectedAdditionalField;
    }
}