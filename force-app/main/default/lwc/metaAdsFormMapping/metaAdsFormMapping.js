import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFormsAndFields from '@salesforce/apex/MetaAdsFormMappingController.getFormsAndFields';
import getSalesforceLeadFields from '@salesforce/apex/MetaAdsFormMappingController.getSalesforceLeadFields';
import getExistingMappings from '@salesforce/apex/MetaAdsFormMappingController.getExistingMappings';
import saveMappingApex from '@salesforce/apex/MetaAdsFormMappingController.saveMapping';

const ACTIONS = [
    { label: 'Edit', name: 'edit' },
    { label: 'Delete', name: 'delete' }
];

const COLUMNS = [
    { label: 'Form Name', fieldName: 'formName', type: 'text' },
    { label: 'Form ID', fieldName: 'formId', type: 'text' },
    { label: 'Page ID', fieldName: 'pageId', type: 'text' },
    { label: 'Mapped Fields', fieldName: 'mappedCount', type: 'number' },
    {
        type: 'action',
        typeAttributes: { rowActions: ACTIONS },
    },
];

export default class MetaAdsFormMapping extends LightningElement {
    columns = COLUMNS;
    
    @track isLoading = true;
    @track tableData = [];
    
    @track isModalOpen = false;
    @track isModalLoading = false;
    
    @track availableForms = []; // Forms from Meta API
    @track salesforceLeadFields = []; // Fields from SF
    
    @track selectedFormId = '';
    @track currentFormFields = []; // [{key, label, value}]
    
    // Overall JSON state
    // Format: { clientAppId: { pageId: { formId: { metaKey: sfField } } } }
    fullMappingJson = {};
    
    // Meta Config State
    currentClientAppId = '';
    currentPageId = '';

    connectedCallback() {
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
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }

    handleFormSelection(event) {
        this.selectedFormId = event.target.value;
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
            
            // Wait for DOM update then set selects
            setTimeout(() => {
                this.currentFormFields.forEach(f => {
                    let sel = this.template.querySelector(`select[data-key="${f.key}"]`);
                    if (sel) {
                        sel.value = f.value;
                    }
                });
            }, 0);
            
        } else {
            this.currentFormFields = [];
        }
    }

    handleMappingChange(event) {
        const metaKey = event.target.dataset.key;
        const sfField = event.target.value;
        
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

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'edit') {
            this.editRow(row);
        } else if (actionName === 'delete') {
            this.deleteRow(row);
        }
    }

    editRow(row) {
        // Only allow edit if the connection matches, or we could support multi-page edit 
        // but for now we set the context.
        this.currentClientAppId = row.clientAppId;
        this.currentPageId = row.pageId;
        
        this.selectedFormId = row.formId;
        this.isModalOpen = true;
        
        // Wait for select element to render
        setTimeout(() => {
            let formSelect = this.template.querySelector('select:not([data-key])');
            if (formSelect) {
                formSelect.value = this.selectedFormId;
                // mock event
                this.handleFormSelection({target: {value: this.selectedFormId}});
            }
        }, 0);
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
