import { LightningElement, track, api } from 'lwc';
import getObjectFields from '@salesforce/apex/GoogleLeadFieldMappingController.getObjectFields';
import saveMappings from '@salesforce/apex/GoogleLeadFieldMappingController.saveMappings';
import getMetadata from '@salesforce/apex/GoogleLeadFieldMappingController.getMetadata';
import getGoogleAdsFieldsJson from '@salesforce/apex/GoogleLeadFieldMappingController.getSocialMediaFieldsJson';
import saveGoogleAdsFieldsJson from '@salesforce/apex/GoogleLeadFieldMappingController.saveSocialMediaFieldsJson';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import externalCss from '@salesforce/resourceUrl/templateCss';
import { NavigationMixin } from 'lightning/navigation';
import { errorDebugger } from 'c/globalProperties';

export default class GoogleLeadFieldMapping extends NavigationMixin(LightningElement) {
    @api integrationType = 'Google'; // Default to Google
    @track dropDownPairs = [];
    @track salesforceOptions = [];
    @track mainSalesforceOptions = [];
    @track updateSalesforce = [];
    @track googleFieldOptions = [];
    @track mainGoogleFieldOptions = [];
    @track updateGoogleFields = [];
    @track isLoading = true;
    @track savebutton = true;
    @track showConfirmationModal = false;
    @track showManageFieldsModal = false;
    @track newGoogleFieldLabel = '';
    @track newGoogleFieldValue = '';
    @track isScroll = false;

    get integrationLabel() {
        return this.integrationType === 'Meta' ? 'Meta Ads' : 'Google Ads';
    }

    get dropDownPairsWithIndex() {
        return this.dropDownPairs.map((pair, index) => ({
            ...pair,
            displayIndex: index + 1
        }));
    }

    get isDropDownpairAvailable() {
        return this.dropDownPairs.length > 0;
    }

    connectedCallback() {
        loadStyle(this, externalCss);
        loadStyle(this, MulishFontCss);
        this.getSocialMediaFields();
        this.getMappingMetadata();
    }

    renderedCallback() {
        if (this.isScroll) {
            const container = this.template.querySelector('.table-content');
            if (container) {
                container.scrollTop = container.scrollHeight;
            }
            this.isScroll = false;
        }
    }

    async getSocialMediaFields(isRetry = false) {
        try {
            console.log(`Fetching ${this.integrationLabel} fields, isRetry:`, isRetry);
            const result = await getGoogleAdsFieldsJson({ integrationType: this.integrationType });
            if (result) {
                console.log('result', result);
                
                let fields = JSON.parse(result);
                console.log(`Fetched ${this.integrationLabel} fields:`, JSON.stringify(fields));
                fields = fields.map(field => ({
                    ...field,
                    isCustom: field.isCustom !== undefined ? field.isCustom : false,
                    disable: field.isCustom !== undefined ? !field.isCustom : true
                }));
                this.googleFieldOptions = [...fields.sort((a, b) => a.label.localeCompare(b.label))];
                this.mainGoogleFieldOptions = [...this.googleFieldOptions];
                this.filterAndUpdateGoogleFieldOptions();
            } else {
                console.log(`No ${this.integrationLabel} fields returned, setting empty arrays`);
                this.googleFieldOptions = [];
                this.mainGoogleFieldOptions = [];
            }
        } catch (error) {
            console.error(`Error fetching ${this.integrationLabel} fields:`, error.stack);
            errorDebugger('GoogleLeadFieldMapping', 'getSocialMediaFields', error, 'warn', `Error in getSocialMediaFields for ${this.integrationType}`);
            this.showToast('Error', `Failed to load ${this.integrationLabel} fields`, 'error');
        }
    }

    getMappingMetadata() {
        try {
            // Changed objectName from 'Lead' to 'Contact'
            getObjectFields({ objectName: 'Contact' })
                .then(data => {
                    this.handleSalesforceObjectFields(data);
                    if (this.mainSalesforceOptions.length !== 0) {
                        this.getMetadataFunction();
                    }
                })
                .catch(error => {
                    errorDebugger('GoogleLeadFieldMapping', 'getMappingMetadata', error, 'warn', 'Error in getMappingMetadata');
                });
        } catch (error) {
            errorDebugger('GoogleLeadFieldMapping', 'getMappingMetadata', error, 'warn', 'Error in getMappingMetadata');
        }
    }

