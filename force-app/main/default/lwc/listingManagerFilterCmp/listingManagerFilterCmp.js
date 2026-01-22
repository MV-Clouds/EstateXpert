import { LightningElement,track} from 'lwc';
import getStaticFields from '@salesforce/apex/ListingManagerFilterController.getStaticFields';
import getPicklistValues from '@salesforce/apex/ListingManagerFilterController.getPicklistValues';
import getFilteredListings from '@salesforce/apex/ListingManagerFilterController.getFilteredListings';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { loadStyle } from 'lightning/platformResourceLoader';
import { errorDebugger } from 'c/globalProperties';

export default class ListingManagerFilterCmp extends LightningElement {

    @track addModal = false;
    @track listings = [];
    @track valueFromChild = [];
    @track isAddButtonDisabled = true;
    @track filterFields =[];
    @track filteredListings;
    @track staticFields=[];
    @track isLoading = false;
    @track screenWidth = 0;
    @track modalValue = false;
    @track parentField = null;

    @track isCustomLogicEnabled = false;
    @track customLogicExpression = '';
    @track customLogicError = null;

    /**
    * Method Name: connectedCallback
    * @description: set the get static fields, set listing record wrapper, set offre records.
    * Date: 13/06/2024
    * Created By: Vyom Soni
    */   
    connectedCallback(){
        loadStyle(this, MulishFontCss);
        if (!import.meta.env.SSR) {
            window?.globalThis?.addEventListener('resize', this.updateScreenWidth);
        }
        this.updateScreenWidth();
        this.initializeStaticFields();
    }

    /**
    * Method Name: initializeStaticFields
    * @description: get the static fields from custom metadata.
    * Date: 03/07/2024
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
                console.log('this.filterFields',JSON.stringify(this.filterFields));
                
                this.isLoading = false;
            })
            .catch(error => {
                errorDebugger('ListingManagerFilterCmp', 'initializeStaticFields', error, 'warn', 'Error in initializeStaticFields');
            });
    }

    /**
    * Method Name: setPicklistValue
    * @description: get the picklist values one by one for static fields.
    * Date: 13/06/2024
    * Created By: Vyom Soni
    */    
    setPicklistValue(){
        this.staticFields.forEach(field => {
            if (field.picklist) {
                this.loadPicklistValues(field);
                }
        });
    }

