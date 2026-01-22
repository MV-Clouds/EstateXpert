import { LightningElement, track } from 'lwc';
import getObjectFields from '@salesforce/apex/MapFieldCmp.getObjectFields';
import saveMappings from '@salesforce/apex/MapFieldCmp.saveMappings';
import getMetadata from '@salesforce/apex/MapFieldCmp.getMetadata';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import externalCss from '@salesforce/resourceUrl/templateCss';
import { NavigationMixin } from 'lightning/navigation';
import { errorDebugger } from 'c/globalProperties';

export default class MapFields extends NavigationMixin(LightningElement) {
    @track dropDownPairs = [];
    @track ListingOptions = [];
    @track MainListingOptions = [];
    @track updateListing = [];
    @track updateProperty = [];
    @track PropertyOptions = [];
    @track MainPropertyOptions = [];
    @track checkboxValue = false;
    @track isLoading = true;
    @track savebutton = true;
    @track showConfirmationModal = false;
    @track isScroll = false;

    /**
    * Method Name: delButtonClass
    * @description: handle the delete button enable/disable.
    * Date: 28/06/2024
    * Created By: Vyom Soni
    */
    get delButtonClass() {
        return this.isAutoSyncEnabled ? 'slds-m-left_x-small del-button disabled-del' : ' slds-m-left_x-small del-button';
    }

    /**
    * Method Name: isAutoSyncEnabled
    * @description: handle the autosync checkbox enable/disable..
    * Date: 28/06/2024
    * Created By: Vyom Soni
    */
    get isAutoSyncEnabled() {
        return this.checkboxValue;
    }

    /**
    * Method Name: dropDownPairsWithIndex
    * @description: handle the dropdown pairs with index.
    * Date: 18/09/2024
    * Created By: Karan Singh
    */
    get dropDownPairsWithIndex() {
        return this.dropDownPairs.map((pair, index) => ({
            ...pair,
            displayIndex: index + 1
        }));
    }

    get isDropDownpairAvailable(){
        return this.dropDownPairs.length > 0;
    }

    /**
    * Method Name: connectedCallback
    * @description: fetch the listing object fields.
    * Date: 28/06/2024
    * Created By: Vyom Soni
    */
    connectedCallback() {
        loadStyle(this, externalCss);
        loadStyle(this, MulishFontCss);
        this.getMappingMetadata();
    }
    
    renderedCallback(){
        if (this.isScroll) {
            const container = this.template.querySelector('.table-content');
            if (container) {
                container.scrollTop = container.scrollHeight;
            }
            this.isScroll = false;
        }
    }

    /**
    * Method Name: getMappingMetadata
    * @description: fetch the mapping metadata.
    * Date: 18/09/2024
    * Created By: Karan Singh
    */
    getMappingMetadata() {
        try {
            getObjectFields({ objectName: 'MVEX__Listing__c' })
            .then(data => {
                this.handleListingObjectFields(data);
                if (this.MainListingOptions.length !== 0) {
                    this.callPropertyFields();
                }
            })
            .catch(error => {
                errorDebugger('MapFields', 'getMappingMetadata', error, 'warn', 'Error in getMappingMetadata');
            });

            this.filterAndUpdateListingOptions();
        } catch (error) {
            errorDebugger('MapFields', 'getMappingMetadata', error, 'warn', 'Error in getMappingMetadata');
        }
    }

    /**
    * Method Name: callPropertyFields
    * @description: fetch the property object fieds.
    * Date: 28/06/2024
    * Created By: Vyom Soni
    */
    callPropertyFields() {
        try {
            getObjectFields({ objectName: 'MVEX__Property__c' })
            .then(data => {
                this.handlePropertyObjectFields(data);
                if (this.MainPropertyOptions.length !== 0) {
                    this.getMetadataFunction();
                }
            })
            .catch(error => {
                errorDebugger('MapFields', 'callPropertyFields', error, 'warn', 'Error in callPropertyFields');
            });
        } catch (error) {
            errorDebugger('MapFields', 'callPropertyFields', error, 'warn', 'Error in callPropertyFields');
        }
    }

