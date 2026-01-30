import { LightningElement, track, api } from 'lwc';
import getContactFields from '@salesforce/apex/MarketingListFilterController.getContactFields';

export default class MarketingListFilterAddCmp extends LightningElement {
    @track fieldOptions = [];
    @track selectedFields = [];
    @track selectedField = [];
    @track breadcrumbs = [];
    @track selectedValues = [];
    @track showCombobox = true;
    // Custom combobox properties
    @track searchTerm1 = '';
    @track isFocused1 = false;
    @track valueIsField = false;
    @track notCheckboxValue = false;
    @track contactFields = [];
    @track options1 = [];
    @track isDisabled = true;

    /**
   * Method Name: connectedCallback
   * @description: handle add button disable, fetch contact fields.
   * Date: 26/06/2024
   * Created By: Vyom Soni
   */
    connectedCallback() {
        this.handleAddButtonDisable();
        this.fetchObjectFields('Contact');
    }

    /**
   * Method Name: fetchObjectFields
   * @description: fetch the fields values.
   * @param: objectApiName- object api name.
   * Date: 26/06/2024
   * Created By: Vyom Soni
   */
    fetchObjectFields(objectApiName) {
        this.isDisabled = true;
        getContactFields({ objectApiName })
            .then(fields => {
                let filteredFields = fields.filter(field => field.fieldAPIName !== 'OwnerId');
                if (this.breadcrumbs.length > 0) {
                    filteredFields = fields.filter(field => field.fieldType != 'REFERENCE');
                }
                if (fields) {
                    this.fieldOptions = filteredFields.map(field => {
                        return {
                            label: field.fieldName, // Only show the label
                            value: field.fieldAPIName,
                            type: field.fieldType, // Add type to identify lookup fields
                            referenceObjectName: field.referenceFields || [],
                            objectApiName: field.referenceObjectName || '',
                            picklistValues: field.picklistValues || []
                            // Include reference fields if any
                        };
                    });
                    const offerField = [{ "value": "MVEX__Inquiry__c", "label": "Inquiry", "type": "REFERENCE", "objectApiName": "MVEX__Inquiry__c" }];
                    this.fieldOptions = this.fieldOptions.concat(offerField);
                    this.options1 = this.fieldOptions;
                    this.isDisabled = false;
                }
            })
            .catch(error => {
                console.error('Error fetching object fields:', error);
            });
    }

    /**
    * Method Name: fetchObjectFieldsWithoutReference
    * @description: fetch fields when reference field was clicked.
    * @param: objectApiName- object api name.
    * Date: 26/06/2024
    * Created By: Vyom Soni
    */
    fetchObjectFieldsWithoutReference(objectApiName) {
        this.isDisabled = true;
        getContactFields({ objectApiName })
            .then(fields => {
                let filteredFields = fields;
                if (this.breadcrumbs.length > 0) {
                    filteredFields = fields.filter(field => field.fieldType != 'REFERENCE');
                }
                if (fields) {
                    this.fieldOptions = filteredFields.map(field => {
                        return {
                            label: field.fieldName, // Only show the label
                            value: field.fieldAPIName,
                            type: field.fieldType, // Add type to identify lookup fields
                            referenceObjectName: field.referenceFields || [],
                            objectApiName: field.referenceObjectName || '',
                            picklistValues: field.picklistValues || []
                            // Include reference fields if any
                        };
                    });
                    this.options1 = this.fieldOptions;
                    this.isDisabled = false;
                }
            })
            .catch(error => {
                console.error('Error fetching object fields:', error);
            });
    }

    /**
   * Method Name: currentFieldOptions
   * @description: getter for the set the current selectedfield operator options.
   * Date: 26/06/2024
   * Created By: Vyom Soni
   */
    get currentFieldOptions() {
        if (this.selectedField.length === 0) return [];

        const fieldType = this.selectedField[0].type;
        let options = [];

        switch (fieldType) {
            case 'PICKLIST':
                options = [
                    { label: 'Includes', value: 'includes' },
                    { label: 'Equals', value: 'equals' }
                ];
                break;
            case 'MULTIPICKLIST':
                options = [
                    { label: 'Includes', value: 'includes' },
                    { label: 'Equals', value: 'equals' }
                ];
                break;
            case 'BOOLEAN':
                options = [
                    { label: 'True/False', value: 'boolean' }
                ];
                break;
            case 'DOUBLE':
                options = [
                    { label: 'Range', value: 'range' },
                    { label: 'Minimum', value: 'minimum' },
                    { label: 'Maximum', value: 'maximum' }
                ];
                break;
            case 'CURRENCY':
                options = [
                    { label: 'Range', value: 'range' },
                    { label: 'Minimum', value: 'minimum' },
                    { label: 'Maximum', value: 'maximum' }
                ];
                break;
            case 'STRING':
                options = [
                    { label: 'Equals', value: 'equals' },
                    { label: 'Contains', value: 'contains' },
                    { label: 'Starts With', value: 'startswith' }
                ];
                break;
            case 'TEXTAREA':
                options = [
                    { label: 'Equals', value: 'equals' },
                    { label: 'Contains', value: 'contains' },
                    { label: 'Starts With', value: 'startswith' }
                ];
                break;
            case 'DATE':
                options = [
                    { label: 'Date Range', value: 'daterange' },
                    { label: 'Date Minimum', value: 'dateminimum' },
                    { label: 'Date Maximum', value: 'datemaximum' }
                ];
                break;
            case 'DATETIME':
                options = [
                    { label: 'Date Range', value: 'daterange' },
                    { label: 'Date Minimum', value: 'dateminimum' },
                    { label: 'Date Maximum', value: 'datemaximum' }
                ];
                break;
            case 'ID':
                options = [
                    { label: 'Equals', value: 'equals' }
                ];
                break;
            case 'EMAIL':
                options = [
                    { label: 'Equals', value: 'equals' }
                ];
                break;
            case 'PHONE':
                options = [
                    { label: 'Equals', value: 'equals' }
                ];
                break;
            case 'URL':
                options = [
                    { label: 'Equals', value: 'equals' }
                ];
                break;
            default:
                options = [];
        }
        return options;
    }

