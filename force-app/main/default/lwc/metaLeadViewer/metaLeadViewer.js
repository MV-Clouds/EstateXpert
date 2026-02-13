import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue, updateRecord } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';

import CONTACT_OBJECT from '@salesforce/schema/Contact';
import JSON_FIELD from '@salesforce/schema/Contact.Meta_Raw_JSON__c';
import FORM_NAME_FIELD from '@salesforce/schema/Contact.Meta_Form_Name__c';

const BASE_ROW_CLASS = 'slds-grid slds-wrap slds-gutters slds-grid_vertical-align-center sync-row';

export default class MetaLeadViewer extends LightningElement {
    @api recordId;
    
    @track parsedData = [];
    @track mappingRows = [];
    @track contactFieldOptions = [];
    
    isModalOpen = false;
    isLoading = false;

    get hasData() {
        return this.parsedData && this.parsedData.length > 0;
    }

    get isSyncDisabled() {
        return !this.hasData;
    }

    connectedCallback() {
        loadStyle(this, MulishFontCss).catch(error => {
            console.error('Error loading custom font', error);
        });
    }

    @wire(getObjectInfo, { objectApiName: CONTACT_OBJECT })
    wiredObjectInfo({ error, data }) {
        if (data) {
            const fields = data.fields;
            this.contactFieldOptions = Object.values(fields)
                .filter(field => field.updateable)
                .map(field => {
                    return { label: field.label + ' (' + field.apiName + ')', value: field.apiName };
                })
                .sort((a, b) => a.label.localeCompare(b.label));
        } else if (error) {
            this.showToast('Error', 'Failed to load Contact fields', 'error');
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: [JSON_FIELD, FORM_NAME_FIELD] })
    wiredContact({ error, data }) {
        if (data) {
            const jsonString = getFieldValue(data, JSON_FIELD);
            const formName = getFieldValue(data, FORM_NAME_FIELD);
            
            this.parsedData = []; 
            
            if (jsonString) {
                this.processJSON(jsonString, formName);
            }
        } else if (error) {
            this.showToast('Error loading record data', error.body?.message || 'Unknown error', 'error');
        }
    }

    processJSON(jsonString, formName) {
        try {
            const rawData = JSON.parse(jsonString);
            let tableRows = [];

            if (formName) {
                tableRows.push({ key: 'Form Name', value: formName });
            }

            if (rawData.platform) tableRows.push({ key: 'Platform', value: rawData.platform.toUpperCase() });
            if (rawData.id) tableRows.push({ key: 'Lead ID', value: rawData.id });
            if (rawData.created_time) tableRows.push({ key: 'Created Time', value: rawData.created_time });

            if (rawData.field_data && Array.isArray(rawData.field_data)) {
                rawData.field_data.forEach(field => {
                    let answer = field.values && field.values.length > 0 ? field.values[0] : '';
                    let question = field.name.replace(/_/g, ' ');
                    question = question.charAt(0).toUpperCase() + question.slice(1);

                    tableRows.push({ key: question, value: answer });
                });
            }

            this.parsedData = tableRows;

        } catch (e) {
            console.error('Error parsing JSON', e);
            this.parsedData = [];
        }
    }

    openModal() {
        this.mappingRows = this.parsedData.map(row => ({
            ...row,
            selectedField: null,
            hasMapping: false,
            cssClass: BASE_ROW_CLASS 
        }));
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
        this.mappingRows = [];
    }

    handleMappingChange(event) {
        const index = event.target.dataset.index;
        
        // When the custom combobox is cleared, event.detail becomes an empty array []
        // This line gracefully handles both selection and clearing.
        const selectedApiName = (event.detail && event.detail.length > 0) ? event.detail[0] : null;
        
        this.updateMappingRowState(index, selectedApiName);
    }

    updateMappingRowState(index, fieldValue) {
        let row = { ...this.mappingRows[index] };
        row.selectedField = fieldValue;
        row.hasMapping = !!fieldValue;
        
        // Applies the yellow highlight when an option is mapped
        row.cssClass = row.hasMapping ? `${BASE_ROW_CLASS} highlight-yellow` : BASE_ROW_CLASS;
        
        this.mappingRows[index] = row;
        this.mappingRows = [...this.mappingRows];
    }

    async handleSaveSync() {
        this.isLoading = true;
        
        const fields = { Id: this.recordId };
        let hasMappings = false;

        this.mappingRows.forEach(row => {
            if (row.selectedField) {
                fields[row.selectedField] = row.value;
                hasMappings = true;
            }
        });

        if (!hasMappings) {
            this.showToast('Info', 'No fields were mapped. Nothing to sync.', 'info');
            this.isLoading = false;
            return;
        }

        try {
            await updateRecord({ fields });
            this.showToast('Success', 'Contact updated successfully.', 'success');
            this.closeModal();
        } catch (error) {
            const errorMessage = error.body?.output?.errors?.[0]?.message || error.body?.message || 'Update failed.';
            this.showToast('Error syncing data', errorMessage, 'error', 'sticky');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant, mode = 'dismissible') {
        const event = new ShowToastEvent({ title, message, variant, mode });
        this.dispatchEvent(event);
    }
}