    /**
    * Method Name: handleListingObjectFields
    * @description: set listing object fields.
    * Date: 28/06/2024
    * Created By: Vyom Soni
    */
    handleListingObjectFields(data) {
        try {
            const filteredFields = data;
            if (data) {
                this.MainListingOptions = filteredFields.map((field) => ({
                    label: field.label,
                    value: field.apiName,
                    dataType: field.dataType
                })).sort((a, b) => a.label.localeCompare(b.label));
                this.ListingOptions = this.MainListingOptions;
            }
        } catch (error) {
            errorDebugger('MapFields', 'handleListingObjectFields', error, 'warn', 'Error in handleListingObjectFields');
        }
    }

    /**
    * Method Name: handlePropertyObjectFields
    * @description: set property object fields.
    * Date: 28/06/2024
    * Created By: Vyom Soni
    */
    handlePropertyObjectFields(data) {
        try {
            const filteredFields = data;
            if (data) {
                this.MainPropertyOptions = filteredFields.map((field) => ({
                    label: field.label,
                    value: field.apiName,
                    dataType: field.dataType // Remember the data type
                })).sort((a, b) => a.label.localeCompare(b.label));
            }
        } catch (error) {
            errorDebugger('MapFields', 'handlePropertyObjectFields', error, 'warn', 'Error in handlePropertyObjectFields');
        }

    }


    /**
  * Method Name: getMetadataFunction
  * @description: Get metadata from the record and set in picklists pair 
  * Date: 28/06/2024
  * Created By: Vyom Soni
  */
    getMetadataFunction() {
        try {
            getMetadata()
            .then(result => {
                if (result[0] != null) {
                    this.parseAndSetMappings(result[0]);
                }
                if (result[1] == null) {
                    this.setCheckboxValue(result[0]);
                } else {
                    this.setCheckboxValue(result[1]);
                }

            }).catch(error => {
                errorDebugger('MapFields', 'getMetadataFunction', error, 'warn', 'Error in getMetadataFunction');

            });
            this.filterAndUpdateListingOptions();
            this.filterAndUpdatePropertyOptions();
        } catch (error) {
            errorDebugger('MapFields', 'getMetadataFunction', error, 'warn', 'Error in getMetadataFunction');
        }
    }

    /**
    * Method Name: parseAndSetMappings
    * @description: set the dropdown pairs using the metadata string
    * @param mappingString string value
    * Date: 28/06/2024
    * Created By: Vyom Soni
    */
    parseAndSetMappings(mappingString) {
        try {
            const mappings = mappingString.split(';');
            if (this.ListingOptions != null) {
                mappings.forEach(mapping => {
                    this.isLoading = true;
                    const [selectedListing, selectedProperty] = mapping.split(':');
                    if (selectedListing && selectedProperty) {
                        const newPair = {
                            id: this.dropDownPairs.length,
                            selectedListing: selectedListing,
                            selectedProperty: selectedProperty,
                            listingOptions: this.ListingOptions,
                            propertyOptions: this.filterPropertyOptions(selectedListing),
                            isPropertyPicklistDisabled: false
                        };
                        this.dropDownPairs.push(newPair);
                        this.filterAndUpdateListingOptions();
                        this.filterAndUpdatePropertyOptions();

                    }
                    this.isLoading = false;
                });
                this.isLoading = false;
            }
        } catch (error) {
            errorDebugger('MapFields', 'parseAndSetMappings', error, 'warn', 'Error in parseAndSetMappings');
        }
    }

    /**
    * Method Name: setCheckboxValue
    * @description: set the checkbox value
    * Date: 28/06/2024
    * Created By: Vyom Soni
    */
    setCheckboxValue(checkboxValue) {
        if (checkboxValue == 'true') {
            this.checkboxValue = true;
        } else {
            this.checkboxValue = false;
        }
    }

