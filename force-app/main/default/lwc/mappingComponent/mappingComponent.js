import { LightningElement, track } from 'lwc';
import getObjectFields from '@salesforce/apex/DynamicMappingCmp.getObjectFields';
import saveMappings from '@salesforce/apex/DynamicMappingCmp.saveMappings';
import getMetadata from '@salesforce/apex/DynamicMappingCmp.getMetadata';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/leadassignmentcss';
import { NavigationMixin } from 'lightning/navigation';
import { errorDebugger } from 'c/globalProperties';

export default class MappingComponent extends NavigationMixin(LightningElement)  {
    @track listingOptions = [];
    @track inquiryOptions = [];
    @track mainListingOptions = [];
    @track mainInquiryOptions = [];
    @track isLoading = false;
    @track showConfirmationModal = false;
    @track logicalConditionListing = '';
    @track logicalConditionInquiry = '';
    @track isSaveButtonDisabled = true;
    @track isModalOpen = false;
    @track selectedConditionTypeInquiry = 'any';
    @track selectedConditionTypeListing = 'any';
    @track setScroll = false;
    @track inquiryObject = 'MVEX__Inquiry__c';
    @track listingObject = 'MVEX__Listing__c';

    @track modalType = '';

    @track selectedListingFields = [];
    @track selectedInquiryFields = [];

    @track activeSections = ['listingSection'];
    // @track activeSectionsExample = ['Example-1'];

    @track listingDropDownPairs = [];
    @track inquiryDropDownPairs = [];

    @track listingLogicError = null;
    @track inquiryLogicError = null;
    @track isDirectAccess = false;

    @track conditionsOptions = [
        { label: 'Greater Than', value: 'greaterThan', type: 'DOUBLE', type2: 'DOUBLE' },
        { label: 'Less Than', value: 'lessThan', type: 'DOUBLE', type2: 'DOUBLE' },
        { label: 'Equal To', value: 'equalTo', type: 'DOUBLE', type2: 'TEXT' },
        { label: 'Not Equal To', value: 'notEqualTo', type: 'DOUBLE', type2: 'TEXT' }, // new added
        { label: 'Contains', value: 'contains', type: 'TEXT', type2: 'TEXT' },
        { label: 'Not Contains', value: 'notContains', type: 'TEXT', type2: 'TEXT' } // new added
    ];

    @track objectOptions = [
        { label: 'Listing', value: 'MVEX__Listing__c' },
        { label: 'Inquiry', value: 'MVEX__Inquiry__c' }
    ];

    get inquiryDropDownPairsWithIndex(){
        return this.inquiryDropDownPairs.map((pair, index) => ({
            ...pair,
            displayIndex: index + 1
            }));
    }

    get listingDropDownPairsWithIndex(){
        return this.listingDropDownPairs.map((pair, index) => ({
            ...pair,
            displayIndex: index + 1
        }));
    }

    get conditionTypeOptions() {
        return [
            { label: 'Select Any Condition', value: 'any' },
            { label: 'Select All Conditions', value: 'all' },
            { label: 'Custom Logic', value: 'custom' }
        ];
    }

    get isListingdropDownAvaialble(){
        return this.listingDropDownPairs.length > 0;
    }

    get isInquirydropDownAvailable(){
        return this.inquiryDropDownPairs.length > 0;
    }

    get selectedConditionLabel() {
        switch (this.selectedConditionTypeListing) {
            case 'any':
                return 'Any Condition';
            case 'all':
                return 'All Conditions';
            case 'custom':
                return 'Custom Logic';
            default:
                return 'None';
        }
    }

    get selectedConditionLabelinquiry() {
        switch (this.selectedConditionTypeInquiry) {
            case 'any':
                return 'Any Condition';
            case 'all':
                return 'All Conditions';
            case 'custom':
                return 'Custom Logic';
            default:
                return 'None';
        }
    }

    
    get isCustomLogicSelectedListing (){
        return this.selectedConditionTypeListing === 'custom';
    }

    get isCustomLogicSelectedInquiry (){
        return this.selectedConditionTypeInquiry === 'custom';
    }

    get isModalListing(){
        return this.modalType === 'MVEX__Listing__c';
    }

