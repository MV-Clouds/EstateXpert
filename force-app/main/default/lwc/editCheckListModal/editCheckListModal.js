import { LightningElement, track, api} from 'lwc';
import getObjectFields from '@salesforce/apex/CheckListItemController.getObjectFields';
import manageChecklistRecords from '@salesforce/apex/CheckListItemController.manageChecklistRecords';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { errorDebugger } from 'c/globalProperties';

export default class EditCheckListModal extends LightningElement {

    @track myVariable;
    @track objectoptions = [];
    @track fieldoptions = [];
    @track listOfFields = [];
    @api objectName;
    @api recordId;
    @track selectedObjectName;
    @track checklistItems;
    @track checklistRecords;
    @track isSpinner = true;
    @track setScroll = false;
    @track isPrimary = false;
    @track isPicklist = false;
    @track isReference = false;

    operatorOptions = [
        { label: 'Equals', value: 'Equals' },
        { label: 'Not Equals to', value: 'Not Equals to' },
        { label: 'Is Null', value: 'Is Null' },
        { label: 'Greater Than', value: 'Greater Than' },
        { label: 'Greater Than Equal To', value: 'Greater Than Equal To' },
        { label: 'Less Than', value: 'Less Than' },
        { label: 'Less Than Equal To', value: 'Less Than Equal To' },
        { label: 'Contains', value: 'Contains' },
        { label: 'Not Contains', value: 'Not Contains' },
    ];

    /**
    * Method Name: isDataAvailable
    * @description: Used to check if data is available.
    * Date: 09/07/2024
    * Created By: Karan Singh
    */
    get isDataAvailable() {
        return this.checklistItems && this.checklistItems.length > 0;
    }

    /**
    * Method Name: connectedCallback
    * @description: Used to call getObjectFieldsAndName method.
    * Created Date: 09/07/2024
    * Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    connectedCallback(){
        try {
            loadStyle(this, MulishFontCss);
            this.getObjectFieldsAndName();
        } catch (error) {
            errorDebugger('EditCheckListModal', 'connectedCallback', error, 'warn', 'error in connectedCallback');
        }
	}

    /**
    * Method Name: renderedCallback
    * @description: Used to scroll to bottom of the table.
    * Created Date: 09/07/2024
    * Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    renderedCallback(){
        try {
            if(this.setScroll){
                const container = this.template.querySelector('.table-content');
                container.scrollTop = container.scrollHeight;
                this.setScroll = false;
            }
        } catch (error) {
            errorDebugger('EditCheckListModal', 'renderedCallback', error, 'warn', 'error in renderedCallback');
        }
    }

    /**
    * Method Name: getObjectFieldsAndName
    * @description: Used to get object fields and name.
    * Created Date: 09/07/2024
    * Created By: Karan Singh
    */
    getObjectFieldsAndName() {
        try {
            getObjectFields({ objectName: this.objectName })
                .then(result => {
                    // Create deep copies of the checklist array
                    this.checklistItems = JSON.parse(JSON.stringify(result.checklist));
                    this.checklistRecords = JSON.parse(JSON.stringify(result.checklist));
                    this.listOfFields = result.fields;
    
                    const primaryFieldTypes = ['TEXT', 'DATETIME', 'DATE', 'NUMBER', 'EMAIL'];
                    const picklistFieldTypes = ['PICKLIST', 'BOOLEAN', 'MULTIPICKLIST'];
                    const referenceFieldTypes = ['REFERENCE'];
    
                    this.checklistItems.forEach(item => {
                        const fieldType = item.MVEX__Data_Type__c;
    
                        item.isPrimary = primaryFieldTypes.includes(fieldType);
                        item.isPicklist = picklistFieldTypes.includes(fieldType);
                        item.isReference = referenceFieldTypes.includes(fieldType);
    
                        // If isPicklist is true, get picklist values from result.fields
                        if (item.isPicklist) {
                            const field = result.fields.find(f => f.value === item.MVEX__Field_Name__c);
                            if (field && field.picklistValues.length > 0) {
                                item.picklistValues = field.picklistValues.map(picklistValue => {
                                    return { label: picklistValue, value: picklistValue };
                                });
                            }
                        } else if (item.isReference) {
                            const field = result.fields.find(f => f.value === item.MVEX__Field_Name__c);
                            if (field && field.referenceTo) {
                                item.objectApiName = field.referenceTo;
                            }
                        }

                        if (item.MVEX__Operator__c && item.MVEX__Operator__c.includes('Is Null')) {

                            item.isPrimary = false;
                            item.isPicklist = true;
                            item.isReference = false;

                            item.picklistValues = [
                                { label: 'True', value: 'true' },
                                { label: 'False', value: 'false' }
                            ];
                        }
                    });
    
                    this.selectedObjectName = result.label;
                    this.fieldoptions = result.fields.map(field => {
                        return { label: field.label, value: field.value };
                    }).sort((a, b) => a.label.localeCompare(b.label));
                    this.isSpinner = false;
                })
                .catch(error => {
                    this.isSpinner = false;
                    errorDebugger('EditCheckListModal', 'getObjectFieldsAndName', error, 'warn', 'error in getObjectFieldsAndName');
                });
        } catch (error) {
            this.isSpinner = false;
            errorDebugger('EditCheckListModal', 'getObjectFieldsAndName', error, 'warn', 'error in getObjectFieldsAndName');
        }
    }