    /**
    * Method Name: filterPropertyOptions
    * @description: set property option according listing data-type
    * @param: selectedListing string vlaue
    * Date: 28/06/2024
    * Created By: Vyom Soni
    */
    filterPropertyOptions(selectedListing) {
        try {
            if (!selectedListing) return; 
            this.filterAndUpdatePropertyOptions();
            const selectedListingField = this.ListingOptions.find(
                (option) => option.value === selectedListing
            );
            if (!selectedListingField || !selectedListingField.dataType) {
                return;
            }
            this.PropertyOptions = [...this.PropertyOptions];
            this.PropertyOptions = this.PropertyOptions.filter((option) => {
                return option.dataType === selectedListingField.dataType;
            });
            return this.PropertyOptions;
        } catch (error) {
            errorDebugger('MapFields', 'filterPropertyOptions', error, 'warn', 'Error in filterPropertyOptions');
        }
    }


    /**
    * Method Name: handleSourceFieldChange
    * @description: Handle picklists selection of listing fileds
    * Date: 28/06/2024
    * Created By: Vyom Soni
    */
    handleSourceFieldChange(event) {
        try {
            const index = event.target.dataset.index;
            this.dropDownPairs[index].selectedListing = event.detail.value;
            this.dropDownPairs[index].propertyOptions = this.filterPropertyOptions(event.detail.value);
            this.dropDownPairs[index].isPropertyPicklistDisabled = false;
            this.dropDownPairs[index].selectedProperty = '';
            this.updateListingOptionsAfterIndex(index);
            this.filterAndUpdateListingOptions();
        } catch (error) {
            errorDebugger('MapFields', 'handleSourceFieldChange', error, 'warn', 'Error in handleSourceFieldChange');
        }
    }

    /**
    * Method Name: updateListingOptionsAfterIndex
    * @description: remove the selected item from other dropdown pairs
    * @param startIndex integer value
    * Date: 28/06/2024
    * Created By: Vyom Soni
    */
    updateListingOptionsAfterIndex(startIndex) {
        try {
            for (let i = startIndex; i < this.dropDownPairs.length; i++) {
                const pair = this.dropDownPairs[i];
                pair.listingOptions = this.MainListingOptions.slice();
                for (let j = 0; j < i; j++) {
                    const otherPair = this.dropDownPairs[j];
                    if (otherPair.selectedListing) {
                        pair.listingOptions = pair.listingOptions.filter(option => option.value !== otherPair.selectedListing);
                    }
                }
            }
        } catch (error) {
            errorDebugger('MapFields', 'updateListingOptionsAfterIndex', error, 'warn', 'Error in updateListingOptionsAfterIndex');
        }
    }

    /**
    * Method Name: handleDestinationFieldChange
    * @description: Handle picklists selection of property fileds
    * Date: 28/06/2024
    * Created By: Vyom Soni
    */
    handleDestinationFieldChange(event) {
        try {
            const index = event.target.dataset.index;
            this.dropDownPairs[index].selectedProperty = event.detail.value;
            const isPropertyValid = this.dropDownPairs.every(pair => pair.selectedProperty);
            const isListingValid = this.dropDownPairs.every(pair => pair.selectedListing);
            if (isListingValid && isPropertyValid) {
                this.savebutton = false;
            }
            this.filterAndUpdatePropertyOptions();
        } catch (error) {
            errorDebugger('MapFields', 'handleDestinationFieldChange', error, 'warn', 'Error in handleDestinationFieldChange');
        }
    }

    /**
     * Method Name: filterAndUpdateListingOptions
     * @description: Exculde the selected picklists values from lisitng fields
     * Date: 28/06/2024
     * Created By: Vyom Soni
     */
    filterAndUpdateListingOptions() {
        try {
            this.updateListing = this.MainListingOptions;
            const selectedListingValues = this.dropDownPairs.map(pair => pair.selectedListing);
            this.dropDownPairs.forEach(pair => {
                pair.listingOptions = this.MainListingOptions.filter(option => {
                    return !selectedListingValues.includes(option.value) || option.value === pair.selectedListing;
                });
            });

            selectedListingValues.forEach(selectedValue => {
                this.excludeSelectedOptionFromListing(selectedValue);
            });
            this.ListingOptions = this.updateListing;
            this.updateListing = [];
        } catch (error) {
            errorDebugger('MapFields', 'filterAndUpdateListingOptions', error, 'warn', 'Error in filterAndUpdateListingOptions');
        }
    }