    handleSalesforceObjectFields(data) {
        try {
            if (data) {
                this.mainSalesforceOptions = data.map(field => ({
                    label: field.label,
                    value: field.apiName,
                    dataType: field.dataType
                })).sort((a, b) => a.label.localeCompare(b.label));
                this.salesforceOptions = [...this.mainSalesforceOptions];
            }
        } catch (error) {
            errorDebugger('GoogleLeadFieldMapping', 'handleSalesforceObjectFields', error, 'warn', 'Error in handleSalesforceObjectFields');
        }
    }

    getMetadataFunction() {
        try {
            console.log('getMetadataFunction called');
            
            getMetadata({ integrationType: this.integrationType })
                .then(result => {
                    console.log('Metadata result:', JSON.stringify(result));
                    if (result) {
                        
                        this.parseAndSetMappings(result);
                    }
                    this.isLoading = false;
                })
                .catch(error => {
                    errorDebugger('GoogleLeadFieldMapping', 'getMetadataFunction', error, 'warn', 'Error in getMetadataFunction');
                });
        } catch (error) {
            errorDebugger('GoogleLeadFieldMapping', 'getMetadataFunction', error, 'warn', 'Error in getMetadataFunction');
        }
    }

    parseAndSetMappings(mappingJson) {
        try {
            this.isLoading = true;
            if (mappingJson) {
                const mappings = JSON.parse(mappingJson);
                mappings.forEach(mapping => {
                    const newPair = {
                        id: this.dropDownPairs.length,
                        metaField: mapping.metaField,
                        salesforceField: mapping.salesforceField,
                        googleFieldOptions: [...this.googleFieldOptions],
                        salesforceOptions: [...this.salesforceOptions]
                    };
                    this.dropDownPairs.push(newPair);
                });
            }
            this.filterAndUpdateGoogleFieldOptions();
            this.filterAndUpdateSalesforceOptions();
            this.isLoading = false;
        } catch (error) {
            errorDebugger('GoogleLeadFieldMapping', 'parseAndSetMappings', error, 'warn', 'Error in parseAndSetMappings');
        }
    }

    handleGoogleFieldChange(event) {
        try {
            const index = event.target.dataset.index;
            const value = event.detail.value;
            this.dropDownPairs[index].metaField = value;
            this.filterAndUpdateGoogleFieldOptions();
            this.validatePairs();
            this.forceUpdate();
        } catch (error) {
            errorDebugger('GoogleLeadFieldMapping', 'handleGoogleFieldChange', error, 'warn', 'Error in handleGoogleFieldChange');
        }
    }

    handleNewGoogleFieldChange(event) {
        this.newGoogleFieldLabel = event.detail.value;
    }

    handleNewGoogleFieldValueChange(event) {
        this.newGoogleFieldValue = event.detail.value;
    }