    /**
    * Method Name: loadPicklistValues
    * @description: add the picklist values in the static fields.
    * @param: field- field's object
    * Date: 13/06/2024
    * Created By: Vyom Soni
    */    
    loadPicklistValues(field) {
        getPicklistValues({apiName:field.apiName,objectName:field.objectApiName})
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
            errorDebugger('ListingManagerFilterCmp', 'loadPicklistValues', error, 'warn', 'Error in loadPicklistValues');
        });
    }

    /**
    * Method Name: handleValueSelected
    * @description: this method is set the field from the child field-add cmp .
    * Date: 07/06/2024
    * Created By: Vyom Soni
    */
    handleValueSelected(event) {
        try{
        this.valueFromChild = event.detail;
        this.valueFromChild = this.valueFromChild.map(field => {
            return {
                label: field.label,
                type: field.type,
                apiName: field.value,
                prevFieldApiName : field.prevFieldApiName,
                objectApiName: field.objectApiName,
                operatorName: field.operation,
                picklistValue: field.picklistValues||[],
                unchangePicklistValue: field.picklistValues||[],
                prevApiName : field.prevApiName,
                minValue:null,
                maxValue:null,
                minDate:null,
                maxDate:null,
                isNot: field.isNot || false,
                searchTerm:'',
                isFocused:false,
                picklist: field.type === 'PICKLIST',
                string: field.type === 'STRING'||field.type === 'TEXTAREA'||field.type === 'URL'||field.type === 'ID'||field.type === 'EMAIL'||field.type === 'PHONE',
                fieldChecked:false,
                currency: field.type === 'CURRENCY',
                double: field.type === 'DOUBLE',
                date:field.type === 'DATE',
                datetime:field.type === 'DATETIME',
                boolean:field.type === 'BOOLEAN',
                isDateRange:field.operation === 'daterange',
                isDateMax:field.operation === 'datemaximum',
                isDateMin :field.operation === 'dateminimum', 
                isRange:field.operation === 'range',
                isMax:field.operation === 'minimum',
                isMin :field.operation === 'maximum',
                message:''
            };
        });
        this.valueFromChild.forEach(newField => {
            const isFieldPresent = this.filterFields.some(field => 
                (field.apiName === newField.apiName ||field.value === newField.apiName)&&
                field.label === newField.label &&
                field.objectApiName === newField.objectApiName &&
                field.type === newField.type &&
                field.isNot === newField.isNot
            );
            if (!isFieldPresent) {
                this.filterFields = [...this.filterFields, newField];
            }else{
                const evt = new ShowToastEvent({
                    title: 'Field is not added',
                    message: `${newField.label} is already added in filter fields`,
                    variant: 'error',
                });
                this.dispatchEvent(evt);
            }
        });
        this.updateFilterIndices();
        console.log('this.filterFields',JSON.stringify(this.filterFields));
    }catch(error){
        errorDebugger('ListingManagerFilterCmp', 'handleValueSelected', error, 'warn', 'Error in handleValueSelected');
    }
    }

    /**
    * Method Name : updateScreenWidth
    * @description : update the width variable.
    * * Date: 3/06/2024
    * Created By:Vyom Soni
    */
    updateScreenWidth =()=> {
        this.screenWidth = window.innerWidth;
    }

     /**
    * Method Name: applyFilters
    * @description: apply the filters on the listings.
    * Date: 14/06/2024
    * Created By: Vyom Soni
    */
    applyFilters(event) {
        try {

            // Initialize queryFilters as an array with null values to ensure correct indexing
            let queryFilters = new Array(this.filterFields.length + 1).fill(null); // +1 for 1-based indexing
            let hasOfferFilters = false;

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
                    if (field.objectApiName === 'MVEX__Offer__c') {
                        hasOfferFilters = true;
                        fieldPath = `MVEX__Offers__r.${field.apiName}`;
                    } else if (field.objectApiName !== 'MVEX__Listing__c') {
                        if (field.prevApiName?.endsWith('Id')) {
                            fieldPath = `${field.prevApiName.replace('Id', '')}.${field.apiName}`;
                        } else {
                            fieldPath = `${field.prevApiName?.replace('__c', '__r')}.${field.apiName}`;
                        }
                    } else {
                        fieldPath = field.apiName;
                    }

                    let condition;
                    if (hasSelectedOptions && (field.picklist || field.string)) {
                        if (field.operatorName === 'contains') {
                            const conditions = field.selectedOptions.map(opt => 
                                `${fieldPath} ${field.isNot ? 'NOT LIKE' : 'LIKE'} '%${opt.value.replace(/'/g, '\\\'')}%'`
                            );
                            condition = `(${conditions.join(' OR ')})`;
                        } else if (field.operatorName === 'startswith') {
                            const conditions = field.selectedOptions.map(opt => 
                                `${fieldPath} ${field.isNot ? 'NOT LIKE' : 'LIKE'} '${opt.value.replace(/'/g, '\\\'')}%'`
                            );
                            condition = `(${conditions.join(' OR ')})`;
                        } else if (field.operatorName === 'equals') {
                            const conditions = field.selectedOptions.map(opt => 
                                `${fieldPath} ${field.isNot ? '!=' : '='} '${opt.value.replace(/'/g, '\\\'')}'`
                            );
                            condition = `(${conditions.join(' OR ')})`;
                        } else {
                            const values = field.selectedOptions.map(opt => `'${opt.value.replace(/'/g, '\\\'')}'`).join(',');
                            const operator = field.isNot ? 'NOT IN' : 'IN';
                            condition = `${fieldPath} ${operator} (${values})`;
                        }
                    }

                    if (field.boolean && hasFieldChecked) {
                        condition = `${fieldPath} = ${field.fieldChecked}`;
                    }

                    if ((field.currency || field.double) && (hasMinValue || hasMaxValue)) {
                        let conditions = [];
                        if (hasMinValue) {
                            conditions.push(`${fieldPath} >= ${field.minValue}`);
                        }
                        if (hasMaxValue) {
                            conditions.push(`${fieldPath} <= ${field.maxValue}`);
                        }
                        condition = conditions.length > 1 ? `(${conditions.join(' AND ')})` : conditions[0];
                    }

                    if ((field.date || field.datetime) && (hasMinDate || hasMaxDate)) {
                        let conditions = [];
                        if (hasMinDate) {
                            conditions.push(`${fieldPath} >= ${field.minDate}`);
                        }
                        if (hasMaxDate) {
                            conditions.push(`${fieldPath} <= ${field.maxDate}`);
                        }
                        condition = conditions.length > 1 ? `(${conditions.join(' AND ')})` : conditions[0];
                    }

                    if (condition) {
                        queryFilters[index + 1] = condition; // Store at 1-based index (filterFields[0] -> index 1)
                        console.log(`Filter ${index + 1}: ${condition}`); // Debug each filter condition
                    }
                }
            });

            let finalQuery = '';
            if (this.isCustomLogicEnabled && this.customLogicExpression && !this.customLogicError) {
                // Use custom logic expression only if filterConditions is true
                finalQuery = this.customLogicExpression;
                console.log('Custom Logic Expression:', finalQuery); // Debug custom logic
                for (let i = 1; i <= this.filterFields.length; i++) {
                    if (queryFilters[i]) {
                        finalQuery = finalQuery.replace(new RegExp(`\\b${i}\\b`, 'g'), queryFilters[i]);
                    } else {
                        console.warn(`No condition found for filter index ${i} in custom logic. Replacing with TRUE.`);
                        finalQuery = finalQuery.replace(new RegExp(`\\b${i}\\b`, 'g'), 'TRUE');
                    }
                }
                if (finalQuery.includes('AND') || finalQuery.includes('OR')) {
                    finalQuery = `(${finalQuery})`;
                }
            } else {
                // Combine all filters with AND when filterConditions is false or custom logic is disabled
                finalQuery = queryFilters.filter(Boolean).join(' AND ');
                console.log('Using AND logic for filters:', finalQuery); // Debug AND logic
            }

            if (hasOfferFilters) {
                const offerFilters = queryFilters.filter(filter => 
                    filter && filter.includes('MVEX__Offers__r.')
                ).map(filter => filter.replace('MVEX__Offers__r.', ''));

                const listingFilters = queryFilters.filter(filter => 
                    filter && !filter.includes('MVEX__Offers__r.')
                );

                let offerQuery = '';
                if (offerFilters.length > 0) {
                    let offerConditions;
                    if (this.isCustomLogicEnabled && this.customLogicExpression && !this.customLogicError) {
                        offerConditions = [finalQuery.replace('MVEX__Offers__r.', '')];
                    } else {
                        offerConditions = offerFilters.filter(Boolean);
                    }
                    offerQuery = `Id IN (SELECT MVEX__Listing__c FROM MVEX__Offer__c WHERE ${offerConditions.join(' AND ')})`;
                    console.log('Offer Query:', offerQuery); // Debug offer query
                }

                const allFilters = [
                    ...(offerQuery ? [offerQuery] : []),
                    ...listingFilters
                ].filter(Boolean);

                finalQuery = allFilters.length > 0 ? allFilters.join(' AND ') : 'TRUE';
            }

            // If no filters are applied, use 'TRUE' to return all records
            if (!finalQuery) {
                finalQuery = 'TRUE';
            }

            console.log('Final Query:', finalQuery); // Debug the final query string
            this.isLoading = true;
            getFilteredListings({ filterConditions: finalQuery })
                .then(result => {
                    this.filteredListings = result;
                    this.setFilteredListings();
                    this.isLoading = false;
                })
                .catch(error => {
                    errorDebugger('ListingManagerFilterCmp', 'applyFilters', error, 'error', 'Error in applyFilters: ' + JSON.stringify(error));
                    this.isLoading = false;
                });

        } catch(error) {
            errorDebugger('ListingManagerFilterCmp', 'applyFilters', error, 'error', 'Error in applyFilters: ' + JSON.stringify(error));
            this.isLoading = false;
        }
    }

    /**
    * Method Name: setFilteredListings
    * @description: set Listings in the Parent listing manager component.
    * Date: 14/06/2024
    * Created By: Vyom Soni
    */
    setFilteredListings(){
        const filterlistings = this.filteredListings;
        const customEvent = new CustomEvent('valueselected', {
            detail: {filterlistings}
        });
        this.dispatchEvent(customEvent);
    }
      
    /**
    * Method Name: setFilteredListingsReset
    * @description: set Listings in the Parent when reset button is clicked.
    * Date: 14/06/2024
    * Created By: Vyom Soni
    */
    setFilteredListingsReset(){
        const filterlistings = true;
        const customEvent = new CustomEvent('valuereset', {
            detail: {filterlistings}
        });
        this.dispatchEvent(customEvent);
    }  

    /**
    * Method Name: handleSearchChange1
    * @description: Handle the search option feature in picklist fields.
    * Date: 14/06/2024
    * Created By: Vyom Soni
    */
    handleSearchChange1(event) {
      try{
        this.isCustomLogicEnabled = false;
          const index = event.currentTarget.dataset.id;
          this.filterFields[index].searchTerm = event.target.value;
          if (this.filterFields[index].searchTerm.length > 50) {
              this.filterFields[index].message = 'The character length should not greater then 50 characters.';
          } else {
              this.filterFields[index].message = null;
              this.filterFields[index].picklistValue =this.filterFields[index].unchangePicklistValue.filter(option =>
                  option.label.toLowerCase().includes(this.filterFields[index].searchTerm.toLowerCase().trim())
              );
              if (event.key === 'Enter') {
                  let fields = this.filterFields;
                  const value = this.filterFields[index].picklistValue[0].value;
                  const field = fields[index];
                  if (field != null) {
                      if (field.selectedOptions == null) {
                          field.selectedOptions = [];
                      }
                      const exists = field.selectedOptions.some(option => option.value === value);
                      if (!exists) {
                          this.filterFields[index].searchTerm = '';
                          field.selectedOptions = [...field.selectedOptions, {"label": value, "value": value}];
                          this.applyFilters();
          
                          const newPicklistValue = field.unchangePicklistValue.map(option => {
                              if (option.value === value) {
                                  return {...option, showRightIcon: true};
                              }
                              return option;
                          });
          
                          field.picklistValue = newPicklistValue;
                          field.unchangePicklistValue = newPicklistValue;
                          fields[index] = field;
                          this.filterFields = fields;
                          const inputs = this.template.querySelectorAll('.picklist-input');
                          inputs.forEach(input => input.blur());
                          this.handleBlur1(event);
                      }
                  }
              }
          }
      }catch(error){
        errorDebugger('ListingManagerFilterCmp', 'handleSearchChange1', error, 'warn', 'Error in handleSearchChange1');
    }
    }

    /**
    * Method Name: handleFocus1
    * @description: Handle the Focus event in picklist fiedls.
    * Date: 14/06/2024
    * Created By: Vyom Soni
    */
    handleFocus1(event) {
        try{
            const index = event.currentTarget.dataset.id;
            this.filterFields[index].isFocused = true;
            this.filterFields[index].picklistValue = this.filterFields[index].unchangePicklistValue;   
        }catch(error){
            errorDebugger('ListingManagerFilterCmp', 'handleFocus1', error, 'warn', 'Error in handleFocus1');
        }
    }

    /**
    * Method Name: handleBlur1
    * @description: Handle the blur event in picklist fiedls.
    * Date: 14/06/2024
    * Created By: Vyom Soni
    */
    handleBlur1(event) {
        try{
            const index = event.currentTarget.dataset.id;
            this.filterFields[index].isFocused = false;
        }catch(error){
            errorDebugger('ListingManagerFilterCmp', 'handleBlur1', error, 'warn', 'Error in handleBlur1');
        }
    }

    /**
    * Method Name: handlePreventDefault
    * @description: prevent default events when the options div clicked.
    * Date: 23/07/2024
    * Created By: Vyom Soni
    */
    handlePreventDefault(event){
        event.preventDefault();
    }

    /**
    * Method Name: selectOption1
    * @description: Handle the slection of option in picklist fiedls.
    * Date: 14/06/2024
    * Created By: Vyom Soni
    */
    selectOption1(event) {
        try{
            this.isCustomLogicEnabled = false;
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
                    field.selectedOptions = [...field.selectedOptions, {"label": value, "value": value}];
                    this.applyFilters();
                    const newPicklistValue = field.unchangePicklistValue.map(option => {
                        if (option.value === value) {
                            return {...option, showRightIcon: true};
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
        }catch(error){
            errorDebugger('ListingManagerFilterCmp', 'selectOption1', error, 'warn', 'Error in selectOption1');
        }
    }
    
    /**
    * Method Name: removeOptionMethod
    * @description: Handle the remove of pill from under if picklist fiedls.
    * Date: 14/06/2024
    * Created By: Vyom Soni
    */
    removeOptionMethod(event){
        this.isCustomLogicEnabled = false;
        this.removeOption1(event);
        this.applyFilters();
    }

    /**
    * Method Name: removeOption1
    * @description: Handle the remove of pill from under if picklist fiedls.
    * Date: 14/06/2024
    * Created By: Vyom Soni
    */
    removeOption1(event) {
        try{
            const optionToRemove = event.currentTarget.dataset.id;
            const index = event.currentTarget.dataset.index;
            this.filterFields[index].searchTerm = '';
        
            if (index > -1) {
                let fields = [...this.filterFields];
                let field = {...fields[index]};
                
                field.selectedOptions = field.selectedOptions.filter(option => option.value !== optionToRemove);
                if (field.selectedOptions.length === 0) {
                    field.selectedOptions = null;
                }
        
                const newPicklistValue = field.picklistValue.map(option => {
                    if (option.value === optionToRemove) {
                        return {...option, showRightIcon: false};
                    }
                    return option;
                });
        
                field.picklistValue = newPicklistValue;
                field.unchangePicklistValue = newPicklistValue;
                fields[index] = field;
                this.filterFields = fields;
                this.updateFilterIndices();
            }
        }catch(error){
            errorDebugger('ListingManagerFilterCmp', 'removeOption1', error, 'warn', 'Error in removeOption1');
        }
    }
    
    /**
    * Method Name: removeOptionMethodString
    * @description: call the removeOptionString and applyFilter method.
    * Date: 14/06/2024
    * Created By: Vyom Soni
    */
    removeOptionMethodString(event){
        this.removeOptionString(event);
        this.applyFilters();
    }

    /**
    * Method Name: removeOptionString
    * @description: Handle remove the pill from the string fields.
    * Date: 14/06/2024
    * Created By: Vyom Soni
    */
    removeOptionString(event) {
        try{
            const optionToRemove = event.currentTarget.dataset.id;
            const index = event.currentTarget.dataset.index;
           
            if (index > -1) {
                this.filterFields[index].selectedOptions = this.filterFields[index].selectedOptions.filter(option => option.value !== optionToRemove);
                if (this.filterFields[index].selectedOptions.length === 0) {
                    this.filterFields[index].selectedOptions = null;
                }
            }

            this.updateFilterIndices();
        }catch(error){
            errorDebugger('ListingManagerFilterCmp', 'removeOptionString', error, 'warn', 'Error in removeOptionString');
        }
    }

    /**
    * Method Name: handleSearchChangeString
    * @description: Handle the string change in string fiedls.
    * Date: 14/06/2024
    * Created By: Vyom Soni
    */
    handleSearchChangeString(event) {
        try{
            const index = event.currentTarget.dataset.id;
            this.filterFields[index].searchTerm = event.target.value;
            if (this.filterFields[index].searchTerm.length > 50) {
                this.filterFields[index].message = 'The character length should not greater then 50 characters.';
            } else {
                this.filterFields[index].message = null;
                if (event.key === 'Enter') {
                    this.addTheString(event);
                }
            }
        }catch(error){
            errorDebugger('ListingManagerFilterCmp', 'handleSearchChangeString', error, 'warn', 'Error in handleSearchChangeString');
        }
    }

    /**
    * Method Name: addTheString
    * @description: Handle the string add in the multi selection in string fiedls.
    * Date: 14/06/2024
    * Created By: Vyom Soni
    */
    addTheString(event) {
        try{
            this.isCustomLogicEnabled = false;
            const index = event.currentTarget.dataset.id;
            const value = this.filterFields[index].searchTerm.trim();
            
            if (value !== '') {
                const field = this.filterFields[index];
                if (field.selectedOptions == null) {
                    field.selectedOptions = [];
                }
                const isValueAlreadySelected = field.selectedOptions.some(option => option.value === value);
                if (!isValueAlreadySelected) {
                    field.selectedOptions = [...field.selectedOptions, {"label": value, "value": value}];
                    this.filterFields[index].searchTerm = '';
                }
            }
            this.applyFilters();
        }catch(error){
            errorDebugger('ListingManagerFilterCmp', 'addTheString', error, 'warn', 'Error in addTheString');
        }
    }

    /**
     * Method Name: handleMinValueChange
     * @description: Handle the min value change in the number Input field.
     * Date: 9/06/2024
     * Created By: Vyom Soni
     */
    handleMinValueChange(event) {
        try {
            this.isCustomLogicEnabled = false;
            const index = event.currentTarget.dataset.index;
            let value = parseInt(event.target.value, 10);
    
            if (isNaN(value)) {
                value = null;
            }
    
            // Clear any existing debounce timer
            if (this.debounceTimeout) {
                clearTimeout(this.debounceTimeout);
            }
    
            // Set a new debounce timer
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
                    this.filterFields[index].message =
                        'Min Value cannot be Greater than the Max Value';
                }
            }, 300); // Adjust the debounce delay (in milliseconds) as needed
        } catch (error) {
            errorDebugger('ListingManagerFilterCmp', 'handleMinValueChange', error, 'warn', 'Error in handleMinValueChange');
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
            this.isCustomLogicEnabled = false;
            const index = event.currentTarget.dataset.index;
            let value = parseInt(event.target.value, 10);
    
            if (isNaN(value)) {
                value = null;
            }
    
            // Clear any existing debounce timer
            if (this.debounceTimeout) {
                clearTimeout(this.debounceTimeout);
            }
    
            // Set a new debounce timer
            this.debounceTimeout = setTimeout(() => {
                this.filterFields[index].maxValue = value;
    
                if (
                    this.filterFields[index].isMax === true ||
                    value === 0 ||
                    value >= this.filterFields[index].minValue
                ) {
                    this.applyFilters();
                    this.filterFields[index].message = '';
                } else {
                    this.filterFields[index].message =
                        'Min Value cannot be Greater than the Max Value';
                }
            }, 300); // Adjust debounce delay as needed
        } catch (error) {
            errorDebugger('ListingManagerFilterCmp', 'handleMaxValueChange', error, 'warn', 'Error in handleMaxValueChange');
        }
    }

    /**
     * Method Name: incrementMinValue
     * @description: Increment the min input value
     * Date: 9/06/2024
     * Created By: Vyom Soni
     */
    incrementMinValue(event) {
        try {
            this.isCustomLogicEnabled = false;
            const index = event.currentTarget.dataset.index;
            let currentValue = parseInt(this.filterFields[index].minValue, 10);
    
            if (isNaN(currentValue)) {
                currentValue = 0; // Default to 0 if value is null or NaN
            }
    
            // Clear any existing debounce timer
            if (this.debounceTimeout) {
                clearTimeout(this.debounceTimeout);
            }
    
            // Set a new debounce timer
            this.debounceTimeout = setTimeout(() => {
                this.filterFields[index].minValue = currentValue + 1;
    
                if (
                    this.filterFields[index].isMin === true ||
                    currentValue + 1 <= this.filterFields[index].maxValue
                ) {
                    this.applyFilters();
                    this.filterFields[index].message = null;
                } else {
                    this.filterFields[index].message =
                        'Min Value cannot be Greater than the Max Value';
                }
            }, 300); // Adjust debounce delay as needed
        } catch (error) {
            errorDebugger('ListingManagerFilterCmp', 'incrementMinValue', error, 'warn', 'Error in incrementMinValue');
        }
    }
    
    /**
     * Method Name: decrementMinValue
     * @description: Decrement the min input value
     * Date: 9/06/2024
     * Created By: Vyom Soni
     */
    decrementMinValue(event) {
        try {
            this.isCustomLogicEnabled = false;
            const index = event.currentTarget.dataset.index;
            let currentValue = parseInt(this.filterFields[index].minValue, 10);
    
            if (isNaN(currentValue) || currentValue <= 0) {
                currentValue = 0;
            } else {
                currentValue--;
            }
    
            // Clear existing debounce timer
            if (this.debounceTimeout) {
                clearTimeout(this.debounceTimeout);
            }
    
            // Set a new debounce timer
            this.debounceTimeout = setTimeout(() => {
                this.filterFields[index].minValue = currentValue;
    
                if (
                    this.filterFields[index].isMin === true ||
                    currentValue <= this.filterFields[index].maxValue
                ) {
                    this.applyFilters();
                    this.filterFields[index].message = null;
                } else {
                    this.filterFields[index].message =
                        'Min Value cannot be Greater than the Max Value';
                }
            }, 300); // Adjust debounce delay as needed
        } catch (error) {
            errorDebugger('ListingManagerFilterCmp', 'decrementMinValue', error, 'warn', 'Error in decrementMinValue');
        }
    }

    /**
     * Method Name: incrementMaxValue
     * @description: Increment the max input value
     * Date: 9/06/2024
     * Created By: Vyom Soni
     */
    incrementMaxValue(event) {
        try {
            this.isCustomLogicEnabled = false;
            const index = event.currentTarget.dataset.index;
            let currentValue = parseInt(this.filterFields[index].maxValue, 10);
    
            if (isNaN(currentValue)) {
                currentValue = 0;
            }
    
            // Clear existing debounce timer
            if (this.debounceTimeout) {
                clearTimeout(this.debounceTimeout);
            }
    
            // Set a new debounce timer
            this.debounceTimeout = setTimeout(() => {
                this.filterFields[index].maxValue = currentValue + 1;
    
                if (
                    this.filterFields[index].isMax === true ||
                    currentValue + 1 >= this.filterFields[index].minValue
                ) {
                    this.applyFilters();
                    this.filterFields[index].message = null;
                } else {
                    this.filterFields[index].message =
                        'Min Value cannot be Greater than the Max Value';
                }
            }, 300); // Adjust debounce delay as needed
        } catch (error) {
            errorDebugger('ListingManagerFilterCmp', 'incrementMaxValue', error, 'warn', 'Error in incrementMaxValue');
        }
    }
    

    /**
     * Method Name: decrementMaxValue
     * @description: Decrement the max input value
     * Date: 9/06/2024
     * Created By: Vyom Soni
     */
    decrementMaxValue(event) {
        try {
            this.isCustomLogicEnabled = false;
            const index = event.currentTarget.dataset.index;
            let currentValue = parseInt(this.filterFields[index].maxValue, 10);
    
            if (isNaN(currentValue) || currentValue <= this.filterFields[index].minValue) {
                currentValue = this.filterFields[index].minValue;
                this.filterFields[index].message =
                    'Min Value cannot be Greater than the Max Value';
            } else {
                currentValue--;
            }
    
            // Clear existing debounce timer
            if (this.debounceTimeout) {
                clearTimeout(this.debounceTimeout);
            }
    
            // Set a new debounce timer
            this.debounceTimeout = setTimeout(() => {
                this.filterFields[index].maxValue = currentValue;
    
                if (
                    this.filterFields[index].isMax === true ||
                    currentValue >= this.filterFields[index].minValue
                ) {
                    this.applyFilters();
                    this.filterFields[index].message = null;
                }
            }, 300); // Adjust debounce delay as needed
        } catch (error) {
            errorDebugger('ListingManagerFilterCmp', 'decrementMaxValue', error, 'warn', 'Error in decrementMaxValue');
        }
    }
    

    /**
    * Method Name: checkboxFieldChange
    * @description:  handle th checkbox field change
    * Date: 9/06/2024
    * Created By: Vyom Soni
    */
    checkboxFieldChange(event){
        try{
            this.isCustomLogicEnabled = false;
            const index = event.currentTarget.dataset.index;
            this.filterFields[index].fieldChecked = !this.filterFields[index].fieldChecked;
            this.applyFilters();
        }catch(error){
            errorDebugger('ListingManagerFilterCmp', 'checkboxFieldChange', error, 'warn', 'Error in checkboxFieldChange');
        }
    }

    /**
    * Method Name: handleMinDate
    * @description:  handle min date field change
    * Date: 9/06/2024
    * Created By: Vyom Soni
    */
    handleMinDate(event) {
        try{
            this.isCustomLogicEnabled = false;
            const index = event.currentTarget.dataset.id;
            const newValue = event.target.value;
            this.filterFields[index].minDate = newValue;

            const minDate = new Date(this.filterFields[index].minDate);
            const maxDate = new Date(this.filterFields[index].maxDate);
            
            if (minDate <= maxDate || this.filterFields[index].isDateMin == true) {
                this.applyFilters();
                this.filterFields[index].message = null;
            } else {
                this.filterFields[index].message = 'Min Value can not be Greater than the Max Value';
            }
        }catch(error){
            errorDebugger('ListingManagerFilterCmp', 'handleMinDate', error, 'warn', 'Error in handleMinDate');
        }
    }
    
    /**
     * Method Name: handleMaxDate
     * @description: handle max date field change
     * Date: 9/06/2024
     * Created By: Vyom Soni
     */
    handleMaxDate(event) {
        try{
            this.isCustomLogicEnabled = false;
            const index = event.currentTarget.dataset.id;
            const newValue = event.target.value;
            this.filterFields[index].maxDate = newValue;

            const minDate = new Date(this.filterFields[index].minDate);
            const maxDate = new Date(this.filterFields[index].maxDate);
        
            if (minDate <= maxDate || this.filterFields[index].isDateMax == true) {
                this.applyFilters(); 
                this.filterFields[index].message = null;
            } else {
                this.filterFields[index].message = 'Min Value can not be Greater than the Max Value';
            }
        }catch(error){
            errorDebugger('ListingManagerFilterCmp', 'handleMaxDate', error, 'warn', 'Error in handleMaxDate');
        }
    }

    /**
    * Method Name: clearSearch
    * @description: Removes a field from the filed list.
    * Date: 14/06/2024
    * Created By: Vyom Soni
    */
    clearSearch(event) {
        try{
            this.isCustomLogicEnabled = false;
            const index = event.currentTarget.dataset.id;
            if (index > -1 && index < this.filterFields.length) {
                this.filterFields.splice(index, 1);
            }
            this.applyFilters();
            this.updateFilterIndices();
        }catch(error){
            errorDebugger('ListingManagerFilterCmp', 'clearSearch', error, 'warn', 'Error in clearSearch');
        }
    }

    /**
    * Method Name: handleReset
    * @description: Remove the all except static fields.
    * Date: 14/06/2024
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
            this.filterFields = this.staticFields.map(field => {
                return {
                    ...field,
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
            this.isCustomLogicEnabled = false;
            this.customLogicExpression = '';
            this.customLogicError = null;
            this.setFilteredListingsReset();

            this.updateFilterIndices();
        } catch (error) {
            errorDebugger('ListingManagerFilterCmp', 'handleReset', error, 'warn', 'Error in handleReset');
        }
    }
    /**
    * Method Name: handleClose
    * @description: handle the close event of modal.
    * Date: 14/06/2024
    * Created By: Vyom Soni
    */
    handleClose() {
        this.addModal = false;
        if(this.screenWidth <= 900){
        this.modalValue = false;
        this.handleAddButtonChange();
        }
    }

    /**
    * Method Name: handleSave
    * @description: handle the sae evnet in modal.
    * Date: 14/06/2024
    * Created By: Vyom Soni
    */
    handleSave() {
        try{
            this.addModal = false;
            if(this.screenWidth <= 900){
            this.modalValue = false;
            this.handleAddButtonChange();
            }
            const childComponent = this.template.querySelector('c-listing-manager-filter-add-cmp');
    
            if (childComponent) {
                childComponent.handleButtonClick();
            }
        }catch(error){
            errorDebugger('ListingManagerFilterCmp', 'handleSave', error, 'warn', 'Error in handleSave');
        }
    }
 
    /**
    * Method Name: handleFieldChange
    * @description: fetch the custom event data and set pop-up add button disable.
    * Date: 14/06/2024
    * Created By: Vyom Soni
    */
    handleFieldChange(event) {
        try{
            const field = event.detail;
            this.isAddButtonDisabled = (field.length === 0 && field.operation == null);
        }catch(error){
            errorDebugger('ListingManagerFilterCmp', 'handleFieldChange', error, 'warn', 'Error in handleFieldChange');
        }
    }

    /**
    * Method Name: openModal
    * @description: open the modal.
    * Date: 14/06/2024
    * Created By: Vyom Soni
    */
    openModal(){
        this.addModal = true;
        if(this.screenWidth <= 900){
        this.modalValue = true;
        this.handleAddButtonChange();
        }
    }
    
    /**
    * Method Name: handleAddButtonChange
    * @description: set the pop-modal visiblity in the parent component.
    * Date: 14/06/2024
    * Created By: Vyom Soni
    */
    handleAddButtonChange(){
        const customEvent = new CustomEvent('modalvaluechange', {
            detail:  this.modalValue
        });
        this.dispatchEvent(customEvent);
    }

    // Add this method to update displayIndex for filterFields
    updateFilterIndices() {
        this.filterFields = this.filterFields.map((field, index) => ({
            ...field,
            displayIndex: index + 1
        }));
    }

    handleApplyCustomLogic() {
        try {
            this.validateCustomLogic();
            if (!this.customLogicError) {
                this.applyFilters();
            }
        } catch (error) {
            console.log('Error in handleApplyCustomLogic:', error.stack);
            errorDebugger('ListingManagerFilterCmp', 'handleApplyCustomLogic', error, 'warn', 'Error in handleApplyCustomLogic');
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error Applying Custom Logic',
                    message: 'An error occurred while applying custom logic. Please check your expression and try again.',
                    variant: 'error',
                })
            );
        }
    }

    /**
     * Method Name: handleCustomLogicToggle
     * @description: Handle the custom logic checkbox toggle and set default logic string
     * Date: 14/06/2024
     * Created By: Vyom Soni
     */
    handleCustomLogicToggle(event) {
        try {
            this.isCustomLogicEnabled = event.target.checked;
            if (this.isCustomLogicEnabled) {
                // Generate default logic string based on filters with selected values
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

                // Create default logic string, e.g., "2 AND 3 AND 4"
                this.customLogicExpression = requiredIndices.length > 0 
                    ? requiredIndices.join(' AND ') 
                    : '';
                this.customLogicError = null;
            } else {
                // Clear expression and error when custom logic is disabled
                this.customLogicExpression = '';
                this.customLogicError = null;
                this.applyFilters();
            }
        } catch (error) {
            console.log('Error in handleCustomLogicToggle:', error.stack);
            errorDebugger('ListingManagerFilterCmp', 'handleCustomLogicToggle', error, 'warn', 'Error in handleCustomLogicToggle');
        }
    }

    handleCustomLogicChange(event) {
        try {
            this.customLogicExpression = event.target.value;
            // this.validateCustomLogic();
            // No validation or filtering here; wait for Apply button click
        } catch (error) {
            console.log('Error in handleCustomLogicChange:', error.stack);
            errorDebugger('ListingManagerFilterCmp', 'handleCustomLogicChange', error, 'warn', 'Error in handleCustomLogicChange');
        }
    }

    validateCustomLogic() {
        try {
            if (!this.customLogicExpression) {
                this.customLogicError = null;
                return;
            }

            // Normalize the expression to uppercase for validation, preserve original for display
            const normalizedExpression = this.customLogicExpression.replace(/\s+/g, ' ').trim().toUpperCase();

            // Basic validation for allowed characters (numbers, spaces, parentheses, AND, OR)
            const validPattern = /^[\d\s()]+((AND|OR)[\d\s()]+)*$/i;
            if (!validPattern.test(normalizedExpression)) {
                this.customLogicError = 'Invalid characters in custom logic expression. Use numbers, AND, OR, spaces, and parentheses only.';
                return;
            }

            // Token-based validation for operator placement
            const tokens = normalizedExpression.split(' ').filter(token => token !== '');
            for (let i = 0; i < tokens.length; i++) {
                if (['AND', 'OR'].includes(tokens[i])) {
                    // Operators must be between two valid tokens (number or parenthesis)
                    if (i === 0 || i === tokens.length - 1) {
                        this.customLogicError = `Operator ${tokens[i]} cannot be at the start or end of the expression.`;
                        return;
                    }
                    if (!(/\d+/.test(tokens[i - 1]) || tokens[i - 1] === ')') || 
                        !(/\d+/.test(tokens[i + 1]) || tokens[i + 1] === '(')) {
                        this.customLogicError = `Operator ${tokens[i]} must be between numbers or parenthesized expressions.`;
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

            // Extract unique indices from the custom logic expression
            const usedIndices = [...new Set(this.customLogicExpression.match(/\d+/g) || [])];

            // If no filters have selected values, expression should be empty
            if (requiredIndices.length === 0 && usedIndices.length > 0) {
                this.customLogicError = 'No filters have selected values, but indices are included in the expression.';
                return;
            }

            // Check if all required indices are included
            const missingIndices = requiredIndices.filter(index => !usedIndices.includes(index));
            if (missingIndices.length > 0) {
                this.customLogicError = `Custom logic must include all filters with selected values. Missing indices: ${missingIndices.join(', ')}.`;
                return;
            }

            // Check if any used indices correspond to filters without selected values
            const invalidIndices = usedIndices.filter(index => !requiredIndices.includes(index));
            if (invalidIndices.length > 0) {
                this.customLogicError = `Custom logic includes indices without selected values: ${invalidIndices.join(', ')}.`;
                return;
            }

            // Check if used indices are within valid range (1 to filterFields.length)
            const maxIndex = this.filterFields.length;
            for (let index of usedIndices) {
                if (parseInt(index) > maxIndex || parseInt(index) < 1) {
                    this.customLogicError = `Invalid filter index ${index}. Use indices from 1 to ${maxIndex}.`;
                    return;
                }
            }

            // Basic syntax check for balanced parentheses
            let openParens = 0;
            for (let char of this.customLogicExpression) {
                if (char === '(') openParens++;
                if (char === ')') openParens--;
                if (openParens < 0) {
                    this.customLogicError = 'Unbalanced parentheses in custom logic expression.';
                    return;
                }
            }
            if (openParens !== 0) {
                this.customLogicError = 'Unbalanced parentheses in custom logic expression.';
                return;
            }

            this.customLogicError = null;
        } catch (error) {
            console.log('Error in validateCustomLogic:', error.stack);
            errorDebugger('ListingManagerFilterCmp', 'validateCustomLogic', error, 'warn', 'Error in validateCustomLogic');
            this.customLogicError = 'Error validating custom logic expression.';
        }
    }
    
}