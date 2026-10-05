import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getConnectedPages from '@salesforce/apex/MetaAdsFormMappingController.getConnectedPages';
import getLeadForms from '@salesforce/apex/MetaAdsFormMappingController.getLeadForms';
import getSalesforceLeadFields from '@salesforce/apex/MetaAdsFormMappingController.getSalesforceLeadFields';
import getExistingMappings from '@salesforce/apex/MetaAdsFormMappingController.getExistingMappings';
import saveMappingApex from '@salesforce/apex/MetaAdsFormMappingController.saveMapping';
import deactivateConnection from '@salesforce/apex/MetaAdsTokenController.deactivateConnection';
import checkConnectionStatus from '@salesforce/apex/MetaAdsTokenController.checkConnectionStatus';
import getFailedLeads from '@salesforce/apex/MetaAdsFormMappingController.getFailedLeads';
import retryFailedLead from '@salesforce/apex/MetaAdsFormMappingController.retryFailedLead';
import retryMultipleFailedLeads from '@salesforce/apex/MetaAdsFormMappingController.retryMultipleFailedLeads';
import deleteFailedLeads from '@salesforce/apex/MetaAdsFormMappingController.deleteFailedLeads';
import getActiveSites from '@salesforce/apex/MetaAdsFormMappingController.getActiveSites';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import globalStyles from '@salesforce/resourceUrl/globalStyles';

const SOURCE_META = 'Meta Form Field';
const SOURCE_CUSTOM = 'Custom Value';

const DEFAULT_SALESFORCE_FIELDS = [
    'FirstName',
    'LastName',
    'Email',
    'Phone'
];

export default class MetaAdsFormMapping extends LightningElement {
    
    @track isLoading = true;
    @track tableData = [];
    @track connectedAccountName = '';

    @track isModalOpen = false;
    @track isModalLoading = false;
    @track isEditingMode = false;
    @track spinnerLabel = 'Loading forms...';

    @track isWebhookModalOpen = false;
    @track siteOptions = [];
    @track selectedSite = '';

    @track availablePages = [];      // Pages from Meta API
    @track availableForms = [];      // Forms for selected page
    @track salesforceLeadFields = []; // SF Contact fields

    @track selectedPageId = '';
    @track selectedFormId = '';
    @track currentFormFields = [];   // [{ key, label, value, options }]
    @track formsLoaded = false;      // true once forms have been fetched for selected page
    @track availableSalesforceFields = [];

    @track actionDropdown = {
        isOpen: false,
        id: null,
        formId: null,
        top: 0,
        left: 0
    };
    @track showAddField = false;
    @track selectedAdditionalField = '';

    pendingAction = null;
    pendingRow = null;

    @track isFailedLeadsModalOpen = false;
    @track failedWizardStep = 1;
    @track activeFailedLeadId = null;
    failedLeadDataMap = {};
    @track failedLeads = [];
    @track isRetrying = false;
    selectedFailedLeadsFormId = '';
    pendingRetryIds = [];  // IDs pending retry after mapping edit
    
    // ─── GETTERS ─────────────────────────────────────────────────────────────

    /** 
     * @description Checks if failed wizard is on step 1 
     */
    get isFailedWizardStep1() { return this.failedWizardStep === 1; }
    
    /** 
     * @description Checks if failed wizard is on step 2 
     */
    get isFailedWizardStep2() { return this.failedWizardStep === 2; }

    /** 
     * @description Checks if all failed leads are selected 
     */
    get isAllFailedLeadsSelected() {
        try {
            return this.failedLeads.length > 0 && this.failedLeads.every(l => l.selected);
        } catch (e) { console.error(e); return false; }
    }

    /** 
     * @description Checks if any failed leads are selected 
     */
    get hasSelectedFailedLeads() {
        try {
            return this.failedLeads && this.failedLeads.some(l => l.selected);
        } catch (e) { console.error(e); return false; }
    }

    /** 
     * @description Checks if there are any mappings 
     */
    get hasMappings() {
        try { return this.tableData.length > 0; } catch (e) { console.error(e); return false; }
    }

    /** 
     * @description Form section is locked until a page is chosen 
     */
    get isFormSectionDisabled() {
        try { return !this.selectedPageId || this.isEditingMode; } catch (e) { console.error(e); return true; }
    }

    /** 
     * @description Page selection is disabled while loading or in edit mode 
     */
    get isPageSelectionDisabled() {
        try { return this.isModalLoading || this.isEditingMode; } catch (e) { console.error(e); return true; }
    }

    /** 
     * @description Form dropdown is disabled while loading OR no page selected OR in edit mode 
     */
    get isFormDropdownDisabled() {
        try { return this.isModalLoading || !this.selectedPageId || this.isEditingMode; } catch (e) { console.error(e); return true; }
    }

    /** 
     * @description Show "no forms" message only after forms have been fetched and list is empty 
     */
    get showNoFormsMsg() {
        try { return this.formsLoaded && this.selectedPageId && this.formOptions.length === 0; } catch (e) { console.error(e); return false; }
    }

    /** 
     * @description Show field-mapping section only when a form is selected AND fields exist 
     */
    get hasFormFields() {
        try { return !!this.selectedFormId; } catch (e) { console.error(e); return false; }
    }

    /** 
     * @description Save is enabled only when a form is selected 
     */
    get isSaveDisabled() {
        try { return !this.selectedFormId || this.isModalLoading; } catch (e) { console.error(e); return true; }
    }

    /** 
     * @description Gets the name of the page being edited 
     */
    get editPageName() {
        try {
            if (!this.selectedPageId) return '';
            const p = this.availablePages.find(page => String(page.id) === String(this.selectedPageId));
            return p ? p.name : this.selectedPageId;
        } catch (e) { console.error(e); return ''; }
    }

    /** 
     * @description Gets the name of the form being edited 
     */
    get editFormName() {
        try {
            if (!this.selectedFormId) return '';
            const f = this.availableForms.find(form => String(form.id) === String(this.selectedFormId));
            return f ? f.name : this.selectedFormId;
        } catch (e) { console.error(e); return ''; }
    }

    /** 
     * @description Formats the available pages as combobox options 
     */
    get pageOptions() {
        try {
            return this.availablePages.map(p => {
                return { label: `${p.name} (${p.id})`, value: String(p.id) };
            });
        } catch (e) { console.error(e); return []; }
    }

    /** 
     * @description Formats the available forms as combobox options and filters out already mapped ones 
     */
    get formOptions() {
        try {
            return this.availableForms.map(f => {
                return { label: `${f.name} (${f.id})`, value: String(f.id) };
            }).filter(opt => {
                if (opt.value === this.selectedFormId) return true;
                let pageRow = this.tableData.find(row => String(row.pageId) === String(this.selectedPageId));
                if (pageRow) {
                    return !pageRow.forms.some(f => String(f.formId) === opt.value);
                }
                return true;
            });
        } catch (e) { console.error(e); return []; }
    }