    /**
    * Method Name: changeFields
    * @description: handle the fields select of non-reference field.
    * Date: 26/06/2024
    * Created By: Vyom Soni
    */
    changeFields(event) {
        this.handleFieldSelect(event);
        this.showCombobox = false;
        this.valueIsField = true;
        this.selectedField = [this.selectedFields.length > 0 ? this.selectedFields[this.selectedFields.length - 1] : null];
    }

    /**
    * Method Name: handleFieldSelect
    * @description: add the selected field from checkbox into selcetdFields.
    * Date: 26/06/2024
    * Created By: Vyom Soni
    */
    handleFieldSelect(event) {
        try {
            const selectedValue = event.currentTarget.dataset.id;
            const selectedField = this.fieldOptions.find(option => option.value === selectedValue);

            if (selectedValue && selectedField && !this.selectedValues.includes(selectedValue)) {

                this.selectedFields.push({ label: selectedField.label, objectApiName: selectedField.objectApiName, value: selectedField.value, type: selectedField.type, picklistValues: selectedField.picklistValues, prevApiName: this.selectedValues.length > 0 ? this.selectedValues[this.selectedValues.length - 1] : '' });
                this.selectedValues.push(selectedValue);
                this.updateBreadcrumbs();
            }
            this.searchTerm1 = ''; // Clear the search term to reset the search
            this.isFocused1 = false; // Close the dropdown
        } catch (error) {
            console.error('Error -> handleFieldSelect' + error);
        }
    }


    /**
    * Method Name: changeTheCheckboxValue
    * @description: handle the fields select of reference field.
    * Date: 26/06/2024
    * Created By: Vyom Soni
    */
    changeTheCheckboxValue(event) {
        try {
            this.selectedField = [];
            this.valueIsField = false;
            const selectedValue = event.currentTarget.dataset.id;
            const selectedField = this.fieldOptions.find(option => option.value === selectedValue);
            if (selectedField != null) {
                this.handleFieldSelect(event);
                this.fetchObjectFieldsWithoutReference(selectedField.objectApiName);
            }
        } catch (error) {
            console.error('Error -> changeTheCheckboxValue' + error);
        }
    }

    /**
   * Method Name: findFieldRecursively
   * @description: this method check the from fiedls hierarchy.
   * @param: fields- fields list
   * @param: selectedValue- selected Item in fields picklist.
   * Date: 26/06/2024
   * Created By: Vyom Soni
   */
    findFieldRecursively(fields, selectedValue) {
        try {
            for (let i = 0; i < fields.length; i++) { // Changed from for...of to traditional for loop
                const field = fields[i]; // Access the field using the index
                if (field.apiName === selectedValue || field.value === selectedValue) {
                    return field; // Return the field if found
                }
                // If the current field is a reference field and has referenceFields, recursively search them
                if (field.type === 'REFERENCE' && field.referenceFields && field.referenceFields.length > 0) {
                    const foundField = this.findFieldRecursively(field.referenceFields, selectedValue);
                    if (foundField) {
                        return foundField; // Return the found field if it exists
                    }
                }
            }
            return null; // Return null if the field is not found
        } catch (error) {
            console.error('Error -> findFieldRecursively' + error);
        };

    }

    /**
    * Method Name: updateBreadcrumbs
    * @description: handle the combobox options when the bread crumbs is clicked.
    * Date: 26/06/2024
    * Created By: Vyom Soni
    */
    updateBreadcrumbs() {
        try {
            this.valueIsField = false;
            this.breadcrumbs = this.selectedFields.map(selectedValue => {
                return { label: selectedValue.label };
            });
        } catch (error) {
            console.error('Error updateBreadcrumbs' + error);
        }
    }

