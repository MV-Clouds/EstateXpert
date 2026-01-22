import { LightningElement, track,api } from 'lwc';
import getListingFields from '@salesforce/apex/ListingManagerFilterController.getListingFields';
import Icons from '@salesforce/resourceUrl/listingManagerIcons';
import { loadStyle } from 'lightning/platformResourceLoader';
import designcss from '@salesforce/resourceUrl/listingManagerCss';
import { errorDebugger } from 'c/globalProperties';

export default class ListingManagerFilterAddCmp extends LightningElement {
    @track fieldOptions = [];
    @track options1= [];
    @track selectedFields = [];
    @track selectedField = [];
    @track breadcrumbs = [];
    @track selectedValues = [];
    @track showCombobox = true;
    @track chevRight = Icons + '/chevRight.png';
    @track searchTerm1 = '';
    @track selectedOptions1 = [];
    @track isFocused1 = false;
    @track valueIsField = false;
    @track notCheckboxValue = false;
    @track isDisabled = true;

    /**
    * Method Name: currentFieldOptions
    * @description: getter for the set the current selectedfield operator options.
    * Date: 09/06/2024
    * Created By: Vyom Soni
    */
    get currentFieldOptions() {
        try{
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
        }catch(error){
            errorDebugger('ListingManagerFilterAddCmp', 'currentFieldOptions', error, 'warn', 'Error in currentFieldOptions');
            return null;
        }
    }

    /**
    * Method Name: computedDropdownClass
    * @description: return dynamic class for the combobox.
    * Date: 07/06/2024
    * Created By: Vyom Soni
    */
    get computedDropdownClass() {
        return `slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ${this.isFocused1 ? 'slds-is-open' : ''}`;
    }

    /**
    * Method Name: showOptions1
    * @description: Hide / Unhide options of the combobox.
    * Date: 07/06/2024
    * Created By: Vyom Soni
    */
    get showOptions1() {
        return this.isFocused1 || this.searchTerm1 !== '';
    }

    /**
    * Method Name: filteredOptions1
    * @description: this getter made the field list to show in the UI.
    * Date: 07/06/2024
    * Created By: Vyom Soni
    */
    get filteredOptions1() {
        try{
            if (this.searchTerm1 === '' && !this.isFocused1) {
                return [];
            }
            return this.options1.filter(option =>
                option.label.toLowerCase().includes(this.searchTerm1.toLowerCase()) &&
                !this.selectedOptions1.some(selectedOption => selectedOption.value === option.value)
            ).map(option => ({
                ...option,
                showRightIcon: this.isLookupField(option.type)
            }));
        }catch(error){
            errorDebugger('ListingManagerFilterAddCmp', 'filteredOptions1', error, 'warn', 'Error in filteredOptions1');
            return null;
        }
    }

    /**
    * Method Name: handleButtonClick
    * @description: It is call from the parent component and it send teh selected field to parent component.
    * Date: 09/06/2024
    * Created By: Vyom Soni
    */
    @api
    handleButtonClick() {
        try{
            const customEvent = new CustomEvent('valueselected', {
                detail: this.selectedField
            });
            if (!import.meta.env.SSR) {
                this.dispatchEvent(customEvent);
            }
        }catch(error){
            errorDebugger('ListingManagerFilterAddCmp', 'handleButtonClick', error, 'warn', 'Error in handleButtonClick');
        }
    }

    /**
    * Method Name: connectedCallback
    * @description:handle add button disable, fetch listing fields.
    * Date: 07/06/2024
    * Created By: Vyom Soni
    */
    connectedCallback() {
        loadStyle(this, designcss); 
        this.handleAddButtonDisable();
        this.fetchObjectFields('MVEX__Listing__c');   
    }

    /**
    * Method Name: fetchObjectFields
    * @description: fetch the fields values.
    * @param: objectApiName- object api name.
    * Date: 07/06/2024
    * Created By: Vyom Soni
    */
    fetchObjectFields(objectApiName) {
        this.isDisabled = true;
        getListingFields({ objectApiName })
            .then(fields => {
                let filteredFields = fields.filter(field => field.fieldAPIName !== 'OwnerId');
                if(this.breadcrumbs.length >0){
                    filteredFields = fields.filter(field => field.fieldType != 'REFERENCE');
                }
                if (fields) {
                    this.fieldOptions = filteredFields.map(field => {
                        return {
                            label: field.fieldName,
                            value: field.fieldAPIName,
                            type: field.fieldType,
                            referenceObjectName: field.referenceFields || [], 
                            objectApiName : field.referenceObjectName || '',
                            picklistValues: field.picklistValues || []
                        };
                    });
                    const offerField = [{"value":"MVEX__Offer__c","label":"Offer","type":"REFERENCE","objectApiName":"MVEX__Offer__c"}];
                    this.fieldOptions = this.fieldOptions.concat(offerField);
                    this.options1 = this.fieldOptions;
                    this.isDisabled = false;
                }
            })
            .catch(error => {
                errorDebugger('ListingManagerFilterAddCmp', 'fetchObjectFields', error, 'warn', 'Error in fetchObjectFields');
            });
    }