    /** 
     * @description Gets options for adding a new field 
     */
    get additionalFieldOptions() {
        try {
            return this.availableSalesforceFields
                .filter(field => !this.currentFormFields.some(current => current.key === field.value))
                .map(field => ({ label: field.label, value: field.value }));
        } catch (e) { console.error(e); return []; }
    }

    /** 
     * @description Checks if there are any additional fields available to add 
     */
    get hasAdditionalFieldOptions() {
        try { return this.additionalFieldOptions.length > 0; } catch (e) { console.error(e); return false; }
    }

    /** 
     * @description Disables the Add Field button if no field is selected 
     */
    get isAddFieldDisabled() {
        try { return !this.selectedAdditionalField; } catch (e) { console.error(e); return true; }
    }

    /** 
     * @description Checks if action buttons for failed leads should be disabled 
     */
    get isFailedActionDisabled() {
        try { return !this.hasSelectedFailedLeads || this.isRetrying; } catch (e) { console.error(e); return true; }
    }

    /** 
     * @description Checks if editing a failed lead mapping should be disabled 
     */
    get isEditMappingDisabled() {
        try {
            if (!this.failedLeads) return true;
            const selectedCount = this.failedLeads.filter(l => l.selected).length;
            return selectedCount === 0 || this.isRetrying;
        } catch (e) { console.error(e); return true; }
    }

    /** 
     * @description Checks if there are any Site options available for Webhook 
     */
    get hasSiteOptions() {
        try { return this.siteOptions.length > 0; } catch (e) { console.error(e); return false; }
    }

    /** 
     * @description Checks if Webhook copy button should be disabled 
     */
    get isCopyWebhookDisabled() {
        try { return !this.selectedSite; } catch (e) { console.error(e); return true; }
    }

    /** 
     * @description Gets the label for the failed summary 
     */
    get failedSummary() {
        try {
            const total = this.failedLeads.length;
            const selected = this.failedLeads.filter(l => l.selected).length;
            return `${total} failed lead(s), ${selected} selected`;
        } catch (e) { console.error(e); return ''; }
    }

    /** 
     * @description Checks if there is a pending retry (after edit mapping) 
     */
    get hasPendingRetry() {
        try { return this.pendingRetryIds.length > 0; } catch (e) { return false; }
    }

    /** 
     * @description Gets the save button label depending on pending retry state 
     */
    get saveButtonLabel() {
        try {
            return this.hasPendingRetry ? `Save & Retry (${this.pendingRetryIds.length})` : 'Save Mapping';
        } catch (e) { return 'Save Mapping'; }
    }

    /** 
     * @description Gets the retry banner text 
     */
    get retryBannerText() {
        try {
            return `Fixing mapping for this form. After saving, ${this.pendingRetryIds.length} selected failed lead(s) will be retried automatically.`;
        } catch (e) { return ''; }
    }

    /** 
     * @description Generates the Webhook endpoint URL preview 
     */
    get webhookEndpointPreview() {
        try {
            if (!this.selectedSite) return '';
            let base = this.selectedSite.replace(/\/+$/, '');
            return `${base}/services/apexrest/MVEX/PAGE/webhooks/`;
        } catch (e) { console.error(e); return ''; }
    }

    get actionDropdownStyle() {
        return `position: fixed; top: ${this.actionDropdown.top}px; left: ${this.actionDropdown.left}px; z-index: 9999;`;
    }

    // ─── LIFECYCLE HOOKS ─────────────────────────────────────────────────────

    // Overall JSON state — { pageId: { pageName, forms: { formId: { formName, mappings: {} } } } }
    fullMappingJson = {};

    currentClientAppId = '';

    /**
     * @description Called when the component is inserted into the DOM.
     * Loads required styles and initial data.
     */
    connectedCallback() {
        try {
            Promise.all([
                loadStyle(this, MulishFontCss),
                loadStyle(this, globalStyles)
            ]).catch(error => {
                console.error('Error loading styles', error);
            });
            this.loadInitialData();
        } catch (e) {
            console.error('Error in connectedCallback', e);
        }
    }