    get saveButtonDisabled(){
        const areAllFieldsSelectedListings = this.listingDropDownPairs.every(pair => 
            pair.selectedFirst && pair.selectedSecond
        );
    
        const areAllFieldsSelectedInquiries = this.inquiryDropDownPairs.every(pair => 
            pair.selectedFirst && pair.selectedSecond
        );
    
        const areAllFieldsSelected = areAllFieldsSelectedListings && areAllFieldsSelectedInquiries;

        return this.isSaveButtonDisabled || !areAllFieldsSelected;
    }
    
    connectedCallback() {
        // Check if accessed directly via URL
        if (typeof window !== 'undefined') {
            const currentUrl = window.location.href;
            if (currentUrl.includes('MVEX__Map_Listing_and_Inquiry')) {
                this.isDirectAccess = true;
                this.isLoading = false;
                return;
            }
        }
        
        this.isLoading = true;
        loadStyle(this, MulishFontCss);
        getObjectFields({ objectName: 'MVEX__Listing__c' })
            .then((data) => {

                this.handleListingObjectFields(data);
                if (this.mainListingOptions.length !== 0) {
                    this.callInquiryFields();
                }
            })
            .catch((error) => {
                errorDebugger('MappingComponent', 'getObjectFields', error, 'warn', 'Error in getObjectFields');
                this.showToast('Error', 'Error fetching Listing field data', 'error');
                this.isLoading = false;
            });
    }

    renderedCallback(){
        if(this.setScroll){
            const container = this.template.querySelector('.table-content');
            container.scrollTop = container.scrollHeight;
            this.setScroll = false;
        }
    }
    
    callInquiryFields() {
        getObjectFields({ objectName: 'MVEX__Inquiry__c' })
            .then((data) => {
                this.handleInquiryObjectFields(data);
                if (this.mainInquiryOptions.length !== 0) {
                    this.getMetadataFunction();
                }
            })
            .catch((error) => {
                errorDebugger('MappingComponent', 'callInquiryFields', error, 'warn', 'Error in callInquiryFields');
                this.showToast('Error', 'Error fetching Inquiry field data', 'error');
                this.isLoading = false;
            });
    }

    handleListingObjectFields(data) {

        if (data) {
            this.mainListingOptions = data.map((field) => ({
                label: field.label,
                value: field.apiName,
                dataType: field.dataType
            }));
            this.listingOptions = [...this.mainListingOptions];
        }
    }

    handleInquiryObjectFields(data) {

        if (data) {
            this.mainInquiryOptions = data.map((field) => ({
                label: field.label,
                value: field.apiName,
                dataType: field.dataType
            }));
            this.inquiryOptions = [...this.mainInquiryOptions];
        }
    }

    getMetadataFunction() {
        getMetadata()
            .then((result) => {

                if (result[0] != null) { 
                    this.parseAndSetMappings(result[0]);
                }

                const listingLogic = result[1];
                const listingCondition = result[2];
                const inquiryLogic = result[3];
                const inquiryCondition = result[4];

                this.selectedConditionTypeListing = listingCondition;
                this.selectedConditionTypeInquiry = inquiryCondition;

                if(listingCondition === 'custom'){
                    this.logicalConditionListing = listingLogic == 'empty' ? '' : listingLogic;
                }

                if(inquiryCondition === 'custom'){
                    this.logicalConditionInquiry = inquiryLogic === 'empty' ? '' : inquiryLogic;
                }

            })
            .catch((error) => {
                errorDebugger('MappingComponent', 'getMetadataFunction', error, 'warn', 'Error in getMetadataFunction');
                this.showToast('Error', 'Error fetching metadata', 'error');
                this.isLoading = false;
            });
    }

    parseAndSetMappings(mappingString) {

        const mappings = mappingString.split(';');
        mappings.forEach((mapping) => {
            const [selectedObject, selectedFirst, condition, selectedSecond] = mapping.split(':');
            if (selectedObject === 'MVEX__Listing__c') {
                this.addNewListingPair(selectedFirst, selectedSecond, condition);
            } else if (selectedObject === 'MVEX__Inquiry__c') {
                this.addNewInquiryPair(selectedFirst, selectedSecond, condition);
            }
        });

        this.isLoading = false;
    }

