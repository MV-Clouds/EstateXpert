import { LightningElement, track } from 'lwc';
import getStaticFields from '@salesforce/apex/MarketingListFilterController.getStaticFields';
import getPicklistValues from '@salesforce/apex/MarketingListFilterController.getPicklistValues';
import getFilteredContacts from '@salesforce/apex/MarketingListFilterController.getFilteredContacts';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { loadStyle } from 'lightning/platformResourceLoader';

export default class MarketingListFilterCmp extends LightningElement {
    @track addModal = false;
    @track contacts = [];
    // dyanamic fields selctor variables
    @track valueFromChild = [];
    @track isAddButtonDisabled = true;
    @track filterFields = [];
    @track filteredContacts = [];
    @track staticFields = [];
    @track isLoading = false;
    @track screenWidth = 0;
    @track modalValue = false;
    @track parentField = null;

    @track isCustomerroricEnabled = false;
    @track customerroricExpression = '';
    @track customerroricError = null;

    /**
    * Method Name: connectedCallback
    * @description: set the get static fields, set contact record wrapper, set Inquiry records.
    * Date: 25/06/2024
    * Created By: Vyom Soni
    */
    connectedCallback() {
        loadStyle(this, MulishFontCss);
        this.screenWidth = window?.globalThis?.innerWidth;
        window?.globalThis?.addEventListener('resize', this.handleResize);
        this.initializeStaticFields();
    }

    /**
    * Method Name: initializeStaticFields
    * @description: get the static fields from custom metadata.
    * Date: 25/06/2024
    * Created By: Vyom Soni
    */
    initializeStaticFields() {
        this.isLoading = true;
        getStaticFields()
            .then(result => {
                this.staticFields = JSON.parse(result);
                this.filterFields = this.filterFields.concat(this.staticFields);
                this.setPicklistValue();
                this.updateFilterIndices();
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error loading static fields from metadata', error);
                this.isLoading = false;
            });
    }

    /**
    * Method Name: setPicklistValue
    * @description: get the picklist values one by one for static fields.
    * Date: 25/06/2024
    * Created By: Vyom Soni
    */
    setPicklistValue() {
        try {
            this.staticFields.forEach(field => {
                if (field.picklist) {
                    this.loadPicklistValues(field);
                }
            });
        } catch (error) {
            console.error('Error setPicklistValue->' + error);
        }
    }

    /**
    * Method Name: loadPicklistValues
    * @description: add the picklist values in the static fields.
    * Date: 25/06/2024
    * Created By: Vyom Soni
    */
    loadPicklistValues(field) {
        getPicklistValues({ apiName: field.apiName, objectName: field.objectApiName })
            .then(result => {
                this.staticFields = this.staticFields.map(f => {
                    if (f.apiName === field.apiName) {
                        return {
                            ...f,
                            picklistValue: result,
                            unchangePicklistValue: result
                        };
                    }
                    return f;
                });
                this.filterFields = [...this.staticFields];
                this.updateFilterIndices();
            })
            .catch(error => {
                console.error('Error loading picklist values', error);
            });
    }

    /**
  * Method Name: handleValueSelected
  * @description: this method is set the field from the child field-add cmp .
  * Date: 25/06/2024
  * Created By: Vyom Soni
  */
    handleValueSelected(event) {
        try {
            // Get the value from the event detail and store it in a property
            this.valueFromChild = event.detail;
            console.error('this.valueFromChild' + JSON.stringify(this.valueFromChild));
            this.valueFromChild = this.valueFromChild.map(field => {
                return {
                    label: field.label,
                    type: field.type, // Map field types
                    apiName: field.value,
                    prevFieldApiName: field.prevFieldApiName,
                    objectApiName: field.objectApiName,
                    operatorName: field.operation,
                    picklistValue: field.picklistValues || [], // Set operatorName based on type
                    unchangePicklistValue: field.picklistValues || [], // Set operatorName based on type
                    prevApiName: field.prevApiName,
                    minValue: null,
                    maxValue: null,
                    minDate: null,
                    maxDate: null,
                    isNot: field.isNot || false,
                    searchTerm: '',
                    isFocused: false,
                    picklist: field.type === 'PICKLIST',
                    string: field.type === 'STRING' || field.type === 'TEXTAREA' || field.type === 'URL' || field.type === 'ID' || field.type === 'EMAIL' || field.type === 'PHONE',
                    fieldChecked: false,
                    currency: field.type === 'CURRENCY',
                    double: field.type === 'DOUBLE',
                    date: field.type === 'DATE',
                    datetime: field.type === 'DATETIME',
                    boolean: field.type === 'BOOLEAN',
                    isDateRange: field.operation === 'daterange',
                    isDateMax: field.operation === 'datemaximum',
                    isDateMin: field.operation === 'dateminimum',
                    isRange: field.operation === 'range',
                    isMax: field.operation === 'minimum',
                    isMin: field.operation === 'maximum',
                    message: ''
                };
            });
            this.valueFromChild.forEach(newField => {
                const isFieldPresent = this.filterFields.some(field =>
                    (field.apiName === newField.apiName || field.value === newField.apiName) &&
                    field.label === newField.label &&
                    field.objectApiName === newField.objectApiName &&
                    field.type === newField.type &&
                    field.prevApiName === newField.prevApiName &&
                    field.isNot === newField.isNot
                );
                if (!isFieldPresent) {
                    this.filterFields = [...this.filterFields, newField];
                } else {
                    const evt = new ShowToastEvent({
                        title: 'Field is not added',
                        message: `${newField.label} is already added in filter fields`,
                        variant: 'error',
                    });
                    this.dispatchEvent(evt);
                }
            });
            this.updateFilterIndices();
        } catch (e) {
            console.error('Error handleValueSelected ->' + e);
        }
    }

