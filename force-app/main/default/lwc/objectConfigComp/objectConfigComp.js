import { LightningElement, track, api } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import getRequiredFields from '@salesforce/apex/ObjectConfigController.getRequiredFields';
import getTextAndPhoneFields from '@salesforce/apex/ObjectConfigController.getTextAndPhoneFields';
import getUserConfig from '@salesforce/apex/ObjectConfigController.getUserConfig';
import saveUserConfig from '@salesforce/apex/ObjectConfigController.saveUserConfig';
import getRecordName from '@salesforce/apex/ObjectConfigController.getRecordName';
import MulishFontCss from '@salesforce/resourceUrl/leadassignmentcss';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ObjectConfigComp extends LightningElement {
    // ── Object is always fixed to Contact ────────────────────────────────────
    @track selectedObject = 'Contact';

    // ── Webhook config ───────────────────────────────────────────────────────
    @track requiredFields = [];
    @track phoneFields = [];
    @track selectedPhoneFieldVal = '';
    @track selectedPhoneFieldLabel = '';

    // ── Chat window config ───────────────────────────────────────────────────
    @track chatWindowRows = [];
    @track chatConfigCounter = 0;

    // ── UI state ─────────────────────────────────────────────────────────────
    @track activeSectionName = ['chatWindowConfig', 'webhookConfig'];
    @track isEditMode = false;   // single flag controls both sections
    @track isDirty = false;      // single dirty flag for Save button
    @track isLoading = false;

    @api isPopup = false;

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    async connectedCallback() {
        try {
            this.isLoading = true;
            loadStyle(this, MulishFontCss);
            this.loadSavedValues();
        } catch (e) {
            console.error('Error in connectedCallback:::', e.message);
        }
    }

    // ── Load previously saved configuration ──────────────────────────────────
    loadSavedValues() {
        try {
            this.isLoading = true;
            getUserConfig()
                .then(data => {
                    // Webhook config
                    const config = JSON.parse(data.ObjectConfigInfo);
                    if (config != '{}') {
                        this.selectedObject = 'Contact'; // always Contact
                        const savedPhoneField = config?.phoneField || '';
                        const savedFieldValues = config.requiredFields?.reduce((acc, field) => {
                            acc[field.name] = field.value;
                            return acc;
                        }, {});
                        this.loadRequiredFields(savedPhoneField, savedFieldValues);
                    } else {
                        this.loadRequiredFields('', {});
                    }

                    // Chat window config
                    const chatConfig = JSON.parse(data.ChatWindowConfigInfo);
                    if (chatConfig != '{}') {
                        this.chatWindowRows = Object.keys(chatConfig).map(objectName => {
                            const row = {
                                id: this.chatConfigCounter,
                                selectedObject: objectName,
                                selectedNameField: chatConfig[objectName].nameField,
                                selectedPhoneField: chatConfig[objectName].phoneField,
                                selectedEmailField: chatConfig[objectName].emailField || '',
                                phoneFieldOptions: [],
                            };
                            this.fetchFieldsForObject(row.id, objectName);
                            this.chatConfigCounter++;
                            return row;
                        });
                    } else {
                        this.handleAddRow();
                    }
                })
                .catch(error => {
                    console.error('Error fetching saved values:', error);
                })
                .finally(() => {
                    this.isLoading = false;
                });
        } catch (error) {
            console.error('Exception in loading saved values : ', error);
        }
    }

    // ── Load required fields for Contact object ───────────────────────────────
    loadRequiredFields(savedPhoneField = '', savedFieldValues = {}) {
        try {
            this.isLoading = true;
            getRequiredFields({ objectName: this.selectedObject })
                .then(data => {
                    const rawPhoneFields = data[0]?.phoneFields || [];
                    this.phoneFields = rawPhoneFields.map(field => ({ ...field, isSelected: false }));

                    // Select saved phone field, fallback to 'Phone', then first available
                    let selectedField = null;
                    if (savedPhoneField && this.phoneFields.some(f => f.value === savedPhoneField)) {
                        selectedField = this.phoneFields.find(f => f.value === savedPhoneField);
                    } else if (this.phoneFields.some(f => f.value === 'Phone')) {
                        selectedField = this.phoneFields.find(f => f.value === 'Phone');
                    } else {
                        selectedField = this.phoneFields[0] || null;
                    }

                    if (selectedField) {
                        this.selectedPhoneFieldVal = selectedField.value;
                        this.selectedPhoneFieldLabel = selectedField.label;
                        this.phoneFields = this.phoneFields.map(f => ({
                            ...f,
                            isSelected: f.value === this.selectedPhoneFieldVal
                        }));
                    } else {
                        this.selectedPhoneFieldVal = '';
                        this.selectedPhoneFieldLabel = '';
                    }

                    this.requiredFields = (data[0]?.requiredFields || []).map(field => ({
                        apiName: field.name,
                        label: field.label,
                        type: this.capitalizeFirstLetter(field.type),
                        value: field.type === 'BOOLEAN'
                            ? (savedFieldValues[field.name] !== undefined ? savedFieldValues[field.name] : false)
                            : field.type === 'DATE'
                                ? (savedFieldValues[field.name] || field.value || new Date().toISOString().split('T')[0])
                                : field.type === 'DATETIME'
                                    ? (savedFieldValues[field.name] || field.value || new Date().toISOString())
                                    : field.type === 'INTEGER' || field.type === 'DOUBLE' || field.type === 'CURRENCY'
                                        ? (savedFieldValues[field.name] || field.value || 0)
                                        : (savedFieldValues[field.name] || field.value || ''),
                        picklistValues: field?.picklistValues,
                        relatedObject: field?.relatedObject,
                        relatedRecordName: field?.relatedRecordName,
                        isString: field.type === 'STRING',
                        isNumber: field.type === 'INTEGER' || field.type === 'DOUBLE' || field.type === 'CURRENCY',
                        isDate: field.type === 'DATE',
                        isDateTime: field.type === 'DATETIME',
                        isBoolean: field.type === 'BOOLEAN',
                        isPicklist: field.type === 'PICKLIST',
                        isReference: field.type === 'REFERENCE',
                        isTextArea: field.type === 'TEXTAREA'
                    }));

                    this.populateReferenceNames();
                })
                .catch(error => {
                    console.error('Error fetching required fields:', error);
                })
                .finally(() => {
                    this.isLoading = false;
                });
        } catch (error) {
            console.error('Exception in loading required fields : ', error);
        }
    }

    capitalizeFirstLetter(str) {
        if (!str) return str;
        return str.charAt(0).toUpperCase() + str.slice(1).toLowerCase();
    }

    // ── Populate display names for Reference fields ───────────────────────────
    populateReferenceNames() {
        try {
            const referenceFields = this.requiredFields.filter(f => f.isReference && f.value && f.relatedObject);
            const namePromises = referenceFields.map(field =>
                getRecordName({ recordId: field.value, objectApiName: field.relatedObject })
                    .then(name => ({ apiName: field.apiName, name }))
                    .catch(error => {
                        console.error(`Error fetching name for ${field.apiName}:`, error);
                        return { apiName: field.apiName, name: '' };
                    })
            );
            Promise.all(namePromises)
                .then(results => {
                    this.requiredFields = this.requiredFields.map(field => {
                        const result = results.find(r => r.apiName === field.apiName);
                        return result && field.isReference && !field.relatedRecordName
                            ? { ...field, relatedRecordName: result.name }
                            : field;
                    });
                })
                .catch(error => console.error('Error in Promise.all:', error));
        } catch (error) {
            console.error('Exception in populating reference names:', error);
        }
    }

    // ── Webhook field change handlers ─────────────────────────────────────────
    handleInputChange(event) {
        try {
            const fieldName = event.currentTarget.dataset.field;
            const fieldIndex = this.requiredFields.findIndex(f => f.apiName === fieldName);
            if (fieldIndex !== -1) {
                this.requiredFields[fieldIndex].value = event.target.value;
                this.isDirty = true;
            }
        } catch (error) {
            console.error('Error in input : ', error);
        }
    }

    handleCheckboxChange(event) {
        try {
            const fieldName = event.currentTarget.dataset.field;
            const fieldIndex = this.requiredFields.findIndex(f => f.apiName === fieldName);
            if (fieldIndex !== -1) {
                this.requiredFields[fieldIndex].value = event.target.checked;
                this.isDirty = true;
            }
        } catch (error) {
            console.error('Error in checkbox value change : ', error);
        }
    }

    handleRecordSelection(event) {
        try {
            const fieldName = event.target.dataset.field;
            const selectedRecord = event.detail;
            if (selectedRecord?.recordId != null) {
                this.isDirty = true;
                this.requiredFields = this.requiredFields.map(field =>
                    field.apiName === fieldName ? { ...field, value: selectedRecord?.recordId } : field
                );
            } else {
                this.requiredFields = this.requiredFields.map(field =>
                    field.apiName === fieldName ? { ...field, value: '', relatedRecordName: '' } : field
                );
            }
        } catch (error) {
            console.error('Error in record selection : ', error);
        }
    }

    /*
    * Method Name: handleWebhookPhoneComboChange
    * @description: Handles phone field selection via combobox in Webhook config edit mode
    */
    handleWebhookPhoneComboChange(event) {
        try {
            const selected = event.detail.value;
            this.selectedPhoneFieldVal = selected;
            const match = this.phoneFields.find(f => f.value === selected);
            if (match) {
                this.selectedPhoneFieldLabel = match.label;
                this.phoneFields = this.phoneFields.map(f => ({ ...f, isSelected: f.value === selected }));
            }
            this.isDirty = true;
        } catch (error) {
            console.error('Error in webhook phone combo change:', error);
        }
    }

    // ── Chat window handlers ──────────────────────────────────────────────────
    async handleAddRow() {
        try {
            const newRow = {
                id: this.chatConfigCounter++,
                selectedObject: 'Contact',
                selectedNameField: '',
                selectedPhoneField: '',
                selectedEmailField: '',
                phoneFieldOptions: [],
            };
            this.chatWindowRows = [...this.chatWindowRows, newRow];
            await this.fetchFieldsForObject(newRow.id, 'Contact');
            this.chatWindowRows = this.chatWindowRows.map(row => {
                if (row.id === newRow.id) {
                    return {
                        ...row,
                        selectedPhoneField: row.phoneFieldOptions.length > 0 ? row.phoneFieldOptions[0].value : '',
                    };
                }
                return row;
            });
        } catch (error) {
            console.error('Error in adding new row', error);
        }
    }

    async fetchFieldsForObject(rowId, objectName) {
        try {
            const result = await getTextAndPhoneFields({ objectName });
            const data = result[0];
            const phoneFields = data.phoneFields || [];
            const textFields = data.textFields || [];
            const emailFields = data.emailFields || [];

            this.chatWindowRows = this.chatWindowRows.map(row => {
                if (row.id === parseInt(rowId)) {
                    return {
                        ...row,
                        phoneFieldOptions: phoneFields.map(f => ({ label: `${f.label} (${f.value})`, value: f.value })),
                        nameFieldOptions: textFields.map(f => ({ label: f.label, value: f.value })),
                        emailFieldOptions: emailFields.map(f => ({ label: `${f.label} (${f.value})`, value: f.value })),
                    };
                }
                return row;
            });
        } catch (error) {
            console.error('Error fetching fields:', error);
        }
    }

    handlePhoneFieldChange(event) {
        try {
            const rowId = event.target.dataset.rowId;
            const selectedPhoneField = event.target.value;
            this.chatWindowRows = this.chatWindowRows.map(row => {
                if (row.id === parseInt(rowId)) {
                    return { ...row, selectedPhoneField };
                }
                return row;
            });
            this.isDirty = true;
        } catch (error) {
            console.error('Error in changing Phone picklist : ', error);
        }
    }

    // ── Edit / Cancel / Save ──────────────────────────────────────────────────
    handleEdit() {
        this.isEditMode = true;
        this.isDirty = false;
    }

    handleCancel() {
        this.isLoading = true;
        this.isEditMode = false;
        this.isDirty = false;
        this.loadSavedValues();
    }

    /*
    * Method Name: handleSaveAll
    * @description: Saves both Chat Window config and Webhook config together.
    *               JSON formats are unchanged:
    *   Chat:    { "Contact": { nameField, phoneField, emailField } }
    *   Webhook: { objectApiName, phoneField, requiredFields: [{name, value, type}] }
    */
    handleSaveAll() {
        try {
            // Validate webhook required fields
            const invalidFields = this.requiredFields.filter(field =>
                !field.isBoolean &&
                (field.isString || field.isNumber || field.isDate || field.isDateTime || field.isPicklist || field.isReference || field.isTextArea) &&
                (field.value === '' || field.value === null || field.value === undefined)
            );
            if (invalidFields.length > 0) {
                const fieldNames = invalidFields.map(f => f.apiName).join(', ');
                this.showToast('Error', `Please fill all required fields: ${fieldNames}`, 'error');
                return;
            }

            // Validate chat window
            const invalidChatRows = this.chatWindowRows.filter(row => !row.selectedObject || !row.selectedPhoneField);
            if (invalidChatRows.length > 0) {
                this.showToast('Error', 'Please select a Phone Field under Chat Window Configuration.', 'error');
                return;
            }

            this.isLoading = true;

            // Build webhook JSON — format unchanged
            const webhookJson = JSON.stringify({
                objectApiName: this.selectedObject,
                phoneField: this.selectedPhoneFieldVal,
                requiredFields: this.requiredFields.map(field => ({
                    name: field.apiName,
                    value: field.value.toString(),
                    type: field.type
                }))
            });

            // Build chat window JSON — format unchanged
            const chatConfig = {};
            this.chatWindowRows.forEach(row => {
                if (row.selectedObject && row.selectedPhoneField) {
                    chatConfig[row.selectedObject] = {
                        nameField: row.selectedNameField || '',
                        phoneField: row.selectedPhoneField,
                        emailField: row.selectedEmailField || ''
                    };
                }
            });
            const chatJson = JSON.stringify(chatConfig);

            // Save both configs in parallel
            Promise.all([
                saveUserConfig({ jsonData: webhookJson }),
                saveUserConfig({ jsonDataForChat: chatJson })
            ])
                .then(([webhookResp, chatResp]) => {
                    if (webhookResp == 'Success' && chatResp == 'Success') {
                        this.showToast('Success', 'Configuration saved successfully', 'success');
                        this.populateReferenceNames();
                        this.isEditMode = false;
                        this.isDirty = false;
                    } else {
                        const errMsg = webhookResp != 'Success' ? webhookResp : chatResp;
                        this.showToast('Error', errMsg, 'error');
                    }
                })
                .catch(error => console.error('Error saving config:', error))
                .finally(() => { this.isLoading = false; });
        } catch (error) {
            console.error('Exception in saving configuration: ', error);
        }
    }

    // ── Accordion toggles ─────────────────────────────────────────────────────
    handleToggleSection(event) {
        const sectionName = event.currentTarget.dataset.section;
        const isOpen = this.activeSectionName.includes(sectionName);
        this.activeSectionName = isOpen
            ? this.activeSectionName.filter(s => s !== sectionName)
            : [...this.activeSectionName, sectionName];
    }

    get isChatSectionOpen() {
        return this.activeSectionName.includes('chatWindowConfig');
    }

    get isWebhookSectionOpen() {
        return this.activeSectionName.includes('webhookConfig');
    }

    get chatSectionClass() {
        return `accordion-item ${this.isChatSectionOpen ? 'open' : ''}`;
    }

    get webhookSectionClass() {
        return `accordion-item ${this.isWebhookSectionOpen ? 'open' : ''}`;
    }

    // Save button is disabled until something changes
    get isSaveDisabled() {
        return !this.isDirty;
    }

    // Options for the webhook phone-field combobox
    get webhookPhoneFieldOptions() {
        if (!this.phoneFields || this.phoneFields.length === 0) return [];
        return this.phoneFields.map(f => ({
            label: `${f.label} (${f.value})`,
            value: f.value
        }));
    }

    // ── Utilities ─────────────────────────────────────────────────────────────
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}