import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getConnectedPages from '@salesforce/apex/MetaAdsFormMappingController.getConnectedPages';
import getLeadForms from '@salesforce/apex/MetaAdsFormMappingController.getLeadForms';
import getSalesforceLeadFields from '@salesforce/apex/MetaAdsFormMappingController.getSalesforceLeadFields';
import getExistingMappings from '@salesforce/apex/MetaAdsFormMappingController.getExistingMappings';
import saveMappingApex from '@salesforce/apex/MetaAdsFormMappingController.saveMapping';

import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';

export default class MetaAdsFormMapping extends LightningElement {
    
    @track isLoading = true;
    @track tableData = [];
    
    @track isModalOpen = false;
    @track isModalLoading = false;
    
    @track availablePages = []; // Pages from Meta API
    @track availableForms = []; // Forms from Meta API for selected page
    @track salesforceLeadFields = []; // Fields from SF
    
    @track selectedPageId = '';
    @track selectedFormId = '';
    @track currentFormFields = []; // [{key, label, value}]
    
    @track currentStep = '1';
    
    // Overall JSON state
    // Format: { clientAppId: { pageId: { formId: { metaKey: sfField } } } }
    fullMappingJson = {};
    
    // Meta Config State
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

    get isStep1() { return this.currentStep === '1'; }
    get isStep2() { return this.currentStep === '2'; }
    get isStep3() { return this.currentStep === '3'; }

    get isNextDisabledStep1() {
        return !this.selectedPageId;
    }

    get isNextDisabledStep2() {
        return !this.selectedFormId;
    }

    get isSaveDisabled() {
        return !this.selectedFormId;
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
        this.selectedPageId = '';
        this.selectedFormId = '';
        this.availableForms = [];
        this.currentFormFields = [];
        this.currentStep = '1';
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
        this.currentStep = '1';
    }

    goNext() {
        if (this.currentStep === '1' && this.selectedPageId) {
            this.currentStep = '2';
        } else if (this.currentStep === '2' && this.selectedFormId) {
            this.currentStep = '3';
        }
    }

    goBack() {
        if (this.currentStep === '2') {
            this.currentStep = '1';
        } else if (this.currentStep === '3') {
            this.currentStep = '2';
        }
    }

    async handlePageSelection(event) {
        this.selectedPageId = event.detail.value;
        this.selectedFormId = '';
        this.availableForms = [];
        
        if (!this.selectedPageId) {
            return;
        }

        this.isModalLoading = true;
        try {
            const formsRes = await getLeadForms({ pageId: this.selectedPageId });
            if (formsRes && formsRes.success) {
                if (formsRes.forms) {
                    this.availableForms = formsRes.forms;
                }
                this.currentClientAppId = formsRes.client_app_id || 'default_app_id';
            } else {
                this.showToast('Error', 'Failed to fetch forms: ' + (formsRes.message || ''), 'error');
            }
        } catch (error) {
            this.showToast('Error', 'Error fetching forms.', 'error');
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

        // Find form questions
        const form = this.availableForms.find(f => String(f.id) === String(this.selectedFormId));
        if (form && form.questions) {
            // Check if we have existing mappings for this form
            let existingMappings = {};
            if (this.fullMappingJson[this.selectedPageId]) {
                let pageObj = this.fullMappingJson[this.selectedPageId];
                let formsObj = pageObj.forms !== undefined ? pageObj.forms : pageObj;
                
                if (formsObj[this.selectedFormId]) {
                    existingMappings = formsObj[this.selectedFormId].mappings !== undefined ? formsObj[this.selectedFormId].mappings : formsObj[this.selectedFormId];
                }
            }

            this.currentFormFields = form.questions.map(q => {
                let key = q.key;
                let currentValue = existingMappings[key] || '';
                let metaType = q.type || '';
                
                return {
                    key: key,
                    label: q.label || key,
                    metaType: metaType,
                    value: currentValue,
                    options: this.getFilteredFieldOptions(metaType)
                };
            });
            
        } else {
            this.currentFormFields = [];
        }
    }

    getFilteredFieldOptions(metaType) {
        if (!metaType) return this.salesforceLeadFields;

        metaType = metaType.toUpperCase();
        // Default allowed Salesforce field types for strings/text
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

        return this.salesforceLeadFields.filter(f => {
            let sfType = f.type ? f.type.toUpperCase() : 'STRING';
            return allowedSfTypes.includes(sfType);
        });
    }

    handleMappingChange(event) {
        const metaKey = event.target.dataset.key;
        const sfField = event.detail.value;
        
        let field = this.currentFormFields.find(f => f.key === metaKey);
        if (field) {
            field.value = sfField;
        }
    }

    async saveMapping() {
        // Build mapping object for current form
        let formMapping = {};
        this.currentFormFields.forEach(f => {
            if (f.value) { // only save if mapped
                formMapping[f.key] = f.value;
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
            this.deleteRow(targetRow);
        }
    }

    async editRow(row) {
        this.selectedPageId = row.pageId;
        this.selectedFormId = row.formId;
        
        this.isModalOpen = true;
        this.isModalLoading = true;
        this.currentStep = '3'; // Jump straight to mapping

        try {
            // Fetch forms for this page so we have the questions
            const formsRes = await getLeadForms({ pageId: this.selectedPageId });
            if (formsRes && formsRes.success) {
                if (formsRes.forms) {
                    this.availableForms = formsRes.forms;
                }
            }
            
            // Build fields for mapping step
            this.handleFormSelection({ detail: { value: this.selectedFormId } });
            
        } catch (error) {
            this.showToast('Error', 'Failed to load form details for editing.', 'error');
            this.closeModal();
        } finally {
            this.isModalLoading = false;
        }
    }

    async deleteRow(row) {
        if (!confirm('Are you sure you want to delete this mapping?')) {
            return;
        }

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

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }
}

