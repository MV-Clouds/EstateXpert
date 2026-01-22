import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/leadassignmentcss';
import getLeadAssignmentInitData from '@salesforce/apex/LeadAssignmentController.getLeadAssignmentInitData';
import manageRule from '@salesforce/apex/LeadAssignmentController.manageRule';
import { NavigationMixin } from 'lightning/navigation';

export default class LeadAssignmentRule extends NavigationMixin(LightningElement) {
    @track isLoading = false;
    @track showRulePopup = false;
    @track showDeleteConfirmation = false;
    @track userGroups = [];
    @track originalUserGroups = [];
    @track fieldOptions = [];
    @track sortedFieldOptions = [];
    @track userOptions = [];
    @track currentRule = {};
    @track isEditMode = false;
    @track currentEditIndex = null;
    @track currentDeleteIndex = null;
    @track hasUnsavedChanges = false;
    @track visibleIconName = 'utility:chevronright';
    @track logicError = '';

    conditionOptions = [
        { label: 'Equals', value: 'equals', types: ['STRING', 'PICKLIST', 'BOOLEAN', 'DATE', 'DATETIME', 'REFERENCE', 'DOUBLE', 'CURRENCY', 'INTEGER', 'URL', 'PHONE', 'EMAIL'] },
        { label: 'Not Equals To', value: 'notEqualsTo', types: ['STRING', 'PICKLIST', 'BOOLEAN', 'DATE', 'DATETIME', 'REFERENCE', 'DOUBLE', 'CURRENCY', 'INTEGER', 'URL', 'PHONE', 'EMAIL'] },
        { label: 'Starts With', value: 'startsWith', types: ['STRING', 'TEXTAREA', 'URL', 'PHONE', 'EMAIL'] },
        { label: 'Contains', value: 'contains', types: ['STRING', 'TEXTAREA', 'URL', 'PHONE', 'EMAIL'] },
        { label: 'Does Not Contain', value: 'doesNotContain', types: ['STRING', 'TEXTAREA', 'URL', 'PHONE', 'EMAIL'] },
        { label: 'Less Than', value: 'lessThan', types: ['DOUBLE', 'CURRENCY', 'INTEGER', 'DATE', 'DATETIME'] },
        { label: 'Greater Than', value: 'greaterThan', types: ['DOUBLE', 'CURRENCY', 'INTEGER', 'DATE', 'DATETIME'] },
        { label: 'Less or Equal', value: 'lessOrEqual', types: ['DOUBLE', 'CURRENCY', 'INTEGER', 'DATE', 'DATETIME'] },
        { label: 'Greater or Equal', value: 'greaterOrEqual', types: ['DOUBLE', 'CURRENCY', 'INTEGER', 'DATE', 'DATETIME'] },
        { label: 'Includes', value: 'includes', types: ['MULTIPICKLIST'] },
        { label: 'Excludes', value: 'excludes', types: ['MULTIPICKLIST'] }
    ];

    booleanOptions = [
        { label: 'True', value: 'true' },
        { label: 'False', value: 'false' }
    ];

    get isRulesAvailable() {
        return this.userGroups.length > 0;
    }

    get rulePopupTitle() {
        return this.isEditMode ? 'Edit Rule' : 'New Rule';
    }

    connectedCallback() {
        this.isLoading = true;
        loadStyle(this, MulishFontCss);
        getLeadAssignmentInitData({ objectName: 'Contact' })
            .then(data => {
                console.log('Initialization data received:', data);

                this.fieldOptions = data.objectFields
                    .filter(field => !['ID', 'ADDRESS'].includes(field.dataType))
                    .map(field => ({
                        label: field.label,
                        value: field.apiName,
                        dataType: field.dataType,
                        isPicklist: field.dataType === 'PICKLIST',
                        isMultiPicklist: field.dataType === 'MULTIPICKLIST',
                        isBoolean: field.dataType === 'BOOLEAN',
                        isDate: field.dataType === 'DATE',
                        isDateTime: field.dataType === 'DATETIME',
                        isReference: field.dataType === 'REFERENCE',
                        isUrl: field.dataType === 'URL',
                        isPhone: field.dataType === 'PHONE',
                        isEmail: field.dataType === 'EMAIL',
                        referenceObject: field.referenceTo || null,
                        picklistValues: (field.picklistValues || []).map(v => ({ label: v, value: v }))
                    }));
                this.sortedFieldOptions = [...this.fieldOptions].sort((a, b) => a.label.localeCompare(b.label));
                this.userOptions = (data.users || []).map(user => ({
                    label: user.Name,
                    value: user.Id
                }));
                this.processRules(data.rules || []);
            })
            .catch(error => {
                this.showToast('Error', 'Initialization failed: ' + (error.body?.message || error.message), 'error');
                this.isLoading = false;
            });

        window.addEventListener('beforeunload', this.handleBeforeUnload.bind(this));
    }