    /**
    * Method Name : handleResize
    * @description : call when component is resize.
    * * Date: 3/06/2024
    * Created By:Vyom Soni
    */
    handleResize = () => {
        this.screenWidth = window?.globalThis?.innerWidth;
    }

    /**
    * Method Name: applyFilters
    * @description: apply the filters on the contacts.
    * Date: 14/06/2024
    * Created By: Vyom Soni
    */
    applyFilters() {
        try {
            let contactFilters = [];
            let inquiryFilters = [];
            let filterData = {
                contactFilters: [],
                inquiryFilters: [],
                customerroric: this.isCustomerroricEnabled && this.customerroricExpression ? this.customerroricExpression : ''
            };

            // Process each filter in filterFields to generate conditions
            this.filterFields.forEach((field, index) => {
                const hasSelectedOptions = field.selectedOptions && field.selectedOptions.length > 0;
                const hasMinValue = field.minValue != null && field.minValue !== ''; // Allow zero values
                const hasMaxValue = field.maxValue != null && field.maxValue !== ''; // Allow zero values
                const hasMinDate = field.minDate != null;
                const hasMaxDate = field.maxDate != null;
                const hasFieldChecked = field.fieldChecked != null;

                if (hasSelectedOptions || hasMinValue || hasMaxValue || hasMinDate || hasMaxDate || hasFieldChecked) {
                    let fieldPath;
                    if (field.objectApiName === 'MVEX__Inquiry__c') {
                        fieldPath = field.apiName;
                    } else if (field.objectApiName !== 'Contact') {
                        if (field.prevApiName?.endsWith('Id')) {
                            fieldPath = `${field.prevApiName.replace('Id', '')}.${field.apiName}`;
                        } else {
                            fieldPath = `${field.prevApiName?.replace('__c', '__r')}.${field.apiName}`;
                        }
                    } else {
                        fieldPath = field.apiName;
                    }

                    let condition = {
                        fieldPath: fieldPath,
                        operator: '',
                        values: [],
                        isNot: field.isNot,
                        type: field.type,
                        index: index + 1
                    };

                    if (hasSelectedOptions && (field.picklist || field.string)) {
                        condition.operator = field.operatorName;
                        condition.values = field.selectedOptions.map(opt => opt.value);
                    }

                    if (field.boolean && hasFieldChecked) {
                        condition.operator = 'equals';
                        condition.values = [String(field.fieldChecked)];
                    }

                    if ((field.currency || field.double) && (hasMinValue || hasMaxValue)) {
                        condition.operator = 'range';
                        if (hasMinValue) condition.values.push(String(field.minValue));
                        if (hasMaxValue) condition.values.push(String(field.maxValue));
                    }

                    if ((field.date || field.datetime) && (hasMinDate || hasMaxDate)) {
                        condition.operator = 'daterange';
                        if (hasMinDate) condition.values.push(field.minDate);
                        if (hasMaxDate) condition.values.push(field.maxDate);
                    }

                    if (condition.operator) {
                        if (field.objectApiName === 'MVEX__Inquiry__c') {
                            inquiryFilters.push(condition);
                        } else {
                            contactFilters.push(condition);
                        }
                    }
                }
            });

            filterData.contactFilters = contactFilters;
            filterData.inquiryFilters = inquiryFilters;

            this.isLoading = true;
            getFilteredContacts({ filterData: JSON.stringify(filterData) })
                .then(result => {
                    // Process records in JavaScript
                    const { contacts, inquiries, contactFilters, inquiryFilters, customerroric } = result;
                    let filterIndexToContactIds = {};

                    // Evaluate Contact filters
                    contactFilters.forEach(filter => {
                        let matchingContactIds = new Set();
                        contacts.forEach(contact => {
                            if (this.evaluateCondition(contact, filter)) {
                                matchingContactIds.add(contact.Id);
                            }
                        });
                        filterIndexToContactIds[filter.index] = matchingContactIds;
                    });

                    // Evaluate Inquiry filters
                    inquiryFilters.forEach(filter => {
                        let matchingContactIds = new Set();
                        inquiries.forEach(inquiry => {
                            if (this.evaluateCondition(inquiry, filter)) {
                                matchingContactIds.add(inquiry.MVEX__Contact__c);
                            }
                        });
                        filterIndexToContactIds[filter.index] = matchingContactIds;
                    });

                    // Apply custom erroric or default AND erroric
                    let finalContactIds = new Set();
                    if (this.isCustomerroricEnabled && customerroric) {
                        finalContactIds = this.evaluateCustomerroric(customerroric, filterIndexToContactIds);
                    } else {
                        let firstSet = true;
                        Object.values(filterIndexToContactIds).forEach(contactIds => {
                            if (contactIds.size > 0) {
                                if (firstSet) {
                                    finalContactIds = new Set(contactIds);
                                    firstSet = false;
                                } else {
                                    finalContactIds = new Set([...finalContactIds].filter(id => contactIds.has(id)));
                                }
                            }
                        });
                        // If no filters, include all contact IDs
                        if (finalContactIds.size === 0 && Object.keys(filterIndexToContactIds).length === 0) {
                            finalContactIds = new Set(contacts.map(c => c.Id));
                        }
                    }

                    // Map final Contact IDs to contact records
                    this.filteredContacts = contacts.filter(c => finalContactIds.has(c.Id));
                    this.setFilteredContacts();
                    this.isLoading = false;
                })
                .catch(error => {
                    this.isLoading = false;
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error Applying Filters',
                            message: error.body?.message || 'An error occurred while applying filters.',
                            variant: 'error',
                        })
                    );
                });
        } catch (error) {
            this.isLoading = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error Applying Filters',
                    message: 'An error occurred while applying filters.',
                    variant: 'error',
                })
            );
        }
    }

    // Helper method to evaluate a single condition against a record
    evaluateCondition(record, filter) {
        let fieldValue = filter.fieldPath.includes('.')
            ? filter.fieldPath.split('.').reduce((obj, key) => obj ? obj[key] : undefined, record)
            : record[filter.fieldPath];

        if (fieldValue === undefined || fieldValue === null) return false;

        switch (filter.operator) {
            case 'equals':
                return filter.isNot
                    ? !filter.values.includes(String(fieldValue))
                    : filter.values.includes(String(fieldValue));
            case 'contains':
                return filter.isNot
                    ? !filter.values.some(val => String(fieldValue).toLowerCase().includes(val.toLowerCase()))
                    : filter.values.some(val => String(fieldValue).toLowerCase().includes(val.toLowerCase()));
            case 'startswith':
                return filter.isNot
                    ? !filter.values.some(val => String(fieldValue).toLowerCase().startsWith(val.toLowerCase()))
                    : filter.values.some(val => String(fieldValue).toLowerCase().startsWith(val.toLowerCase()));
            case 'range':
                let numValue = Number(fieldValue);
                let minValue = filter.values[0] != null ? Number(filter.values[0]) : null;
                let maxValue = filter.values[1] != null ? Number(filter.values[1]) : null;
                return (minValue == null || numValue >= minValue) && (maxValue == null || numValue <= maxValue);
            case 'daterange':
                let dateValue = new Date(fieldValue);
                let minDate = filter.values[0] ? new Date(filter.values[0]) : null;
                let maxDate = filter.values[1] ? new Date(filter.values[1]) : null;
                return (minDate == null || dateValue >= minDate) && (maxDate == null || dateValue <= maxDate);
            default:
                return false;
        }
    }

    // Helper method to evaluate custom erroric
    evaluateCustomerroric(erroric, filterIndexToContactIds) {
        try {
            if (!erroric || Object.keys(filterIndexToContactIds).length === 0) {
                return new Set();
            }

            // Tokenize erroric
            let tokens = this.tokenizeerroric(erroric);
            if (!tokens.length) {
                return new Set();
            }

            // Convert to Reverse Polish Notation
            let rpn = this.toReversePolishNotation(tokens);
            if (!rpn.length) {
                return new Set();
            }

            // Evaluate RPN
            let stack = [];
            for (let token of rpn) {
                if (/^\d+$/.test(token)) {
                    let index = parseInt(token);
                    let contactIds = filterIndexToContactIds[index] || new Set();
                    stack.push(contactIds);
                } else if (['AND', 'OR'].includes(token.toUpperCase())) {
                    if (stack.length < 2) {
                        return new Set();
                    }
                    let operand2 = stack.pop();
                    let operand1 = stack.pop();
                    let result = new Set();
                    if (token.toUpperCase() === 'AND') {
                        result = new Set([...operand1].filter(id => operand2.has(id)));
                    } else if (token.toUpperCase() === 'OR') {
                        result = new Set([...operand1, ...operand2]);
                    }
                    stack.push(result);
                }
            }

            if (stack.length !== 1) {
                return new Set();
            }
            return stack[0];
        } catch (error) {
            console.error('evaluateCustomerroric: Error evaluating custom erroric:', error.stack);
            return new Set();
        }
    }

    // Helper method to tokenize erroric string
    tokenizeerroric(erroric) {
        try {
            if (!erroric || typeof erroric !== 'string') {
                return [];
            }

            let tokens = [];
            let current = '';
            let inNumber = false;
            // Normalize spaces and handle case sensitivity
            erroric = erroric.replace(/\s+/g, ' ').trim().toUpperCase();

            for (let i = 0; i < erroric.length; i++) {
                let c = erroric[i];
                if (/\d/.test(c)) {
                    current += c;
                    inNumber = true;
                } else if (c === '(' || c === ')') {
                    if (current) {
                        tokens.push(current.trim());
                        current = '';
                        inNumber = false;
                    }
                    tokens.push(c);
                } else if (c === ' ') {
                    if (current && !inNumber) {
                        tokens.push(current.trim());
                        current = '';
                    }
                } else {
                    if (inNumber) {
                        tokens.push(current.trim());
                        current = '';
                        inNumber = false;
                    }
                    current += c;
                }
            }
            if (current) {
                tokens.push(current.trim());
            }
            return tokens.filter(token => token !== '');
        } catch (error) {
            console.error('tokenizeerroric: Error:', error.stack);
            return [];
        }
    }

    // Helper method to convert tokens to Reverse Polish Notation
    toReversePolishNotation(tokens) {
        try {
            if (!tokens || !tokens.length) {
                return [];
            }

            let output = [];
            let operatorStack = [];
            let precedence = { 'AND': 2, 'OR': 1 };

            for (let token of tokens) {
                if (/^\d+$/.test(token)) {
                    output.push(token);
                } else if (token === 'AND' || token === 'OR') {
                    while (operatorStack.length && operatorStack[operatorStack.length - 1] !== '(' &&
                        precedence[operatorStack[operatorStack.length - 1]] >= precedence[token]) {
                        output.push(operatorStack.pop());
                    }
                    operatorStack.push(token);
                } else if (token === '(') {
                    operatorStack.push(token);
                } else if (token === ')') {
                    while (operatorStack.length && operatorStack[operatorStack.length - 1] !== '(') {
                        output.push(operatorStack.pop());
                    }
                    if (operatorStack.length && operatorStack[operatorStack.length - 1] === '(') {
                        operatorStack.pop();
                    } else {
                        console.error('toReversePolishNotation: Unbalanced parentheses');
                        return [];
                    }
                }
            }

            while (operatorStack.length) {
                let op = operatorStack.pop();
                if (op !== '(' && op !== ')') {
                    output.push(op);
                }
            }

            return output;
        } catch (error) {
            console.error('toReversePolishNotation: Error:', error.stack);
            return [];
        }
    }

    /**
    * Method Name: setFilteredContacts
    * @description: set Contacts in the Parent contact manager component.
    * Date: 25/06/2024
    * Created By: Vyom Soni
    */
    setFilteredContacts() {
        try {
            const filtercontacts = this.filteredContacts;
            const customEvent = new CustomEvent('valueselected', {
                detail: { filtercontacts }
            });
            this.dispatchEvent(customEvent);
        } catch (e) {
            console.error('Error setFilter ->' + e);
        }
    }

    setFilteredContactsReset() {
        const filtercontacts = true;
        const customEvent = new CustomEvent('valuereset', {
            detail: { filtercontacts }
        });
        this.dispatchEvent(customEvent);
    }

    /**
    * Method Name: handleSearchChange1
    * @description: Handle the search option feature in picklist fields.
    * Date: 25/06/2024
    * Created By: Vyom Soni
    */
    handleSearchChange1(event) {
        try {
            this.isCustomerroricEnabled = false;
            const index = event.currentTarget.dataset.id;
            this.filterFields[index].searchTerm = event.target.value;
            if (this.filterFields[index].searchTerm.length > 50) {
                this.filterFields[index].message = 'The character length should not greater then 50 characters.';
            } else {
                this.filterFields[index].message = null; // Clear the message if the input length is valid
                this.filterFields[index].picklistValue = this.filterFields[index].unchangePicklistValue.filter(option =>
                    option.label.toLowerCase().includes(this.filterFields[index].searchTerm.toLowerCase().trim())
                );
                if (event.key === 'Enter') { // Check if Enter key was pressed
                    let fields = this.filterFields; // Assuming this is where 'fields' should be declared
                    const value = this.filterFields[index].picklistValue[0].value;
                    const field = fields[index]; // Access 'fields' instead of 'this.filterFields'
                    if (field != null) {
                        if (field.selectedOptions == null) {
                            field.selectedOptions = [];
                        }

                        // Check if the value already exists in selectedOptions
                        const exists = field.selectedOptions.some(option => option.value === value);
                        if (!exists) {
                            this.filterFields[index].searchTerm = '';
                            field.selectedOptions = [...field.selectedOptions, { "label": value, "value": value }];
                            this.applyFilters();

                            const newPicklistValue = field.unchangePicklistValue.map(option => {
                                if (option.value === value) {
                                    return { ...option, showRightIcon: true };
                                }
                                return option;
                            });

                            field.picklistValue = newPicklistValue;
                            field.unchangePicklistValue = newPicklistValue;
                            fields[index] = field;
                            this.filterFields = fields;
                            const inputs = this.template.querySelectorAll('.picklist-input');
                            // Loop through each input and call the blur method
                            inputs.forEach(input => input.blur());
                            this.handleBlur1(event);
                        } else {
                            console.error('Value already exists in selectedOptions');
                        }
                    }
                }
            }
        } catch (e) {
            console.error('Error handleSearchChange1 ->' + e);
        }
    }

    /**
    * Method Name: handleFocus1
    * @description: Handle the Focus event in picklist fiedls.
    * Date: 25/06/2024
    * Created By: Vyom Soni
    */
    handleFocus1(event) {
        try {
            const index = event.currentTarget.dataset.id;
            this.filterFields[index].isFocused = true;
            this.filterFields[index].picklistValue = this.filterFields[index].unchangePicklistValue;
        } catch (error) {
            console.error('Error handleFocus1->' + error);
        }
    }

    /**
   * Method Name: handleBlur1
   * @description: Handle the blur event in picklist fiedls.
   * Date: 25/06/2024
   * Created By: Vyom Soni
   */
    handleBlur1(event) {
        try {
            // Delay the blur action to allow click event to be registered
            const index = event.currentTarget.dataset.id;
            this.filterFields[index].isFocused = false;
        } catch (error) {
            console.error('Error handleBlur1->' + error);
        }
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

    /**
    * Method Name: selectOption1
    * @description: Handle the slection of option in picklist fiedls.
    * Date: 25/06/2024
    * Created By: Vyom Soni
    */
    selectOption1(event) {
        try {
            this.isCustomerroricEnabled = false;
            const value = event.currentTarget.dataset.id;
            const index = event.currentTarget.dataset.index;

            let fields = this.filterFields;
            const inputs = this.template.querySelectorAll('.picklist-input');
            inputs.forEach(input => input.blur());

            const field = fields[index];
            if (field != null) {
                if (field.selectedOptions == null) {
                    field.selectedOptions = [];
                }

                const exists = field.selectedOptions.some(option => option.value === value);
                if (!exists) {
                    this.filterFields[index].searchTerm = '';
                    field.selectedOptions = [...field.selectedOptions, { "label": value, "value": value }];
                    this.applyFilters();

                    const newPicklistValue = field.unchangePicklistValue.map(option => {
                        if (option.value === value) {
                            return { ...option, showRightIcon: true };
                        }
                        return option;
                    });

                    field.picklistValue = newPicklistValue;
                    field.unchangePicklistValue = newPicklistValue;
                    fields[index] = field;
                    this.filterFields = fields;
                    this.filterFields[index].isFocused = false;

                } else {
                    this.filterFields[index].isFocused = false;
                }
            }
        } catch (e) {
            console.error('Error selectOption1 ->' + e);
        }
    }

    /**
    * Method Name: removeOptionMethod
    * @description: Handle the remove of pill from under if picklist fiedls.
    * Date: 25/06/2024
    * Created By: Vyom Soni
    */
    removeOptionMethod(event) {
        this.isCustomerroricEnabled = false;
        this.removeOption1(event);
        this.applyFilters();
    }

    /**
   * Method Name: removeOption1
   * @description: Handle the remove of pill from under if picklist fiedls.
   * Date: 25/06/2024
   * Created By: Vyom Soni
   */
    removeOption1(event) {
        try {
            const optionToRemove = event.currentTarget.dataset.id;
            const index = event.currentTarget.dataset.index;
            this.filterFields[index].searchTerm = '';

            if (index > -1) {
                let fields = [...this.filterFields];
                let field = { ...fields[index] };

                // Update the selectedOptions array
                field.selectedOptions = field.selectedOptions.filter(option => option.value !== optionToRemove);
                if (field.selectedOptions.length === 0) {
                    field.selectedOptions = null;
                }

                // Update the picklistValues array to set showRightIcon to false
                const newPicklistValue = field.picklistValue.map(option => {
                    if (option.value === optionToRemove) {
                        return { ...option, showRightIcon: false };
                    }
                    return option;
                });

                field.picklistValue = newPicklistValue;
                field.unchangePicklistValue = newPicklistValue;
                fields[index] = field;
                this.filterFields = fields;
                this.updateFilterIndices();
            }
        } catch (error) {
            console.error('Error removeOption1->' + error);
        }
    }

    /**
    * Method Name: removeOptionMethodString
    * @description: call the removeOptionString and applyFilter method.
    * Date: 25/06/2024
    * Created By: Vyom Soni
    */
    removeOptionMethodString(event) {
        this.removeOptionString(event);
        this.applyFilters();
    }

    /**
   * Method Name: removeOptionString
   * @description: Handle remove the pill from the string fields.
   * Date: 25/06/2024
   * Created By: Vyom Soni
   */
    removeOptionString(event) {
        try {
            const optionToRemove = event.currentTarget.dataset.id;
            const index = event.currentTarget.dataset.index;
            if (index > -1) {
                this.filterFields[index].selectedOptions = this.filterFields[index].selectedOptions.filter(option => option.value !== optionToRemove);
                if (this.filterFields[index].selectedOptions.length === 0) {
                    this.filterFields[index].selectedOptions = null;
                }
            }

            this.updateFilterIndices();
        } catch (error) {
            console.error('Error removeOptionString->' + error);
        }
    }

    /**
   * Method Name: handleSearchChangeString
   * @description: Handle the string change in string fiedls.
   * Date: 25/06/2024
   * Created By: Vyom Soni
   */
    handleSearchChangeString(event) {
        try {
            const index = event.currentTarget.dataset.id;
            this.filterFields[index].searchTerm = event.target.value;
            if (this.filterFields[index].searchTerm.length > 50) {
                this.filterFields[index].message = 'The character length should not greater then 50 characters.';
            } else {
                this.filterFields[index].message = null; // Clear the message if the input length is valid
                if (event.key === 'Enter') { // Check if Enter key was pressed
                    this.addTheString(event);
                }
            }
        } catch (error) {
            console.error('Error handleSearchChangeString->' + error);
        }
    }

    /**
    * Method Name: addTheString
    * @description: Handle the string add in the multi selection in string fiedls.
    * Date: 25/06/2024
    * Created By: Vyom Soni
    */
    addTheString(event) {
        try {
            this.isCustomerroricEnabled = false;
            var index = event.currentTarget.dataset.id;;
            var value = this.filterFields[index].searchTerm.trim();;

            if (value !== '') {
                const field = this.filterFields[index];

                if (field.selectedOptions == null) {
                    field.selectedOptions = [];
                }

                // Check if the value already exists in selectedOptions
                const isValueAlreadySelected = field.selectedOptions.some(option => option.value === value);

                if (!isValueAlreadySelected) {
                    field.selectedOptions = [...field.selectedOptions, { "label": value, "value": value }];
                    this.filterFields[index].searchTerm = '';
                }
            }

            this.applyFilters();
        } catch (e) {
            console.error('Error addTheString ->' + e);
        }
    }

    /**
     * Method Name: handleMinValueChange
     * @description: Handle the min value change in the number Input field.
     * Date: 25/06/2024
     * Created By: Vyom Soni
     */
    handleMinValueChange(event) {
        try {
            this.isCustomerroricEnabled = false;
            const index = event.currentTarget.dataset.index;
            let value = parseInt(event.target.value, 10);

            if (isNaN(value)) {
                value = null;
            }

            if (this.debounceTimeout) {
                clearTimeout(this.debounceTimeout);
            }

            this.debounceTimeout = setTimeout(() => {
                this.filterFields[index].minValue = value;

                if (
                    this.filterFields[index].isMin === true ||
                    value <= this.filterFields[index].maxValue ||
                    value === 0
                ) {
                    this.applyFilters();
                    this.filterFields[index].message = null;
                } else {
                    this.filterFields[index].message = 'Min Value cannot be Greater than the Max Value';
                }
            }, 300);
        } catch (error) {
            console.error('Error handleMinValueChange ->', error);
        }
    }

    /**
     * Method Name: handleMaxValueChange
     * @description: Handle change in the max input field.
     * Date: 9/06/2024
     * Created By: Vyom Soni
     */
    handleMaxValueChange(event) {
        try {
            this.isCustomerroricEnabled = false;
            const index = event.currentTarget.dataset.index;
            let value = parseInt(event.target.value, 10);

            if (isNaN(value)) {
                value = null;
            }

            if (this.debounceTimeout) {
                clearTimeout(this.debounceTimeout);
            }

            this.debounceTimeout = setTimeout(() => {
                this.filterFields[index].maxValue = value;

                if (this.filterFields[index].isMax === true || value === 0 || value >= this.filterFields[index].minValue) {
                    this.applyFilters();
                    this.filterFields[index].message = '';
                } else {
                    this.filterFields[index].message = 'Min Value cannot be Greater than the Max Value';
                }
            }, 300);
        } catch (error) {
            console.error('Error handleMaxValueChange ->', error);
        }
    }

    /**
     * Method Name: incrementMinValue
     * @description: Increment the min input value
     * Date: 25/06/2024
     * Created By: Vyom Soni
     */
    incrementMinValue(event) {
        try {
            this.isCustomerroricEnabled = false;
            const index = event.currentTarget.dataset.index;
            let currentValue = parseInt(this.filterFields[index].minValue, 10);

            if (isNaN(currentValue)) {
                currentValue = 0;
            }

            if (this.debounceTimeout) {
                clearTimeout(this.debounceTimeout);
            }

            this.debounceTimeout = setTimeout(() => {
                this.filterFields[index].minValue = currentValue + 1;

                if (this.filterFields[index].isMin === true || currentValue + 1 <= this.filterFields[index].maxValue) {
                    this.applyFilters();
                    this.filterFields[index].message = null;
                } else {
                    this.filterFields[index].message = 'Min Value cannot be Greater than the Max Value';
                }
            }, 300);
        } catch (error) {
            console.error('Error incrementMinValue ->', error);
        }
    }

    /**
     * Method Name: decrementMinValue
     * @description: Decrement the min input value
     * Date: 25/06/2024
     * Created By: Vyom Soni
     */
    decrementMinValue(event) {
        try {
            this.isCustomerroricEnabled = false;
            const index = event.currentTarget.dataset.index;
            let currentValue = parseInt(this.filterFields[index].minValue, 10);

            if (isNaN(currentValue) || currentValue <= 0) {
                currentValue = 0;
            } else {
                currentValue--;
            }

            if (this.debounceTimeout) {
                clearTimeout(this.debounceTimeout);
            }

            this.debounceTimeout = setTimeout(() => {
                this.filterFields[index].minValue = currentValue;

                if (this.filterFields[index].isMin === true || currentValue <= this.filterFields[index].maxValue) {
                    this.applyFilters();
                    this.filterFields[index].message = null;
                } else {
                    this.filterFields[index].message = 'Min Value cannot be Greater than the Max Value';
                }
            }, 300);
        } catch (error) {
            console.error('Error decrementMinValue ->', error);
        }
    }

    /**
     * Method Name: incrementMaxValue
     * @description: Increment the max input value
     * Date: 25/06/2024
     * Created By: Vyom Soni
     */
    incrementMaxValue(event) {
        try {
            this.isCustomerroricEnabled = false;
            const index = event.currentTarget.dataset.index;
            let currentValue = parseInt(this.filterFields[index].maxValue, 10);

            if (isNaN(currentValue)) {
                currentValue = 0;
            }

            if (this.debounceTimeout) {
                clearTimeout(this.debounceTimeout);
            }

            this.debounceTimeout = setTimeout(() => {
                this.filterFields[index].maxValue = currentValue + 1;

                if (this.filterFields[index].isMax === true || currentValue + 1 >= this.filterFields[index].minValue) {
                    this.applyFilters();
                    this.filterFields[index].message = null;
                } else {
                    this.filterFields[index].message = 'Min Value cannot be Greater than the Max Value';
                }
            }, 300);
        } catch (error) {
            console.error('Error incrementMaxValue ->', error);
        }
    }


    /**
     * Method Name: decrementMaxValue
     * @description: Decrement the max input value
     * Date: 25/06/2024
     * Created By: Vyom Soni
     */
    decrementMaxValue(event) {
        try {
            this.isCustomerroricEnabled = false;
            const index = event.currentTarget.dataset.index;
            let currentValue = parseInt(this.filterFields[index].maxValue, 10);

            if (isNaN(currentValue) || currentValue <= this.filterFields[index].minValue) {
                currentValue = this.filterFields[index].minValue;
                this.filterFields[index].message = 'Min Value cannot be Greater than the Max Value';
            } else {
                currentValue--;
            }

            if (this.debounceTimeout) {
                clearTimeout(this.debounceTimeout);
            }

            this.debounceTimeout = setTimeout(() => {
                this.filterFields[index].maxValue = currentValue;

                if (this.filterFields[index].isMax === true || currentValue >= this.filterFields[index].minValue) {
                    this.applyFilters();
                    this.filterFields[index].message = null;
                }
            }, 300);
        } catch (error) {
            console.error('Error decrementMaxValue ->', error);
        }
    }

    /**
    * Method Name: checkboxFieldChange
    * @description:  handle th checkbox field change
    * Date: 25/06/2024
    * Created By: Vyom Soni
    */
    checkboxFieldChange(event) {
        try {
            this.isCustomerroricEnabled = false;
            const index = event.currentTarget.dataset.index;
            this.filterFields[index].fieldChecked = !this.filterFields[index].fieldChecked;
            this.applyFilters();
        } catch (error) {
            console.error('Error checkboxFieldChange->' + error);
        }
    }

    /**
    * Method Name: handleMinDate
    * @description: handle min date field change
    * Date: 25/06/2024
    * Created By: Vyom Soni
    */
    handleMinDate(event) {
        try {
            this.isCustomerroricEnabled = false;
            const index = event.currentTarget.dataset.id;
            const newValue = event.target.value;
            this.filterFields[index].minDate = newValue;
            // Perform validation
            const minDate = new Date(this.filterFields[index].minDate);
            const maxDate = new Date(this.filterFields[index].maxDate);

            if (minDate <= maxDate || this.filterFields[index].isDateMin == true) {
                this.applyFilters();
                this.filterFields[index].message = null;
            } else {
                this.filterFields[index].message = 'Min Value can not be Greater than the Max Value';
            }
        } catch (error) {
            console.error('Error handleMinDate->' + error);
        }
    }

    /**
     * Method Name: handleMaxDate
     * @description: handle max date field change
     * Date: 25/06/2024
     * Created By: Vyom Soni
     */
    handleMaxDate(event) {
        try {
            this.isCustomerroricEnabled = false;
            const index = event.currentTarget.dataset.id;
            const newValue = event.target.value;
            this.filterFields[index].maxDate = newValue;
            // Perform validation
            const minDate = new Date(this.filterFields[index].minDate);
            const maxDate = new Date(this.filterFields[index].maxDate);

            if (minDate <= maxDate || this.filterFields[index].isDateMax == true) {
                this.applyFilters();
                this.filterFields[index].message = null;
            } else {
                this.filterFields[index].message = 'Min Value can not be Greater than the Max Value';
            }
        } catch (error) {
            console.error('Error handleMaxDate->' + error);
        }
    }

    // Clears the search input field
    /**
    * Method Name: clearSearch
    * @description: Removes a field from the filed list.
    * Date: 25/06/2024
    * Created By: Vyom Soni
    */
    clearSearch(event) {
        try {
            this.isCustomerroricEnabled = false;
            const index = event.currentTarget.dataset.id;
            if (index > -1 && index < this.filterFields.length) {
                this.filterFields.splice(index, 1);
            }
            this.applyFilters();
            this.updateFilterIndices();
        } catch (error) {
            console.error('Error clearSearch->' + error);
        }
    }

    //handel reset
    /**
    * Method Name: handleReset
    * @description: Remove the all except static fields.
    * Date: 25/06/2024
    * Created By: Vyom Soni
    */
    handleReset() {
        try {
            this.staticFields.forEach(field => {
                if (field.picklistValue) {
                    field.picklistValue.forEach(picklist => {
                        picklist.showRightIcon = false;
                    });
                }
                if (field.unchangePicklistValue) {
                    field.unchangePicklistValue.forEach(picklist => {
                        picklist.showRightIcon = false;
                    });
                }
            });

            this.filterFields = this.staticFields;
            this.filterFields = this.staticFields.map(field => {
                return {
                    ...field, // Spread the existing field properties
                    selectedOptions: null,
                    picklistValue: field.picklistValue,
                    minValue: null,
                    maxValue: null,
                    minDate: null,
                    maxDate: null,
                    fieldChecked: null,
                    message: null,
                    searchTerm: null
                };
            });
            this.isCustomerroricEnabled = false;
            this.customerroricExpression = '';
            this.customerroricError = null;
            this.setFilteredContactsReset();

            this.updateFilterIndices();
        } catch (error) {
            console.error('Error handleReset->' + error);
        }
    }

    // Modal cmp
    /**
    * Method Name: handleClose
    * @description: Remove the all except static fields.
    * Date: 25/06/2024
    * Created By: Vyom Soni
    */
    handleClose() {
        this.addModal = false;
        if (this.screenWidth <= 900) {
            this.modalValue = false;
            this.handleAddButtonChange();
        }
    }

    /**
    * Method Name: handleSave
    * @description: call the handleButtonClick method from child component.
    * Date: 25/06/2024
    * Created By: Vyom Soni
    */
    handleSave() {
        try {
            this.addModal = false;
            if (this.screenWidth <= 900) {
                this.modalValue = false;
                this.handleAddButtonChange();
            }
            const childComponent = this.template.querySelector('c-marketing-list-filter-add-cmp');

            if (childComponent) {
                // Call the method on the child component
                childComponent.handleButtonClick();
            }
        } catch (error) {
            console.error('Error handleSave->' + error);
        }
    }

    /**
    * Method Name: handleFieldChange
    * @description: fetch the custom event data and set pop-up add button disable.
    * Date: 25/06/2024
    * Created By: Vyom Soni
    */
    handleFieldChange(event) {
        try {
            const field = event.detail;
            this.isAddButtonDisabled = (field.length === 0 && field.operation == null);
        } catch (error) {
            console.error('Error handleFieldChange ->' + error);
        }
    }

    /**
    * Method Name: openModal
    * @description: open the pop-up modal.
    * Date: 25/06/2024
    * Created By: Vyom Soni
    */
    openModal() {
        this.addModal = true;
        if (this.screenWidth <= 900) {
            this.modalValue = true;
            this.handleAddButtonChange();
        }
    }

    handleAddButtonChange() {
        const customEvent = new CustomEvent('modalvaluechange', {
            detail: this.modalValue
        });
        this.dispatchEvent(customEvent);
    }

    disconnectedCallback() {
        window?.globalThis?.removeEventListener('resize', this.handleResize);
    }

    // Add this method to update displayIndex for filterFields
    updateFilterIndices() {
        this.filterFields = this.filterFields.map((field, index) => ({
            ...field,
            displayIndex: index + 1
        }));
    }

    handleApplyCustomerroric() {
        try {
            this.validateCustomerroric();
            if (!this.customerroricError) {
                this.applyFilters();
            }
        } catch (error) {
            errorDebugger('ListingManagerFilterCmp', 'handleApplyCustomerroric', error, 'warn', 'Error in handleApplyCustomerroric');
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error Applying Custom erroric',
                    message: 'An error occurred while applying custom erroric. Please check your expression and try again.',
                    variant: 'error',
                })
            );
        }
    }

    /**
     * Method Name: handleCustomerroricToggle
     * @description: Handle the custom erroric checkbox toggle and set default erroric string
     * Date: 14/06/2024
     * Created By: Vyom Soni
     */
    handleCustomerroricToggle(event) {
        try {
            this.isCustomerroricEnabled = event.target.checked;
            if (this.isCustomerroricEnabled) {
                // Generate default erroric string based on filters with selected values
                const requiredIndices = [];
                this.filterFields.forEach((field, index) => {
                    const hasSelectedValues =
                        (field.selectedOptions && field.selectedOptions.length > 0) ||
                        (field.minValue != null && field.minValue !== '' && !isNaN(parseFloat(field.minValue))) ||
                        (field.maxValue != null && field.maxValue !== '' && !isNaN(parseFloat(field.maxValue))) ||
                        (field.minDate != null && field.minDate !== '') ||
                        (field.maxDate != null && field.maxDate !== '') ||
                        (field.fieldChecked === true);
                    if (hasSelectedValues) {
                        requiredIndices.push(index + 1); // 1-based index
                    }
                });

                // Create default erroric string, e.g., "2 AND 3 AND 4"
                this.customerroricExpression = requiredIndices.length > 0
                    ? requiredIndices.join(' AND ')
                    : '';
                this.customerroricError = null;
            } else {
                // Clear expression and error when custom erroric is disabled
                this.customerroricExpression = '';
                this.customerroricError = null;
                this.applyFilters();
            }
        } catch (error) {
            console.error('Error in handleCustomerroricToggle:', error.stack);
            errorDebugger('ListingManagerFilterCmp', 'handleCustomerroricToggle', error, 'warn', 'Error in handleCustomerroricToggle');
        }
    }

    handleCustomerroricChange(event) {
        try {
            this.customerroricExpression = event.target.value;
            this.validateCustomerroric();
        } catch (error) {
            errorDebugger('ListingManagerFilterCmp', 'handleCustomerroricChange', error, 'warn', 'Error in handleCustomerroricChange');
        }
    }

    validateCustomerroric() {
        try {
            if (!this.customerroricExpression) {
                this.customerroricError = null;
                return;
            }

            // Normalize the expression to uppercase for validation, preserve original for display
            const normalizedExpression = this.customerroricExpression.replace(/\s+/g, ' ').trim().toUpperCase();

            // Basic validation for allowed characters (numbers, spaces, parentheses, AND, OR)
            const validPattern = /^[\d\s()]+((AND|OR)[\d\s()]+)*$/i;
            if (!validPattern.test(normalizedExpression)) {
                this.customerroricError = 'Invalid characters in custom erroric expression. Use numbers, AND, OR, spaces, and parentheses only.';
                return;
            }

            // Token-based validation for operator placement
            const tokens = normalizedExpression.split(' ').filter(token => token !== '');
            for (let i = 0; i < tokens.length; i++) {
                if (['AND', 'OR'].includes(tokens[i])) {
                    // Operators must be between two valid tokens (number or parenthesis)
                    if (i === 0 || i === tokens.length - 1) {
                        this.customerroricError = `Operator ${tokens[i]} cannot be at the start or end of the expression.`;
                        return;
                    }
                    if (!(/\d+/.test(tokens[i - 1]) || tokens[i - 1] === ')') ||
                        !(/\d+/.test(tokens[i + 1]) || tokens[i + 1] === '(')) {
                        this.customerroricError = `Operator ${tokens[i]} must be between numbers or parenthesized expressions.`;
                        return;
                    }
                }
            }

            // Get indices of filters with selected values
            const requiredIndices = [];
            this.filterFields.forEach((field, index) => {
                const hasSelectedValues =
                    (field.selectedOptions && field.selectedOptions.length > 0) ||
                    (field.minValue != null && field.minValue !== '' && !isNaN(parseFloat(field.minValue))) ||
                    (field.maxValue != null && field.maxValue !== '' && !isNaN(parseFloat(field.maxValue))) ||
                    (field.minDate != null && field.minDate !== '') ||
                    (field.maxDate != null && field.minDate !== '') ||
                    (field.fieldChecked === true);
                if (hasSelectedValues) {
                    requiredIndices.push((index + 1).toString()); // 1-based index
                }
            });

            // Extract unique indices from the custom erroric expression
            const usedIndices = [...new Set(this.customerroricExpression.match(/\d+/g) || [])];

            // If no filters have selected values, expression should be empty
            if (requiredIndices.length === 0 && usedIndices.length > 0) {
                this.customerroricError = 'No filters have selected values, but indices are included in the expression.';
                return;
            }

            // Check if all required indices are included
            const missingIndices = requiredIndices.filter(index => !usedIndices.includes(index));
            if (missingIndices.length > 0) {
                this.customerroricError = `Custom erroric must include all filters with selected values. Missing indices: ${missingIndices.join(', ')}.`;
                return;
            }

            // Check if any used indices correspond to filters without selected values
            const invalidIndices = usedIndices.filter(index => !requiredIndices.includes(index));
            if (invalidIndices.length > 0) {
                this.customerroricError = `Custom erroric includes indices without selected values: ${invalidIndices.join(', ')}.`;
                return;
            }

            // Check if used indices are within valid range (1 to filterFields.length)
            const maxIndex = this.filterFields.length;
            for (let index of usedIndices) {
                if (parseInt(index) > maxIndex || parseInt(index) < 1) {
                    this.customerroricError = `Invalid filter index ${index}. Use indices from 1 to ${maxIndex}.`;
                    return;
                }
            }

            // Basic syntax check for balanced parentheses
            let openParens = 0;
            for (let char of this.customerroricExpression) {
                if (char === '(') openParens++;
                if (char === ')') openParens--;
                if (openParens < 0) {
                    this.customerroricError = 'Unbalanced parentheses in custom erroric expression.';
                    return;
                }
            }
            if (openParens !== 0) {
                this.customerroricError = 'Unbalanced parentheses in custom erroric expression.';
                return;
            }

            this.customerroricError = null;
        } catch (error) {
            errorDebugger('ListingManagerFilterCmp', 'validateCustomerroric', error, 'warn', 'Error in validateCustomerroric');
            this.customerroricError = 'Error validating custom erroric expression.';
        }
    }
}