    addNewListingPair(selectedFirst, selectedSecond, condition) {
        let listingFields = [];
        let inquiryFields = [];

        const newPair = {
            id: this.listingDropDownPairs.length,
            selectedFirst,
            selectedSecond,
            selectedCondition: condition,
            conditionsOptions: this.filterConditionOptions(selectedFirst),
            firstOptions: this.mainListingOptions,
            secondOptions: this.mainInquiryOptions,
        };
        this.listingDropDownPairs.push(newPair);
        listingFields.push(selectedFirst);
        inquiryFields.push(selectedSecond);
    }

    addNewInquiryPair(selectedFirst, selectedSecond, condition) {
        let listingFields = [];
        let inquiryFields = [];

        const newPair = {
            id: this.inquiryDropDownPairs.length,
            selectedFirst,
            selectedSecond,
            selectedCondition: condition,
            conditionsOptions: this.filterConditionOptions(selectedFirst),
            firstOptions: this.mainInquiryOptions,
            secondOptions: this.mainListingOptions,
        };
        this.inquiryDropDownPairs.push(newPair);
        listingFields.push(selectedSecond);
        inquiryFields.push(selectedFirst);
    }

    updateFilteredOptions() {
        try {
            const selectedListingFields = new Set();
            const selectedInquiryFields = new Set();
    
            this.listingDropDownPairs.forEach(pair => {
                if (pair.selectedFirst) {
                    selectedListingFields.add(pair.selectedFirst);
                }
                if (pair.selectedSecond) {
                    selectedInquiryFields.add(pair.selectedSecond);
                }
            });
    
            this.inquiryDropDownPairs.forEach(pair => {
                if (pair.selectedFirst) {
                    selectedInquiryFields.add(pair.selectedFirst);
                }
                if (pair.selectedSecond) {
                    selectedListingFields.add(pair.selectedSecond);
                }
            });
    
            // Check if any selectedFirst or selectedSecond field is no longer available, reset if needed
            this.listingDropDownPairs = this.listingDropDownPairs.map((pair, index) => {
                if (pair.selectedFirst && !pair.firstOptions.find(option => option.value === pair.selectedFirst)) {
                    this.listingDropDownPairs[index].selectedFirst = '';
                }
                if (pair.selectedSecond && !pair.secondOptions.find(option => option.value === pair.selectedSecond)) {
                    this.listingDropDownPairs[index].selectedSecond = '';
                }
                return pair;
            });
    
            this.inquiryDropDownPairs = this.inquiryDropDownPairs.map((pair, index) => {
                if (pair.selectedFirst && !pair.firstOptions.find(option => option.value === pair.selectedFirst)) {
                    this.inquiryDropDownPairs[index].selectedFirst = '';
                }
                if (pair.selectedSecond && !pair.secondOptions.find(option => option.value === pair.selectedSecond)) {
                    this.inquiryDropDownPairs[index].selectedSecond = '';
                }
                return pair;
            });
    
            this.listingDropDownPairs = [...this.listingDropDownPairs];
            this.inquiryDropDownPairs = [...this.inquiryDropDownPairs];
        } catch (error) {
            errorDebugger('MappingComponent', 'updateFilteredOptions', error, 'warn', 'Error in updateFilteredOptions');
        }
    }
    
    
    handleModalOpen(event){
        const selectedObject = event.target.dataset.object;
        this.modalType = selectedObject;
        this.isModalOpen = true;
    }

    hideModalBox(){
        this.isModalOpen = false;
    }