    /**
    * Method Name: handleBreadcrumbClick
    * @description: handle the combobox options when the bread crumbs is clicked
    * Date: 26/06/2024
    * Created By: Vyom Soni
    */
    handleBreadcrumbClick(event) {
        try {
            const clickedIndex = parseInt(event.currentTarget.dataset.index, 10);
            this.selectedFields = this.selectedFields.slice(0, clickedIndex);
            this.selectedValues = this.selectedValues.slice(0, clickedIndex);
            this.selectedField = [];
            this.handleAddButtonDisable();

            if (this.selectedValues.length > 0) {
                let lastSelectedField = this.selectedFields[this.selectedFields.length - 1].objectApiName;
                if (lastSelectedField == null) {
                    lastSelectedField = 'Contact'
                }
                else {
                    this.fetchObjectFieldsWithoutReference(lastSelectedField);
                }
            } else {
                this.fetchObjectFields('Contact');
            }

            this.showCombobox = true;
            this.updateBreadcrumbs();
        } catch (error) {
            console.error('Error handleBreadcrumbClick' + error);
        }

    }

    /**
    * Method Name: handleSearchChange1
    * @description: handle search text change.
    * Date: 26/06/2024
    * Created By: Vyom Soni
    */
    handleSearchChange1(event) {
        this.searchTerm1 = event.target.value;
    }

    /**
    * Method Name: handleFocus1
    * @description: handle focus event in combobox.
    * Date: 26/06/2024
    * Created By: Vyom Soni
    */
    handleFocus1() {
        this.isFocused1 = true;
    }

    /**
    * Method Name: handleBlur1
    * @description: handle blur event in the combobox.
    * Date: 26/06/2024
    * Created By: Vyom Soni
    */
    handleBlur1() {
        // Delay the blur action to allow click event to be registered
        this.isFocused1 = false;
    }

    /**
    * Method Name: showOptions1
    * @description: Hide / Unhide options of the combobox.
    * Date: 26/06/2024
    * Created By: Vyom Soni
    */
    get showOptions1() {
        return this.isFocused1 || this.searchTerm1 !== '';
    }

    /**
    * Method Name: filteredOptions1
    * @description: this getter made the field list to show in the UI.
    * Date: 26/06/2024
    * Created By: Vyom Soni
    */
    get filteredOptions1() {
        try {
            if (this.searchTerm1 === '' && !this.isFocused1) {
                return [];
            }
            return this.options1.filter(option =>
                option.label.toLowerCase().includes(this.searchTerm1.toLowerCase())
            ).map(option => ({
                ...option,
                showRightIcon: this.isLookupField(option.type) // Check if it's a lookup field
            }));
        } catch (error) {
            console.error('Error filteredOptions1' + error);
            return null;
        }
    }

    /**
    * Method Name: isLookupField
    * @description: check field is lookup or reference.
    * @param: fieldType- field's data-type
    * Date: 26/06/2024
    * Created By: Vyom Soni
    */
    isLookupField(fieldType) {
        return fieldType === 'REFERENCE' || fieldType === 'Lookup'; // Adjust this condition based on your field types
    }


    /**
    * Method Name: computedDropdownClass
    * @description: return dynamic class for the combobox.
    * Date: 26/06/2024
    * Created By: Vyom Soni
    */
    get computedDropdownClass() {
        return `slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ${this.isFocused1 ? 'slds-is-open' : ''}`;
    }

    // operation checkbox change errorin

    /**
   * Method Name: handleNotCheckboxChange
   * @description: handle the not checkbox change.
   * Date: 26/06/2024
   * Created By: Vyom Soni
   */
    handleNotCheckboxChange(event) {
        this.notCheckboxValue = event.target.checked;
        this.selectedField[0].isNot = event.target.checked;
    }

    /**
    * Method Name: operationSelect
    * @description: handle the operation combobox change.
    * Date: 26/06/2024
    * Created By: Vyom Soni
    */
    operationSelect(event) {
        this.selectedField[0].operation = event.target.value;
        this.handleAddButtonDisable();
    }

    /**
   * Method Name: handleAddButtonDisable
   * @description: set add button disable when the selectedfield in empty.
   * Date: 26/06/2024
   * Created By: Vyom Soni
   */
    handleAddButtonDisable() {
        if (typeof window !== 'undefined') {
            this.dispatchEvent(new CustomEvent('fieldchange', { detail: this.selectedField }));
        }
    }

    /**
    * Method Name: handleButtonClick
    * @description: It is call from the parent component and it send teh selected field to parent component.
    * Date: 26/06/2024
    * Created By: Vyom Soni
    */
    @api
    handleButtonClick() {
        // Create a custom event with the value you want to pass to the parent
        const customEvent = new CustomEvent('valueselected', {
            detail: this.selectedField
        });

        // Dispatch the custom event
        this.dispatchEvent(customEvent);
    }

    /**
    * Method Name: handlePreventDefault
    * @description: prevent default events when the options div clicked.
    * Date: 23/07/2024
    * Created By: Vyom Soni
    */
    handlePreventDefault(event) {
        event.preventDefault();
    }

}