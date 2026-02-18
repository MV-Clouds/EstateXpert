import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue, updateRecord } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';

import CONTACT_OBJECT from '@salesforce/schema/Contact';
import JSON_FIELD from '@salesforce/schema/Contact.Meta_Raw_JSON__c';
import FORM_NAME_FIELD from '@salesforce/schema/Contact.Meta_Form_Name__c';
import CAMPAIGN_NAME_FIELD from '@salesforce/schema/Contact.Meta_Campaign_Name__c'; 

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

    @wire(getRecord, { recordId: '$recordId', fields: [JSON_FIELD, FORM_NAME_FIELD,CAMPAIGN_NAME_FIELD] })
    wiredContact({ error, data }) {
        if (data) {
            const jsonString = getFieldValue(data, JSON_FIELD);
            const formName = getFieldValue(data, FORM_NAME_FIELD);
            const campaignName = getFieldValue(data, CAMPAIGN_NAME_FIELD);
            
            this.parsedData = []; 
            
            if (jsonString) {
                this.processJSON(jsonString, formName,campaignName);
            }
        } else if (error) {
            this.showToast('Error loading record data', error.body?.message || 'Unknown error', 'error');
        }
    }

    processJSON(jsonString, formName, campaignName) {
        try {
            const rawData = JSON.parse(jsonString);
            let tableRows = [];

            if (formName) {tableRows.push({ key: 'Form Name', value: formName});}
            if (campaignName) {tableRows.push({ key: 'Campaign Name', value: campaignName});}
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
            displayValue: '',
            hasMapping: false,
            cssClass: BASE_ROW_CLASS,
            isDropdownOpen: false,
            searchTerm: '',
            filteredOptions: this.contactFieldOptions
        }));
        this.isModalOpen = true;
        // Add click listener to close dropdowns when clicking outside
        setTimeout(() => {
            document.addEventListener('click', this.handleDocumentClick.bind(this));
        }, 0);
    }

    closeModal() {
        this.isModalOpen = false;
        this.mappingRows = [];
        // Remove document click listener
        document.removeEventListener('click', this.handleDocumentClick.bind(this));
    }

    handleComboboxClick(event) {
        event.stopPropagation();
        const index = parseInt(event.currentTarget.dataset.index);
        // Always open the dropdown when clicking the input wrapper
        this.openDropdown(index);
    }

    handleDropdownClick(event) {
        // Prevent clicks inside the dropdown from closing it
        event.stopPropagation();
    }

    openDropdown(index) {
        this.mappingRows = this.mappingRows.map((row, i) => ({
            ...row,
            isDropdownOpen: i === index ? true : false
        }));
        
        // Focus the search input after the dropdown is rendered
        setTimeout(() => {
            const searchInput = this.template.querySelector(`input.combobox-search-input[data-index="${index}"]`);
            if (searchInput) {
                searchInput.focus();
            }
        }, 0);
    }

    closeAllDropdowns() {
        this.mappingRows = this.mappingRows.map(row => ({
            ...row,
            isDropdownOpen: false
        }));
    }

    handleSearchInput(event) {
        event.stopPropagation();
        const index = parseInt(event.target.dataset.index);
        const searchTerm = event.target.value.toLowerCase();
        
        let row = { ...this.mappingRows[index] };
        row.searchTerm = searchTerm;
        
        // Filter options based on search term
        if (searchTerm) {
            row.filteredOptions = this.contactFieldOptions.filter(option => 
                option.label.toLowerCase().includes(searchTerm)
            );
        } else {
            row.filteredOptions = this.contactFieldOptions;
        }
        
        this.mappingRows[index] = row;
        this.mappingRows = [...this.mappingRows];
    }

    handleOptionSelect(event) {
        event.stopPropagation();
        const index = parseInt(event.currentTarget.dataset.index);
        const value = event.currentTarget.dataset.value;
        const label = event.currentTarget.dataset.label;
        
        this.updateMappingRowState(index, value, label);
        this.closeAllDropdowns();
    }

    handleClearSelection(event) {
        event.stopPropagation();
        const index = parseInt(event.currentTarget.dataset.index);
        this.updateMappingRowState(index, null, '');
    }

    handleDocumentClick(event) {
        // Close all dropdowns when clicking outside
        const comboboxContainers = this.template.querySelectorAll('.custom-combobox-container');
        let clickedInside = false;
        
        comboboxContainers.forEach(container => {
            if (container.contains(event.target)) {
                clickedInside = true;
            }
        });
        
        if (!clickedInside) {
            this.closeAllDropdowns();
        }
    }

    updateMappingRowState(index, fieldValue, displayLabel = '') {
        let row = { ...this.mappingRows[index] };
        row.selectedField = fieldValue;
        row.displayValue = displayLabel;
        row.hasMapping = !!fieldValue;
        row.searchTerm = '';
        row.filteredOptions = this.contactFieldOptions;
        
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