    /**
    * Method Name: fetchObjectFieldsWithoutReference
    * @description: fetch fields when reference field was clicked.
    * @param: objectApiName- object api name.
    * Date: 07/06/2024
    * Created By: Vyom Soni
    */
    fetchObjectFieldsWithoutReference(objectApiName) {
        this.isDisabled = true;
        getListingFields({ objectApiName })
            .then(fields => {
                let filteredFields = fields;
                if(this.breadcrumbs.length >0){
                    filteredFields = fields.filter(field => field.fieldType != 'REFERENCE');
                }
                if (fields) {
                    this.fieldOptions = filteredFields.map(field => {
                        return {
                            label: field.fieldName,
                            value: field.fieldAPIName,
                            type: field.fieldType,
                            referenceObjectName: field.referenceFields || [], 
                            objectApiName : field.referenceObjectName || '',
                            picklistValues: field.picklistValues || []
                        };
                    });
                    this.options1 = this.fieldOptions;
                    this.isDisabled = false;
                }
            })
            .catch(error => {
                errorDebugger('ListingManagerFilterAddCmp', 'fetchObjectFieldsWithoutReference', error, 'warn', 'Error in fetchObjectFieldsWithoutReference');
            });
    }

    /**
    * Method Name: changeFields
    * @description: handle the fields select of non-reference field.
    * Date: 07/06/2024
    * Created By: Vyom Soni
    */
    changeFields(event){
        try{
            this.handleFieldSelect(event);
            this.showCombobox = false;
            this.valueIsField = true;
            this.selectedField= [this.selectedFields.length > 0 ? this.selectedFields[this.selectedFields.length - 1] : null];
        }catch(error){
            errorDebugger('ListingManagerFilterAddCmp', 'changeFields', error, 'warn', 'Error in changeFields');
        }
    }

    /**
    * Method Name: handleFieldSelect
    * @description: add the selected field from checkbox into selcetdFields.
    * Date: 07/06/2024
    * Created By: Vyom Soni
    */
    handleFieldSelect(event) {
        try{
            const selectedValue = event.currentTarget.dataset.id;
            const selectedField = this.fieldOptions.find(option => option.value === selectedValue);
            if (selectedValue && selectedField && !this.selectedValues.includes(selectedValue)) {   
                this.selectedFields.push({ label: selectedField.label, objectApiName: selectedField.objectApiName,value:selectedField.value,type:selectedField.type,picklistValues:selectedField.picklistValues,prevApiName:this.selectedValues.length > 0 ? this.selectedValues[this.selectedValues.length - 1]:'',isNot:false}); // Only store the label
                this.selectedValues.push(selectedValue);
                this.updateBreadcrumbs();
            }
            this.searchTerm1 = '';
            this.isFocused1 = false;
        }catch(error){
            errorDebugger('ListingManagerFilterAddCmp', 'handleFieldSelect', error, 'warn', 'Error in handleFieldSelect');
        }
    }

    /**
    * Method Name: changeTheCheckboxValue
    * @description: handle the fields select of reference field.
    * Date: 07/06/2024
    * Created By: Vyom Soni
    */
    changeTheCheckboxValue(event){
        try{
            this.selectedField = [];
            this.valueIsField = false;
            const selectedValue = event.currentTarget.dataset.id;
            const selectedField = this.fieldOptions.find(option => option.value === selectedValue);
            if(selectedField != null){
                this.handleFieldSelect(event);
                this.fetchObjectFieldsWithoutReference(selectedField.objectApiName);
            }
        }catch(error){
            errorDebugger('ListingManagerFilterAddCmp', 'changeTheCheckboxValue', error, 'warn', 'Error in changeTheCheckboxValue');
        }
    }

