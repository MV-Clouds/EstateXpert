import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getConnectedPages from '@salesforce/apex/MetaAdsFormMappingController.getConnectedPages';
import getLeadForms from '@salesforce/apex/MetaAdsFormMappingController.getLeadForms';
import getSalesforceLeadFields from '@salesforce/apex/MetaAdsFormMappingController.getSalesforceLeadFields';
import getExistingMappings from '@salesforce/apex/MetaAdsFormMappingController.getExistingMappings';
import saveMappingApex from '@salesforce/apex/MetaAdsFormMappingController.saveMapping';
import deactivateConnection from '@salesforce/apex/MetaAdsTokenController.deactivateConnection';
import getFailedLeads from '@salesforce/apex/MetaAdsFormMappingController.getFailedLeads';
import retryFailedLead from '@salesforce/apex/MetaAdsFormMappingController.retryFailedLead';
import retryMultipleFailedLeads from '@salesforce/apex/MetaAdsFormMappingController.retryMultipleFailedLeads';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';

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

    @track isModalOpen = false;
    @track isModalLoading = false;
    @track spinnerLabel = 'Loading forms...';

    @track availablePages = [];      // Pages from Meta API
    @track availableForms = [];      // Forms for selected page
    @track salesforceLeadFields = []; // SF Contact fields

    @track selectedPageId = '';
    @track selectedFormId = '';
    @track currentFormFields = [];   // [{ key, label, value, options }]
    @track formsLoaded = false;      // true once forms have been fetched for selected page
    @track availableSalesforceFields = [];
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
    
    get isFailedWizardStep1() { return this.failedWizardStep === 1; }
    get isFailedWizardStep2() { return this.failedWizardStep === 2; }

    get isAllFailedLeadsSelected() {
        return this.failedLeads.length > 0 && this.failedLeads.every(l => l.selected);
    }

    get hasSelectedFailedLeads() {
        return this.failedLeads.some(l => l.selected);
    }

    // Overall JSON state — { pageId: { pageName, forms: { formId: { formName, mappings: {} } } } }
    fullMappingJson = {};

    currentClientAppId = '';

    connectedCallback() {
        loadStyle(this, MulishFontCss).catch(error => {
            console.error('Error loading MulishFontCss', error);
        });
        this.loadInitialData();
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

    get hasMappings() {
        return this.tableData.length > 0;
    }

    // ─── Single-page wizard computed properties ───────────────────────────────

    /** Form section is locked until a page is chosen */
    get isFormSectionDisabled() {
        return !this.selectedPageId;
    }

    /** Form dropdown is disabled while loading OR no page selected */
    get isFormDropdownDisabled() {
        return this.isModalLoading || !this.selectedPageId;
    }

    /** Show "no forms" message only after forms have been fetched and list is empty */
    get showNoFormsMsg() {
        return this.formsLoaded && this.selectedPageId && this.formOptions.length === 0;
    }

    /** Show field-mapping section only when a form is selected AND fields exist */
    get hasFormFields() {
        return !!this.selectedFormId;
    }

    /** Save is enabled only when a form is selected */
    get isSaveDisabled() {
        return !this.selectedFormId || this.isModalLoading;
    }

    get pageOptions() {
        return this.availablePages.map(p => {
            return {
                label: `${p.name} (${p.id})`,
                value: String(p.id)
            };
        });
    }

    get formOptions() {
        return this.availableForms.map(f => {
            return {
                label: `${f.name} (${f.id})`,
                value: String(f.id)
            };
        }).filter(opt => {
            // allow if it's the currently selected form (we are editing)
            if (opt.value === this.selectedFormId) return true;
            // filter out if it already exists in tableData for the selected page
            let pageRow = this.tableData.find(row => String(row.pageId) === String(this.selectedPageId));
            if (pageRow) {
                return !pageRow.forms.some(f => String(f.formId) === opt.value);
            }
            return true;
        });
    }

    // --- Modal Logic ---

    openNewMappingModal() {
        this.selectedPageId    = '';
        this.selectedFormId    = '';
        this.availableForms    = [];
        this.currentFormFields = [];
        this.availableSalesforceFields = [];
        this.showAddField = false;
        this.selectedAdditionalField = '';
        this.formsLoaded       = false;
        this.isModalOpen       = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }

    async handlePageSelection(event) {
        this.selectedPageId = event.detail.value;
        this.selectedFormId = '';
        this.availableForms = [];
        
        if (!this.selectedPageId) {
            return;
        }

        this.isModalLoading = true;
        this.spinnerLabel   = 'Loading forms...';
        this.formsLoaded    = false;
        try {
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

    handleFormSelection(event) {
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
                    // New format! k is the Salesforce Field
                    mappingData[k] = val;
                    savedFieldKeys.push(k);
                } else {
                    // Old format! k is Meta Field or "custom", val is Salesforce Field
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
    }

    autoMatchMetaField(sfKey, options) {
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
    }

    getFilteredMetaFieldOptions(formQuestions, sfType) {
        let options = [];
        
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
    }

    isReferenceField(salesforceField) {
        return salesforceField?.type === 'REFERENCE' || !!salesforceField?.referenceTo;
    }

    handleSourceTypeChange(event) {
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
    }

    handleMetaFieldChange(event) {
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
    }

    handleCustomValueChange(event) {
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
    }

    handleReferenceChange(event) {
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
    }

    // Add Field Logic
    get additionalFieldOptions() {
        return this.availableSalesforceFields
            .filter(field => !this.currentFormFields.some(current => current.key === field.value))
            .map(field => ({
                label: field.label,
                value: field.value
            }));
    }

    get hasAdditionalFieldOptions() {
        return this.additionalFieldOptions.length > 0;
    }

    get isAddFieldDisabled() {
        return !this.selectedAdditionalField;
    }

    handleAdditionalFieldChange(event) {
        this.selectedAdditionalField = event.detail.value;
    }

    handleShowAddField() {
        this.showAddField = true;
    }

    handleCancelAddField() {
        this.selectedAdditionalField = '';
        this.showAddField = false;
    }

    handleAddField() {
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
        this.selectedAdditionalField = '';
        this.showAddField = false;
    }

    async saveMapping() {
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
                this.showToast('Success', 'Form mapping saved and webhook subscribed successfully.', 'success');
                // Optional: we don't have form names natively in tableData since we aren't fetching ALL forms anymore.
                // We could fetch forms for table building, or just use the Form ID in the table. 
                // For now, it will use "Form ID: xxx" since we didn't fetch all forms globally.
                this.buildTableData();
                this.closeModal();
            } else {
                this.showToast('Error', result.message || 'Error saving mapping.', 'error');
            }
        } catch (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        } finally {
            this.isModalLoading = false;
        }
    }

    // --- Table Actions ---

    handleToggleRow(event) {
        const rowId = event.currentTarget.dataset.id;
        const row = this.tableData.find(r => r.id === rowId);
        if (row) {
            row.isExpanded = !row.isExpanded;
        }
    }

    handleEditRow(event) {
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
    }

    handleDeleteRow(event) {
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
    }

    async editRow(row) {
        this.selectedPageId    = row.pageId;
        this.selectedFormId    = row.formId;
        this.availableForms    = [];
        this.currentFormFields = [];
        this.formsLoaded       = false;
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
    }

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

    handleDeactivateClick() {
        this.pendingAction = 'deactivate';
        this.showMessagePopup('Warning', 'Deactivate Integration', 'Are you sure you want to deactivate the Meta Ads integration? This will remove the connection.');
    }

    async confirmDeactivate() {
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
    }

    handleConfirmation(event) {
        if (event.detail === true) {
            if (this.pendingAction === 'delete') {
                this.deleteRow(this.pendingRow);
            } else if (this.pendingAction === 'deactivate') {
                this.confirmDeactivate();
            }
        }
        this.pendingAction = null;
        this.pendingRow = null;
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
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }

    // --- Failed Leads Actions ---
    async openFailedLeadsModal(event) {
        this.selectedFailedLeadsFormId = event.currentTarget.dataset.id;
        this.failedWizardStep = 1;
        this.activeFailedLeadId = null;
        this.failedLeadDataMap = {};
        this.isFailedLeadsModalOpen = true;
        await this.loadFailedLeads();
    }

    closeFailedLeadsModal() {
        this.isFailedLeadsModalOpen = false;
        this.selectedFailedLeadsFormId = '';
        this.failedWizardStep = 1;
        this.activeFailedLeadId = null;
        this.failedLeadDataMap = {};
    }

    async loadFailedLeads() {
        this.isRetrying = true;
        try {
            const results = await getFailedLeads({ formId: this.selectedFailedLeadsFormId });
            this.failedLeads = results.map(r => {
                return {
                    Id: r.Id,
                    Name: r.Name,
                    Date: new Date(r.CreatedDate).toLocaleString(),
                    Body: r.MVEX__Error_Body__c,
                    selected: false
                };
            });
        } catch (error) {
            this.showToast('Error', 'Failed to load error records', 'error');
        } finally {
            this.isRetrying = false;
        }
    }

    handleSelectAllFailedLeads(event) {
        const isChecked = event.target.checked;
        this.failedLeads = this.failedLeads.map(l => ({ ...l, selected: isChecked }));
    }

    handleFailedLeadSelection(event) {
        const leadId = event.target.dataset.id;
        const isChecked = event.target.checked;
        this.failedLeads = this.failedLeads.map(l => {
            if (l.Id === leadId) {
                return { ...l, selected: isChecked };
            }
            return l;
        });
    }

    async retrySelectedFailedLeads() {
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
    }

    async reviewFailedLead(event) {
        const leadId = event.currentTarget.dataset.id;
        const failedLead = this.failedLeads.find(l => l.Id === leadId);
        if (!failedLead) return;

        this.activeFailedLeadId = leadId;
        this.failedWizardStep = 2;
        
        let payload = {};
        try {
            payload = JSON.parse(failedLead.Body);
        } catch (e) {
            console.error('Failed to parse error body', e);
        }

        this.failedLeadDataMap = {};
        if (payload.leadData && payload.leadData.field_data) {
            payload.leadData.field_data.forEach(field => {
                if (field.name && field.values && field.values.length > 0) {
                    this.failedLeadDataMap[field.name] = field.values[0];
                }
            });
        }

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
        
        this.currentFormFields = this.currentFormFields.map(f => {
            let leadValue = '';
            if (f.sourceType === SOURCE_META && f.metaField) {
                leadValue = this.failedLeadDataMap[f.metaField] || '';
            }
            return {
                ...f,
                failedLeadValue: leadValue
            };
        });
    }

    backToFailedLeadsList() {
        this.failedWizardStep = 1;
        this.activeFailedLeadId = null;
        this.failedLeadDataMap = {};
    }

    async saveAndRetryFailedLead() {
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
    }
}