    handleFirstFieldChange(event) {
        try {
            const index = event.target.dataset.index;
            const selectedFirst = event.target.value;
            const selectedObject = event.target.dataset.object;
            let filteredSecondOptions = [];
    
            // Handle logic for MVEX__Listing__c
            if (selectedObject === 'MVEX__Listing__c') {
                const selectedFirstField = this.listingOptions.find(option => option.value === selectedFirst);
                const selectedFirstDataType = selectedFirstField ? selectedFirstField.dataType : null;
                filteredSecondOptions = this.mainInquiryOptions.filter(option => option.dataType === selectedFirstDataType);
    
                // Update listingDropDownPairs
                this.listingDropDownPairs = this.listingDropDownPairs.map((pair, i) => {
                    if (i === parseInt(index, 10)) {
                        return {
                            ...pair,
                            selectedFirst,
                            secondOptions: filteredSecondOptions,
                            conditionsOptions: this.filterConditionOptions(selectedFirst),
                            selectedSecond: '',  // Reset second field
                            selectedCondition: ''  // Reset condition field
                        };
                    }
                    return pair;
                });
    
            // Handle logic for MVEX__Inquiry__c
            } else if (selectedObject === 'MVEX__Inquiry__c') {
                const selectedFirstField = this.inquiryOptions.find(option => option.value === selectedFirst);
                const selectedFirstDataType = selectedFirstField ? selectedFirstField.dataType : null;
                filteredSecondOptions = this.mainListingOptions.filter(option => option.dataType === selectedFirstDataType);
    
                // Update inquiryDropDownPairs
                this.inquiryDropDownPairs = this.inquiryDropDownPairs.map((pair, i) => {
                    if (i === parseInt(index, 10)) {
                        return {
                            ...pair,
                            selectedFirst,
                            secondOptions: filteredSecondOptions,
                            conditionsOptions: this.filterConditionOptions(selectedFirst),
                            selectedSecond: '',  // Reset second field
                            selectedCondition: ''  // Reset condition field
                        };
                    }
                    return pair;
                });
            }
    
            this.updateSaveButtonState(); 
        } catch (error) {
            errorDebugger('MappingComponent', 'handleFirstFieldChange', error, 'warn', 'Error in handleFirstFieldChange');
        }
    }
    

    handleConditionChange(event) {
        try {
            const index = event.target.dataset.index;
            const selectedCondition = event.target.value;
            const selectedObject = event.target.dataset.object;
    
            if (selectedObject === 'MVEX__Listing__c') {
                this.listingDropDownPairs = this.listingDropDownPairs.map((pair, i) => {
                    if (i === parseInt(index, 10)) {
                        return { ...pair, selectedCondition };
                    }
                    return pair;
                });
            } else if (selectedObject === 'MVEX__Inquiry__c') {
                this.inquiryDropDownPairs = this.inquiryDropDownPairs.map((pair, i) => {
                    if (i === parseInt(index, 10)) {
                        return { ...pair, selectedCondition };
                    }
                    return pair;
                });
            }
    
            this.updateSaveButtonState();
        } catch (error) {
            errorDebugger('MappingComponent', 'handleConditionChange', error, 'warn', 'Error in handleConditionChange');
        }
    }
    
    handleSecondFieldChange(event) {
        try {
            const index = event.target.dataset.index;
            const selectedSecond = event.target.value;
            const selectedObject = event.target.dataset.object;
    
            if (selectedObject === 'MVEX__Listing__c') {
                // Update second field for listingDropDownPairs
                this.listingDropDownPairs = this.listingDropDownPairs.map((pair, i) => {
                    if (i === parseInt(index, 10)) {
                        return { ...pair, selectedSecond };
                    }
                    return pair;
                });
            } else if (selectedObject === 'MVEX__Inquiry__c') {
                // Update second field for inquiryDropDownPairs
                this.inquiryDropDownPairs = this.inquiryDropDownPairs.map((pair, i) => {
                    if (i === parseInt(index, 10)) {
                        return { ...pair, selectedSecond };
                    }
                    return pair;
                });
            }
    
            this.updateSaveButtonState();
        } catch (error) {
            errorDebugger('MappingComponent', 'handleSecondFieldChange', error, 'warn', 'Error in handleSecondFieldChange');
        }
    }
    

    filterConditionOptions(selectedFirst) {

        try {
            if (!selectedFirst) return this.conditionsOptions;
    
            const selectedFirstField = this.listingOptions.find(option => option.value === selectedFirst) || 
                                       this.inquiryOptions.find(option => option.value === selectedFirst);
        
            if (selectedFirstField) {
                if (selectedFirstField.dataType === 'DOUBLE' || selectedFirstField.dataType === 'CURRENCY' || selectedFirstField.dataType === 'DATETIME') {
                    return this.conditionsOptions.filter(option => option.type === 'DOUBLE');
                } else {
                    return this.conditionsOptions.filter(option => option.type === 'TEXT' || option.type2 === 'TEXT');
                }
            }
            return this.conditionsOptions;
        } catch (error) {
            errorDebugger('MappingComponent', 'filterConditionOptions', error, 'warn', 'Error in filterConditionOptions');
        }

    }