    /**
    * Method Name: handleOrderChange
    * @description: Used to handle order change.
    * Created Date: 09/07/2024
    * Created By: Karan Singh
    */
    handleOrderChange(event) {
        try {
            const action = event.currentTarget.dataset.action;
            const index = parseInt(event.currentTarget.dataset.index, 10);
            if (action === 'up') {
                this.moveItemUp(index);
            } else if (action === 'down') {
                this.moveItemDown(index);
            }
        } catch (error) {
            errorDebugger('EditCheckListModal', 'handleOrderChange', error, 'warn', 'error in handleOrderChange');
        }
    }

    /**
    * Method Name: moveItemUp
    * @description: Used to move item up.
    * Created Date: 09/07/2024
    * Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    moveItemUp(index) {
        try {
            if (index > 0) {
                const updatedItems = [...this.checklistItems];
                [updatedItems[index - 1], updatedItems[index]] = [updatedItems[index], updatedItems[index - 1]]; // Swap items
                this.checklistItems = updatedItems;
            }
        } catch (error) {
            errorDebugger('EditCheckListModal', 'moveItemUp', error, 'warn', 'error in moveItemUp');
        }
    }

    /**
    * Method Name: moveItemDown
    * @description: Used to move item down.
    * Created Date: 09/07/2024
    * Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    moveItemDown(index) {
        try {
            if (index < this.checklistItems.length - 1) {
                const updatedItems = [...this.checklistItems];
                [updatedItems[index], updatedItems[index + 1]] = [updatedItems[index + 1], updatedItems[index]]; // Swap items
                this.checklistItems = updatedItems;
            }
        } catch (error) {
            errorDebugger('EditCheckListModal', 'moveItemDown', error, 'warn', 'error in moveItemDown');
        }
    }

    /**
    * Method Name: handleDelete
    * @description: Used to handle delete.
    * Created Date: 09/07/2024
    * Created By: Karan Singh
    */
    handleDelete(event) {
        try {
            const index = parseInt(event.currentTarget.dataset.index, 10);
            const updatedItems = [...this.checklistItems];
            updatedItems.splice(index, 1); // Remove the item at the specified index
            this.checklistItems = updatedItems;
        } catch (error) {
            errorDebugger('EditCheckListModal', 'handleDelete', error, 'warn', 'error in handleDelete');
        }
    }

    /**
    * Method Name: handleDialogueClose
    * @description: Used to handle dialogue close.
    * Created Date: 09/07/2024
    * Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    handleDialogueClose() {
        try {
            let custEvent = new CustomEvent('hidepopup', {
                details: false
            });
            this.dispatchEvent(custEvent);
        } catch (error) {
            errorDebugger('EditCheckListModal', 'handleDialogueClose', error, 'warn', 'error in handleDialogueClose');
        }
    }

    /**
    * Method Name: addNewRow
    * @description: Used to add new row.
    * Created Date: 09/07/2024
    * Created By: Karan Singh
    */
    addNewRow() {
        try {
            const newItem = {
                Id: '',
                Name: '',
                MVEX__Field_Name__c: '',
                MVEX__Operator__c: '',
                MVEX__Value__c: '',
                MVEX__Description__c: '',
                MVEX__Data_Type__c: 'TEXT',
                isPrimary: true
            };
            this.checklistItems = [...this.checklistItems, newItem];
            this.setScroll = true;
        } catch (error) {
            errorDebugger('EditCheckListModal', 'addNewRow', error, 'warn', 'error in addNewRow');
        }
    }