    /**
    * Method Name: findFieldRecursively
    * @description: this method check the from fiedls hierarchy.
    * @param: fields- fields list
    * @param: selectedValue- selected Item in fields picklist.
    * Date: 07/06/2024
    * Created By: Vyom Soni
    */
    findFieldRecursively(fields, selectedValue) {
        try{
            for(let i=0;i<fields.length;i++){
                if (fields[i].apiName === selectedValue || fields[i].value === selectedValue) {
                    return fields[i];
                }
                if (fields[i].type === 'REFERENCE' && fields[i].referenceFields && fields[i].referenceFields.length > 0) {
                    const foundField = this.findFieldRecursively(fields[i].referenceFields, selectedValue);
                    if (foundField) {
                        return foundField;
                    }
                }
            }
            return null;
        }catch(error){
            errorDebugger('ListingManagerFilterAddCmp', 'findFieldRecursively', error, 'warn', 'Error in findFieldRecursively');
            return null;
        }
    }

    /**
    * Method Name: updateBreadcrumbs
    * @description: handle the combobox options when the bread crumbs is clicked.
    * Date: 07/06/2024
    * Created By: Vyom Soni
    */
    updateBreadcrumbs() {
        try{
            this.valueIsField = false;
            this.breadcrumbs = this.selectedFields.map(selectedValue => {
                return { label: selectedValue.label };
            });
        }catch(error){
            errorDebugger('ListingManagerFilterAddCmp', 'updateBreadcrumbs', error, 'warn', 'Error in updateBreadcrumbs');
        }
    }

    /**
    * Method Name: handleBreadcrumbClick
    * @description: handle the combobox options when the bread crumbs is clicked
    * Date: 07/06/2024
    * Created By: Vyom Soni
    */
    handleBreadcrumbClick(event) {
        try{
            const clickedIndex = parseInt(event.currentTarget.dataset.index, 10);
            this.selectedFields = this.selectedFields.slice(0, clickedIndex);
            this.selectedValues = this.selectedValues.slice(0, clickedIndex);
            this.selectedField = [];
            this.handleAddButtonDisable();

            if (this.selectedValues.length > 0) {
                let lastSelectedField = this.selectedFields[this.selectedFields.length - 1].objectApiName;
                if(lastSelectedField == null){
                    lastSelectedField='MVEX__Listing__c'
                }else {
                    this.fetchObjectFieldsWithoutReference(lastSelectedField);
                }
                
            } else {
                this.fetchObjectFields('MVEX__Listing__c');
            }
    
            this.showCombobox = true;
            this.updateBreadcrumbs();
        }catch(error){
            errorDebugger('ListingManagerFilterAddCmp', 'handleBreadcrumbClick', error, 'warn', 'Error in handleBreadcrumbClick');
        }
    }

    /**
    * Method Name: handleSearchChange1
    * @description: handle search text change.
    * Date: 07/06/2024
    * Created By: Vyom Soni
    */
    handleSearchChange1(event) {
        this.searchTerm1 = event.target.value;
    }

    /**
    * Method Name: handleFocus1
    * @description: handle focus event in combobox.
    * Date: 07/06/2024
    * Created By: Vyom Soni
    */
    handleFocus1() {
        this.isFocused1 = true;
    }

    /**
    * Method Name: handleBlur1
    * @description: handle blur event in the combobox.
    * Date: 07/06/2024
    * Created By: Vyom Soni
    */
    handleBlur1() {
        this.isFocused1 = false;
    }

    /**
    * Method Name: handlePreventDefault
    * @description: prevent default events when the options div clicked.
    * Date: 07/06/2024
    * Created By: Vyom Soni
    */
    handlePreventDefault(event){
        event.preventDefault();
    }

    /**
    * Method Name: isLookupField
    * @description: check field is lookup or reference.
    * @param: fieldType- field's data-type
    * Date: 07/06/2024
    * Created By: Vyom Soni
    */
    isLookupField(fieldType) {
        return fieldType === 'REFERENCE' || fieldType === 'Lookup';
    }

    /**
    * Method Name: handleNotCheckboxChange
    * @description: handle the not checkbox change.
    * Date: 09/06/2024
    * Created By: Vyom Soni
    */
    handleNotCheckboxChange(event) {
        this.notCheckboxValue = event.target.checked;
        this.selectedField[0].isNot = event.target.checked;
    }

    /**
    * Method Name: operationSelect
    * @description: handle the operation combobox change.
    * Date: 09/06/2024
    * Created By: Vyom Soni
    */
    operationSelect(event){
        this.selectedField[0].operation = event.target.value;
        this.handleAddButtonDisable();
    }

    /**
    * Method Name: handleAddButtonDisable
    * @description: set the custom event when the field value is selected.
    * Date: 09/06/2024
    * Created By: Vyom Soni
    */
    handleAddButtonDisable(){
        if (!import.meta.env.SSR) {
        this.dispatchEvent(new CustomEvent('fieldchange', { detail: this.selectedField }));
        }
    }
}