    updateSaveButtonState() {
        try {
            const allNotEmptyListings = this.listingDropDownPairs.every(pair => 
                pair.selectedFirst != '' && pair.selectedSecond != '' && pair.selectedCondition != ''
            );
    
            const allNotEmptyInquiries = this.inquiryDropDownPairs.every(pair => 
                pair.selectedFirst != '' && pair.selectedSecond != '' && pair.selectedCondition != ''
            );

    
            const allNotEmpty = allNotEmptyListings && allNotEmptyInquiries;
            this.isSaveButtonDisabled = !allNotEmpty;
        } catch (error) {
            errorDebugger('MappingComponent', 'updateSaveButtonState', error, 'warn', 'Error in updateSaveButtonState');
        }
    }
    

    deletePair(event) {
        const index = event.currentTarget.dataset.id;
        const selectedObject = event.currentTarget.dataset.object;
    
        if (selectedObject === 'MVEX__Listing__c') {
            this.listingDropDownPairs.splice(index, 1);
            this.filterAndUpdateOptions(); 
        } else if (selectedObject === 'MVEX__Inquiry__c') {
            this.inquiryDropDownPairs.splice(index, 1);
            this.filterAndUpdateOptions(); 
        }
    
        this.updateSaveButtonState();
    }
    

    addNewPairlisting() {
        const selectedObject = 'MVEX__Listing__c';
        const isInquiry = selectedObject === 'MVEX__Inquiry__c';

        this.listingDropDownPairs.push({
            id: this.listingDropDownPairs.length,
            selectedObject : selectedObject,
            firstOptions: isInquiry ? this.inquiryOptions : this.listingOptions,
            secondOptions: isInquiry ? this.listingOptions : this.inquiryOptions,
            selectedFirst: '',
            selectedSecond: '',
            selectedCondition: '',
            conditionsOptions : this.conditionsOptions,
            firstlabel: isInquiry ? 'Inquiry Field' : 'Listing Field',
            secondlabel: isInquiry ? 'Listing Field' : 'Inquiry Field',
        });
        this.filterAndUpdateOptions();
        this.updateSaveButtonState();
        this.setScroll = true;
    }

    addNewPairInquiry() {
        const selectedObject = 'MVEX__Inquiry__c';
        const isInquiry = selectedObject === 'MVEX__Inquiry__c';

        this.inquiryDropDownPairs.push({
            id: this.inquiryDropDownPairs.length,
            selectedObject : selectedObject,
            firstOptions: isInquiry ? this.inquiryOptions : this.listingOptions,
            secondOptions: isInquiry ? this.listingOptions : this.inquiryOptions,
            selectedFirst: '',
            selectedSecond: '',
            selectedCondition: '',
            conditionsOptions : this.conditionsOptions,
            firstlabel: isInquiry ? 'Inquiry Field' : 'Listing Field',
            secondlabel: isInquiry ? 'Listing Field' : 'Inquiry Field',
        });
        this.filterAndUpdateOptions();
        this.updateSaveButtonState();
        this.setScroll = true;
    }

    filterAndUpdateOptions() {
        try {
    
            this.listingDropDownPairs.forEach((pair, index) => {
                if (pair.selectedFirst && !pair.firstOptions.find(option => option.value === pair.selectedFirst)) {
                    this.listingDropDownPairs[index].selectedFirst = '';
                }
                if (pair.selectedSecond && !pair.secondOptions.find(option => option.value === pair.selectedSecond)) {
                    this.listingDropDownPairs[index].selectedSecond = '';
                }
            });
    
            this.inquiryDropDownPairs.forEach((pair, index) => {
                if (pair.selectedFirst && !pair.firstOptions.find(option => option.value === pair.selectedFirst)) {
                    this.inquiryDropDownPairs[index].selectedFirst = '';
                }
                if (pair.selectedSecond && !pair.secondOptions.find(option => option.value === pair.selectedSecond)) {
                    this.inquiryDropDownPairs[index].selectedSecond = '';
                }
            });
    
        } catch (error) {
            errorDebugger('MappingComponent', 'filterAndUpdateOptions', error, 'warn', 'Error in filterAndUpdateOptions');
        }
    }
    

