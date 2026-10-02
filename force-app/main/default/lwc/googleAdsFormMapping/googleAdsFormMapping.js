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

    connectedCallback() {
        loadStyle(this, GlobalStyles).catch(error => console.error('Error loading globalStyles', error));
        this.loadInitialData();
    }

    // ===================== Generic helpers =====================
    // Runs task with the spinner on; shows an error toast on failure.
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

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    getErrorMessage(error) {
        return error?.body?.message || error?.message || 'An unexpected error occurred.';
    }

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

    clone(value) {
        return JSON.parse(JSON.stringify(value || {}));
    }

    formatFieldLabel(value) {
        return value ? String(value).replace(/_/g, ' ').replace(/\b\w/g, char => char.toUpperCase()) : '';
    }

    getAccount(accountId) {
        return this.accounts.find(account => String(account.id) === String(accountId));
    }

    getAccountName(accountId) {
        return this.getAccount(accountId)?.descriptiveName || `Google Ads Account ${accountId}`;
    }

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
    async loadInitialData() {
        await this.withLoading(async () => {
            await this.loadConnection();
            await this.loadMappingData();
        });
        this.hasLoaded = true;
    }

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

    async ensureMappingData() {
        if (!this.isMappingDataLoaded) {
            await this.loadMappingData();
        }
    }

    async loadConnection() {
        try {
            this.accounts = (await getConnection()) || [];
        } catch (error) {
            this.accounts = [];
            throw error;
        }
    }

    get hasConnection() {
        return this.accounts.length > 0;
    }

    get accountOptions() {
        return this.accounts.map(account => ({
            label: account.descriptiveName ? `${account.descriptiveName} (${account.id})` : String(account.id),
            value: String(account.id)
        }));
    }

    // ---------- connection card ----------
    get showConnectionScreen() {
        return this.hasLoaded && !this.hasConnection;
    }

    get showConnectIntro() {
        return !this.showTokenInput && !this.isConnectionPending;
    }

    get showTokenForm() {
        return this.showTokenInput && !this.isConnectionPending;
    }

    get connectionStatusLabel() {
        return this.isConnectionPending ? 'Connection pending' : 'Not Connected';
    }

    get connectionStatusClass() {
        return this.isConnectionPending ? 'connection-status connection-status--pending' : 'connection-status';
    }

    // Opens the Google consent screen in a new tab and reveals the token field.
    login() {
        return this.withLoading(async () => {
            const url = await getGoogleAuthUrl();
            if (url) {
                window.open(url, '_blank');
            }
            this.showTokenInput = true;
        });
    }

    handleShowTokenInput() {
        this.showTokenInput = true;
    }

    handleCancelConnection() {
        this.refreshToken = '';
        this.showTokenInput = false;
    }

    handleChangeToken() {
        this.isConnectionPending = false;
        this.showTokenInput = true;
    }

    handleChange(event) {
        this.refreshToken = event.target.value || '';
    }

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
            // The token is stored through an async metadata deployment, so it may not be readable yet.
            this.isConnectionPending = true;

            await this.loadConnection();
            if (this.hasConnection) {
                this.isConnectionPending = false;
                await this.ensureMappingData();
                this.showToast('Success', 'Google Ads connection saved successfully.', 'success');
            } else {
                this.showToast('Success', 'Token saved. It can take up to a minute to take effect.', 'success');
            }
        });
    }

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

    handleDisconnectClick() {
        this.openConfirmation({
            title: 'Disconnect Google Ads',
            message: 'Are you sure you want to disconnect Google Ads? This will remove Google Ads webhook subscriptions for all mapped forms, revoke the Google OAuth connection, and delete the saved Google Ads mappings.',
            confirmLabel: 'Disconnect',
            isDanger: true,
            action: () => this.confirmDisconnect()
        });
    }

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

    dismissSyncNotice() {
        this.syncNotice = '';
    }

    get hasSyncNotice() {
        return !!this.syncNotice;
    }

    // ===================== Wizard open / close =====================
    openWizard() {
        this.pendingRetryIds = [];
        this.resetWizard();
        this.isModalOpen = true;
    }

    openNewMappingModal() {
        if (!this.hasWebhookUrl) {
            this.showToast('Error', 'Select a Force.com webhook site before creating a mapping.', 'error');
            return;
        }
        this.openWizard();
    }

    resetWizard() {
        this.refreshToken = '';
        this.selectedAccount = '';
        this.selectedFormId = '';
        this.forms = [];
        this.showForms = false;
        this.currentFormFields = [];
        this.isEditMode = false;
    }

    closeModal() {
        if (this.isLoading) {
            return;
        }
        this.isModalOpen = false;
        this.isEditMode = false;
        this.restoreFailedModal();   // Cancel in retry mode goes back to the failed list
    }

    // ===================== Account / forms =====================
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

    // Apex returns standard fields and custom questions as plain strings.
    getGoogleFields(form) {
        return [...(form?.fields || []), ...(form?.customQuestions || [])].map(name => ({
            value: String(name),
            label: this.formatFieldLabel(name)
        }));
    }

    selectFormCard(event) {
        if (this.hasPendingRetry) {   // form is locked while fixing a mapping for failed leads
            return;
        }
        this.selectedFormId = event.currentTarget.dataset.id;
        this.forms = this.forms.map(form => {
            const isSelected = String(form.id) === String(this.selectedFormId);
            return { ...form, isSelected, ariaPressed: String(isSelected) };
        });
        this.prepareFormFields();
    }

    handleFormCardKeydown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.selectFormCard(event);
        }
    }

    get formStepBadgeClass() {
        return this.isFormSectionDisabled ? 'wizard-step-badge wizard-step-badge--disabled' : 'wizard-step-badge';
    }

    // ===================== Mapping rows =====================
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

    isRequiredField(field) {
        return String(field?.required) === 'true';
    }

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

    // Derived template flags, recomputed whenever a row changes.
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

    updateField(key, patch) {
        this.currentFormFields = this.currentFormFields.map(field =>
            field.key === key ? this.decorate({ ...field, showRequiredError: false, ...patch }) : field
        );
    }

    handleSourceTypeChange(event) {
        this.updateField(event.target.dataset.key, {
            sourceType: event.detail.value,
            googleField: '',
            customValue: ''
        });
    }

    handleGoogleFieldChange(event) {
        this.updateField(event.target.dataset.key, { googleField: event.detail.value });
    }

    handleCustomValueChange(event) {
        this.updateField(event.target.dataset.key, { customValue: event.target.value || '' });
    }

    handleReferenceChange(event) {
        this.updateField(event.target.dataset.key, { customValue: event.detail.recordId || '' });
    }

    // ---------- add extra Salesforce field ----------
    handleShowAddField() {
        this.showAddField = true;
    }

    handleCancelAddField() {
        this.selectedAdditionalField = '';
        this.showAddField = false;
    }

    handleAdditionalFieldChange(event) {
        this.selectedAdditionalField = event.detail.value;
    }

    handleAddField() {
        const salesforceField = this.salesforceLeadFields.find(field => field.value === this.selectedAdditionalField);
        if (!salesforceField) {
            return;
        }
        this.currentFormFields = [...this.currentFormFields, this.buildFieldRow(salesforceField)];
        this.handleCancelAddField();
    }

    // ===================== Save mapping =====================
    isMapped(field) {
        return (field.sourceType === SOURCE_GOOGLE && !!field.googleField) ||
            (field.sourceType === SOURCE_CUSTOM && !!field.customValue?.trim());
    }

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

    markRequiredErrors() {
        this.currentFormFields = this.currentFormFields.map(field =>
            field.required ? this.decorate({ ...field, showRequiredError: !this.isMapped(field) }) : field
        );
    }

    buildCurrentMapping() {
        const mapping = {};
        this.currentFormFields.filter(field => this.isMapped(field)).forEach(field => {
            mapping[field.key] = field.sourceType === SOURCE_GOOGLE
                ? { sourceType: SOURCE_GOOGLE, googleField: field.googleField }
                : { sourceType: SOURCE_CUSTOM, customValue: field.customValue.trim() };
        });
        return mapping;
    }

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

    confirmSaveMapping(mappingJson) {
        const retryIds = [...this.pendingRetryIds];

        return this.withLoading(async () => {
            const result = await saveMapping({ mappingJson });
            if (!result?.success) {
                throw new Error(result?.message || 'Failed to save mapping.');
            }

            this.fullMappingJson = JSON.parse(mappingJson);
            this.buildTableData();
            this.isModalOpen = false;
            this.showToast('Success', 'Google Ads form mapping saved successfully.', 'success');

            if (retryIds.length) {
                this.pendingRetryIds = [];
                this.isFailedModalOpen = true;
                await this.runRetry(retryIds);   // mapping is saved, now reprocess
            }
        });
    }

    // ===================== Mapping table =====================
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

    handleToggleRow(event) {
        const rowId = event.currentTarget.dataset.id;
        this.tableData = this.tableData.map(row => ({
            ...row,
            isExpanded: row.id === rowId ? !row.isExpanded : row.isExpanded
        }));
    }

    handleEditRow(event) {
        const hit = this.findFormRow(event.currentTarget.dataset.id);
        if (hit) {
            this.editRow(hit.formRow, hit.accountRow.accountId);
        }
    }

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

    get hasMappings() {
        return this.tableData.length > 0;
    }

    // ===================== Failed leads =====================
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
        this.withLoading(() => this.refreshFailedLeads());
    }

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

    closeFailedModal() {
        if (this.isLoading) {
            return;
        }
        this.isFailedModalOpen = false;
        this.failedLeads = [];
    }

    restoreFailedModal() {
        if (this.pendingRetryIds.length) {
            this.pendingRetryIds = [];
            this.isFailedModalOpen = true;   // selection is still in this.failedLeads
        }
    }

    handleFailedLeadSelect(event) {
        const { id } = event.target.dataset;
        const checked = event.target.checked;
        this.failedLeads = this.failedLeads.map(lead => (lead.id === id ? { ...lead, isSelected: checked } : lead));
    }

    handleSelectAllFailed(event) {
        const checked = event.target.checked;
        this.failedLeads = this.failedLeads.map(lead => ({ ...lead, isSelected: checked }));
    }

    handleRetrySelected() {
        return this.runRetry(this.selectedFailedIds);
    }

    async handleEditMappingAndRetry() {
        const ids = this.selectedFailedIds;
        if (!ids.length) {
            return;
        }
        const { accountId, formId } = this.failedContext;
        this.pendingRetryIds = ids;
        this.isFailedModalOpen = false;
        await this.editRow({ formId }, accountId);   // reuses the existing wizard, prefilled
    }

    async runRetry(ids) {
        if (!ids?.length) {
            return;
        }
        await this.withLoading(async () => {
            const results = await retryFailedLeads({ errorIds: ids });
            const succeeded = results.filter(r => r.success).length;
            const failed = results.length - succeeded;

            await this.refreshFailedLeads();

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

    confirmDiscard(ids) {
        return this.withLoading(async () => {
            const count = await discardFailedLeads({ errorIds: ids });
            await this.refreshFailedLeads();
            this.showToast('Success', `${count} failed lead(s) discarded.`, 'success');
        });
    }

    // ===================== Webhook site =====================
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

    closeWebhookModal() {
        if (!this.isLoading) {
            this.isWebhookModalOpen = false;
        }
    }

    handleSiteChange(event) {
        this.selectedSite = event.detail.value;
    }

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
    openConfirmation({ title, message, confirmLabel = 'Confirm', cancelLabel = 'Cancel', isDanger = false, action }) {
        this.confirmation = { isOpen: true, title, message, confirmLabel, cancelLabel, isDanger, action };
    }

    cancelConfirmation() {
        this.confirmation = { ...CLOSED_CONFIRMATION };
    }

    async confirmAction() {
        const { action } = this.confirmation;
        this.cancelConfirmation();
        if (typeof action === 'function') {
            await action();
        }
    }

    get confirmButtonClass() {
        return this.confirmation.isDanger ? 'exp-red-btn-css' : 'exp-blue-btn-css';
    }

    // ===================== Getters =====================
    get hasFailedLeads() {
        return this.failedLeads.length > 0;
    }

    get selectedFailedIds() {
        return this.failedLeads.filter(lead => lead.isSelected).map(lead => lead.id);
    }

    get isAllFailedSelected() {
        return this.failedLeads.length > 0 && this.failedLeads.every(lead => lead.isSelected);
    }

    get isFailedActionDisabled() {
        return this.isLoading || this.selectedFailedIds.length === 0;
    }

    get failedModalTitle() {
        return `Failed Leads - ${this.failedContext.formName}`;
    }

    get failedSummary() {
        return `${this.failedLeads.length} failed lead(s), ${this.selectedFailedIds.length} selected`;
    }

    get hasPendingRetry() {
        return this.pendingRetryIds.length > 0;
    }

    get isAccountLocked() {
        return this.isLoading || this.hasPendingRetry;
    }

    get saveButtonLabel() {
        return this.hasPendingRetry ? `Save & Retry (${this.pendingRetryIds.length})` : 'Save Mapping';
    }

    get retryBannerText() {
        return `Fixing the mapping for "${this.failedContext.formName}". After you save, ${this.pendingRetryIds.length} selected failed lead(s) will be retried automatically.`;
    }

    get hasWebhookUrl() {
        return !!this.webhookUrl;
    }

    get showWebhookHint() {
        return this.hasConnection && !this.hasWebhookUrl;
    }

    get isWebhookLocked() {
        return this.hasMappings && this.hasWebhookUrl;
    }

    get webhookButtonTitle() {
        return this.isWebhookLocked ? 'The webhook site cannot be changed while mappings exist. Delete all mappings to change it.' : 'Select the Force.com site that receives Google leads';
    }

    get hasSiteOptions() {
        return this.siteOptions.length > 0;
    }

    get isSaveWebhookDisabled() {
        return !this.selectedSite || this.selectedSite === this.webhookUrl || this.isLoading;
    }

    get webhookEndpointPreview() {
        return this.selectedSite ? `${this.selectedSite.replace(/\/+$/, '')}/services/apexrest/Lead` : '';
    }

    get editAccountName() {
        return this.fullMappingJson?.[this.selectedAccount]?.accountName || this.getAccountName(this.selectedAccount);
    }

    get editFormName() {
        return this.fullMappingJson?.[this.selectedAccount]?.forms?.[this.selectedFormId]?.formName || `Form ID: ${this.selectedFormId}`;
    }

    get isFormSectionDisabled() {
        return !this.selectedAccount;
    }

    get isSaveDisabled() {
        return !this.hasConnection || !this.selectedAccount || !this.selectedFormId || this.isLoading;
    }

    get isSaveConnectionDisabled() {
        return !this.refreshToken?.trim() || this.isLoading;
    }

    get additionalFieldOptions() {
        const used = new Set(this.currentFormFields.map(field => field.key));
        return this.salesforceLeadFields.filter(field => !used.has(field.value)).map(field => ({ label: field.label || this.formatFieldLabel(field.value), value: field.value }));
    }

    get hasAdditionalFieldOptions() {
        return this.additionalFieldOptions.length > 0;
    }

    get isAddFieldDisabled() {
        return !this.selectedAdditionalField;
    }
}