    /**
    * Method Name: filterAndUpdateListingOptions
    * @description: Exculde the selected picklists values from property fields
    * Date: 28/06/2024
    * Created By: Vyom Soni
    */
    filterAndUpdatePropertyOptions() {
        try {
            this.updateProperty = this.MainPropertyOptions;
            const selectedListingValues = this.dropDownPairs.map(pair => pair.selectedProperty);

            selectedListingValues.forEach(selectedValue => {
                this.excludeSelectedOptionFromProperty(selectedValue);
            });
            this.PropertyOptions = this.updateProperty;
            this.updateProperty = [];
        } catch (error) {
            errorDebugger('MapFields', 'filterAndUpdatePropertyOptions', error, 'warn', 'Error in filterAndUpdatePropertyOptions');
        }
    }

    /**
    * Method Name: excludeSelectedOptionFromListing
    * @description: update the removed listing fields list
    * @param: selectedValue object value
    * Date: 28/06/2024
    * Created By: Vyom Soni
    */
    excludeSelectedOptionFromListing(selectedValue) {
        try{
            this.updateListing = this.updateListing.filter(option => option.value !== selectedValue);
        }catch(error){
            errorDebugger('MapFields', 'excludeSelectedOptionFromListing', error, 'warn', 'Error in excludeSelectedOptionFromListing');
        }
    }

    /**
     * Method Name: excludeSelectedOptionFromProperty
     * @description: update the removed property fields list
     * @param: selectedValue object value
     * Date: 28/06/2024
     * Created By: Vyom Soni
     */
    excludeSelectedOptionFromProperty(selectedValue) {
        try{
            this.updateProperty = this.updateProperty.filter(option => option.value !== selectedValue);
        }catch(error){
            errorDebugger('MapFields', 'excludeSelectedOptionFromProperty', error, 'warn', 'Error in excludeSelectedOptionFromProperty');
        }
    }

    /**
  * Method Name: addNewPair
  * @description: Add dropdown pair of picklists
  * Date: 28/06/2024
  * Created By: Vyom Soni
  */
    addNewPair() {
        try {
            this.filterAndUpdateListingOptions();
            this.filterAndUpdatePropertyOptions();
            const newPair = {
                id: this.dropDownPairs.length,
                selectedListing: '',
                selectedProperty: '',
                listingOptions: this.ListingOptions,
                propertyOptions: [],
                isPropertyPicklistDisabled: true
            };

            this.dropDownPairs.push(newPair);
            this.savebutton = true;
            const isPropertyValid = this.dropDownPairs.every(pair => pair.selectedProperty);
            const isListingValid = this.dropDownPairs.every(pair => pair.selectedListing);
            if (isListingValid && isPropertyValid) {
                this.savebutton = false;
            }
            this.isScroll = true;
        } catch (error) {
            errorDebugger('MapFields', 'addNewPair', error, 'warn', 'Error in addNewPair');
        }
    }

    /**
    * Method Name: deletePair
    * @description: delete dropdown pair of picklists
    * Date: 28/06/2024
    * Created By: Vyom Soni
    */
    deletePair(event) {
        try {
            const index = event.currentTarget.dataset.id;
            this.dropDownPairs.splice(index, 1);
            this.filterAndUpdateListingOptions();
            this.filterAndUpdatePropertyOptions();
            const isPropertyValid = this.dropDownPairs.every(pair => pair.selectedProperty);
            const isListingValid = this.dropDownPairs.every(pair => pair.selectedListing);
            if (isListingValid && isPropertyValid) {
                this.savebutton = false;
            }
        } catch (error) {
            errorDebugger('MapFields', 'deletePair', error, 'warn', 'Error in deletePair');
        }
    }

    /**
    * Method Name: handleCheckboxChange
    * @description: handle checkbox 
    * Date: 28/06/2024
    * Created By: Vyom Soni
    */
    handleCheckboxChange() {
        if (this.checkboxValue == false) {
            this.checkboxValue = true;
        } else {
            this.checkboxValue = false;
        }
        this.savebutton = false;
    }