    handleAddPairClick() {

        const hasDuplicateInArray = (currentMappings) => {
            let mappingSet = new Set();
            return currentMappings.some(mapping => {
                const key = `${mapping.selectedFirst}-${mapping.selectedSecond}-${mapping.selectedCondition}`;
                if (mappingSet.has(key)) {
                    return true; 
                }
                mappingSet.add(key);
                return false;
            });
        };

        if (hasDuplicateInArray(this.inquiryDropDownPairs)) {
            this.showToast('Error', 'Duplicate mapping found in Inquiry! Please select different fields and conditions.', 'error');
            return;
        }    

        if (hasDuplicateInArray(this.listingDropDownPairs)) {
            this.showToast('Error', 'Duplicate mapping found in Listing! Each combination must be unique.', 'error');
            return;
        }   


        if(this.listingDropDownPairs.length < 2 || this.inquiryDropDownPairs.length < 2){
            this.showToast('Error', 'Add atleast two mapping in both objects', 'error');
            this.isSaveButtonDisabled = true;
            return;
        }

        let isCorrecySyntaxListing = true;

        let isCorrecySyntaxInquiry = true;

        if(this.selectedConditionTypeListing === 'custom'){
            this.validateCustomLogic();
            isCorrecySyntaxListing = !this.listingLogicError;
            if (!isCorrecySyntaxListing) {
                this.showToast('Error', 'Invalid custom logic for Listing. Please check the logical expression.', 'error');
                this.isSaveButtonDisabled = true;
                return;
            }
        }

        if(this.selectedConditionTypeInquiry === 'custom'){
            this.validateCustomLogic();
            isCorrecySyntaxInquiry = !this.inquiryLogicError;
            if (!isCorrecySyntaxInquiry) {
                this.showToast('Error', 'Invalid custom logic for Inquiry. Please check the logical expression.', 'error');
                this.isSaveButtonDisabled = true;
                return;
            }
        }

        if(isCorrecySyntaxListing && isCorrecySyntaxInquiry){
            this.showConfirmationModal = true;
        }

    }

    handleConfirmAddPair() {
        const areAllFieldsSelectedListings = this.listingDropDownPairs.every(pair => 
            pair.selectedFirst && pair.selectedSecond
        );
    
        const areAllFieldsSelectedInquiries = this.inquiryDropDownPairs.every(pair => 
            pair.selectedFirst && pair.selectedSecond
        );
    
        const areAllFieldsSelected = areAllFieldsSelectedListings && areAllFieldsSelectedInquiries;
    
        if (areAllFieldsSelected) {
            this.isLoading = true;
    
            const data = [
                ...this.listingDropDownPairs.map((pair) =>
                    `${this.listingObject}:${pair.selectedFirst}:${pair.selectedCondition}:${pair.selectedSecond}`
                ),
                ...this.inquiryDropDownPairs.map((pair) =>
                    `${this.inquiryObject}:${pair.selectedFirst}:${pair.selectedCondition}:${pair.selectedSecond}`
                )
            ].join(';');
    
            if (this.logicalConditionListing === '' || this.selectedConditionTypeListing !== 'custom') {
                this.logicalConditionListing = '';
            }
    
            if(this.logicalConditionInquiry === '' || this.selectedConditionTypeInquiry !== 'custom'){
                this.logicalConditionInquiry = '';
            }
            saveMappings({ mappingsData: data, listingLogic: this.logicalConditionListing, conditionValueListing: this.selectedConditionTypeListing , inquiryLogic : this.logicalConditionInquiry , conditionValueInquiry: this.selectedConditionTypeInquiry})
                .then(() => {
                    this.showToast('Success', 'Mappings saved successfully', 'success');
                    this.showConfirmationModal = false;
                    this.isLoading = false;
                    this.isSaveButtonDisabled = true;
                })
                .catch((error) => {
                    errorDebugger('MappingComponent', 'handleConfirmAddPair', error, 'warn', 'Error in handleConfirmAddPair');
                    this.showToast('Error', 'Error saving mappings', 'error');
                    this.isLoading = false;
                });
        } else {
            this.showConfirmationModal = false;
            this.isSaveButtonDisabled = true;
            this.showToast('Error', 'Please complete all empty fields.', 'error');
        }
    }
    

    closeConfirmationModal() {
        this.showConfirmationModal = false;
    }