    disconnectedCallback() {
        window.removeEventListener('beforeunload', this.handleBeforeUnload.bind(this));
    }

    handleBeforeUnload(event) {
        if (this.hasUnsavedChanges) {
            event.preventDefault();
        }
    }

    processRules(rules) {
        const groupedRules = new Map();
        rules.forEach(rule => {
            let conditions = rule.MVEX__Conditions__c ? JSON.parse(rule.MVEX__Conditions__c) : [];
            const userName = this.userOptions.find(u => u.value === rule.Name)?.label || 'Unknown User';
            groupedRules.set(rule.Id, {
                Id: rule.Id,
                selectedUser: rule.Name,
                selectedUserName: userName,
                displayUserName: userName,
                doNotReassignOwner: rule.MVEX__Do_Not_Reassign_Owner__c || false,
                conditions: conditions.map((condition, cIndex) => ({
                    selectedField: condition.Lead_Field,
                    selectedCondition: condition.Condition,
                    selectedValue: condition.Value,
                    order: condition.Order || cIndex
                })),
                userOrder: rule.MVEX__User_Order__c || 0,
                logicalExpression: rule.MVEX__Logical_Expression__c || '',
                displayLogicalExpression: rule.MVEX__Logical_Expression__c || 'All conditions must be true (AND)',
                showConditions: false,
                visibleIconName: 'utility:chevronright'
            });
        });

        this.userGroups = Array.from(groupedRules.values()).map((group, index) => {
            group.fieldOptions = this.fieldOptions;
            group.userOrder = index;
            group.serialNumber = index + 1;
            group.sectionLabel = `User Assignment ${index + 1}`;
            group.conditions = group.conditions.map((condition, cIndex) => {
                const field = this.fieldOptions.find(f => f.value === condition.selectedField) || {};
                const conditionLabel = this.conditionOptions.find(c => c.value === condition.selectedCondition)?.label || condition.selectedCondition;
                let formattedValue = condition.selectedValue;
                let inputType = 'text';
                let placeholder = 'Enter Value';
                let isCombobox = field.isPicklist || field.isMultiPicklist || field.isBoolean || false;
                if (field.isDate) {
                    formattedValue = condition.selectedValue ? new Date(condition.selectedValue).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' }) : '';
                    inputType = 'date';
                    placeholder = 'Select Date';
                } else if (field.isDateTime) {
                    formattedValue = condition.selectedValue ? new Date(condition.selectedValue).toLocaleString('en-US', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : '';
                    inputType = 'datetime-local';
                    placeholder = 'Select DateTime';
                } else if (field.isUrl) {
                    inputType = 'url';
                    placeholder = 'Enter URL';
                } else if (field.isPhone) {
                    inputType = 'tel';
                    placeholder = 'Enter Phone Number';
                } else if (field.isEmail) {
                    inputType = 'email';
                    placeholder = 'Enter Email';
                } else if (field.isReference) {
                    formattedValue = condition.selectedValue || 'No Record Selected';
                } else if (['DOUBLE', 'CURRENCY', 'INTEGER'].includes(field.dataType)) {
                    inputType = 'number';
                    placeholder = 'Enter Number';
                } else if (isCombobox) {
                    placeholder = 'Select Value';
                }
                return {
                    Id: `${group.Id}_${cIndex}`,
                    selectedField: condition.selectedField,
                    selectedCondition: condition.selectedCondition,
                    selectedValue: condition.selectedValue,
                    displayCondition: `${field.label || condition.selectedField} ${conditionLabel} ${formattedValue}`,
                    fieldOptions: this.fieldOptions,
                    conditionOptions: this.filterConditionOptions(field.dataType),
                    valueOptions: field.isPicklist || field.isMultiPicklist ? field.picklistValues : field.isBoolean ? this.booleanOptions : [],
                    isPicklist: field.isPicklist || false,
                    isMultiPicklist: field.isMultiPicklist || false,
                    isBoolean: field.isBoolean || false,
                    isDate: field.isDate || false,
                    isDateTime: field.isDateTime || false,
                    isReference: field.isReference || false,
                    isUrl: field.isUrl || false,
                    isPhone: field.isPhone || false,
                    isEmail: field.isEmail || false,
                    referenceObject: field.referenceObject || null,
                    order: condition.order,
                    inputType: inputType,
                    placeholder: placeholder,
                    isCombobox: isCombobox
                };
            });
            group.conditions.sort((a, b) => a.order - b.order);
            return group;
        });
        this.originalUserGroups = JSON.parse(JSON.stringify(this.userGroups));
        this.isLoading = false;
        this.userGroups = [...this.userGroups];
    }

    getPicklistValues(fieldName) {
        const field = this.fieldOptions.find(f => f.value === fieldName);
        return Promise.resolve(field ? (field.isBoolean ? this.booleanOptions : field.picklistValues) : []);
    }

    filterConditionOptions(dataType) {
        return dataType ? this.conditionOptions.filter(option => option.types.includes(dataType)) : this.conditionOptions;
    }

    backToControlCenter() {
        if (this.hasUnsavedChanges) {
            this.showToast('Warning', 'You have unsaved changes. Please save changes before navigating.', 'warning');
        } else {
            this[NavigationMixin.Navigate]({
                type: 'standard__navItemPage',
                attributes: {
                    apiName: 'MVEX__Control_Center'
                }
            });
        }
    }

    openNewRulePopup() {
        this.currentRule = {
            selectedUser: '',
            selectedUserName: '',
            displayUserName: 'Select User',
            doNotReassignOwner: false,
            conditions: [{
                Id: `temp_${Date.now()}_0`,
                selectedField: '',
                selectedCondition: '',
                selectedValue: '',
                displayCondition: '',
                fieldOptions: this.sortedFieldOptions,
                conditionOptions: this.conditionOptions,
                valueOptions: [],
                isPicklist: false,
                isMultiPicklist: false,
                isBoolean: false,
                isDate: false,
                isDateTime: false,
                isReference: false,
                isUrl: false,
                isPhone: false,
                isEmail: false,
                referenceObject: null,
                order: 1,
                inputType: 'text',
                placeholder: 'Enter Value',
                isCombobox: false
            }],
            logicalExpression: '',
            displayLogicalExpression: 'All conditions must be true (AND)'
        };
        this.isEditMode = false;
        this.showRulePopup = true;
        this.logicError = '';
    }

    openEditRulePopup(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        this.currentEditIndex = index;
        this.currentRule = JSON.parse(JSON.stringify(this.userGroups[index]));
        this.currentRule.conditions = this.currentRule.conditions.map(condition => ({
            ...condition,
            fieldOptions: this.sortedFieldOptions,
            valueOptions: condition.isCombobox ? condition.valueOptions : []
        }));
        this.isEditMode = true;
        this.showRulePopup = true;
        this.validateLogicalExpression(this.currentRule.logicalExpression, this.currentRule.conditions.length); // Validate on open
    }

    openDeleteConfirmation(event) {
        this.currentDeleteIndex = parseInt(event.currentTarget.dataset.index, 10);
        this.showDeleteConfirmation = true;
    }

    closeRulePopup() {
        this.showRulePopup = false;
        this.currentRule = {};
        this.isEditMode = false;
        this.currentEditIndex = null;
        this.logicError = '';
    }

    closeDeleteConfirmation() {
        this.showDeleteConfirmation = false;
        this.currentDeleteIndex = null;
    }

    confirmDelete() {
        const group = this.userGroups[this.currentDeleteIndex];
        this.isLoading = true;
        manageRule({ operation: 'delete', ruleData: { Id: group.Id } })
            .then(() => {
                this.userGroups = this.userGroups.filter((_, index) => index !== this.currentDeleteIndex);
                this.userGroups = this.userGroups.map((g, index) => ({
                    ...g,
                    userOrder: index,
                    serialNumber: index + 1,
                    sectionLabel: `User Assignment ${index + 1}`
                }));
                this.showToast('Success', 'Rule deleted successfully.', 'success');
                this.closeDeleteConfirmation();
                this.hasUnsavedChanges = true;
            })
            .catch(error => {
                this.showToast('Error', 'Failed to delete rule: ' + (error.body?.message || error.message), 'error');
                this.closeDeleteConfirmation();
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleUserChange(event) {
        const userId = event.target.value;
        const userName = this.userOptions.find(u => u.value === userId)?.label || '';
        this.currentRule.selectedUser = userId;
        this.currentRule.selectedUserName = userName;
        this.currentRule.displayUserName = userName || 'Select User';
        this.currentRule = { ...this.currentRule };
    }

    handleDoNotReassignChange(event) {
        this.currentRule.doNotReassignOwner = event.target.checked;
        this.currentRule = { ...this.currentRule };
    }

    handleFieldChange(event) {
        const conditionIndex = parseInt(event.target.dataset.conditionIndex, 10);
        const selectedField = event.target.value;
        const field = this.fieldOptions.find(f => f.value === selectedField) || {};

        this.currentRule.conditions = this.currentRule.conditions.map((condition, cIndex) => {
            if (cIndex === conditionIndex) {
                const conditionLabel = this.conditionOptions.find(c => c.value === condition.selectedCondition)?.label || condition.selectedCondition;
                let formattedValue = condition.selectedValue;
                let inputType = 'text';
                let placeholder = 'Enter Value';
                let isCombobox = field.isPicklist || field.isMultiPicklist || field.isBoolean || false;
                if (field.isDate) {
                    formattedValue = condition.selectedValue ? new Date(condition.selectedValue).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' }) : '';
                    inputType = 'date';
                    placeholder = 'Select Date';
                } else if (field.isDateTime) {
                    formattedValue = condition.selectedValue ? new Date(condition.selectedValue).toLocaleString('en-US', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : '';
                    inputType = 'datetime-local';
                    placeholder = 'Select DateTime';
                } else if (field.isUrl) {
                    inputType = 'url';
                    placeholder = 'Enter URL';
                } else if (field.isPhone) {
                    inputType = 'tel';
                    placeholder = 'Enter Phone Number';
                } else if (field.isEmail) {
                    inputType = 'email';
                    placeholder = 'Enter Email';
                } else if (['DOUBLE', 'CURRENCY', 'INTEGER'].includes(field.dataType)) {
                    inputType = 'number';
                    placeholder = 'Enter Number';
                } else if (field.isReference) {
                    formattedValue = condition.selectedValue || 'No Record Selected';
                } else if (isCombobox) {
                    placeholder = 'Select Value';
                }
                return {
                    ...condition,
                    selectedField,
                    conditionOptions: this.filterConditionOptions(field.dataType),
                    valueOptions: field.isPicklist || field.isMultiPicklist ? field.picklistValues : field.isBoolean ? this.booleanOptions : [],
                    isPicklist: field.isPicklist || false,
                    isMultiPicklist: field.isMultiPicklist || false,
                    isBoolean: field.isBoolean || false,
                    isDate: field.isDate || false,
                    isDateTime: field.isDateTime || false,
                    isReference: field.isReference || false,
                    isUrl: field.isUrl || false,
                    isPhone: field.isPhone || false,
                    isEmail: field.isEmail || false,
                    referenceObject: field.referenceObject || null,
                    selectedCondition: '',
                    selectedValue: '',
                    displayCondition: `${field.label || selectedField} ${conditionLabel} ${formattedValue}`,
                    inputType: inputType,
                    placeholder: placeholder,
                    isCombobox: isCombobox
                };
            }
            return condition;
        });
        this.currentRule = { ...this.currentRule };
        this.validateLogicalExpression(this.currentRule.logicalExpression, this.currentRule.conditions.length); // Re-validate logic
    }

    handleConditionChange(event) {
        const conditionIndex = parseInt(event.target.dataset.conditionIndex, 10);
        const selectedCondition = event.target.value;
        this.currentRule.conditions = this.currentRule.conditions.map((condition, cIndex) => {
            if (cIndex === conditionIndex) {
                const conditionLabel = this.conditionOptions.find(c => c.value === selectedCondition)?.label || selectedCondition;
                const field = this.fieldOptions.find(f => f.value === condition.selectedField) || {};
                let formattedValue = condition.selectedValue;
                if (field.isDate) {
                    formattedValue = condition.selectedValue ? new Date(condition.selectedValue).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' }) : '';
                } else if (field.isDateTime) {
                    formattedValue = condition.selectedValue ? new Date(condition.selectedValue).toLocaleString('en-US', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : '';
                } else if (field.isUrl || field.isPhone || field.isEmail) {
                    formattedValue = condition.selectedValue || '';
                } else if (['DOUBLE', 'CURRENCY', 'INTEGER'].includes(field.dataType)) {
                    formattedValue = condition.selectedValue || '';
                } else if (field.isReference) {
                    formattedValue = condition.selectedValue || 'No Record Selected';
                }
                return {
                    ...condition,
                    selectedCondition,
                    displayCondition: `${field.label || condition.selectedField} ${conditionLabel} ${formattedValue}`
                };
            }
            return condition;
        });
        this.currentRule = { ...this.currentRule };
    }

    handleValueChange(event) {
        const conditionIndex = parseInt(event.target.dataset.conditionIndex, 10);
        const selectedValue = event.detail.value || event.detail.recordId;
        this.currentRule.conditions = this.currentRule.conditions.map((condition, cIndex) => {
            if (cIndex === conditionIndex) {
                const conditionLabel = this.conditionOptions.find(c => c.value === condition.selectedCondition)?.label || condition.selectedCondition;
                const field = this.fieldOptions.find(f => f.value === condition.selectedField) || {};
                let formattedValue = selectedValue;
                if (field.isDate) {
                    formattedValue = selectedValue ? new Date(selectedValue).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' }) : '';
                } else if (field.isDateTime) {
                    formattedValue = selectedValue ? new Date(selectedValue).toLocaleString('en-US', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : '';
                } else if (field.isUrl || field.isPhone || field.isEmail) {
                    formattedValue = selectedValue || '';
                } else if (['DOUBLE', 'CURRENCY', 'INTEGER'].includes(field.dataType)) {
                    formattedValue = selectedValue || '';
                } else if (field.isReference) {
                    formattedValue = selectedValue || 'No Record Selected';
                }
                return {
                    ...condition,
                    selectedValue,
                    displayCondition: `${field.label || condition.selectedField} ${conditionLabel} ${formattedValue}`
                };
            }
            return condition;
        });
        this.currentRule = { ...this.currentRule };
    }

    handleLogicChange(event) {
        const expression = event.target.value;
        this.currentRule.logicalExpression = expression;
        this.currentRule.displayLogicalExpression = expression || 'All conditions must be true (AND)';
        this.currentRule = { ...this.currentRule };
        this.validateLogicalExpression(expression, this.currentRule.conditions.length); // Real-time validation
    }

    addNewCondition() {
        const newCondition = {
            Id: `temp_${Date.now()}_${this.currentRule.conditions.length}`,
            selectedField: '',
            selectedCondition: '',
            selectedValue: '',
            displayCondition: '',
            fieldOptions: this.sortedFieldOptions,
            conditionOptions: this.conditionOptions,
            valueOptions: [],
            isPicklist: false,
            isMultiPicklist: false,
            isBoolean: false,
            isDate: false,
            isDateTime: false,
            isReference: false,
            isUrl: false,
            isPhone: false,
            isEmail: false,
            referenceObject: null,
            order: this.currentRule.conditions.length + 1,
            inputType: 'text',
            placeholder: 'Enter Value',
            isCombobox: false
        };
        this.currentRule.conditions.push(newCondition);
        this.currentRule = { ...this.currentRule };
        this.validateLogicalExpression(this.currentRule.logicalExpression, this.currentRule.conditions.length); // Re-validate logic
    }

    deleteCondition(event) {
        const conditionIndex = parseInt(event.currentTarget.dataset.conditionIndex, 10);
        this.currentRule.conditions = this.currentRule.conditions
            .filter((_, cIndex) => cIndex !== conditionIndex)
            .map((condition, index) => ({ ...condition, order: index + 1 }));
        this.currentRule = { ...this.currentRule };
        this.validateLogicalExpression(this.currentRule.logicalExpression, this.currentRule.conditions.length); // Re-validate logic
    }

    saveRule() {
        const errors = [];

        if (!this.currentRule.selectedUser) {
            errors.push('Assigned User is required.');
        }

        this.currentRule.conditions.forEach((condition, index) => {
            if (!condition.selectedField) {
                errors.push(`Lead Field is required for Condition ${index + 1}.`);
            }
            if (!condition.selectedCondition) {
                errors.push(`Condition is required for Condition ${index + 1}.`);
            }
            if (!condition.selectedValue) {
                errors.push(`Value is required for Condition ${index + 1}.`);
            }
        });

        const conditionKeys = this.currentRule.conditions.map(c => `${c.selectedField}-${c.selectedCondition}-${c.selectedValue}`);
        const uniqueKeys = new Set(conditionKeys);
        if (conditionKeys.length !== uniqueKeys.size) {
            errors.push('Duplicate conditions found.');
        }

        if (this.currentRule.logicalExpression && this.logicError) {
            errors.push(this.logicError);
        }

        if (errors.length > 0) {
            this.showToast('Error', errors.join('\n'), 'error');
            return;
        }

        this.isLoading = true;
        const ruleToSave = {
            Id: this.isEditMode ? this.userGroups[this.currentEditIndex].Id : null,
            Name: this.currentRule.selectedUser,
            Conditions: JSON.stringify(this.currentRule.conditions.map(condition => ({
                Lead_Field: condition.selectedField,
                Condition: condition.selectedCondition,
                Value: condition.selectedValue,
                Order: condition.order
            }))),
            Object_Name: 'Contact',
            Logic_Type: this.currentRule.logicalExpression ? 'Custom' : 'All',
            Logical_Expression: this.currentRule.logicalExpression || '',
            User_Order: this.isEditMode ? this.userGroups[this.currentEditIndex].userOrder : this.userGroups.length,
            Do_Not_Reassign_Owner: this.currentRule.doNotReassignOwner || false
        };

        manageRule({ operation: this.isEditMode ? 'update' : 'insert', ruleData: ruleToSave })
            .then(result => {
                const updatedRule = {
                    ...this.currentRule,
                    Id: this.isEditMode ? this.userGroups[this.currentEditIndex].Id : result,
                    displayUserName: this.currentRule.displayUserName || 'Select User',
                    doNotReassignOwner: this.currentRule.doNotReassignOwner || false,
                    displayLogicalExpression: this.currentRule.logicalExpression || 'All conditions must be true (AND)',
                    showConditions: false,
                    visibleIconName: 'utility:chevronright'
                };

                if (this.isEditMode) {
                    this.userGroups[this.currentEditIndex] = {
                        ...updatedRule,
                        serialNumber: this.currentEditIndex + 1,
                        sectionLabel: `User Assignment ${this.currentEditIndex + 1}`
                    };
                } else {
                    updatedRule.userOrder = this.userGroups.length;
                    updatedRule.serialNumber = this.userGroups.length + 1;
                    updatedRule.sectionLabel = `User Assignment ${this.userGroups.length + 1}`;
                    this.userGroups.push(updatedRule);
                }

                this.userGroups = [...this.userGroups];
                this.originalUserGroups = JSON.parse(JSON.stringify(this.userGroups));
                this.showToast('Success', 'Rule saved successfully.', 'success');
                this.closeRulePopup();
            })
            .catch(error => {
                this.showToast('Error', 'Failed to save rule: ' + (error.body?.message || error.message), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    validateLogicalExpression(expression, conditionCount) {
        if (!expression) {
            this.logicError = '';
            return true;
        }

        try {
            // Check for valid characters (numbers, AND, OR, parentheses, spaces)
            const validSyntax = /^[0-9\s()ANDOR]+$/;
            if (!validSyntax.test(expression)) {
                this.logicError = 'Invalid characters in logic. Use only condition numbers, AND, OR, parentheses, and spaces.';
                return false;
            }

            // Check condition numbers
            const numbers = expression.match(/\b\d+\b/g) || [];
            if (numbers.length === 0) {
                this.logicError = 'Logic must include at least one condition number.';
                return false;
            }

            const validNumbers = numbers.every(num => {
                const n = parseInt(num, 10);
                return n > 0 && n <= conditionCount;
            });
            if (!validNumbers) {
                this.logicError = `Condition numbers must be between 1 and ${conditionCount}.`;
                return false;
            }

            // Basic bracket matching
            let openBrackets = 0;
            for (let char of expression) {
                if (char === '(') openBrackets++;
                if (char === ')') openBrackets--;
                if (openBrackets < 0) {
                    this.logicError = 'Unmatched closing parenthesis.';
                    return false;
                }
            }
            if (openBrackets !== 0) {
                this.logicError = 'Unmatched opening parenthesis.';
                return false;
            }

            // Check for valid operator usage
            const tokens = expression.split(/\s+/).filter(t => t);
            for (let i = 0; i < tokens.length; i++) {
                if (['AND', 'OR'].includes(tokens[i]) && (i === 0 || i === tokens.length - 1)) {
                    this.logicError = 'AND/OR operators cannot be at the start or end of expression.';
                    return false;
                }
                if (['AND', 'OR'].includes(tokens[i]) && ['AND', 'OR'].includes(tokens[i + 1])) {
                    this.logicError = 'Consecutive AND/OR operators are not allowed.';
                    return false;
                }
            }

            this.logicError = '';
            return true;
        } catch (error) {
            this.logicError = 'Invalid logical expression. Please check syntax.';
            return false;
        }
    }

    handleDragStart(event) {
        event.dataTransfer.setData('text/plain', event.currentTarget.dataset.index);
    }

    handleDragOver(event) {
        event.preventDefault();
    }

    handleDrop(event) {
        event.preventDefault();
        const draggedIndex = parseInt(event.dataTransfer.getData('text/plain'), 10);
        const targetIndex = parseInt(event.target.closest('.rule-item')?.dataset.index, 10);
        if (isNaN(targetIndex) || draggedIndex === targetIndex) return;

        const groups = [...this.userGroups];
        const [draggedGroup] = groups.splice(draggedIndex, 1);
        groups.splice(targetIndex, 0, draggedGroup);
        this.userGroups = groups.map((group, index) => ({
            ...group,
            userOrder: index,
            serialNumber: index + 1,
            sectionLabel: `User Assignment ${index + 1}`
        }));
        this.hasUnsavedChanges = true;
        this.userGroups = [...this.userGroups];
    }

    saveOrderChanges() {
        this.isLoading = true;
        const rules = this.userGroups.map(group => ({
            Id: group.Id,
            User_Order: group.userOrder
        }));

        manageRule({ operation: 'save', ruleData: rules })
            .then(() => {
                this.originalUserGroups = JSON.parse(JSON.stringify(this.userGroups));
                this.hasUnsavedChanges = false;
                this.showToast('Success', 'Rule order saved successfully.', 'success');
            })
            .catch(error => {
                this.showToast('Error', 'Failed to save rule order: ' + (error.body?.message || error.message), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    toggleConditions(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        this.userGroups = this.userGroups.map((group, gIndex) => {
            if (gIndex === index) {
                const show = !group.showConditions;
                return {
                    ...group,
                    showConditions: show,
                    visibleIconName: show ? 'utility:chevrondown' : 'utility:chevronright'
                };
            }
            return group;
        });
        this.userGroups = [...this.userGroups];
    }

    checkForUnsavedChanges() {
        const currentGroups = JSON.stringify(this.userGroups.map(g => ({
            Id: g.Id,
            userOrder: g.userOrder
        })));
        const originalGroups = JSON.stringify(this.originalUserGroups.map(g => ({
            Id: g.Id,
            userOrder: g.userOrder
        })));

        this.hasUnsavedChanges = currentGroups !== originalGroups;
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(event);
    }
}