    /**
    * Method Name: handleFieldNameChange
    * @description: Used to handle field name change.
    * Created Date: 09/07/2024
    * Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    handleFieldNameChange(event) {
        try {
            this.removeError();
            const index = event.currentTarget.dataset.index;
            const value = event.currentTarget.value;
            this.checklistItems[index].MVEX__Field_Name__c = value;
            this.checklistItems[index].MVEX__Value__c = '';
            this.checklistItems[index].MVEX__Operator__c = '';
        
            // Find the matching field from listoffields
            const selectedField = this.listOfFields.find(field => field.value === value);
            if (selectedField) {
                const fieldType = selectedField.type;

                const primaryFieldTypes = ['TEXT', 'DATETIME', 'DATE', 'NUMBER', 'EMAIL'];
                const picklistFieldTypes = ['PICKLIST', 'BOOLEAN', 'MULTIPICKLIST'];
                const referenceFieldTypes = ['REFERENCE'];
        
                this.checklistItems[index].isPrimary = primaryFieldTypes.includes(fieldType);
                this.checklistItems[index].isPicklist = picklistFieldTypes.includes(fieldType);
                this.checklistItems[index].isReference = referenceFieldTypes.includes(fieldType);
                this.checklistItems[index].MVEX__Data_Type__c = fieldType;

                if (fieldType == 'REFERENCE') {
                    this.checklistItems[index].objectApiName = selectedField.referenceTo;
                } else {
                    if (this.checklistItems[index].isPicklist && selectedField.picklistValues.length > 0) {
                        this.checklistItems[index].picklistValues = selectedField.picklistValues.map(picklistValue => {
                            return { label: picklistValue, value: picklistValue };
                        });
                    } else {
                        this.checklistItems[index].picklistValues = null;
                    }
                }        
            }
            this.checklistItems = [...this.checklistItems]; // Force reactivity
        } catch (error) {
            errorDebugger('EditCheckListModal', 'handleFieldNameChange', error, 'warn', 'error in handleFieldNameChange');
        }
    }
    

    /**
    * Method Name: handleOperatorChange
    * @description: Used to handle operator change.
    * Created Date: 09/07/2024
    * Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    handleOperatorChange(event) {
        try {
            this.removeError();
            const index = event.currentTarget.dataset.index;
            const value = event.currentTarget.value;
            const fieldApiName = event.currentTarget.dataset.fieldapiname;
            this.checklistItems[index].MVEX__Operator__c = value;

            if (value === 'Is Null') {
                this.checklistItems[index].isPrimary = false;
                this.checklistItems[index].isPicklist = true;
                this.checklistItems[index].isReference = false;

                this.checklistItems[index].picklistValues = [
                    { label: 'True', value: 'true' },
                    { label: 'False', value: 'false' }
                ];
            } else if (value === 'Greater Than' || value === 'Greater Than Equal To' || value === 'Less Than' || value === 'Less Than Equal To') {
                this.checklistItems[index].isPrimary = true;
                this.checklistItems[index].isPicklist = false;
                this.checklistItems[index].isReference = false;
                this.checklistItems[index].MVEX__Data_Type__c = 'NUMBER';
            } else {
                const selectedField = this.listOfFields.find(field => field.value === fieldApiName);
                if (selectedField) {
                    const fieldType = selectedField.type;

                    const primaryFieldTypes = ['TEXT', 'DATETIME', 'DATE', 'NUMBER', 'EMAIL'];
                    const picklistFieldTypes = ['PICKLIST', 'BOOLEAN', 'MULTIPICKLIST'];
                    const referenceFieldTypes = ['REFERENCE'];
            
                    this.checklistItems[index].isPrimary = primaryFieldTypes.includes(fieldType);
                    this.checklistItems[index].isPicklist = picklistFieldTypes.includes(fieldType);
                    this.checklistItems[index].isReference = referenceFieldTypes.includes(fieldType);
                    this.checklistItems[index].MVEX__Data_Type__c = fieldType;

                    if (fieldType == 'REFERENCE') {
                        this.checklistItems[index].objectApiName = selectedField.referenceTo;
                    } else {
                        if (this.checklistItems[index].isPicklist && selectedField.picklistValues.length > 0) {
                            this.checklistItems[index].picklistValues = selectedField.picklistValues.map(picklistValue => {
                                return { label: picklistValue, value: picklistValue };
                            });
                        } else {
                            this.checklistItems[index].picklistValues = null;
                        }
                    }        
                }
            }

            this.checklistItems = [...this.checklistItems];
        } catch (error) {
            errorDebugger('EditCheckListModal', 'handleOperatorChange', error, 'warn', 'error in handleOperatorChange');
        }
    }

    /**
    * Method Name: handleInputChange
    * @description: Used to handle input change.
    * Created Date: 09/07/2024
    * Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    handleInputChange(event) {
        try {
            this.removeError();
            const index = event.currentTarget.dataset.index;
            const field = event.currentTarget.dataset.field;
            const value = event.currentTarget.value;
            this.checklistItems[index][field] = value;
        } catch (error) {
            errorDebugger('EditCheckListModal', 'handleInputChange', error, 'warn', 'error in handleInputChange');
        }
    }

    /**
    * Method Name: saveChecklistRecords
    * @description: Used to save checklist records.
    * Created Date: 09/07/2024
    * Created By: Karan Singh
    */
    saveChecklistRecords(){
        try {
            this.isSpinner = true;

            const inputElements = this.template.querySelectorAll('lightning-input');
            let allValid = true;

            inputElements.forEach(input => {
                if (!input.checkValidity()) {
                    allValid = false;
                }
            });

            if (!allValid) {
                this.toast('Error', 'Please correct the highlighted errors.', 'error');
                this.isSpinner = false;
                return;
            }
            
            // Check if there are any changes
            if (JSON.stringify(this.checklistItems) === JSON.stringify(this.checklistRecords)) {
                this.toast('Success', 'Checklist updated successfully', 'success');
                this.isSpinner = false;
                this.handleDialogueClose();
                return;
            }

            // Validate each checklist item using a traditional for loop instead of for-of
            for (let index = 0; index < this.checklistItems.length; index++) {
                const item = this.checklistItems[index];
                if (!item.Name || !item.Name.trim()) {
                    this.toast('Error', `Checklist Name field is required.`, 'error');
                    let fieldName1 = 'Name';
                    const inputElement = this.template.querySelector(`lightning-input[data-field="${fieldName1}"][data-index="${index}"]`);
                    if (inputElement) {
                        inputElement.classList.add('error_css');
                    }
                    this.isSpinner = false;
                    return;
                } else if (item.Name.length > 80) {
                    this.toast('Error', `Checklist Name field exceeds 80 characters.`, 'error');
                    let fieldName2 = 'Name';
                    const inputElement = this.template.querySelector(`lightning-input[data-field="${fieldName2}"][data-index="${index}"]`);
                    if (inputElement) {
                        inputElement.classList.add('error_css');
                    }
                    this.isSpinner = false;
                    return;
                }

                if (item.MVEX__Field_Name__c || item.MVEX__Operator__c || item.MVEX__Value__c) {
                    if (!item.MVEX__Field_Name__c) {
                        this.toast('Error', `Field Name should not be empty.`, 'error');
                        let fieldName3 = 'MVEX__Field_Name__c';
                        const inputElement = this.template.querySelector(`lightning-combobox[data-field="${fieldName3}"][data-index="${index}"]`);
                        if (inputElement) {
                            inputElement.classList.add('error_css');
                        }
                        this.isSpinner = false;
                        return;
                    }
                    if (!item.MVEX__Operator__c) {
                        this.toast('Error', `Operator should not be empty.`, 'error');
                        let fieldName4 = 'MVEX__Operator__c';
                        const inputElement = this.template.querySelector(`lightning-combobox[data-field="${fieldName4}"][data-index="${index}"]`);
                        if (inputElement) {
                            inputElement.classList.add('error_css');
                        }
                        this.isSpinner = false;
                        return;
                    }
                    if (!item.MVEX__Value__c || !item.MVEX__Value__c.trim()) {
                        this.toast('Error', `Value should not be empty.`, 'error');
                        let fieldName5 = 'MVEX__Value__c';
                        const inputElement = this.template.querySelector(`lightning-input[data-field="${fieldName5}"][data-index="${index}"]`);
                        if (inputElement) {
                            inputElement.classList.add('error_css');
                        }
                        this.isSpinner = false;
                        return;
                    }
                }
            }

            const removeUnwantedFields = (item) => {
                // Create a copy of the item to avoid mutating the original object
                const newItem = { ...item };
                
                // Remove unwanted properties
                delete newItem.isPrimary;
                delete newItem.isPicklist;
                delete newItem.isReference;
                delete newItem.picklistValues;
                delete newItem.objectApiName;
                
                return newItem;
            };

            // Categorize items
            const itemsToCreate = [];
            const itemsToUpdate = [];
            const itemsToDelete = this.checklistRecords
                .filter(record => record.Id && !this.checklistItems.some(item => item.Id === record.Id))
                .map(record => record.Id);

            this.checklistItems.forEach((item, index) => {
                item.MVEX__Sequence__c = index + 1; // Add sequence number only if order changed

                if (!item.Id) {
                    const newItem = { ...item, MVEX__Object_Name__c: this.objectName };
                    delete newItem.Id; // Remove Id field
                    itemsToCreate.push(removeUnwantedFields(newItem));
                } else {
                    const originalItem = this.checklistRecords.find(record => record.Id === item.Id);
                    if (originalItem && (
                        item.Name !== originalItem.Name ||
                        item.MVEX__Field_Name__c !== originalItem.MVEX__Field_Name__c ||
                        item.MVEX__Operator__c !== originalItem.MVEX__Operator__c ||
                        item.MVEX__Value__c !== originalItem.MVEX__Value__c ||
                        item.MVEX__Description__c !== originalItem.MVEX__Description__c ||
                        item.MVEX__Sequence__c !== originalItem.MVEX__Sequence__c ||
                        item.MVEX__Data_Type__c !== originalItem.MVEX__Data_Type__c
                    )) {
                        itemsToUpdate.push(removeUnwantedFields(item));
                    }
                }
            });

            manageChecklistRecords({
                itemsToCreate: itemsToCreate,
                itemsToUpdate: itemsToUpdate,
                itemsToDelete: itemsToDelete
            })
            .then(result => {
                this.isSpinner = false;
                if (result === 'success') {
                    this.toast('Success', 'Checklist updated successfully', 'success');
                    this.handleRefresh();
                } else {
                    this.toast('Error', result, 'error');
                }
            })
            .catch(error => {
                this.isSpinner = false;
                this.toast('Error', 'Error while updating checklist', 'error');
                errorDebugger('EditCheckListModal', 'saveChecklistRecords', error, 'warn', 'error in saveChecklistRecords');
            });
        } catch (error) {
            errorDebugger('EditCheckListModal', 'saveChecklistRecords', error, 'warn', 'error in saveChecklistRecords');
            this.isSpinner = false;
        }
    }

