import { LightningElement, track } from 'lwc';
import getObjectFields from '@salesforce/apex/MapFieldCmp.getObjectFields';
import saveMappings from '@salesforce/apex/MapFieldCmp.saveMappings';
import getMetadata from '@salesforce/apex/MapFieldCmp.getMetadata';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import externalCss from '@salesforce/resourceUrl/templateCss';
import FORM_FACTOR from '@salesforce/client/formFactor';
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
    @track isDirectAccess = false;
    @track hasChanges = false;
    @track originalDropDownPairs = [];
    @track originalCheckboxValue = false;

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
    * @description: Enriches each dropdown pair with computed display labels, search-
    *   filtered option lists, open/closed state, disabled flags, placeholder text, and
    *   CSS class strings required by the custom searchable combobox UI.
    * Date: 18/09/2024 | Updated: 29/05/2026
    * Created By: Karan Singh
    */
    get dropDownPairsWithIndex() {
        return this.dropDownPairs.map((pair, index) => {
            const listingSearch = pair.listingSearch || '';
            const propertySearch = pair.propertySearch || '';

            // Filter listing options by current search text; annotate the selected item
            const listingFiltered = (pair.listingOptions || [])
                .filter(o => !listingSearch || o.label.toLowerCase().includes(listingSearch.toLowerCase()))
                .map(o => ({
                    ...o,
                    itemClass: o.value === pair.selectedListing
                        ? 'combobox-option combobox-option-selected'
                        : 'combobox-option'
                }));

            // Filter property options by current search text; annotate the selected item
            const propertyFiltered = (pair.propertyOptions || [])
                .filter(o => !propertySearch || o.label.toLowerCase().includes(propertySearch.toLowerCase()))
                .map(o => ({
                    ...o,
                    itemClass: o.value === pair.selectedProperty
                        ? 'combobox-option combobox-option-selected'
                        : 'combobox-option'
                }));

            // Resolve human-readable labels for the selected values
            const listingOption = (pair.listingOptions || []).find(o => o.value === pair.selectedListing)
                || (this.MainListingOptions || []).find(o => o.value === pair.selectedListing);
            const propertyOption = (pair.propertyOptions || []).find(o => o.value === pair.selectedProperty)
                || (this.MainPropertyOptions || []).find(o => o.value === pair.selectedProperty);

            const listingDisplayLabel = listingOption ? listingOption.label : '';
            const propertyDisplayLabel = propertyOption ? propertyOption.label : '';

            // When open  : show the live search text so the user can type to filter.
            // When closed : show the selected label (empty if nothing selected yet).
            const listingInputValue = pair.listingOpen ? listingSearch : listingDisplayLabel;
            const propertyInputValue = pair.propertyOpen ? propertySearch : propertyDisplayLabel;

            // Property field is locked until a listing field has been chosen
            const isPropertyDisabled = !pair.selectedListing || this.isAutoSyncEnabled;

            return {
                ...pair,
                _index: index,
                displayIndex: index + 1,
                listingFiltered,
                propertyFiltered,
                listingHasNoResults: listingFiltered.length === 0,
                propertyHasNoResults: propertyFiltered.length === 0,
                listingInputValue,
                propertyInputValue,
                isPropertyDisabled,
                // Show hint text below the property combobox before a listing is selected
                showPropertyHint: !pair.selectedListing && !this.isAutoSyncEnabled,
                propertyPlaceholder: !pair.selectedListing
                    ? 'Select Listing Field first'
                    : 'Search Property Field…',
                listingComboboxClass: this.isAutoSyncEnabled
                    ? 'custom-combobox disabled'
                    : 'custom-combobox',
                propertyComboboxClass: isPropertyDisabled
                    ? 'custom-combobox disabled'
                    : 'custom-combobox'
            };
        });
    }

    get isDropDownpairAvailable() {
        return this.dropDownPairs.length > 0;
    }

    /**
    * Method Name: isRevertDisabled
    * @description: Disable revert button when no changes exist
    * Date: 18/02/2026
    * Created By: Karan Singh
    */
    get isRevertDisabled() {
        return !this.hasChanges;
    }

    get isMobileOrTablet() {
        return FORM_FACTOR === 'Small' || FORM_FACTOR === 'Medium';
    }

    /**
    * Method Name: connectedCallback
    * @description: fetch the listing object fields.
    * Date: 28/06/2024
    * Created By: Vyom Soni
    */
    connectedCallback() {
        loadStyle(this, MulishFontCss);
        // Check if accessed directly via URL
        if (typeof window !== 'undefined') {
            const currentUrl = window.location.href;
            if (currentUrl.includes('MVEX__Map_Listing_and_Property')) {
                this.isDirectAccess = true;
                this.isLoading = false;
                return;
            }
        }

        loadStyle(this, externalCss);
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
                    // Store AFTER both mappings and checkbox value are fully set
                    this.storeOriginalState();
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
                            isPropertyPicklistDisabled: false,
                            // Custom combobox open/search state
                            listingOpen: false,
                            propertyOpen: false,
                            listingSearch: '',
                            propertySearch: ''
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
    * @description: Filters available property field options based on the selected listing
    *   field data type. Uses MainListingOptions for the type lookup so it remains correct
    *   even after filterAndUpdateListingOptions has excluded the option from ListingOptions.
    *   Special rule: PICKLIST listing fields may map to both PICKLIST and TEXT property
    *   fields, enabling broader mapping flexibility.
    * @param: selectedListing string value
    * Date: 28/06/2024 | Updated: 29/05/2026
    * Created By: Vyom Soni
    */
    filterPropertyOptions(selectedListing) {
        try {
            if (!selectedListing) return [];
            this.filterAndUpdatePropertyOptions();
            // Use MainListingOptions so the lookup works regardless of filtering state
            const selectedListingField = this.MainListingOptions.find(
                (option) => option.value === selectedListing
            );
            if (!selectedListingField || !selectedListingField.dataType) {
                return this.PropertyOptions;
            }
            this.PropertyOptions = [...this.PropertyOptions];
            const listingDataType = selectedListingField.dataType;

            if (listingDataType === 'PICKLIST') {
                this.PropertyOptions = this.PropertyOptions.filter((option) => {
                    return option.dataType === 'PICKLIST' || option.dataType === 'STRING';
                });
            } else {
                this.PropertyOptions = this.PropertyOptions.filter((option) => {
                    return option.dataType === listingDataType;
                });
            }
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
            this.checkForChanges();
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
            this.checkForChanges();
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
        try {
            this.updateListing = this.updateListing.filter(option => option.value !== selectedValue);
        } catch (error) {
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
        try {
            this.updateProperty = this.updateProperty.filter(option => option.value !== selectedValue);
        } catch (error) {
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
                isPropertyPicklistDisabled: true,
                // Custom combobox open/search state
                listingOpen: false,
                propertyOpen: false,
                listingSearch: '',
                propertySearch: ''
            };

            this.dropDownPairs.push(newPair);
            this.savebutton = true;
            const isPropertyValid = this.dropDownPairs.every(pair => pair.selectedProperty);
            const isListingValid = this.dropDownPairs.every(pair => pair.selectedListing);
            if (isListingValid && isPropertyValid) {
                this.savebutton = false;
            }
            this.isScroll = true;
            this.checkForChanges();
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
            this.checkForChanges();
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
        this.checkForChanges();
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
                    this.storeOriginalState();
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

    /**
    * Method Name: storeOriginalState
    * @description: Store the original state for revert functionality
    * Date: 18/02/2026
    * Created By: Karan Singh
    */
    storeOriginalState() {
        try {
            this.originalDropDownPairs = JSON.parse(JSON.stringify(this.dropDownPairs));
            this.originalCheckboxValue = this.checkboxValue;
            this.hasChanges = false;
        } catch (error) {
            errorDebugger('MapFields', 'storeOriginalState', error, 'warn', 'Error in storeOriginalState');
        }
    }

    /**
    * Method Name: checkForChanges
    * @description: Check if any changes have been made from original state
    * Date: 18/02/2026
    * Created By: Karan Singh
    */
    checkForChanges() {
        try {
            const currentState = JSON.stringify({
                pairs: this.dropDownPairs.map(pair => ({
                    selectedListing: pair.selectedListing,
                    selectedProperty: pair.selectedProperty
                })),
                checkbox: this.checkboxValue
            });

            const originalState = JSON.stringify({
                pairs: this.originalDropDownPairs.map(pair => ({
                    selectedListing: pair.selectedListing,
                    selectedProperty: pair.selectedProperty
                })),
                checkbox: this.originalCheckboxValue
            });

            this.hasChanges = currentState !== originalState;
        } catch (error) {
            errorDebugger('MapFields', 'checkForChanges', error, 'warn', 'Error in checkForChanges');
        }
    }

    /**
    * Method Name: revertChanges
    * @description: Revert all changes back to original state
    * Date: 18/02/2026
    * Created By: Karan Singh
    */
    revertChanges() {
        try {
            this.dropDownPairs = JSON.parse(JSON.stringify(this.originalDropDownPairs));
            this.checkboxValue = this.originalCheckboxValue;
            this.hasChanges = false;
            this.savebutton = true;
            this.filterAndUpdateListingOptions();
            this.filterAndUpdatePropertyOptions();
            this.showToast('Success', 'Changes have been reverted', 'success');
        } catch (error) {
            errorDebugger('MapFields', 'revertChanges', error, 'warn', 'Error in revertChanges');
        }
    }

    // ── Custom Combobox Handlers ─────────────────────────────────────────────

    /**
    * Method Name: handleComboFocus
    * @description: Opens the custom combobox dropdown for the focused field.
    *   Also closes any other open dropdowns on any row.
    *   Blocked when Auto Sync is on, or when the Property combobox is focused
    *   before a Listing field has been selected for that row.
    * Date: 29/05/2026
    * Created By: Karan Singh
    */
    handleComboFocus(event) {
        try {
            const index = parseInt(event.currentTarget.dataset.index, 10);
            const field = event.currentTarget.dataset.field;

            if (this.isAutoSyncEnabled) return;
            if (field === 'property' && !this.dropDownPairs[index].selectedListing) return;

            // Open the targeted dropdown; close every other open dropdown
            this.dropDownPairs = this.dropDownPairs.map((pair, i) => {
                if (i === index) {
                    return {
                        ...pair,
                        listingOpen: field === 'listing',
                        propertyOpen: field === 'property',
                        // Clear search so the user sees the full unfiltered list on open
                        listingSearch: field === 'listing' ? '' : pair.listingSearch,
                        propertySearch: field === 'property' ? '' : pair.propertySearch
                    };
                }
                return { ...pair, listingOpen: false, propertyOpen: false, listingSearch: '', propertySearch: '' };
            });
        } catch (error) {
            errorDebugger('MapFields', 'handleComboFocus', error, 'warn', 'Error in handleComboFocus');
        }
    }

    /**
    * Method Name: handleComboBlur
    * @description: Closes the custom combobox dropdown when the input loses focus.
    *   A 200 ms delay is intentional: it lets onmousedown on a dropdown option
    *   fire and register the selection BEFORE blur closes the dropdown.
    * Date: 29/05/2026
    * Created By: Karan Singh
    */
    handleComboBlur(event) {
        try {
            const index = parseInt(event.currentTarget.dataset.index, 10);
            const field = event.currentTarget.dataset.field;

            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                this.dropDownPairs = this.dropDownPairs.map((pair, i) => {
                    if (i === index) {
                        return {
                            ...pair,
                            listingOpen: field === 'listing' ? false : pair.listingOpen,
                            propertyOpen: field === 'property' ? false : pair.propertyOpen,
                            listingSearch: field === 'listing' ? '' : pair.listingSearch,
                            propertySearch: field === 'property' ? '' : pair.propertySearch
                        };
                    }
                    return pair;
                });
            }, 200);
        } catch (error) {
            errorDebugger('MapFields', 'handleComboBlur', error, 'warn', 'Error in handleComboBlur');
        }
    }

    /**
    * Method Name: handleSearchInput
    * @description: Updates the live search text for the active combobox field
    *   as the user types. The dropDownPairsWithIndex getter re-computes the
    *   filtered option list reactively on every keystroke.
    * Date: 29/05/2026
    * Created By: Karan Singh
    */
    handleSearchInput(event) {
        try {
            const index = parseInt(event.currentTarget.dataset.index, 10);
            const field = event.currentTarget.dataset.field;
            const searchText = event.target.value;

            this.dropDownPairs = this.dropDownPairs.map((pair, i) => {
                if (i === index) {
                    return {
                        ...pair,
                        listingSearch: field === 'listing' ? searchText : pair.listingSearch,
                        propertySearch: field === 'property' ? searchText : pair.propertySearch
                    };
                }
                return pair;
            });
        } catch (error) {
            errorDebugger('MapFields', 'handleSearchInput', error, 'warn', 'Error in handleSearchInput');
        }
    }

    /**
    * Method Name: handleOptionSelect
    * @description: Fired via onmousedown (not onclick) on each dropdown option so
    *   it executes BEFORE the input's onblur event, ensuring the selection registers
    *   before the dropdown closes. event.preventDefault() prevents the browser
    *   from moving focus away from the input during the mousedown.
    *   Mirrors the logic of handleSourceFieldChange / handleDestinationFieldChange.
    * Date: 29/05/2026
    * Created By: Karan Singh
    */
    handleOptionSelect(event) {
        try {
            // Prevent mousedown from causing the input to lose focus prematurely
            event.preventDefault();

            const index = parseInt(event.currentTarget.dataset.index, 10);
            const field = event.currentTarget.dataset.field;
            const value = event.currentTarget.dataset.value;

            if (field === 'listing') {
                // Mirror handleSourceFieldChange:
                // Derive property options BEFORE filterAndUpdateListingOptions
                // removes this value from ListingOptions.
                this.dropDownPairs[index].selectedListing = value;
                this.dropDownPairs[index].propertyOptions = this.filterPropertyOptions(value);
                this.dropDownPairs[index].isPropertyPicklistDisabled = false;
                this.dropDownPairs[index].selectedProperty = '';
                this.dropDownPairs[index].listingOpen = false;
                this.dropDownPairs[index].listingSearch = '';
                this.updateListingOptionsAfterIndex(index);
                this.filterAndUpdateListingOptions();
                // Spread to trigger LWC reactive update
                this.dropDownPairs = [...this.dropDownPairs];
            } else {
                // Mirror handleDestinationFieldChange
                this.dropDownPairs[index].selectedProperty = value;
                this.dropDownPairs[index].propertyOpen = false;
                this.dropDownPairs[index].propertySearch = '';

                const isPropertyValid = this.dropDownPairs.every(pair => pair.selectedProperty);
                const isListingValid = this.dropDownPairs.every(pair => pair.selectedListing);
                if (isListingValid && isPropertyValid) {
                    this.savebutton = false;
                }
                this.filterAndUpdatePropertyOptions();
                // Spread to trigger LWC reactive update
                this.dropDownPairs = [...this.dropDownPairs];
            }

            this.checkForChanges();
        } catch (error) {
            errorDebugger('MapFields', 'handleOptionSelect', error, 'warn', 'Error in handleOptionSelect');
        }
    }

}