    showToast(title, message, variant) {
        if (typeof window !== 'undefined') {
            const event = new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            });
            this.dispatchEvent(event);
        }
    }

    handleConditionTypeChange(event) {
        const selectedObject = event.target.dataset.name;
        if(selectedObject === 'listing'){
            this.selectedConditionTypeListing = event.target.value;
            if (this.selectedConditionTypeListing === 'custom') {
                // Generate default logic string for listing
                const requiredIndices = this.listingDropDownPairs
                    .map((pair, index) => pair.selectedFirst && pair.selectedSecond && pair.selectedCondition ? index + 1 : null)
                    .filter(index => index !== null);
                this.logicalConditionListing = requiredIndices.length > 0 ? requiredIndices.join(' AND ') : '';
                this.listingLogicError = null;
            } else {
                this.logicalConditionListing = '';
                this.listingLogicError = null;
            }
        } else {
            this.selectedConditionTypeInquiry = event.target.value;
            if (this.selectedConditionTypeInquiry === 'custom') {
                // Generate default logic string for inquiry
                const requiredIndices = this.inquiryDropDownPairs
                    .map((pair, index) => pair.selectedFirst && pair.selectedSecond && pair.selectedCondition ? index + 1 : null)
                    .filter(index => index !== null);
                this.logicalConditionInquiry = requiredIndices.length > 0 ? requiredIndices.join(' AND ') : '';
                this.inquiryLogicError = null;
            } else {
                this.logicalConditionInquiry = '';
                this.inquiryLogicError = null;
            }
        }
    }

    handleConditionInputChange(event) {
        try {
            const selectedObject = event.target.dataset.name;
            if (selectedObject === 'listing') {
                this.logicalConditionListing = event.target.value;
                this.validateCustomLogic();
            } else {
                this.logicalConditionInquiry = event.target.value;
                this.validateCustomLogic();
            }
        } catch (error) {
            errorDebugger('MappingComponent', 'handleConditionInputChange', error, 'warn', 'Error in handleConditionInputChange');
        }
    }

    validateCustomLogic() {
        try {
            let logicExpression = '';
            let dropDownPairs = [];
            let logicError = null;

            if (this.isModalListing) {
                logicExpression = this.logicalConditionListing;
                dropDownPairs = this.listingDropDownPairs;
                logicError = 'listingLogicError';
            } else {
                logicExpression = this.logicalConditionInquiry;
                dropDownPairs = this.inquiryDropDownPairs;
                logicError = 'inquiryLogicError';
            }

            if (!logicExpression || logicExpression.trim() === '') {
                this[logicError] = 'Custom logic expression cannot be empty.';
                return;
            }

            // Normalize the expression to uppercase for validation
            const normalizedExpression = logicExpression.replace(/\s+/g, ' ').trim().toUpperCase();

            // Basic validation for allowed characters (numbers, spaces, parentheses, AND, OR)
            const validPattern = /^[\d\s()]+((AND|OR)[\d\s()]+)*$/i;
            if (!validPattern.test(normalizedExpression)) {
                this[logicError] = 'Invalid characters in custom logic expression. Use numbers, AND, OR, spaces, and parentheses only.';
                return;
            }

            // Token-based validation for operator placement
            const tokens = normalizedExpression.split(' ').filter(token => token !== '');
            for (let i = 0; i < tokens.length; i++) {
                if (['AND', 'OR'].includes(tokens[i])) {
                    if (i === 0 || i === tokens.length - 1) {
                        this[logicError] = `Operator ${tokens[i]} cannot be at the start or end of the expression.`;
                        return;
                    }
                    if (!(/\d+/.test(tokens[i - 1]) || tokens[i - 1] === ')') || 
                        !(/\d+/.test(tokens[i + 1]) || tokens[i + 1] === '(')) {
                        this[logicError] = `Operator ${tokens[i]} must be between numbers or parenthesized expressions.`;
                        return;
                    }
                }
            }

            // Get indices of pairs with selected values
            const requiredIndices = dropDownPairs
                .map((pair, index) => pair.selectedFirst && pair.selectedSecond && pair.selectedCondition ? (index + 1).toString() : null)
                .filter(index => index !== null);

            // Extract unique indices from the custom logic expression
            const usedIndices = [...new Set(logicExpression.match(/\d+/g) || [])];

            // If no pairs have selected values, expression should be empty
            if (requiredIndices.length === 0 && usedIndices.length > 0) {
                this[logicError] = 'No mappings have selected values, but indices are included in the expression.';
                return;
            }

            // Check if all required indices are included
            const missingIndices = requiredIndices.filter(index => !usedIndices.includes(index));
            if (missingIndices.length > 0) {
                this[logicError] = `Custom logic must include all mappings with selected values. Missing indices: ${missingIndices.join(', ')}.`;
                return;
            }

            // Check if any used indices correspond to pairs without selected values
            const invalidIndices = usedIndices.filter(index => !requiredIndices.includes(index));
            if (invalidIndices.length > 0) {
                this[logicError] = `Custom logic includes indices without selected values: ${invalidIndices.join(', ')}.`;
                return;
            }

            // Check if used indices are within valid range (1 to dropDownPairs.length)
            const maxIndex = dropDownPairs.length;
            for (let index of usedIndices) {
                if (parseInt(index) > maxIndex || parseInt(index) < 1) {
                    this[logicError] = `Invalid mapping index ${index}. Use indices from 1 to ${maxIndex}.`;
                    return;
                }
            }

            // Basic syntax check for balanced parentheses
            let openParens = 0;
            for (let char of logicExpression) {
                if (char === '(') openParens++;
                if (char === ')') openParens--;
                if (openParens < 0) {
                    this[logicError] = 'Unbalanced parentheses in custom logic expression.';
                    return;
                }
            }
            if (openParens !== 0) {
                this[logicError] = 'Unbalanced parentheses in custom logic expression.';
                return;
            }

            this[logicError] = null;
        } catch (error) {
            errorDebugger('MappingComponent', 'validateCustomLogic', error, 'warn', 'Error in validateCustomLogic');
            this[this.isModalListing ? 'listingLogicError' : 'inquiryLogicError'] = 'Error validating custom logic expression.';
        }
    }

    checkConditionSyntax() {
        try {
            this.validateCustomLogic();
            let currentError = this[this.isModalListing ? 'listingLogicError' : 'inquiryLogicError'];
            if (!currentError) {
                this.showToast('Success', 'Logical Condition is Correct', 'success');
                this.isModalOpen = false;
                this.isSaveButtonDisabled = false;
            } else {
                this.showToast('Error', currentError, 'error');
                this.isSaveButtonDisabled = true;
            }
        } catch (error) {
            errorDebugger('MappingComponent', 'checkConditionSyntax', error, 'warn', 'Error in checkConditionSyntax');
            this.showToast('Error', 'Error validating custom logic', 'error');
        }
    }
    
    checkcondition() {
        this.validateCustomLogic();
        return !this[this.isModalListing ? 'listingLogicError' : 'inquiryLogicError'];
    }

    /**
    * Method Name : scrollToTop
    * @description : scroll to top in list
    * * Date: 03/08/2024
    * Created By:Vyom Soni
    */
    scrollToTop() {
        try{
            const tableDiv = this.template.querySelector('.table-content');
            if (tableDiv) {
                // tableDiv.scrollTop = 100;
                tableDiv.scrollTop = tableDiv.scrollHeight;
            }
        }catch(error){
            errorDebugger('MappingComponent', 'scrollToTop', error, 'warn', 'Error in scrollToTop');
        }
    }

     /**
    * Method Name: backToControlCenter
    * @description: Used to Navigate to the main ControlCenter page.
    * Date: 03/08/2024
    * Created By: Vyom Soni
    */
    backToControlCenter(event) {
        try {
            event.preventDefault();
            this[NavigationMixin.Navigate]({
                type: "standard__navItemPage",
                attributes: {
                    apiName: "MVEX__Control_Center",
                },
            });
        } catch (error) {
            errorDebugger('MappingComponent', 'backToControlCenter', error, 'warn', 'Error in backToControlCenter');
        }
    }

    closeModalWithEnable() {
        try {
            this.isModalOpen = false;
            this.isSaveButtonDisabled = false;
        } catch (error) {
            errorDebugger('MappingComponent', 'closeModalWithEnable', error, 'warn', 'Error in closeModalWithEnable');
        }
    }
    
}