    async loadInitialData() {
        this.isLoading = true;
        try {
            // 1. Get SF Fields
            this.salesforceLeadFields = await getSalesforceLeadFields();
            
            // 2. Get Existing Mappings
            const existing = await getExistingMappings();
            if (existing) {
                let parsedJson = JSON.parse(existing);
                // Migrate if root is clientAppId (e.g. 'default_app_id' or similar non-numeric)
                // A Meta page ID is numeric. If the root key isn't numeric, it's likely a clientAppId.
                let newRootJson = {};
                for (let key in parsedJson) {
                    if (isNaN(key)) {
                        // It's a clientAppId, extract the pages inside it
                        let pagesObj = parsedJson[key];
                        for (let pKey in pagesObj) {
                            newRootJson[pKey] = pagesObj[pKey];
                        }
                    } else {
                        newRootJson[key] = parsedJson[key];
                    }
                }
                this.fullMappingJson = newRootJson;
            } else {
                this.fullMappingJson = {};
            }
            
            // 3. Pre-fetch pages
            const pagesRes = await getConnectedPages();
            if (pagesRes && pagesRes.success) {
                if (pagesRes.pages) {
                    this.availablePages = pagesRes.pages;
                }
            } else if (pagesRes && !pagesRes.success) {
                this.showToast('Warning', 'Could not fetch pages from Meta API. ' + (pagesRes.message || ''), 'warning');
            }

            // Client App ID logic isn't tied to a specific page anymore, but we can extract it if needed
            // For now we assume a single client app id environment
            this.currentClientAppId = 'default_app_id'; // We can adapt this if multi-app is needed

            const statusRes = await checkConnectionStatus();
            if (statusRes && statusRes.success) {
                this.connectedAccountName = `Connected - ${statusRes.client_app_id}`;
            }

            this.buildTableData();
            
        } catch (error) {
            console.error('Error loading data', error);
            this.showToast('Error', 'Failed to load initial data.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    buildTableData() {
        let data = [];
        let pageIndex = 1;
        // traverse fullMappingJson
        for (let pId in this.fullMappingJson) {
            let pageObj = this.fullMappingJson[pId];
            
            let isNewFormat = pageObj.forms !== undefined;
            let pageName = isNewFormat ? pageObj.pageName : 'Page ID: ' + pId;
            let formsObj = isNewFormat ? pageObj.forms : pageObj;
            
            if (!isNewFormat || pageName === 'Page ID: ' + pId) {
                let pageNameObj = this.availablePages.find(p => String(p.id) === String(pId));
                if (pageNameObj) pageName = pageNameObj.name;
            }
            
            let pageRow = {
                index: pageIndex++,
                id: pId,
                pageId: pId,
                pageName: pageName,
                isExpanded: false,
                forms: []
            };
            
            let formIndex = 1;
            for (let fId in formsObj) {
                let formVal = formsObj[fId];
                // Check if old format (formVal is a string/object mapping instead of having 'mappings')
                // Wait, if it's the old format but nested under clientAppId, pId would be the clientAppId!
                // Let's migrate clientAppId logic in loadInitialData, or handle it gracefully.
                // If the root key is NOT a numeric Page ID but rather 'default_app_id', this might break.
                // I will add a migration step in loadInitialData to flatten it if it has a clientAppId.
                
                let isFormNewFormat = formVal.mappings !== undefined;
                let formName = isFormNewFormat ? formVal.formName : 'Form ID: ' + fId;
                let mappings = isFormNewFormat ? formVal.mappings : formVal;
                
                if (!isFormNewFormat || formName === 'Form ID: ' + fId) {
                    let fData = this.availableForms.find(f => String(f.id) === String(fId));
                    if (fData) formName = fData.name;
                }
                
                pageRow.forms.push({
                    index: formIndex++,
                    id: fId + '_' + pId,
                    formId: fId,
                    pageId: pId,
                    formName: formName,
                    mappedCount: Object.keys(mappings).length,
                    mappings: mappings
                });
            }
            data.push(pageRow);
        }
        this.tableData = data;
    }



    // --- Modal Logic ---

    /**
     * @description Opens the modal for adding a new form mapping
     */
    openNewMappingModal() {
        try {
            this.selectedPageId    = '';
            this.selectedFormId    = '';
            this.availableForms    = [];
            this.currentFormFields = [];
            this.availableSalesforceFields = [];
            this.showAddField = false;
            this.selectedAdditionalField = '';
            this.formsLoaded       = false;
            this.isEditingMode     = false;
            this.isModalOpen       = true;
        } catch (e) {
            console.error('Error in openNewMappingModal', e);
        }
    }

    /**
     * @description Closes the mapping modal. If a pending retry was in progress, reopen the failed leads modal.
     */
    closeModal() {
        this.isModalOpen = false;
        this.isEditingMode = false;
        // If user cancels out of edit-mapping-and-retry, go back to failed leads modal
        if (this.pendingRetryIds.length > 0) {
            this.pendingRetryIds = [];
            this.isFailedLeadsModalOpen = true;
        }
    }

    async handlePageSelection(event) {
        try {
            this.selectedPageId = event.detail.value;
            this.selectedFormId = '';
            this.availableForms = [];
            
            if (!this.selectedPageId) {
                return;
            }

            this.isModalLoading = true;
            this.spinnerLabel   = 'Loading forms...';
            this.formsLoaded    = false;
            const formsRes = await getLeadForms({ pageId: this.selectedPageId });
            if (formsRes && formsRes.success) {
                this.availableForms     = formsRes.forms || [];
                this.currentClientAppId = formsRes.client_app_id || 'default_app_id';
                this.formsLoaded        = true;
            } else {
                this.showToast('Warning', 'Failed to fetch forms: ' + (formsRes.message || ''), 'warning');
                this.formsLoaded = true; // still mark loaded so error msg shows
            }
        } catch (error) {
            this.showToast('Error', 'Error fetching forms.', 'error');
            this.formsLoaded = true;
        } finally {
            this.isModalLoading = false;
        }
    }

    /**
     * @description Handles form selection change and generates field mappings based on Salesforce fields and Meta form questions.
     * @param {Event} event 
     */
    handleFormSelection(event) {
        try {
            this.selectedFormId = event.detail.value;
            if (!this.selectedFormId) {
                this.currentFormFields = [];
                return;
            }

            const form = this.availableForms.find(f => String(f.id) === String(this.selectedFormId));
            if (form && form.questions) {
                let existingMappings = {};
                if (this.fullMappingJson[this.selectedPageId]) {
                    let pageObj = this.fullMappingJson[this.selectedPageId];
                    let formsObj = pageObj.forms !== undefined ? pageObj.forms : pageObj;
                    if (formsObj[this.selectedFormId]) {
                        existingMappings = formsObj[this.selectedFormId].mappings !== undefined
                            ? formsObj[this.selectedFormId].mappings
                            : formsObj[this.selectedFormId];
                    }
                }

                let mappingData = {};
                const savedFieldKeys = [];
                
                for (let k in existingMappings) {
                    let val = existingMappings[k];
                    if (typeof val === 'object' && val !== null) {
                        mappingData[k] = val;
                        savedFieldKeys.push(k);
                    } else {
                        mappingData[val] = {
                            sourceType: (k.startsWith('"') && k.endsWith('"')) ? SOURCE_CUSTOM : SOURCE_META,
                            metaField: (k.startsWith('"') && k.endsWith('"')) ? '' : k,
                            customValue: (k.startsWith('"') && k.endsWith('"')) ? k.slice(1, -1) : ''
                        };
                        savedFieldKeys.push(val);
                    }
                }

                const fieldsToDisplay = this.salesforceLeadFields.filter(sf => {
                    const key = sf.value;
                    const required = sf.required === 'true';
                    const isDefault = DEFAULT_SALESFORCE_FIELDS.includes(key);
                    const isAlreadyMapped = savedFieldKeys.includes(key);

                    return (required || isDefault || isAlreadyMapped);
                });

                this.currentFormFields = fieldsToDisplay.map(sf => {
                    let key = sf.value;
                    let sfType = sf.type ? sf.type.toUpperCase() : 'STRING';
                    
                    let options = this.getFilteredMetaFieldOptions(form.questions, sfType);
                    let savedData = mappingData[key] || {};

                    let required = sf.required === 'true';

                    let sourceType = savedData.sourceType || '';
                    let customVal = savedData.customValue || '';
                    let metaVal = savedData.metaField || '';
                    
                    if (!sourceType && required) {
                        metaVal = this.autoMatchMetaField(key, options);
                        if (metaVal) sourceType = SOURCE_META;
                    }

                    return {
                        key: key,
                        label: sf.label.split(' (')[0],
                        sourceType: sourceType,
                        sourceOptions: [
                            { label: 'Do Not Map', value: '' },
                            { label: SOURCE_META, value: SOURCE_META },
                            { label: SOURCE_CUSTOM, value: SOURCE_CUSTOM }
                        ],
                        isMetaField: sourceType === SOURCE_META,
                        metaField: metaVal,
                        metaOptions: options,
                        isCustomValue: sourceType === SOURCE_CUSTOM,
                        customValue: customVal,
                        isReferenceField: this.isReferenceField(sf),
                        referenceTo: sf.referenceTo || '',
                        required: required,
                        showRequiredError: required && !sourceType,
                        rowClass: required && !sourceType
                            ? 'mapping-row mapping-row--required mapping-row--error'
                            : (required ? 'mapping-row mapping-row--required' : 'mapping-row')
                    };
                });

                this.availableSalesforceFields = this.salesforceLeadFields.map(sf => {
                    return {
                        label: sf.label.split(' (')[0],
                        value: sf.value,
                        type: sf.type,
                        referenceTo: sf.referenceTo || ''
                    };
                });

                this.selectedAdditionalField = '';
                this.showAddField = false;
            } else {
                this.currentFormFields = [];
                this.availableSalesforceFields = [];
            }
        } catch (error) {
            console.error('Error in handleFormSelection', error);
        }
    }

    /**
     * @description Automatically matches a Salesforce field to a Meta field based on naming priority or fuzzy matching.
     * @param {String} sfKey Salesforce API name
     * @param {Array} options Meta field options
     * @return {String} Matched Meta field value
     */
    autoMatchMetaField(sfKey, options) {
        try {
            if (!options || options.length === 0) return '';
            const norm = sfKey.toLowerCase().replace(/_/g, '').replace(/__c$/i, '');

            const priorityMap = {
                'email':          'email',
                'phone':          'phone_number',
                'mobilephone':    'phone_number',
                'firstname':      'first_name',
                'lastname':       'last_name',
                'mailingcity':    'city',
                'mailingstate':   'state',
                'mailingcountry': 'country',
                'mailingpostalcode': 'zip_code',
                'mailingstreet':  'street_address',
                'accountid':      'company_name',
                'title':          'job_title',
                'birthdate':      'date_of_birth'
            };

            const priorityMatch = priorityMap[norm];
            if (priorityMatch) {
                const found = options.find(o => o.value === priorityMatch);
                if (found) return found.value;
            }

            const fuzzy = options.find(o =>
                o.value.toLowerCase().includes(norm) ||
                norm.includes(o.value.toLowerCase())
            );
            return fuzzy ? fuzzy.value : '';
        } catch (e) {
            console.error('Error in autoMatchMetaField', e);
            return '';
        }
    }

    /**
     * @description Filters Meta field options based on the Salesforce field type.
     * @param {Array} formQuestions Meta form questions
     * @param {String} sfType Salesforce field type
     * @return {Array} Filtered options
     */
    getFilteredMetaFieldOptions(formQuestions, sfType) {
        try {
            let options = [];
            options.push({ label: 'Do Not Map', value: '' });
            
            formQuestions.forEach(q => {
                let metaType = (q.type || '').toUpperCase();
                let allowedSfTypes = ['STRING', 'TEXTAREA', 'PICKLIST', 'MULTIPICKLIST']; 

                if (metaType === 'EMAIL' || metaType === 'WORK_EMAIL') {
                    allowedSfTypes = ['EMAIL', 'STRING'];
                } else if (metaType === 'PHONE' || metaType === 'WORK_PHONE_NUMBER') {
                    allowedSfTypes = ['PHONE', 'STRING'];
                } else if (metaType === 'DOB' || metaType === 'DATE_OF_BIRTH') {
                    allowedSfTypes = ['DATE', 'DATETIME', 'STRING'];
                } else if (metaType === 'GENDER' || metaType === 'MARITAL_STATUS' || metaType === 'RELATIONSHIP_STATUS' || metaType === 'MILITARY_STATUS') {
                    allowedSfTypes = ['PICKLIST', 'STRING'];
                }

                if (allowedSfTypes.includes(sfType)) {
                    options.push({ label: q.label || q.key, value: q.key });
                }
            });
            
            return options;
        } catch (e) {
            console.error('Error in getFilteredMetaFieldOptions', e);
            return [];
        }
    }

    /**
     * @description Checks if a Salesforce field is a reference field.
     * @param {Object} salesforceField 
     * @return {Boolean}
     */
    isReferenceField(salesforceField) {
        try {
            return salesforceField?.type === 'REFERENCE' || !!salesforceField?.referenceTo;
        } catch (e) {
            console.error('Error in isReferenceField', e);
            return false;
        }
    }

    /**
     * @description Handles changes to the source type (Meta or Custom).
     * @param {Event} event 
     */
    handleSourceTypeChange(event) {
        try {
            const sfKey = event.target.dataset.key;
            const type = event.detail.value;

            this.currentFormFields = this.currentFormFields.map(f => {
                if (f.key === sfKey) {
                    let isMapped = (type === SOURCE_META && f.metaField) || (type === SOURCE_CUSTOM && f.customValue?.trim());
                    return Object.assign({}, f, {
                        sourceType: type,
                        isMetaField: type === SOURCE_META,
                        isCustomValue: type === SOURCE_CUSTOM,
                        showRequiredError: f.required && !isMapped,
                        rowClass: (f.required && !isMapped)
                            ? 'mapping-row mapping-row--required mapping-row--error'
                            : (f.required ? 'mapping-row mapping-row--required' : 'mapping-row')
                    });
                }
                return f;
            });
        } catch (e) {
            console.error('Error in handleSourceTypeChange', e);
        }
    }

    /**
     * @description Handles changes to the selected Meta field.
     * @param {Event} event 
     */
    handleMetaFieldChange(event) {
        try {
            const sfKey = event.target.dataset.key;
            const metaField = event.detail.value;

            this.currentFormFields = this.currentFormFields.map(f => {
                if (f.key === sfKey) {
                    let isMapped = (f.sourceType === SOURCE_META && metaField) || (f.sourceType === SOURCE_CUSTOM && f.customValue?.trim());
                    let leadVal = f.failedLeadValue;
                    if (this.failedWizardStep === 2 && this.failedLeadDataMap) {
                        leadVal = this.failedLeadDataMap[metaField] || '';
                    }
                    return Object.assign({}, f, {
                        metaField: metaField,
                        failedLeadValue: leadVal,
                        showRequiredError: f.required && !isMapped,
                        rowClass: (f.required && !isMapped)
                            ? 'mapping-row mapping-row--required mapping-row--error'
                            : (f.required ? 'mapping-row mapping-row--required' : 'mapping-row')
                    });
                }
                return f;
            });
        } catch (e) {
            console.error('Error in handleMetaFieldChange', e);
        }
    }

    /**
     * @description Handles changes to custom input values.
     * @param {Event} event 
     */
    handleCustomValueChange(event) {
        try {
            const sfKey = event.target.dataset.key;
            const customValue = event.target.value;

            this.currentFormFields = this.currentFormFields.map(f => {
                if (f.key === sfKey) {
                    let isMapped = (f.sourceType === SOURCE_META && f.metaField) || (f.sourceType === SOURCE_CUSTOM && customValue?.trim());
                    return Object.assign({}, f, {
                        customValue: customValue,
                        showRequiredError: f.required && !isMapped,
                        rowClass: (f.required && !isMapped)
                            ? 'mapping-row mapping-row--required mapping-row--error'
                            : (f.required ? 'mapping-row mapping-row--required' : 'mapping-row')
                    });
                }
                return f;
            });
        } catch (e) {
            console.error('Error in handleCustomValueChange', e);
        }
    }

    /**
     * @description Handles changes to reference lookup fields.
     * @param {Event} event 
     */
    handleReferenceChange(event) {
        try {
            const key = event.target.dataset.key;
            const recordId = event.detail.recordId || '';

            this.currentFormFields = this.currentFormFields.map(field => {
                if (field.key !== key) {
                    return field;
                }
                let isMapped = (field.sourceType === SOURCE_META && field.metaField) || (field.sourceType === SOURCE_CUSTOM && recordId?.trim());
                return Object.assign({}, field, {
                    customValue: recordId,
                    showRequiredError: field.required && !isMapped,
                    rowClass: (field.required && !isMapped)
                        ? 'mapping-row mapping-row--required mapping-row--error'
                        : (field.required ? 'mapping-row mapping-row--required' : 'mapping-row')
                });
            });
        } catch (e) {
            console.error('Error in handleReferenceChange', e);
        }
    }

    /**
     * @description Handles selection of a new additional field to add.
     * @param {Event} event 
     */
    handleAdditionalFieldChange(event) {
        try {
            this.selectedAdditionalField = event.detail.value;
        } catch (e) {
            console.error('Error in handleAdditionalFieldChange', e);
        }
    }

    /**
     * @description Shows the add field input section.
     */
    handleShowAddField() {
        this.showAddField = true;
    }

    /**
     * @description Hides the add field input section.
     */
    handleCancelAddField() {
        this.selectedAdditionalField = '';
        this.showAddField = false;
    }

    /**
     * @description Adds a new field to the current mapping layout.
     */
    handleAddField() {
        try {
            const fieldKey = this.selectedAdditionalField;

            if (!fieldKey) {
                return;
            }

            const salesforceField = this.availableSalesforceFields.find(field => field.value === fieldKey);

            if (!salesforceField) {
                return;
            }

            const form = this.availableForms.find(f => String(f.id) === String(this.selectedFormId));
            let sfType = salesforceField.type ? salesforceField.type.toUpperCase() : 'STRING';
            let options = form && form.questions ? this.getFilteredMetaFieldOptions(form.questions, sfType) : [];

            const newField = {
                key: salesforceField.value,
                label: salesforceField.label,
                required: false,
                sourceType: '',
                googleField: '',
                customValue: '',
                metaField: '',
                metaOptions: options,
                sourceOptions: [
                    { label: 'Do Not Map', value: '' },
                    { label: SOURCE_META, value: SOURCE_META },
                    { label: SOURCE_CUSTOM, value: SOURCE_CUSTOM }
                ],
                isMetaField: false,
                isCustomValue: false,
                isReferenceField: this.isReferenceField(salesforceField),
                referenceTo: salesforceField.referenceTo || '',
                showRequiredError: false,
                rowClass: 'mapping-row'
            };

            this.currentFormFields = [...this.currentFormFields, newField];
            this.handleCancelAddField();
        } catch (e) {
            console.error('Error in handleAddField', e);
        }
    }

    /**
     * @description Saves the configured form mapping to the backend.
     */
    async saveMapping() {
        try {
            const unmappedRequired = [];
            this.currentFormFields.forEach(f => {
                const isMapped = (f.sourceType === SOURCE_META && f.metaField) || (f.sourceType === SOURCE_CUSTOM && f.customValue?.trim());
                if (f.required && !isMapped) {
                    unmappedRequired.push(f.label);
                }
            });
            
            if (unmappedRequired.length > 0) {
                const names = unmappedRequired.join(', ');
                this.showToast('Validation Error',
                    `The following required Salesforce fields must be mapped before saving: ${names}`,
                    'error');
                return;
            }

            let formMapping = {};
            this.currentFormFields.forEach(f => {
                if (f.sourceType === SOURCE_META && f.metaField) {
                    formMapping[f.key] = {
                        sourceType: SOURCE_META,
                        metaField: f.metaField
                    };
                } else if (f.sourceType === SOURCE_CUSTOM && f.customValue?.trim()) {
                    formMapping[f.key] = {
                        sourceType: SOURCE_CUSTOM,
                        customValue: f.customValue.trim()
                    };
                }
            });

            // Ensure JSON structure and format migration
            let pageName = this.availablePages.find(p => String(p.id) === String(this.selectedPageId))?.name || 'Page ID: ' + this.selectedPageId;
            let formName = this.availableForms.find(f => String(f.id) === String(this.selectedFormId))?.name || 'Form ID: ' + this.selectedFormId;

            // Migrate old format to new format
            if (this.fullMappingJson[this.selectedPageId] && this.fullMappingJson[this.selectedPageId].forms === undefined) {
                 let oldForms = this.fullMappingJson[this.selectedPageId];
                 let migratedForms = {};
                 for (let oldFId in oldForms) {
                     migratedForms[oldFId] = {
                         formName: 'Form ID: ' + oldFId,
                         mappings: oldForms[oldFId]
                     };
                 }
                 this.fullMappingJson[this.selectedPageId] = {
                     pageName: pageName,
                     forms: migratedForms
                 };
            } else if (!this.fullMappingJson[this.selectedPageId]) {
                this.fullMappingJson[this.selectedPageId] = {
                    pageName: pageName,
                    forms: {}
                };
            }
            
            // Save mapping
            this.fullMappingJson[this.selectedPageId].forms[this.selectedFormId] = {
                formName: formName,
                mappings: formMapping
            };

            this.isModalLoading = true;
            try {
                const jsonStr = JSON.stringify(this.fullMappingJson);
                const result = await saveMappingApex({ mappingJson: jsonStr, pageId: this.selectedPageId });
                
                if (result && result.success) {
                    this.buildTableData();
                    this.isModalOpen = false;
                    this.isEditingMode = false;

                    if (this.pendingRetryIds.length > 0) {
                        // Bulk retry the selected leads with the updated mapping
                        const retryIds = [...this.pendingRetryIds];
                        this.pendingRetryIds = [];
                        this.isFailedLeadsModalOpen = true;
                        this.isRetrying = true;
                        try {
                            const results = await retryMultipleFailedLeads({ errorRecordIds: retryIds });
                            let successCount = 0;
                            let errorCount = 0;
                            for (let id in results) {
                                if (results[id] === 'Success') successCount++;
                                else errorCount++;
                            }
                            await this.loadFailedLeads();
                            if (errorCount === 0) {
                                this.showToast('Success', `Mapping saved & ${successCount} lead(s) retried successfully.`, 'success');
                            } else {
                                this.showToast('Retry Completed', `${successCount} success(es), ${errorCount} failure(s). Check the list for details.`, 'warning');
                            }
                        } catch (err) {
                            this.showToast('Error', err.body ? err.body.message : err.message, 'error');
                        } finally {
                            this.isRetrying = false;
                        }
                    } else {
                        this.showToast('Success', 'Form mapping saved and webhook subscribed successfully.', 'success');
                    }
                } else {
                    this.showToast('Error', result.message || 'Error saving mapping.', 'error');
                }
            } catch (error) {
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            } finally {
                this.isModalLoading = false;
            }
        } catch (e) {
            console.error('Error in saveMapping', e);
        }
    }

    // --- Table Actions ---

    /**
     * @description Toggles the expanded state of a table row.
     * @param {Event} event 
     */
    handleToggleRow(event) {
        try {
            const rowId = event.currentTarget.dataset.id;
            const row = this.tableData.find(r => r.id === rowId);
            if (row) {
                row.isExpanded = !row.isExpanded;
            }
        } catch (e) {
            console.error('Error in handleToggleRow', e);
        }
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    openActionDropdown(event) {
        event.stopPropagation();
        
        const id = event.currentTarget.dataset.id;
        const formId = event.currentTarget.dataset.formId;
        const rect = event.currentTarget.getBoundingClientRect();
        
        this.actionDropdown = {
            isOpen: true,
            id: id,
            formId: formId,
            top: rect.bottom + 4,
            left: rect.left - 130 
        };
        
        setTimeout(() => {
            this.dropdownCloseHandler = this.closeActionDropdown.bind(this);
            document.addEventListener('click', this.dropdownCloseHandler);
        }, 0);
    }

    closeActionDropdown() {
        this.actionDropdown.isOpen = false;
        document.removeEventListener('click', this.dropdownCloseHandler);
    }

    handleEditFromDropdown(event) {
        this.closeActionDropdown();
        const fakeEvent = { currentTarget: { dataset: { id: this.actionDropdown.id } } };
        this.handleEditRow(fakeEvent);
    }

    handleDeleteFromDropdown(event) {
        this.closeActionDropdown();
        const fakeEvent = { currentTarget: { dataset: { id: this.actionDropdown.id } } };
        this.handleDeleteRow(fakeEvent);
    }

    handleFailedLeadsFromDropdown(event) {
        this.closeActionDropdown();
        const fakeEvent = { currentTarget: { dataset: { id: this.actionDropdown.formId } } };
        this.openFailedLeadsModal(fakeEvent);
    }

    /**
     * @description Initiates the edit flow for a specific mapping row.
     * @param {Event} event 
     */
    handleEditRow(event) {
        try {
            const rowId = event.currentTarget.dataset.id;
            let targetRow = null;
            for (let page of this.tableData) {
                let found = page.forms.find(f => f.id === rowId);
                if (found) {
                    targetRow = found;
                    break;
                }
            }
            if (targetRow) {
                this.editRow(targetRow);
            }
        } catch (e) {
            console.error('Error in handleEditRow', e);
        }
    }

    /**
     * @description Initiates the delete flow for a specific mapping row.
     * @param {Event} event 
     */
    handleDeleteRow(event) {
        try {
            const rowId = event.currentTarget.dataset.id;
            let targetRow = null;
            for (let page of this.tableData) {
                let found = page.forms.find(f => f.id === rowId);
                if (found) {
                    targetRow = found;
                    break;
                }
            }
            if (targetRow) {
                this.pendingAction = 'delete';
                this.pendingRow = targetRow;
                this.showMessagePopup('Warning', 'Confirm Delete', 'Are you sure you want to delete this mapping?');
            }
        } catch (e) {
            console.error('Error in handleDeleteRow', e);
        }
    }

    /**
     * @description Prepares the component to edit an existing row's mapping.
     * @param {Object} row 
     */
    async editRow(row) {
        try {
            this.selectedPageId    = row.pageId;
            this.selectedFormId    = row.formId;
            this.availableForms    = [];
            this.currentFormFields = [];
            this.formsLoaded       = false;
            this.isEditingMode     = true;
            this.isModalOpen       = true;
            this.isModalLoading    = true;
            this.spinnerLabel      = 'Loading form fields...';

            try {
                const formsRes = await getLeadForms({ pageId: this.selectedPageId });
                if (formsRes && formsRes.success && formsRes.forms) {
                    this.availableForms = formsRes.forms;
                    this.formsLoaded    = true;
                }
                // Populate field mappings for the pre-selected form
                this.handleFormSelection({ detail: { value: this.selectedFormId } });
            } catch (error) {
                this.showToast('Error', 'Failed to load form details for editing.', 'error');
                this.closeModal();
            } finally {
                this.isModalLoading = false;
            }
        } catch (e) {
            console.error('Error in editRow', e);
        }
    }

    /**
     * @description Deletes an existing mapping row.
     * @param {Object} row 
     */
    async deleteRow(row) {
        try {
            this.isLoading = true;
            if (this.fullMappingJson[row.pageId]) {
                let pageObj = this.fullMappingJson[row.pageId];
                let isNewFormat = pageObj.forms !== undefined;
                let formsObj = isNewFormat ? pageObj.forms : pageObj;
                
                if (formsObj[row.formId]) {
                    delete formsObj[row.formId];
                    
                    if (Object.keys(formsObj).length === 0) {
                        delete this.fullMappingJson[row.pageId];
                    }
                }

                const jsonStr = JSON.stringify(this.fullMappingJson);
                const result = await saveMappingApex({ mappingJson: jsonStr, pageId: '' }); // Don't subscribe on delete
                
                if (result && result.success) {
                    this.showToast('Success', 'Mapping deleted.', 'success');
                    this.buildTableData();
                } else {
                    this.showToast('Error', 'Failed to delete mapping.', 'error');
                }
            }
        } catch (e) {
            this.showToast('Error', e.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * @description Initiates the deactivate integration flow.
     */
    handleDeactivateClick() {
        try {
            this.pendingAction = 'deactivate';
            this.showMessagePopup('Warning', 'Deactivate Integration', 'Are you sure you want to deactivate the Meta Ads integration? This will remove the connection.');
        } catch (e) {
            console.error('Error in handleDeactivateClick', e);
        }
    }

    /**
     * @description Confirms and executes the deactivation of the integration.
     */
    async confirmDeactivate() {
        try {
            this.isLoading = true;
            try {
                const result = await deactivateConnection();
                if (result && result.success) {
                    this.showToast('Success', 'Integration deactivated successfully.', 'success');
                    this.fullMappingJson = {};
                    this.availablePages = [];
                    this.buildTableData();
                    this.dispatchEvent(new CustomEvent('mvexdeactivated'));
                } else {
                    this.showToast('Error', result?.message || 'Failed to deactivate integration.', 'error');
                }
            } catch (error) {
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            } finally {
                this.isLoading = false;
            }
        } catch (e) {
            console.error('Error in confirmDeactivate', e);
        }
    }

    /**
     * @description Handles confirmation event from the generic message popup component.
     * @param {Event} event 
     */
    handleConfirmation(event) {
        try {
            if (event.detail === true) {
                if (this.pendingAction === 'delete') {
                    this.deleteRow(this.pendingRow);
                } else if (this.pendingAction === 'deactivate') {
                    this.confirmDeactivate();
                }
            }
            this.pendingAction = null;
            this.pendingRow = null;
        } catch (e) {
            console.error('Error in handleConfirmation', e);
        }
    }

    /**
     * @description Displays a message popup using a child component.
     * @param {String} Status 
     * @param {String} Title 
     * @param {String} Message 
     */
    showMessagePopup(Status, Title, Message) {
        try {
            const messageContainer = this.template.querySelector('c-message-popup')
            if (messageContainer) {
                messageContainer.showMessagePopup({
                    status: Status,
                    title: Title,
                    message: Message,
                });
            }
        } catch (e) {
            console.error('Error in showMessagePopup', e);
        }
    }

    /**
     * @description Dispatches a standard show toast event.
     * @param {String} title 
     * @param {String} message 
     * @param {String} variant 
     */
    showToast(title, message, variant) {
        try {
            const evt = new ShowToastEvent({
                title: title,
                message: message,
                variant: variant,
            });
            this.dispatchEvent(evt);
        } catch (e) {
            console.error('Error in showToast', e);
        }
    }

    // --- Failed Leads Actions ---
    /**
     * @description Opens the failed leads modal.
     * @param {Event} event 
     */
    async openFailedLeadsModal(event) {
        try {
            this.selectedFailedLeadsFormId = event.currentTarget.dataset.id;
            this.failedWizardStep = 1;
            this.activeFailedLeadId = null;
            this.failedLeadDataMap = {};
            this.pendingRetryIds = [];
            this.isFailedLeadsModalOpen = true;
            await this.loadFailedLeads();
        } catch (e) {
            console.error('Error in openFailedLeadsModal', e);
        }
    }

    /**
     * @description Closes the failed leads modal.
     */
    closeFailedLeadsModal() {
        try {
            this.isFailedLeadsModalOpen = false;
            this.selectedFailedLeadsFormId = '';
            this.failedWizardStep = 1;
            this.activeFailedLeadId = null;
            this.failedLeadDataMap = {};
            this.pendingRetryIds = [];
        } catch (e) {
            console.error('Error in closeFailedLeadsModal', e);
        }
    }

    /**
     * @description Loads failed leads from the backend.
     */
    async loadFailedLeads() {
        try {
            this.isRetrying = true;
            try {
                const results = await getFailedLeads({ formId: this.selectedFailedLeadsFormId });
                this.failedLeads = results.map((r, index) => {
                    let leadId = 'Unknown';
                    try {
                        let payload = JSON.parse(r.MVEX__Error_Body__c);
                        if (payload.leadId) leadId = payload.leadId;
                    } catch (e) {}

                    return {
                        Id: r.Id,
                        index: index + 1,
                        leadId: leadId,
                        Name: r.Name,
                        Date: new Date(r.CreatedDate).toLocaleString(),
                        Body: r.MVEX__Error_Body__c,
                        reason: r.MVEX__Error_Message__c || 'Unknown error',
                        selected: false
                    };
                });
            } catch (error) {
                this.showToast('Error', 'Failed to load error records', 'error');
            } finally {
                this.isRetrying = false;
            }
        } catch (e) {
            console.error('Error in loadFailedLeads', e);
        }
    }

    /**
     * @description Handles selecting or deselecting all failed leads.
     * @param {Event} event 
     */
    handleSelectAllFailedLeads(event) {
        try {
            const isChecked = event.target.checked;
            this.failedLeads = this.failedLeads.map(l => ({ ...l, selected: isChecked }));
        } catch (e) {
            console.error('Error in handleSelectAllFailedLeads', e);
        }
    }

    /**
     * @description Handles selecting or deselecting a single failed lead.
     * @param {Event} event 
     */
    handleFailedLeadSelection(event) {
        try {
            const leadId = event.target.dataset.id;
            const isChecked = event.target.checked;
            this.failedLeads = this.failedLeads.map(l => {
                if (l.Id === leadId) {
                    return { ...l, selected: isChecked };
                }
                return l;
            });
        } catch (e) {
            console.error('Error in handleFailedLeadSelection', e);
        }
    }

    /**
     * @description Retries processing the selected failed leads without modifying the mapping.
     */
    async retrySelectedFailedLeads() {
        try {
            const selectedIds = this.failedLeads.filter(l => l.selected).map(l => l.Id);
            if (selectedIds.length === 0) return;

            this.isRetrying = true;
            try {
                const results = await retryMultipleFailedLeads({ errorRecordIds: selectedIds });
                let successCount = 0;
                let errorCount = 0;
                for (let id in results) {
                    if (results[id] === 'Success') successCount++;
                    else errorCount++;
                }
                if (errorCount === 0) {
                    this.showToast('Success', `Successfully retried ${successCount} leads.`, 'success');
                } else {
                    this.showToast('Retry Completed', `${successCount} successes, ${errorCount} failures. Please check error logs for details.`, 'warning');
                }
                await this.loadFailedLeads();
            } catch (error) {
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            } finally {
                this.isRetrying = false;
            }
        } catch (e) {
            console.error('Error in retrySelectedFailedLeads', e);
        }
    }

    /**
     * @description Deletes the selected failed leads permanently.
     */
    async discardSelectedFailedLeads() {
        try {
            const selectedIds = this.failedLeads.filter(l => l.selected).map(l => l.Id);
            if (selectedIds.length === 0) return;

            this.isRetrying = true;
            try {
                const success = await deleteFailedLeads({ errorRecordIds: selectedIds });
                if (success) {
                    this.showToast('Success', `Discarded ${selectedIds.length} failed lead(s).`, 'success');
                    await this.loadFailedLeads();
                } else {
                    this.showToast('Error', 'Failed to discard selected leads.', 'error');
                }
            } catch (error) {
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            } finally {
                this.isRetrying = false;
            }
        } catch (e) {
            console.error('Error in discardSelectedFailedLeads', e);
        }
    }

    /**
     * @description Transitions to the edit mapping step to fix and retry multiple selected failed leads.
     */
    async reviewSelectedFailedLead() {
        try {
            const selectedIds = this.failedLeads.filter(l => l.selected).map(l => l.Id);
            if (!selectedIds.length) return;

            this.pendingRetryIds = selectedIds;
            this.isFailedLeadsModalOpen = false;

            // Use first selected lead's payload to determine pageId / formId context
            const firstLead = this.failedLeads.find(l => l.selected);
            let payload = {};
            try { payload = JSON.parse(firstLead.Body); } catch (e) {}

            let pageId = payload.pageId;
            if (!pageId) {
                for (let page of this.tableData) {
                    if (page.forms && page.forms.some(f => f.id === this.selectedFailedLeadsFormId)) {
                        pageId = page.id;
                        break;
                    }
                }
            }

            this.selectedPageId = pageId;
            this.selectedFormId = this.selectedFailedLeadsFormId;

            if (!this.availableForms || !this.availableForms.some(f => String(f.id) === String(this.selectedFormId))) {
                try {
                    this.isRetrying = true;
                    const formsRes = await getLeadForms({ pageId: this.selectedPageId });
                    if (formsRes && formsRes.success && formsRes.forms) {
                        this.availableForms = formsRes.forms;
                    }
                } catch (e) {
                    console.error(e);
                } finally {
                    this.isRetrying = false;
                }
            }

            this.handleFormSelection({ detail: { value: this.selectedFormId } });

            // Open the main mapping modal with edit mode
            this.isEditingMode = true;
            this.isModalOpen = true;
        } catch (e) {
            console.error('Error in reviewSelectedFailedLead', e);
        }
    }

    /**
     * @description Goes back to the failed leads list (step 1).
     */
    backToFailedLeadsList() {
        try {
            this.failedWizardStep = 1;
            this.activeFailedLeadId = null;
            this.failedLeadDataMap = {};
        } catch (e) {
            console.error('Error in backToFailedLeadsList', e);
        }
    }

    /**
     * @description Saves a new mapping specifically overriding for the selected failed lead and retries it.
     */
    async saveAndRetryFailedLead() {
        try {
            const unmappedRequired = [];
            this.currentFormFields.forEach(f => {
                const isMapped = (f.sourceType === SOURCE_META && f.metaField) || (f.sourceType === SOURCE_CUSTOM && f.customValue?.trim());
                if (f.required && !isMapped) {
                    unmappedRequired.push(f.label);
                }
            });
            
            if (unmappedRequired.length > 0) {
                const names = unmappedRequired.join(', ');
                this.showToast('Validation Error', `The following required Salesforce fields must be mapped before saving: ${names}`, 'error');
                return;
            }

            let formMapping = {};
            this.currentFormFields.forEach(f => {
                if (f.sourceType === SOURCE_META && f.metaField) {
                    formMapping[f.key] = { sourceType: SOURCE_META, metaField: f.metaField };
                } else if (f.sourceType === SOURCE_CUSTOM && f.customValue?.trim()) {
                    formMapping[f.key] = { sourceType: SOURCE_CUSTOM, customValue: f.customValue.trim() };
                }
            });

            let pageName = this.availablePages.find(p => String(p.id) === String(this.selectedPageId))?.name || 'Page ID: ' + this.selectedPageId;
            let formName = this.availableForms.find(f => String(f.id) === String(this.selectedFormId))?.name || 'Form ID: ' + this.selectedFormId;

            let tempMappingJson = JSON.parse(JSON.stringify(this.fullMappingJson));

            if (tempMappingJson[this.selectedPageId] && tempMappingJson[this.selectedPageId].forms === undefined) {
                 let oldForms = tempMappingJson[this.selectedPageId];
                 let migratedForms = {};
                 for (let oldFId in oldForms) {
                     migratedForms[oldFId] = { formName: 'Form ID: ' + oldFId, mappings: oldForms[oldFId] };
                 }
                 tempMappingJson[this.selectedPageId] = { pageName: pageName, forms: migratedForms };
            } else if (!tempMappingJson[this.selectedPageId]) {
                tempMappingJson[this.selectedPageId] = { pageName: pageName, forms: {} };
            }
            
            tempMappingJson[this.selectedPageId].forms[this.selectedFormId] = { formName: formName, mappings: formMapping };

            this.isRetrying = true;
            try {
                const jsonStr = JSON.stringify(tempMappingJson);
                
                const retryRes = await retryFailedLead({ errorRecordId: this.activeFailedLeadId, mappingJsonOverride: jsonStr });
                if (retryRes === 'Success') {
                    this.showToast('Success', 'Lead successfully inserted!', 'success');
                    this.failedWizardStep = 1;
                    await this.loadFailedLeads();
                } else {
                    this.showToast('Retry Failed', retryRes, 'error');
                }
            } catch (error) {
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            } finally {
                this.isRetrying = false;
            }
        } catch (e) {
            console.error('Error in saveAndRetryFailedLead', e);
        }
    }

    // --- Webhook Modal ---

    /**
     * @description Opens the modal displaying webhook info and active sites.
     */
    async openWebhookModal() {
        try {
            this.isLoading = true;
            try {
                const sites = await getActiveSites();
                this.siteOptions = (sites || []).map(s => ({ label: s.label, value: s.value }));
                this.selectedSite = '';
                this.isWebhookModalOpen = true;
            } catch (e) {
                this.showToast('Error', 'Failed to fetch Force.com sites.', 'error');
            } finally {
                this.isLoading = false;
            }
        } catch (e) {
            console.error('Error in openWebhookModal', e);
        }
    }

    /**
     * @description Closes the webhook modal.
     */
    closeWebhookModal() {
        this.isWebhookModalOpen = false;
    }

    /**
     * @description Handles selecting a different force.com site.
     * @param {Event} event 
     */
    handleSiteChange(event) {
        this.selectedSite = event.detail.value;
    }

    /**
     * @description Copies the generated webhook URL to the user's clipboard.
     */
    handleCopyWebhook() {
        try {
            if (!this.webhookEndpointPreview) return;
            
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(this.webhookEndpointPreview)
                    .then(() => {
                        this.showToast('Success', 'Webhook URL copied to clipboard!', 'success');
                    })
                    .catch(err => {
                        this.fallbackCopyTextToClipboard(this.webhookEndpointPreview);
                    });
            } else {
                this.fallbackCopyTextToClipboard(this.webhookEndpointPreview);
            }
        } catch (e) {
            console.error('Error in handleCopyWebhook', e);
        }
    }

    /**
     * @description Fallback method to copy text to clipboard for older browsers.
     * @param {String} text 
     */
    fallbackCopyTextToClipboard(text) {
        try {
            let textArea = document.createElement("textarea");
            textArea.value = text;
            textArea.style.position = "fixed";
            document.body.appendChild(textArea);
            textArea.focus();
            textArea.select();
            try {
                document.execCommand('copy');
                this.showToast('Success', 'Webhook URL copied to clipboard!', 'success');
            } catch (err) {
                this.showToast('Error', 'Failed to copy text.', 'error');
            }
            document.body.removeChild(textArea);
        } catch (e) {
            console.error('Error in fallbackCopyTextToClipboard', e);
        }
    }
}