    /**
    * Method Name: handleRefresh
    * @description: Used to handle refresh.
    * Created Date: 09/07/2024
    * Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    handleRefresh(){
        try {
            let custEvent = new CustomEvent('hidepopupandrefresh', {
                details: false
            });
            this.dispatchEvent(custEvent);
        } catch (error) {
            errorDebugger('EditCheckListModal', 'handleRefresh', error, 'warn', 'error in handleRefresh');
        }
    }

    /**
    * Method Name: toast
    * @description: Used to show toast.
    * @param {string} title - The title of the toast.
    * @param {string} message - The message of the toast.
    * @param {string} variant - The variant of the toast.
    * Created Date: 09/07/2024
    * Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    toast(title, message, variant) {
        try {
            if (!import.meta.env.SSR) {
                const toastEvent = new ShowToastEvent({
                    title,
                    message,
                    variant
                })
                this.dispatchEvent(toastEvent);
            }
        } catch (error) {
            errorDebugger('EditCheckListModal', 'toast', error, 'warn', 'error in toast');
        }
    }

    /**
    * Method Name: removeError
    * @description: Used to remove error.
    * Created Date: 09/07/2024
    * Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    removeError(){
        try {
            const inputElements = this.template.querySelectorAll('lightning-input');
            inputElements.forEach(input => {
                input.classList.remove('error_css');
            });

            const comboboxElements = this.template.querySelectorAll('lightning-combobox');
            comboboxElements.forEach(combobox => {
                combobox.classList.remove('error_css');
            });
        } catch (error) {
            errorDebugger('EditCheckListModal', 'removeError', error, 'warn', 'error in removeError');
        }
    }

    /**
    * Method Name: handleRefChange
    * @description: Used to handle ref change.
    * Created Date: 09/07/2024
    * Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    handleRefChange(event) {
        try {
            event.stopPropagation();
            const index = event.currentTarget.dataset.index;
            const field = event.currentTarget.dataset.field;
            let selectedValueId = event.detail.recordId;
            this.checklistItems[index][field] = selectedValueId;
        } catch (error) {
            errorDebugger('EditCheckListModal', 'handleRefChange', error, 'warn', 'error in handleRefChange');
        }
    }
}