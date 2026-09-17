import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFormsAndFields from '@salesforce/apex/MetaAdsFormMappingController.getFormsAndFields';
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
    
    @track availableForms = []; // Forms from Meta API
    @track salesforceLeadFields = []; // Fields from SF
    
    @track selectedFormId = '';
    @track currentFormFields = []; // [{key, label, value}]
    
    @track currentStep = '1';
    
    // Overall JSON state
    // Format: { clientAppId: { pageId: { formId: { metaKey: sfField } } } }
    fullMappingJson = {};
    
    // Meta Config State
    currentClientAppId = '';
    currentPageId = '';

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
                this.fullMappingJson = JSON.parse(existing);
            } else {
                this.fullMappingJson = {};
            }
            
            // 3. Pre-fetch forms to build the table with names
            const formsRes = await getFormsAndFields();
            if (formsRes && formsRes.success) {
                this.currentClientAppId = formsRes.client_app_id;
                this.currentPageId = formsRes.page_id;
                if (formsRes.forms) {
                    this.availableForms = formsRes.forms;
                }
            } else if (formsRes && !formsRes.success) {
                this.showToast('Warning', 'Could not fetch forms from Meta API. ' + (formsRes.message || ''), 'warning');
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
        let idx = 1;
        // traverse fullMappingJson
        for (let appId in this.fullMappingJson) {
            let pages = this.fullMappingJson[appId];
            for (let pId in pages) {
                let forms = pages[pId];
                for (let fId in forms) {
                    let mappings = forms[fId];
                    let formName = 'Unknown Form';
                    // Try to find name in availableForms
                    let found = this.availableForms.find(f => String(f.id) === String(fId));
                    if (found) {
                        formName = found.name;
                    }
                    
                    data.push({
                        index: idx++,
                        id: fId + '_' + pId,
                        formId: fId,
                        pageId: pId,
                        clientAppId: appId,
                        formName: formName,
                        mappedCount: Object.keys(mappings).length,
                        mappings: mappings // keep reference
                    });
                }
            }
        }
        this.tableData = data;
    }

    get hasMappings() {
        return this.tableData.length > 0;
    }

    get isStep1() {
        return this.currentStep === '1';
    }

    get isStep2() {
        return this.currentStep === '2';
    }

    get isNextDisabled() {
        return !this.selectedFormId;
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
            // filter out if it already exists in tableData
            return !this.tableData.some(row => String(row.formId) === opt.value);
        });
    }

    get isSaveDisabled() {
        return !this.selectedFormId;
    }

    // --- Modal Logic ---

    openNewMappingModal() {
        if (!this.currentClientAppId || !this.currentPageId) {
            this.showToast('Error', 'Meta Ads connection missing. Connect Meta Ads first.', 'error');
            return;
        }
        
        this.selectedFormId = '';
        this.currentFormFields = [];
        this.currentStep = '1';
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
        this.currentStep = '1';
    }

    goNext() {
        if (this.selectedFormId) {
            this.currentStep = '2';
        }
    }

    goBack() {
        this.currentStep = '1';
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
            if (this.fullMappingJson[this.currentClientAppId] && 
                this.fullMappingJson[this.currentClientAppId][this.currentPageId] &&
                this.fullMappingJson[this.currentClientAppId][this.currentPageId][this.selectedFormId]) {
                existingMappings = this.fullMappingJson[this.currentClientAppId][this.currentPageId][this.selectedFormId];
            }

            this.currentFormFields = form.questions.map(q => {
                let key = q.key;
                let currentValue = existingMappings[key] || '';
                return {
                    key: key,
                    label: q.label || key,
                    value: currentValue
                };
            });
            
        } else {
            this.currentFormFields = [];
        }
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

        // Ensure JSON structure
        if (!this.fullMappingJson[this.currentClientAppId]) this.fullMappingJson[this.currentClientAppId] = {};
        if (!this.fullMappingJson[this.currentClientAppId][this.currentPageId]) this.fullMappingJson[this.currentClientAppId][this.currentPageId] = {};
        
        this.fullMappingJson[this.currentClientAppId][this.currentPageId][this.selectedFormId] = formMapping;

        this.isModalLoading = true;
        try {
            const jsonStr = JSON.stringify(this.fullMappingJson);
            const result = await saveMappingApex({ mappingJson: jsonStr });
            
            if (result && result.success) {
                this.showToast('Success', 'Form mapping saved successfully.', 'success');
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

    handleEditRow(event) {
        const rowId = event.currentTarget.dataset.id;
        const row = this.tableData.find(r => r.id === rowId);
        if (row) {
            this.editRow(row);
        }
    }

    handleDeleteRow(event) {
        const rowId = event.currentTarget.dataset.id;
        const row = this.tableData.find(r => r.id === rowId);
        if (row) {
            this.deleteRow(row);
        }
    }

    editRow(row) {
        // Only allow edit if the connection matches, or we could support multi-page edit 
        // but for now we set the context.
        this.currentClientAppId = row.clientAppId;
        this.currentPageId = row.pageId;
        
        this.selectedFormId = row.formId;
        this.currentStep = '1';
        this.isModalOpen = true;
        
        this.handleFormSelection({detail: {value: this.selectedFormId}});
    }

    async deleteRow(row) {
        if (!confirm('Are you sure you want to delete this mapping?')) {
            return;
        }

        try {
            this.isLoading = true;
            if (this.fullMappingJson[row.clientAppId] && 
                this.fullMappingJson[row.clientAppId][row.pageId] &&
                this.fullMappingJson[row.clientAppId][row.pageId][row.formId]) {
                
                delete this.fullMappingJson[row.clientAppId][row.pageId][row.formId];
                
                // Cleanup empty objects
                if (Object.keys(this.fullMappingJson[row.clientAppId][row.pageId]).length === 0) {
                    delete this.fullMappingJson[row.clientAppId][row.pageId];
                }
                if (Object.keys(this.fullMappingJson[row.clientAppId]).length === 0) {
                    delete this.fullMappingJson[row.clientAppId];
                }

                const jsonStr = JSON.stringify(this.fullMappingJson);
                const result = await saveMappingApex({ mappingJson: jsonStr });
                
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