    async addGoogleField() {
        try {
            const trimmedLabel = this.newGoogleFieldLabel.trim();
            const trimmedValue = this.newGoogleFieldValue.trim();

            if (!trimmedLabel) {
                this.showToast('Error', 'Field label cannot be empty or contain only whitespace', 'error');
                return;
            }
            if (!trimmedValue) {
                this.showToast('Error', 'Field API name cannot be empty or contain only whitespace', 'error');
                return;
            }

            // const labelRegex = /^[a-zA-Z0-9\s\-_,.()]+$/;
            // if (!labelRegex.test(trimmedLabel)) {
            //     this.showToast('Error', 'Field label can only contain letters, numbers, spaces, hyphens, commas, periods, or parentheses', 'error');
            //     return;
            // }

            // const apiNameRegex = /^[a-zA-Z][a-zA-Z0-9_]*$/;
            // if (!apiNameRegex.test(trimmedValue)) {
            //     this.showToast('Error', 'Field API name must start with a letter and contain only letters, numbers, and underscores', 'error');
            //     return;
            // }

            if (trimmedLabel.length > 100) {
                this.showToast('Error', 'Field label cannot exceed 100 characters', 'error');
                return;
            }
            if (trimmedValue.length > 80) {
                this.showToast('Error', 'Field API name cannot exceed 80 characters', 'error');
                return;
            }

            if (this.googleFieldOptions.some(field => field.value.toLowerCase() === trimmedValue.toLowerCase())) {
                this.showToast('Error', 'Field API name already exists', 'error');
                return;
            }
            if (this.googleFieldOptions.some(field => field.label.toLowerCase() === trimmedLabel.toLowerCase())) {
                this.showToast('Error', 'Field label already exists', 'error');
                return;
            }

            const reservedKeywords = ['id', 'name', 'createddate', 'lastmodifieddate'];
            if (reservedKeywords.includes(trimmedValue.toLowerCase())) {
                this.showToast('Error', 'Field API name cannot be a reserved keyword', 'error');
                return;
            }

            const newField = { 
                label: trimmedLabel, 
                value: trimmedValue, 
                isCustom: true,
                disable: false
            };
            const updatedFields = [...this.googleFieldOptions, newField];
            console.log(`Saving new ${this.integrationLabel} field:`, JSON.stringify(updatedFields));
            await saveGoogleAdsFieldsJson({ fieldsJson: JSON.stringify(updatedFields), integrationType: this.integrationType });
            this.showToast('Success', `${this.integrationLabel} field added successfully`, 'success');
            this.newGoogleFieldLabel = '';
            this.newGoogleFieldValue = '';
            await this.pollForFieldUpdate([...this.googleFieldOptions, newField], 'add');
        } catch (error) {
            console.error(`Error adding ${this.integrationLabel} field:`, error);
            errorDebugger('GoogleLeadFieldMapping', 'addGoogleField', error, 'warn', `Error in addGoogleField for ${this.integrationType}`);
            this.showToast('Error', `Failed to add ${this.integrationLabel} field`, 'error');
        }
    }

    async deleteGoogleField(event) {
        try {
            const fieldValue = event.currentTarget.dataset.value;
            const field = this.googleFieldOptions.find(f => f.value === fieldValue);
            console.log(`Attempting to delete ${this.integrationLabel} field:`, fieldValue, field);
            if (!field.isCustom) {
                this.showToast('Error', `Cannot delete predefined ${this.integrationLabel} field`, 'error');
                return;
            }
            const updatedFields = this.googleFieldOptions.filter(f => f.value !== fieldValue);
            console.log(`Saving updated ${this.integrationLabel} fields after delete:`, JSON.stringify(updatedFields));
            await saveGoogleAdsFieldsJson({ fieldsJson: JSON.stringify(updatedFields), integrationType: this.integrationType });
            this.showToast('Success', `${this.integrationLabel} field deleted successfully`, 'success');
            await this.pollForFieldUpdate(updatedFields, 'delete');
            this.dropDownPairs = this.dropDownPairs.filter(pair => pair.metaField !== fieldValue);
            this.filterAndUpdateGoogleFieldOptions();
            this.filterAndUpdateSalesforceOptions();
            this.validatePairs();
        } catch (error) {
            console.error(`Error deleting ${this.integrationLabel} field:`, error);
            errorDebugger('GoogleLeadFieldMapping', 'deleteGoogleField', error, 'warn', `Error in deleteGoogleField for ${this.integrationType}`);
            this.showToast('Error', `Failed to delete ${this.integrationLabel} field`, 'error');
        }
    }

    async pollForFieldUpdate(expectedFields, action) {
        const maxAttempts = 5;
        const delayMs = 500;
        let attempts = 0;
        console.log(`Polling for ${action} update, expected fields:`, JSON.stringify(expectedFields));

        while (attempts < maxAttempts) {
            try {
                const result = await getGoogleAdsFieldsJson({ integrationType: this.integrationType });
                if (result) {
                    const fetchedFields = JSON.parse(result).map(field => ({
                        ...field,
                        isCustom: field.isCustom !== undefined ? field.isCustom : false,
                        disable: field.isCustom !== undefined ? !field.isCustom : true
                    }));
                    const fetchedValues = fetchedFields.map(f => f.value).sort();
                    const expectedValues = expectedFields.map(f => f.value).sort();
                    console.log('Fetched values:', fetchedValues, 'Expected values:', expectedValues);
                    if (JSON.stringify(fetchedValues) === JSON.stringify(expectedValues)) {
                        console.log('Fields updated successfully, refreshing UI');
                        this.googleFieldOptions = [...fetchedFields.sort((a, b) => a.label.localeCompare(b.label))];
                        this.mainGoogleFieldOptions = [...this.googleFieldOptions];
                        this.filterAndUpdateGoogleFieldOptions();
                        return;
                    }
                }
                attempts++;
                console.log(`Attempt ${attempts} failed, retrying in ${delayMs}ms`);
                await new Promise(resolve => setTimeout(resolve, delayMs));
            } catch (error) {
                console.error('Polling error:', error);
                attempts++;
                await new Promise(resolve => setTimeout(resolve, delayMs));
            }
        }
        console.warn('Polling timed out after', maxAttempts, 'attempts');
    }