    /**
    * Method Name: handleCheckboxChange
    * @description: handle checkbox 
    * Date: 28/06/2024
    * Created By: Vyom Soni
    */
    createMappingString() {
        try {
            let mappingString = '';
            for (let i = 0; i < this.dropDownPairs.length; i++) {
                const pair = this.dropDownPairs[i];
                if (pair.selectedListing && pair.selectedProperty) {
                    mappingString += pair.selectedListing + ':' + pair.selectedProperty + ';';
                }
            }
            mappingString = mappingString.slice(0, -1);
            return mappingString;
        } catch (error) {
            errorDebugger('MapFields', 'createMappingString', error, 'warn', 'Error in createMappingString');
        }
    }

    /**
    * Method Name: saveMappingsToMetadata
    * @description: save the updated mapping in the metadata
    * Date: 28/06/2024
    * Created By: Vyom Soni
    */
    saveMappingsToMetadata() {
        try {
            const mappingsData = this.createMappingString();
            const checkboxValue = this.checkboxValue;
            saveMappings({ mappingsData, checkboxValue })
                .then(() => {
                    this.showToast('Success', 'Mappings saved successfully', 'success');
                    this.savebutton = true;
                })
                .catch(error => {
                    errorDebugger('MapFields', 'saveMappingsToMetadata', error, 'warn', 'Error in saveMappingsToMetadata');
                    this.showToast('Error', 'Error saving mappings', 'error');
                });
        } catch (error) {
            errorDebugger('MapFields', 'saveMappingsToMetadata', error, 'warn', 'Error in saveMappingsToMetadata');
        }
    }

    //Conformation modal and the alert
    /**
    * Method Name: handleAddPairClick
    * @description: Conformation modal and the alert
    * Date: 28/06/2024
    * Created By: Vyom Soni
    */
    handleAddPairClick() {
        try {
            const isValid = this.dropDownPairs.every(pair => pair.selectedProperty);
            if (!isValid) {
                this.showToast('Error', 'Please fill all pairs or remove!', 'error');
                return;
            }

            const selectedProperties = this.dropDownPairs.map(pair => pair.selectedProperty);
            const duplicateIndex = selectedProperties.findIndex((property, index) => 
                selectedProperties.indexOf(property) !== index
            );

            if (duplicateIndex !== -1) {
                this.showToast('Error', `Duplicate property field value found at index ${duplicateIndex + 1}!`, 'error');
                this.savebutton = true;
                return;
            }

            this.showConfirmationModal = true;
        } catch (error) {
            errorDebugger('MapFields', 'handleAddPairClick', error, 'warn', 'Error in handleAddPairClick');
        }
    }

    /**
    * Method Name: handleConfirmAddPair
    * @description: handle the confirm button in modal
    * Date: 28/06/2024
    * Created By: Vyom Soni
    */
    handleConfirmAddPair() {
        this.saveMappingsToMetadata();
        this.showConfirmationModal = false;
    }

    /**
    * Method Name: closeConfirmationModal
    * @description: handle the close button in modal
    * Date: 28/06/2024
    * Created By: Vyom Soni
    */
    closeConfirmationModal() {
        this.showConfirmationModal = false;
    }

    /**
    * Method Name: handleConfirmAddPair
    * @description: show the toast messsage
    * @param: title string value
    * @param: message string value
    * @param: variant string value
    * Date: 28/06/2024
    * Created By: Vyom Soni
    */
    showToast(title, message, variant) {
        if (typeof window !== 'undefined') {
            const toastEvent = new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            });
            this.dispatchEvent(toastEvent);
        }
    }

    /**
    * Method Name: backToControlCenter
    * @description: Used to Navigate to the main ControlCenter page.
    * Date: 04/06/2024
    * Created By: Karan Singh
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
            errorDebugger('MapFields', 'backToControlCenter', error, 'warn', 'Error in backToControlCenter');
        }
    }

}