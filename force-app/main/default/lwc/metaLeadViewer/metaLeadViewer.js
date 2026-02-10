import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';

// Field Imports
import JSON_FIELD from '@salesforce/schema/Contact.Meta_Raw_JSON__c';
import FORM_NAME_FIELD from '@salesforce/schema/Contact.Meta_Form_Name__c'; // Corrected import name for clarity

export default class MetaLeadViewer extends LightningElement {
    @api recordId;
    @track parsedData = [];

    connectedCallback() {
        // Load custom font if needed
        loadStyle(this, MulishFontCss);
    }

    @wire(getRecord, { recordId: '$recordId', fields: [JSON_FIELD, FORM_NAME_FIELD] })
    wiredContact({ error, data }) {
        if (data) {
            const jsonString = getFieldValue(data, JSON_FIELD);
            const formName = getFieldValue(data, FORM_NAME_FIELD);
            
            this.parsedData = null; // Reset data
            
            if (jsonString) {
                this.processJSON(jsonString, formName);
            }
        } else if (error) {
            console.error('Error loading contact data', error);
        }
    }

    processJSON(jsonString, formName) {
        try {
            const rawData = JSON.parse(jsonString);
            let tableRows = [];

            // --- 0. Add Form Name (First Row, if available) ---
            if (formName) {
                tableRows.push({ key: 'Form Name', value: formName });
            }

            // --- 1. Add System Fields ---
            if (rawData.platform) tableRows.push({ key: 'Platform', value: rawData.platform.toUpperCase() });
            if (rawData.id) tableRows.push({ key: 'Lead ID', value: rawData.id });
            if (rawData.created_time) {
                // Format timestamp if needed
                tableRows.push({ key: 'Created Time', value: rawData.created_time });
            }

            // 2. Add Form Questions & Answers
            if (rawData.field_data && Array.isArray(rawData.field_data)) {
                rawData.field_data.forEach(field => {
                    let answer = '';
                    if (field.values && field.values.length > 0) {
                        answer = field.values[0];
                    }
                    
                    // Clean up Question Text (remove underscores, capitalize)
                    let question = field.name.replace(/_/g, ' ');
                    question = question.charAt(0).toUpperCase() + question.slice(1);

                    tableRows.push({ key: question, value: answer });
                });
            }

            this.parsedData = tableRows;

        } catch (e) {
            console.error('Error parsing JSON', e);
            this.parsedData = null;
        }
    }
}