    openManageFieldsModal() {
        this.showManageFieldsModal = true;
    }

    closeManageFieldsModal() {
        this.showManageFieldsModal = false;
        this.newGoogleFieldLabel = '';
        this.newGoogleFieldValue = '';
    }

    forceUpdate() {
        this.dropDownPairs = [...this.dropDownPairs];
    }

    handleSalesforceFieldChange(event) {
        try {
            const index = event.target.dataset.index;
            this.dropDownPairs[index].salesforceField = event.detail.value;
            this.filterAndUpdateSalesforceOptions();
            this.validatePairs();
        } catch (error) {
            errorDebugger('GoogleLeadFieldMapping', 'handleSalesforceFieldChange', error, 'warn', 'Error in handleSalesforceFieldChange');
        }
    }

    filterAndUpdateGoogleFieldOptions() {
        try {
            this.updateGoogleFields = [...this.mainGoogleFieldOptions];
            const selectedGoogleFields = this.dropDownPairs.map(pair => pair.metaField);
            this.dropDownPairs = this.dropDownPairs.map(pair => ({
                ...pair,
                googleFieldOptions: this.mainGoogleFieldOptions.filter(option => 
                    !selectedGoogleFields.includes(option.value) || option.value === pair.metaField
                )
            }));
            this.googleFieldOptions = [...this.updateGoogleFields];
            this.updateGoogleFields = [];
            console.log('this.googleFieldOptions'+JSON.stringify(this.googleFieldOptions));
            
        } catch (error) {
            console.log('Error in filterAndUpdateGoogleFieldOptions:', error.stack);
            errorDebugger('GoogleLeadFieldMapping', 'filterAndUpdateGoogleFieldOptions', error, 'warn', 'Error in filterAndUpdateGoogleFieldOptions');
        }
    }

    filterAndUpdateSalesforceOptions() {
        try {
            this.updateSalesforce = [...this.mainSalesforceOptions];
            const selectedSalesforceValues = this.dropDownPairs.map(pair => pair.salesforceField);
            this.dropDownPairs = this.dropDownPairs.map(pair => ({
                ...pair,
                salesforceOptions: this.mainSalesforceOptions.filter(option => 
                    !selectedSalesforceValues.includes(option.value) || option.value === pair.salesforceField
                )
            }));
            this.salesforceOptions = [...this.updateSalesforce];
            this.updateSalesforce = [];
            console.log('this.salesforceOptions'+JSON.stringify(this.salesforceOptions));
            
        } catch (error) {
            console.log('Error in filterAndUpdateSalesforceOptions:', error.stack);
            
            errorDebugger('GoogleLeadFieldMapping', 'filterAndUpdateSalesforceOptions', error, 'warn', 'Error in filterAndUpdateSalesforceOptions');
        }
    }

    validatePairs() {
        const isValid = this.dropDownPairs.every(pair => pair.metaField && pair.salesforceField);
        this.savebutton = !isValid;
    }

    addNewPair() {
        try {
            this.filterAndUpdateGoogleFieldOptions();
            this.filterAndUpdateSalesforceOptions();
            const newPair = {
                id: this.dropDownPairs.length,
                metaField: '',
                salesforceField: '',
                googleFieldOptions: [...this.googleFieldOptions],
                salesforceOptions: [...this.salesforceOptions]
            };
            this.dropDownPairs = [...this.dropDownPairs, newPair];
            console.log('this.dropdownpai'+JSON.stringify(this.dropDownPairs));
            
            this.savebutton = true;
            this.isScroll = true;
        } catch (error) {
            console.error('Error adding new pair:', error);
            errorDebugger('GoogleLeadFieldMapping', 'addNewPair', error, 'warn', 'Error in addNewPair');
        }
    }

    deletePair(event) {
        try {
            const index = event.currentTarget.dataset.id;
            this.dropDownPairs = this.dropDownPairs.filter((_, i) => i !== parseInt(index));
            this.filterAndUpdateGoogleFieldOptions();
            this.filterAndUpdateSalesforceOptions();
            this.validatePairs();
        } catch (error) {
            console.error('Error deleting pair:', error.stack);
            errorDebugger('GoogleLeadFieldMapping', 'deletePair', error, 'warn', 'Error in deletePair');
        }
    }

    createMappingJson() {
        try {
            const mappings = this.dropDownPairs.map(pair => ({
                metaField: pair.metaField,
                salesforceField: pair.salesforceField
            }));
            return JSON.stringify(mappings);
        } catch (error) {
            console.error('Error creating mapping JSON:', error);
            errorDebugger('GoogleLeadFieldMapping', 'createMappingJson', error, 'warn', 'Error in createMappingJson');
        }
    }

    saveMappingsToMetadata() {
        try {
            const mappingsData = this.createMappingJson();
            saveMappings({ mappingsData, integrationType: this.integrationType })
                .then(() => {
                    this.showToast('Success', 'Mappings saved successfully', 'success');
                    this.savebutton = true;
                })
                .catch(error => {
                    console.error('Error saving mappings:', error);
                    errorDebugger('GoogleLeadFieldMapping', 'saveMappingsToMetadata', error, 'warn', 'Error in saveMappingsToMetadata');
                    this.showToast('Error', 'Error saving mappings', 'error');
                });
        } catch (error) {
            console.error('Error saving mappings to metadata:', error);
            errorDebugger('GoogleLeadFieldMapping', 'saveMappingsToMetadata', error, 'warn', 'Error in saveMappingsToMetadata');
        }
    }

    handleAddPairClick() {
        try {
            const isValid = this.dropDownPairs.every(pair => pair.metaField && pair.salesforceField);
            if (!isValid) {
                this.showToast('Error', 'Please fill all pairs or remove empty pairs!', 'error');
                return;
            }

            const selectedSalesforceFields = this.dropDownPairs.map(pair => pair.salesforceField);
            const duplicateSalesforceIndex = selectedSalesforceFields.findIndex((field, index) => 
                selectedSalesforceFields.indexOf(field) !== index
            );
            const selectedGoogleFields = this.dropDownPairs.map(pair => pair.metaField);
            const duplicateGoogleIndex = selectedGoogleFields.findIndex((field, index) => 
                selectedGoogleFields.indexOf(field) !== index
            );

            if (duplicateSalesforceIndex !== -1) {
                this.showToast('Error', `Duplicate Salesforce field value found at index ${duplicateSalesforceIndex + 1}!`, 'error');
                this.savebutton = true;
                return;
            }

            if (duplicateGoogleIndex !== -1) {
                this.showToast('Error', `Duplicate ${this.integrationLabel} field value found at index ${duplicateGoogleIndex + 1}!`, 'error');
                this.savebutton = true;
                return;
            }

            this.showConfirmationModal = true;
        } catch (error) {
            console.error('Error handling add pair click:', error);
            errorDebugger('GoogleLeadFieldMapping', 'handleAddPairClick', error, 'warn', 'Error in handleAddPairClick');
        }
    }

    handleConfirmAddPair() {
        this.saveMappingsToMetadata();
        this.showConfirmationModal = false;
    }

    closeConfirmationModal() {
        this.showConfirmationModal = false;
    }

    showToast(title, message, variant) {
        if (typeof window !== 'undefined') {
            this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
        }
    }

    backLeadCenter(event) {
        try {
            event.preventDefault();
            let componentDef = {
                componentDef: "MVEX:leadCaptureCmp",
                attributes: {
                    integrationType: this.integrationType
                }
            };
            let encodedComponentDef = btoa(JSON.stringify(componentDef));
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/one/one.app#' + encodedComponentDef
                }
            });
        } catch (error) {
            console.error('Error navigating back to lead capture:', error);
            errorDebugger('GoogleLeadFieldMapping', 'backLeadCenter', error, 'warn', 'Error in backLeadCenter');
        }
    }
}