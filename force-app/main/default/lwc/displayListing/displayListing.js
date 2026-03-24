import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getRecords from '@salesforce/apex/PropertySearchController.getRecords';
import NoImageFound from '@salesforce/resourceUrl/blankImage';
import propertyIcons from '@salesforce/resourceUrl/PropertyIcons';
import location_icon from '@salesforce/resourceUrl/location_icon';
import mapCss_V1 from '@salesforce/resourceUrl/mapCss_V1';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { loadStyle } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFieldMap from '@salesforce/apex/PropertySearchController.getObjectFields';
import getConfigObjectFields from '@salesforce/apex/RecordManagersCmpController.getObjectFields';
import saveMappings from '@salesforce/apex/RecordManagersCmpController.saveMappings';
import { errorDebugger } from 'c/globalProperties';
import emptyState from '@salesforce/resourceUrl/emptyState';
import getMetadataRecords from '@salesforce/apex/ControlCenterController.getMetadataRecords';
import getRecordName from '@salesforce/apex/PropertySearchController.getRecordName';

export default class DisplayListing extends NavigationMixin(LightningElement) {
    @api recordId;
    @track mapMarkers = [];
    @track totalRecords = 0;
    @track properties = [];
    @track currentPage = 1;
    @track searchTerm = '';
    @track isLoading = false;
    @track pageSize = 9;
    @track bathroom_icon = propertyIcons + '/PropertyIcons/Bathroom.png';
    @track bedroom_icon = propertyIcons + '/PropertyIcons/Bedroom.png';
    @track location_icon = location_icon;
    @track filteredListingData = [];
    @track pagedFilteredListingData = [];
    @track propertyMediaUrls = [];
    @track isPropertyAvailable = true;
    @track selectedView = 'List';
    @track filters = '';
    @track logicalExpression = '';
    @track inquiryRecord = {};
    @track totalListing = [];
    @track conditiontype = 'related';
    @track selectedMappingId = null;

    @track isShowModal = false;

    @track selectedConditionType = 'Related List';
    @track mappings = [];

    @track isAddConditionModalVisible = false;
    @track selectedConditionOperator = '';
    @track selectedInquiryValue = '';

    @track listingFieldObject = {
        'MVEX__Field_Name__c': '',
        'MVEX__Value__c': '',
        'MVEX__Operator__c': '',
        'MVEX__Data_Type__c': '',
        'isPrimary': true,
        'isPicklist': false,
        'isReference': false
    };

    @track listingpicklistOptions = [];
    @track conditionOperatorOptions = [
        { label: 'Less Than', value: 'lessThan' },
        { label: 'Greater Than', value: 'greaterThan' },
        { label: 'Equal To', value: 'equalTo' },
        { label: 'Contains', value: 'contains' },
        { label: 'Not Contains', value: 'notContains' },
        { label: 'Not Equal To', value: 'notEqualTo' },
        { label: 'Is Null', value: 'isNull' }
    ];
    @track listingFieldOptions = [];
    @track inquiryFieldOptions = [];
    @track isConstant = false;
    @track selectedRecordName = '';
    @track visiblePages = 5;
    @track divElement;
    @track NoDataImageUrl = emptyState;
    @track hideFilterButton = false;

    @track listingColumns = [];
    @track isConfigOpen = false;
    @track modalFilteredListingData = []; // New variable to store popup-filtered data
    filterModalSnapshot = null;

    @track defaultColumns = [
        { label: 'Image', fieldName: 'media_url', type: 'image' },
        { label: 'Name', fieldName: 'name', type: 'text' },
        { label: 'Listing Type', fieldName: 'mvex__listing_type__c', type: 'text' },
        { label: 'City', fieldName: 'mvex__city__c', type: 'text' },
        { label: 'Bedrooms', fieldName: 'mvex__bedrooms__c', type: 'number' },
        { label: 'Bathrooms', fieldName: 'mvex__bathrooms__c', type: 'number' },
        { label: 'Price', fieldName: 'mvex__listing_price__c', type: 'currency' }
    ];

    conditionOptions = [
        { label: 'All Condition Are Met', value: 'all' },
        { label: 'Any Condition Is Met', value: 'any' },
        { label: 'Custom Logic Is Met', value: 'custom' },
        { label: 'Related List', value: 'related' },
        { label: 'No Filter', value: 'none' },
    ];

    /**
    * Method Name : isNullOperatorSelected
    * @description : returns true when the selected condition operator is 'isNull'
    * Date: 24/03/2026
    */
    get isNullOperatorSelected() {
        return this.selectedConditionOperator === 'isNull';
    }

    /**
    * Method Name : isNullPicklistOptions
    * @description : returns True/False options for the isNull operator picklist
    * Date: 24/03/2026
    */
    get isNullPicklistOptions() {
        return [
            { label: 'True', value: 'true' },
            { label: 'False', value: 'false' }
        ];
    }

    /**
    * Method Name : isCustomLogicSelected
    * @description : set isCustomLogicSelected field based on condition
    * * Date: 20/08/2024
    * Created By: Rachit Shah
    */
    get isCustomLogicSelected() {
        return this.selectedConditionType === 'Custom Logic Is Met' && this.mappings.length > 0;
    }

    /**
    * Method Name : mappingClass
    * @description : method to set mapping class
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    get mappingClass() {
        return this.selectedConditionType !== 'Related List' && this.selectedConditionType !== 'None' ? 'mapping-item-active' : 'mapping-item-inactive';
    }

    /**
    * Method Name : isRealatedList
    * @description : method to check if related list is selected or not
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    get isRealatedList() {
        return this.selectedConditionType === 'Related List' || this.selectedConditionType === 'None';
    }

    /**
    * Method Name : isListView
    * @description : set list view
    * * Date: 20/08/2024
    * Created By: Rachit Shah
    */
    get isListView() {
        return this.selectedView === 'List';
    }

    /**
    * Method Name : isMapView
    * @description : set map view
    * * Date: 20/08/2024
    * Created By: Rachit Shah
    */
    get isMapView() {
        return this.selectedView === 'map';
    }

    /**
    * Method Name : isGridView
    * @description : set grid view
    * * Date: 20/08/2024
    * Created By: Rachit Shah
    */
    get isGridView() {
        return this.selectedView === 'Grid';
    }

    /**
   * Method Name : totalItems
   * @description : set the totalpages count.
   * * Date: 20/08/2024
   * Created By:Vyom Soni
   */
    get totalItems() {
        return this.pagedFilteredListingData.length;
    }

    /**
    * Method Name : totalPages
    * @description : set the totalpages count.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get totalPages() {
        return Math.ceil(this.totalItems / this.pageSize);
    }

    /**
    * Method Name : showEllipsis
    * @description : show the elipsis when the total pages is gretaer then the visible pages.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get showEllipsis() {
        return Math.ceil(this.totalItems / this.pageSize) > this.visiblePages;
    }

    /**
    * Method Name : isFirstPage
    * @description : check the current page is first.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get isFirstPage() {
        return this.currentPage === 1;
    }

    /**
    * Method Name : isLastPage
    * @description : check the current page is last.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get isLastPage() {
        return this.currentPage === Math.ceil(this.totalItems / this.pageSize);
    }

    /**
    * Method Name : startIndex
    * @description : set the start Index.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get startIndex() {
        return (this.currentPage - 1) * this.pageSize + 1;
    }

    /**
    * Method Name : endIndex
    * @description : set the end Index.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get endIndex() {
        return Math.min(this.currentPage * this.pageSize, this.totalItems);
    }

    /**
    * Method Name : pageNumbers
    * @description : set the list for page number in pagination.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get pageNumbers() {
        try {
            const totalPages = this.totalPages;
            const currentPage = this.currentPage;
            const visiblePages = this.visiblePages;

            let pages = [];

            if (totalPages <= visiblePages) {
                // If the total pages are less than or equal to the visible pages, show all
                for (let i = 1; i <= totalPages; i++) {
                    pages.push({
                        number: i,
                        isEllipsis: false,
                        className: `pagination-button ${i === currentPage ? 'active' : ''}`
                    });
                }
            } else {
                // Always show the first page
                pages.push({
                    number: 1,
                    isEllipsis: false,
                    className: `pagination-button ${currentPage === 1 ? 'active' : ''}`
                });

                if (currentPage > 3) {
                    // Show ellipsis if the current page is greater than 3
                    pages.push({ isEllipsis: true });
                }

                // Show the middle pages
                let start = Math.max(2, currentPage - 1);
                let end = Math.min(currentPage + 1, totalPages - 1);

                for (let i = start; i <= end; i++) {
                    pages.push({
                        number: i,
                        isEllipsis: false,
                        className: `pagination-button ${i === currentPage ? 'active' : ''}`
                    });
                }

                if (currentPage < totalPages - 2) {
                    // Show ellipsis if the current page is less than totalPages - 2
                    pages.push({ isEllipsis: true });
                }

                // Always show the last page
                pages.push({
                    number: totalPages,
                    isEllipsis: false,
                    className: `pagination-button ${currentPage === totalPages ? 'active' : ''}`
                });
            }

            return pages;
        } catch (error) {
            errorDebugger('DisplayListing', 'pageNumbers', error, 'warn', 'Error in pageNumbers');
            return null;
        }
    }

    get pagedProperties() {
        const startIndex = (this.currentPage - 1) * this.pageSize;
        const slicedData = this.pagedFilteredListingData.slice(startIndex, startIndex + this.pageSize);
        const processedData = this.processListingData(slicedData);

        return processedData.map(property => {
            return {
                ...property,
                media_url: property.media_url ? property.media_url : NoImageFound,
                mvex__listing_type__c: property.mvex__listing_type__c ? property.mvex__listing_type__c : 'Sale',
            };
        });
    }

    get isInquiryObject() {
        return this.objectName === 'MVEX__Inquiry__c';
    }

    /**
   * Method Name : objectName
   * @description : set the objectName
   * * Date: 20/08/2024
   * Created By:Vyom Soni
   */
    @wire(CurrentPageReference) pageRef;
    get objectName() {
        if (this.pageRef && this.pageRef.attributes) {
            return this.pageRef.attributes.objectApiName;
        }
        return null;
    }

    /**
    * Method Name: ConnectedCallback
    * @description: Standard ConnectedCallback method which executes when the component is loaded
    */
    async connectedCallback() {
        try {
            loadStyle(this, MulishFontCss);
            loadStyle(this, mapCss_V1);
            this.isLoading = true;
            
            // Wait for both required data loads before fetching filter configuration
            await Promise.all([
                this.getListingFields(),
                this.getInquiryFields()
            ]);
            
            await this.fetchListingConfiguration(); // This will call fetchMetadataRecords internally
            window?.globalThis?.addEventListener('click', this.handleClickOutside);
            this.checkHideFilterButton();
        } catch (error) {
            errorDebugger('DisplayListing', 'connectedCallback', error, 'warn', 'Error in connectedCallback');
            this.isLoading = false;
        }
    }

    checkHideFilterButton() {
        getMetadataRecords()
            .then(result => {
                
                const feature = result.find(item => item.DeveloperName === 'Map_Listing_And_Inquiry');
                if (feature && feature.MVEX__isAvailable__c) {
                    this.hideFilterButton = true;
                }
            })
            .catch(error => {
                errorDebugger('DisplayListing', 'checkHideFilterButton', error, 'warn', 'Error fetching metadata');
            });
    }

    /**
    * Method Name: renderedCallback
    * @description: this method is used to set divElement on any click in the component
    * Date: 17/06/2024
    * Created By: Vyom Soni
    */
    renderedCallback() {
        this.divElement = this.template.querySelector('.open-mapping-div');
    }

    /**
    * Method Name: getListingFields
    * @description: this method is used to get listing field options
    * Date: 17/06/2024
    * Created By: Vyom Soni
    */
    getListingFields() {
        return getFieldMap({ objectName: 'MVEX__Listing__c' })
            .then(result => {
                this.listingFieldOptions = result.fields;
                this.listingpicklistOptions = result.fields.map(field => {
                    return { label: field.label, value: field.value };
                }).sort((a, b) => a.label.localeCompare(b.label));
            })
            .catch(error => errorDebugger('DisplayListing', 'getListingFields', error, 'warn', 'Error in getListingFields'));
    }

    getInquiryFields() {
        return getFieldMap({ objectName: 'MVEX__Inquiry__c' })
            .then(result => {
                this.inquiryFieldOptions = result.fields.map(field => {
                    return { label: field.label, value: field.value };
                }).sort((a, b) => a.label.localeCompare(b.label));
            })
            .catch(error => {
                errorDebugger('DisplayListing', 'getInquiryFields', error, 'warn', 'Error fetching inquiry fields');
            });
    }

    fetchFilterConfiguration() {
        this.isLoading = true;
        return getConfigObjectFields({ objectApiName: 'MVEX__Listing__c', featureName: 'Suggested_Listing_Filters' })
            .then(result => {
                if (result && result.metadataRecords && result.metadataRecords.length > 0) {
                    try {
                        const config = JSON.parse(result.metadataRecords[0]);
                        this.mappings = config.mappings || [];
                        this.logicalExpression = config.logic || '';
                    } catch (e) {
                        console.error('Error parsing filter configuration:', e);
                        this.mappings = [];
                    }
                }
                this.conditiontype = 'related';
                this.fetchListings();
                this.isLoading = false;
            })
            .catch((error) => {
                errorDebugger('DisplayListing', 'fetchFilterConfiguration', error, 'warn', 'Error in fetchFilterConfiguration');
                this.showToast('Error', 'Error fetching filter configuration', 'error');
                this.isLoading = false;
            });
    }

    /**
* Method Name : fetchListingConfiguration
* @description : method to fetch listing configuration from metadata
* Date: 25/08/2025
* Created By: Rachit Shah
*/
    fetchListingConfiguration() {
        return getConfigObjectFields({ objectApiName: 'MVEX__Listing__c', featureName: 'Suggested_Listing_Filters' })
            .then(result => {
                if (result && result.metadataRecords && result.metadataRecords.length > 0) {
                    try {
                        const fieldsData = JSON.parse(result.metadataRecords[0]);
                        // Always include image column first and actions column last
                        this.listingColumns = [
                            { label: 'Image', fieldName: 'media_url', type: 'image' },
                            ...fieldsData.map(field => ({
                                label: field.label || field.fieldLabel,
                                fieldName: (field.fieldName || field.value || '').toLowerCase(),
                                type: this.getColumnType(field.fieldType),
                                fieldType: field.fieldType,
                                format: field.format
                            })),
                            // { label: 'Actions', fieldName: 'actions', type: 'action' }
                        ];
                        this.pageSize = parseInt(result.metadataRecords[1], 10) || this.pageSize;
                    } catch (e) {
                        console.error('Error parsing listing configuration:', e);
                        this.listingColumns = this.defaultColumns;
                    }
                } else {
                    this.listingColumns = this.defaultColumns;
                }
            })
            .catch((error) => {
                console.error('Error fetching listing configuration:', error);
                this.listingColumns = this.defaultColumns;
            })
            .finally(() => {
                // Call existing data fetching method only once
                return this.fetchFilterConfiguration();
            });
    }

    /**
    * Method Name : getColumnType  
    * @description : method to convert field type to column type
    */
    getColumnType(fieldType) {
        switch ((fieldType || '').toUpperCase()) {
            case 'CURRENCY':
                return 'currency';
            case 'NUMBER':
            case 'DOUBLE':
            case 'INTEGER':
                return 'number';
            case 'DATE':
                return 'date';
            case 'DATETIME':
                return 'datetime';
            case 'EMAIL':
                return 'email';
            case 'PHONE':
                return 'phone';
            case 'URL':
                return 'url';
            case 'BOOLEAN':
                return 'boolean';
            default:
                return 'text';
        }
    }

    /**
    * Method Name : applyFieldFormat
    * @description : Method to apply formatting based on the format value from dateOptions and dateTimeOptions
    * Date: 03/03/2026
    * Created By: Karan Singh
    */
    applyFieldFormat(fieldValue, format) {
        try {
            let date = new Date(fieldValue);
            
            // Check if date is valid
            if (isNaN(date.getTime())) {
                return fieldValue;
            }
            
            let day = String(date.getDate()).padStart(2, '0');
            let month = String(date.getMonth() + 1).padStart(2, '0');
            let year = date.getFullYear();
            let hours24 = String(date.getHours()).padStart(2, '0');
            let minutes = String(date.getMinutes()).padStart(2, '0');
            let hours12 = hours24 > 12 ? String(hours24 - 12).padStart(2, '0') : hours24;
            let period = hours24 >= 12 ? 'PM' : 'AM';

            switch (format) {
                // Date formats
                case 'ddmmyyyy':
                    return `${day}-${month}-${year}`;
                case 'mmddyyyy':
                    return `${month}-${day}-${year}`;
                case 'yyyymmdd':
                    return `${year}-${month}-${day}`;

                // DateTime 24-hour formats
                case 'ddmmyyy24':
                    return `${day}-${month}-${year} ${hours24}:${minutes}`;
                case 'mmddyyyy24':
                    return `${month}-${day}-${year} ${hours24}:${minutes}`;
                case 'yyyymmdd24':
                    return `${year}-${month}-${day} ${hours24}:${minutes}`;

                // DateTime 12-hour formats
                case 'ddmmyyy12':
                    return `${day}-${month}-${year} ${hours12}:${minutes} ${period}`;
                case 'mmddyyyy12':
                    return `${month}-${day}-${year} ${hours12}:${minutes} ${period}`;
                case 'yyyymmdd12':
                    return `${year}-${month}-${day} ${hours12}:${minutes} ${period}`;

                default:
                    return fieldValue;
            }
        } catch (error) {
            errorDebugger('displayListing', 'applyFieldFormat', error, 'warn', 'Error applying field format');
            return fieldValue;
        }
    }

    /**
    * Method Name : processListingData
    * @description : process listing data for dynamic columns
    */
    processListingData(listings) {
        const cols = this.tableColumns;

        return (listings || []).map(listing => {
            const row = { ...listing };
            row.displayFields = cols.map(col => {
                let fieldValue = listing[col.fieldName.toLowerCase()];
                // Check if value exists, otherwise default to '-'
                const hasRealValue = fieldValue !== null && fieldValue !== undefined && fieldValue !== '';
                let displayValue = hasRealValue ? fieldValue : '-';
                
                // Apply formatting for date/datetime fields if format is provided
                if (col.format && hasRealValue && (col.type === 'date' || col.type === 'datetime' || col.fieldType === 'DATE' || col.fieldType === 'DATETIME')) {
                    displayValue = this.applyFieldFormat(fieldValue, col.format);
                }
                
                return {
                    key: col.fieldName,
                    value: displayValue,
                    hasValue: true, // Always true to display either the value or the hyphen
                    isNameField: col.fieldName === 'name',
                    isCurrency: col.type === 'currency',
                    isImage: col.type === 'image' || col.fieldName === 'media_url',
                    isAction: col.type === 'action' || col.fieldName === 'actions'
                };
            });
            return row;
        });
    }

    /**
    * Method Name : get tableColumns
    * @description : getter for table columns for list view
    */
    get tableColumns() {
        return this.listingColumns.length > 0 ? this.listingColumns : this.defaultColumns;
    }

    /**
    * Method Name: fetchListings
    * @description: this method is used to get all listing and inquiry data from apex
    * Date: 17/06/2024
    * Created By: Mitrajsinh Gohil
    * Last modified by : Rachit Shah
    */
    fetchListings() {
        getRecords({ recId: this.recordId, objectName: this.objectName })
            .then(result => {
                const data = result;
                let inquiry = {};
                if (this.objectName === 'MVEX__Inquiry__c') {
                    this.totalListing = this.convertKeysToLowercase(data.listings);
                    this.modalFilteredListingData = [...this.totalListing];
                    inquiry = data.inquiries[0];
                    this.inquiryRecord = inquiry;
                    this.propertyMediaUrls = result.medias;
                }

                this.totalListing.forEach(row => {
                    const prop_id = row.mvex__property__c;
                    row.media_url = this.propertyMediaUrls[prop_id];
                });

                const convertoLowerCase = (obj) => {
                    return Object.keys(obj).reduce((acc, key) => {
                        acc[key.toLowerCase()] = obj[key];
                        return acc;
                    }, {});
                };

                const lowerCaseListing = convertoLowerCase(inquiry);
                this.inquiryRecord = lowerCaseListing;

                this.applyFiltersData(this.inquiryRecord);
            })
            .catch(error => errorDebugger('DisplayListing', 'fetchListings', error, 'warn', 'Error in fetchListings'));
    }

    /**
    * Method Name: handleClickOutside
    * @description: this method is used to hide div if any outside click is occurs
    * Date: 17/06/2024
    * Created By: Vyom Soni
    */
    handleClickOutside = (event) => {
        if (this.divElement && !this.divElement.contains(event.target)) {
            this.hideModalBox();
            this.closeAddConditionModal();
        }
    }

    /**
    * Method Name: handleInsideClick
    * @description: this method is used to stop closing div if clicked inside it
    * Date: 17/06/2024
    * Created By: Vyom Soni
    */
    handleInsideClick(event) {
        event.stopPropagation();
    }

    /**
    * Method Name: convertKeysToLowercase
    * @description: this method is used to convert all things in lowercase
    * Date: 17/06/2024
    * Created By: Rachit Shah
    */
    convertKeysToLowercase(array) {
        return array.map(item => {
            const newItem = {};
            Object.keys(item).forEach(key => {
                newItem[key.toLowerCase()] = item[key];
            });
            return newItem;
        });
    }

    /**
    * Method Name: applyFiltersData
    * @description: this method is used to filter data initially when component is loaded
    * Date: 17/06/2024
    * Created By: Rachit Shah
    */
    applyFiltersData(inquiry) {
        try {
            this.pagedFilteredListingData = this.totalListing;

            // Mappings are already objects now
            this.mappings = this.mappings.map(mapping => {
                let resolvedValue = mapping.valueField;
                let displayValue = mapping.displayValue || mapping.valueField;

                if (mapping.type !== 'constant') {
                    // It's a field reference to the Inquiry object
                    const fieldName = mapping.valueField ? mapping.valueField.toLowerCase() : '';
                    resolvedValue = inquiry[fieldName] !== undefined ? inquiry[fieldName] : '';
                    // Try to find label for display if not set
                    if (!mapping.displayValue) {
                        const inquiryOption = this.inquiryFieldOptions.find(opt => opt.value === mapping.valueField);
                        displayValue = inquiryOption ? inquiryOption.label : mapping.valueField;
                    }
                }

                return {
                    ...mapping,
                    resolvedValue: resolvedValue,
                    displayValue: displayValue
                };
            });

            if (this.conditiontype === 'custom') {
                if (!this.logicalExpression || this.logicalExpression.trim() === '') {
                    this.logicalExpression = this.mappings.map(m => m.id).join(' AND ');
                }

                const mappinglength = this.mappings.length;
                const regex = /\d+\s*(?:AND|OR)\s*\d+/i;

                if (!regex.test(this.logicalExpression) && mappinglength > 1) {
                }

                if (!regex.test(this.logicalExpression) && mappinglength > 1 && !/^\d+$/.test(this.logicalExpression)) {
                    this.showToast('Error', 'Invalid condition syntax in custom logic. Use numbers, AND, OR, spaces, and parentheses only.', 'error');
                    return;
                }

                const numbers = this.logicalExpression.match(/\d+/g);
                if (numbers) {
                    const numberSet = new Set(numbers.map(Number));
                    const invalidIndex = Array.from(numberSet).some(num => num >= mappinglength + 1 || num < 1);
                    if (invalidIndex) {
                        this.showToast('Error', `Condition uses invalid index. Use indices from 1 to ${mappinglength}.`, 'error');
                        return;
                    }
                    if (numberSet.size !== mappinglength) {
                        this.showToast('Error', 'Condition must include all indices.', 'error');
                        return;
                    }
                }


                this.pagedFilteredListingData = this.totalListing.filter(listing => {
                    let filterResults = {};

                    this.mappings.forEach((mapping) => {
                        let fieldValue = listing[mapping.field.toLowerCase()];
                        let filterValue = mapping.resolvedValue;

                        // Normalize values for comparison
                        const normFieldValue = (fieldValue !== undefined && fieldValue !== null) ? fieldValue : '';
                        const normFilterValue = (filterValue !== undefined && filterValue !== null) ? filterValue : '';

                        let result = false;
                        switch (mapping.operator) {
                            case 'lessThan':
                                result = isNaN(parseFloat(normFieldValue)) || isNaN(parseFloat(normFilterValue)) ? false : parseFloat(normFieldValue) < parseFloat(normFilterValue);
                                break;
                            case 'greaterThan':
                                result = isNaN(parseFloat(normFieldValue)) || isNaN(parseFloat(normFilterValue)) ? false : parseFloat(normFieldValue) > parseFloat(normFilterValue);
                                break;
                            case 'equalTo':
                                // Use soft equality for string vs number comparison
                                result = normFieldValue == normFilterValue;
                                break;
                            case 'contains':
                                result = String(normFieldValue).toLowerCase().includes(String(normFilterValue).toLowerCase());
                                break;
                            case 'notEqualTo':
                                result = normFieldValue != normFilterValue;
                                break;
                            case 'notContains':
                                result = !String(normFieldValue).toLowerCase().includes(String(normFilterValue).toLowerCase());
                                break;
                            case 'isNull':
                                // true value means find null records; false means find non-null records
                                if (mapping.valueField === 'true') {
                                    result = fieldValue === null || fieldValue === undefined || String(fieldValue).trim() === '';
                                } else {
                                    result = fieldValue !== null && fieldValue !== undefined && String(fieldValue).trim() !== '';
                                }
                                break;
                            default:
                                result = false;
                        }
                        filterResults[mapping.id] = result;
                    });

                    const evalExpression = this.logicalExpression
                        .replace(/\bAND\b/gi, '&&')
                        .replace(/\bOR\b/gi, '||');

                    try {
                        const evaluationResult = eval(evalExpression.replace(/\d+/g, match => filterResults[match]));
                        return evaluationResult;
                    } catch (e) {
                        console.error('Error evaluating expression', e);
                        return false;
                    }
                });
            } else if (this.conditiontype === 'any') {
                this.selectedConditionType = 'Any Condition Is Met';
                this.logicalExpression = '';
                this.pagedFilteredListingData = this.totalListing.filter(listing => {
                    return this.mappings.some(mapping => {
                        let fieldValue = listing[mapping.field.toLowerCase()];
                        let filterValue = mapping.resolvedValue;

                        const normFieldValue = (fieldValue !== undefined && fieldValue !== null) ? fieldValue : '';
                        const normFilterValue = (filterValue !== undefined && filterValue !== null) ? filterValue : '';

                        switch (mapping.operator) {
                            case 'greaterThan':
                                return isNaN(parseFloat(normFieldValue)) || isNaN(parseFloat(normFilterValue)) ? false : parseFloat(normFieldValue) > parseFloat(normFilterValue);
                            case 'lessThan':
                                return isNaN(parseFloat(normFieldValue)) || isNaN(parseFloat(normFilterValue)) ? false : parseFloat(normFieldValue) < parseFloat(normFilterValue);
                            case 'equalTo':
                                return normFieldValue == normFilterValue;
                            case 'contains':
                                return String(normFieldValue).toLowerCase().includes(String(normFilterValue).toLowerCase());
                            case 'notEqualTo':
                                return normFieldValue != normFilterValue;
                            case 'notContains':
                                return !String(normFieldValue).toLowerCase().includes(String(normFilterValue).toLowerCase());
                            case 'isNull':
                                // true value means find null records; false means find non-null records
                                if (mapping.valueField === 'true') {
                                    return fieldValue === null || fieldValue === undefined || String(fieldValue).trim() === '';
                                }
                                return fieldValue !== null && fieldValue !== undefined && String(fieldValue).trim() !== '';
                            default:
                                return false;
                        }
                    });
                });
            } else if (this.conditiontype === 'all') {
                this.selectedConditionType = 'All Condition Are Met';
                this.logicalExpression = '';
                this.pagedFilteredListingData = this.totalListing.filter(listing => {
                    return this.mappings.every(mapping => {
                        let listingValue = listing[mapping.field.toLowerCase()];
                        let filterValue = mapping.resolvedValue;

                        const normListingValue = (listingValue !== undefined && listingValue !== null) ? listingValue : '';
                        const normFilterValue = (filterValue !== undefined && filterValue !== null) ? filterValue : '';

                        switch (mapping.operator) {
                            case 'greaterThan':
                                return isNaN(parseFloat(normListingValue)) || isNaN(parseFloat(normFilterValue)) ? false : parseFloat(normListingValue) > parseFloat(normFilterValue);
                            case 'lessThan':
                                return isNaN(parseFloat(normListingValue)) || isNaN(parseFloat(normFilterValue)) ? false : parseFloat(normListingValue) < parseFloat(normFilterValue);
                            case 'equalTo':
                                return normListingValue == normFilterValue;
                            case 'contains':
                                return String(normListingValue).toLowerCase().includes(String(normFilterValue).toLowerCase());
                            case 'notEqualTo':
                                return normListingValue != normFilterValue;
                            case 'notContains':
                                return !String(normListingValue).toLowerCase().includes(String(normFilterValue).toLowerCase());
                            case 'isNull':
                                // true value means find null records; false means find non-null records
                                if (mapping.valueField === 'true') {
                                    return listingValue === null || listingValue === undefined || String(listingValue).trim() === '';
                                }
                                return listingValue !== null && listingValue !== undefined && String(listingValue).trim() !== '';
                            default:
                                return false;
                        }
                    });
                });
            } else if (this.conditiontype === 'related') {
                this.selectedConditionType = 'Related List';
                this.pagedFilteredListingData = this.totalListing.filter(listing => {
                    return listing.mvex__inquiries__r && listing.mvex__inquiries__r.some(inq => inq.Id === this.recordId);
                });
            } else if (this.conditiontype === 'none') {
                this.selectedConditionType = 'None';
                this.pagedFilteredListingData = [...this.totalListing];
            }

            this.modalFilteredListingData = [...this.pagedFilteredListingData];
            this.hideModalBox(false);
            this.searchTerm = '';
            this.isPropertyAvailable = this.pagedFilteredListingData.length > 0;
            this.totalRecords = this.pagedFilteredListingData.length;
            this.currentPage = 1;
            this.updateMapMarkers();
            this.isLoading = false;
        } catch (error) {
            errorDebugger('DisplayListing', 'applyFiltersData', error, 'warn', 'Error in applyFiltersData');
            this.showToast('Error', 'Error applying filters', 'error');
        }
    }

    /**
    * Method Name : handlePrevious
    * @description : handle the previous button click in the pagination.
    * date: 20/08/2024
    * Created By:Vyom Soni
    */
    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updateMapMarkers();
        }
    }

    /**
     * Method Name : handleNext
     * @description : handle the next button click in the pagination.
     * date: 20/08/2024
     * Created By:Vyom Soni
     */
    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updateMapMarkers();
        }
    }

    /**
     * Method Name : handleMappingClick
     * @description : handle the mapping click in the filter list.
     * date: 16/10/2024
     * Created By:Rachit Shah
     */
    handleMappingClick(event) {
        if (event.target?.closest('.delete-div')) {
            return;
        }

        const nameAttribute = event.currentTarget.dataset.name;

        if (nameAttribute && nameAttribute !== 'delete') {
            const previouslySelected = this.template.querySelector('.selected');
            if (previouslySelected) {
                previouslySelected.classList.remove('selected');
            }

            event.currentTarget.classList.add('selected');

            const mappingId = event.currentTarget.dataset.id;
            this.isAddConditionModalVisible = true;

            const currentMapping = this.mappings.find(mapping => mapping.id === parseInt(mappingId, 10));

            if (currentMapping) {
                this.selectedMappingId = currentMapping.id;
                this.isConstant = currentMapping.type === 'constant';
                this.selectedRecordName = currentMapping.displayValue;

                // Trigger field change logic to populate metadata
                this.handleInquiryFieldChange({ detail: { value: currentMapping.field } });

                // Re-apply values after metadata update
                this.listingFieldObject.MVEX__Field_Name__c = currentMapping.field;
                this.selectedConditionOperator = currentMapping.operator;
                this.selectedInquiryValue = currentMapping.valueField;
                this.selectedRecordName = currentMapping.displayValue;
            }
        }
    }

    /**
     * Method Name : handlePageChange
     * @description : handle the direct click on page number.
     * date: 20/08/2024
     * Created By:Vyom Soni
     */
    handlePageChange(event) {
        const selectedPage = parseInt(event.target.getAttribute('data-id'), 10);
        if (selectedPage !== this.currentPage) {
            this.currentPage = selectedPage;
            this.updateMapMarkers();
        }
    }

    /**
    * Method Name: updateMapMarkers
    * @description: this method is used to update and set the markers on the map for the properties with the pagination
    * Date: 17/06/2024
    * Created By: Mitrajsinh Gohil
    * Last modified by : Rachit Shah
    */
    updateMapMarkers() {
        const startIndex = (this.currentPage - 1) * this.pageSize;
        const currentPageData = this.pagedFilteredListingData.slice(startIndex, startIndex + this.pageSize);

        this.mapMarkers = currentPageData.map(listing => ({
            id: listing.id,
            location: {
                Street: listing.mvex__street__c,
                City: listing.mvex__city__c,
                State: listing.mvex__state__c,
                Country: listing.mvex__country__c
            },
            title: listing.Name,
            description: `City: ${listing.mvex__city__c}, Sq Ft: ${listing.mvex__sq_ft__c}`,
            icon: 'custom:custom26',
            media_url: listing.media_url
        }));
    }

    /**
    * Method Name: applyFilters
    * @description: this method is used apply filter
    * Date: 25/07/2024
    * Created By: Rachit Shah
    */
    applyFilters() {
        try {

            this.pagedFilteredListingData = this.modalFilteredListingData.filter(listing => {
                const searchListing = listing.name.toLowerCase().includes(this.searchTerm);
                return searchListing;
            });

            this.isPropertyAvailable = this.pagedFilteredListingData.length > 0;
            this.currentPage = 1;
            this.totalRecords = this.pagedFilteredListingData.length;
            this.updateMapMarkers();

        } catch (error) {
            errorDebugger('DisplayListing', 'applyFilters', error, 'warn', 'Error in applyFilters');
        }
    }

    /**
    * Method Name: handleSearch
    * @description: this method is used to filter the properties based on the search key without overriding other filters
    * Date: 17/06/2024
    * Created By: Mitrajsinh Gohil
    */
    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.applyFilters();
        this.currentPage = 1;
        this.totalRecords = this.pagedFilteredListingData.length;
        this.isPropertyAvailable = this.totalRecords > 0;
        this.updateMapMarkers();
    }

    /**
    * Method Name : handleMenuTabClick
    * @description : handle the menu clicks in the header
    *  Date: 3/06/2024
    * Created By:Vyom Soni
    */
    handleMenuTabClick(evt) {
        try {
            let target = evt.currentTarget.dataset.tabId;
            if (target === "1") {
                this.selectedView = 'List';
                this.currentPage = 1;
            } else if (target === "2") {
                this.selectedView = 'Grid';
                this.currentPage = 1;
            } else if (target === "3") {
                this.selectedView = 'map';
                this.currentPage = 1;
                this.updateMapMarkers();
            }

            this.template.querySelectorAll(".tab-div").forEach(tabEl => {
                tabEl.classList.remove("active-tab-div");
                const pathEl = tabEl.querySelector('path');
                if (pathEl) {
                    pathEl.style.fill = '#131314';
                }
            });

            // Add active class and set fill color for the selected tab
            const selectedTab = this.template.querySelector(`[data-tab-id="${target}"]`);
            selectedTab.classList.add("active-tab-div");
            const selectedPath = selectedTab.querySelector('path[data-tab-index="' + target + '"]');
            if (selectedPath) {
                selectedPath.style.fill = '#fff';
            }
        } catch (error) {
            errorDebugger('DisplayListing', 'handleMenuTabClick', error, 'warn', 'Error in handleMenuTabClick');
        }
    }

    /**
    * Method Name: navigateToRecord
    * @description: this method is used to navigate to listing record page on click of view more
    * Date: 17/06/2024
    * Created By: Rachit Shah
    */
    navigateToRecord(event) {
        const propertyId = event.target.dataset.id;
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                recordId: propertyId,
                actionName: 'view'
            }
        }).then(url => {
            window?.globalThis?.open(url, '_blank');
        }).catch(error => {
            errorDebugger('DisplayListing', 'navigateToRecord', error, 'warn', 'Error in navigateToRecord');
        });
    }

    /**
    * Method Name: showToast
    * @description: this method is used to show toast message
    * Date: 26/07/2024
    * Created By: Mitrajsinh Gohil
    */
    showToast(title, message, variant) {
        if (typeof window !== 'undefined') {
            this.dispatchEvent(new ShowToastEvent({
                title,
                message,
                variant
            }));
        }
    }

    /**
    * Method Name: showModalBox
    * @description: this method is used to show modal 
    * Date: 17/06/2024
    * Created By: Rachit Shah
    */
    showModalBox() {
        this.filterModalSnapshot = {
            conditiontype: this.conditiontype,
            selectedConditionType: this.selectedConditionType,
            logicalExpression: this.logicalExpression,
            mappings: JSON.parse(JSON.stringify(this.mappings || []))
        };
        this.isShowModal = true;
    }

    /**
    * Method Name: hideModalBox
    * @description: this method is used to hide modal 
    * Date: 17/06/2024
    * Created By: Rachit Shah
    */
    hideModalBox(shouldRevert = true) {
        if (shouldRevert && this.filterModalSnapshot) {
            this.conditiontype = this.filterModalSnapshot.conditiontype;
            this.selectedConditionType = this.filterModalSnapshot.selectedConditionType;
            this.logicalExpression = this.filterModalSnapshot.logicalExpression;
            this.mappings = JSON.parse(JSON.stringify(this.filterModalSnapshot.mappings || []));
        }

        this.filterModalSnapshot = null;
        this.isShowModal = false;
        this.closeAddConditionModal();
    }

    /**
    * Method Name: handleDeleteMapping
    * @description: this method is used to delete mapping from the filter list
    * Date: 17/06/2024
    * Created By: Rachit Shah
    */
    handleDeleteMapping(event) {
        event.stopPropagation();
        const mappingIdToDelete = event.currentTarget.dataset.id;
        this.mappings = this.mappings
            .filter(mapping => mapping.id !== parseInt(mappingIdToDelete, 10))
            .map((mapping, index) => {
                return { ...mapping, id: index + 1 };
            });
    }

    /**
    * Method Name: getValueFromLabel
    * @description: this method is used to get api name from label
    * Date: 17/06/2024
    * Created By: Rachit Shah
    */
    getValueFromLabel(label) {
        let tempLabel = label.toLowerCase();
        const option = this.listingFieldOptions.find(opt => opt.value.toLowerCase() === tempLabel);
        return option ? option.label : tempLabel;
    }

    /**
    * Method Name: displayOperator
    * @description: this method is used to display operator
    * Date: 17/06/2024
    * Created By: Rachit Shah
    */
    displayOperator(operator) {
        switch (operator) {
            case 'lessThan':
                return 'Less than';
            case 'greaterThan':
                return 'Greater than';
            case 'equalTo':
                return 'Equals to';
            case 'contains':
                return 'Contains';
            case 'notEqualTo':
                return 'Not Equal To';
            case 'notContains':
                return 'Not Contains';
            case 'isNull':
                return 'Is Null';
            default:
                return operator;
        }
    }

    /**
    * Method Name: handleConditionTypeChange
    * @description: this method is used handle condition type change
    * Date: 17/06/2024
    * Created By: Rachit Shah
    */
    handleConditionTypeChange(event) {
        this.conditiontype = event.detail.value;
        this.selectedConditionType = this.conditionOptions.find(option => option.value === this.conditiontype)?.label || '';
    }

    /**
    * Method Name: handleLogicalExpressionChange
    * @description: this method is used handle logical condition change
    * Date: 17/06/2024
    * Created By: Rachit Shah
    */
    handleLogicalExpressionChange(event) {
        this.logicalExpression = event.detail.value;
    }

    /**
    * Method Name: addCondition
    * @description: this method is used to open condition modal
    * Date: 17/06/2024
    * Created By: Rachit Shah
    */
    addCondition() {
        this.isAddConditionModalVisible = true;
    }

    /**
    * Method Name: applyModalFilters
    * @description: this method is used to apply filter based on the mappings
    * Date: 17/06/2024
    * Created By: Rachit Shah
    */
    applyModalFilters() {
        try {

            // Save Configuration Logic
            const config = {
                conditionType: 'Related List',
                logic: this.logicalExpression,
                mappings: this.mappings
            };

            saveMappings({objectApiName: 'MVEX__Listing__c', featureName: 'Suggested_Listing_Filters', checklistData: JSON.stringify(config), totalPages: 0})
                .then(result => {
                    if (result === 'Success') {
                        console.log('Configuration saved successfully');
                    } else {
                        this.showToast('Error', 'Failed to save configuration: '+result, 'error');
                    }
                })
                .catch(error => {
                    errorDebugger('DisplayListing', 'saveConfiguration', error, 'warn', 'Error saving configuration');
                });

            if (this.mappings.length === 0) {
                this.pagedFilteredListingData = [...this.totalListing];
                this.modalFilteredListingData = [...this.pagedFilteredListingData];
                this.isPropertyAvailable = this.pagedFilteredListingData.length > 0;
                this.totalRecords = this.pagedFilteredListingData.length;
                this.currentPage = 1;
                this.logicalExpression = '';
                this.hideModalBox(false);
                this.isLoading = false;
                this.updateMapMarkers();
                return;
            }

            this.applyFiltersData(this.inquiryRecord);
        } catch (error) {
            errorDebugger('DisplayListing', 'applyModalFilters', error, 'warn', 'Error in applyModalFilters');
        }
    }

    /**
    * Method Name: handleInquiryFieldChange
    * @description: this method is used to handle data type change in the inqury fields
    * Date: 17/06/2024
    * Created By: Rachit Shah
    */
    handleInquiryFieldChange(event) {
        const value = event.detail.value;
        this.listingFieldObject.MVEX__Field_Name__c = value;
        this.selectedConditionOperator = '';
        this.selectedInquiryValue = '';

        const selectedField = this.listingFieldOptions.find(field => field.value === value);

        if (selectedField) {
            const fieldType = selectedField.type;

            const primaryFieldTypes = ['TEXT', 'DATETIME', 'DATE', 'NUMBER', 'EMAIL'];
            const picklistFieldTypes = ['PICKLIST', 'BOOLEAN', 'MULTIPICKLIST'];
            const referenceFieldTypes = ['REFERENCE'];

            this.listingFieldObject.isPrimary = primaryFieldTypes.includes(fieldType);
            this.listingFieldObject.isPicklist = picklistFieldTypes.includes(fieldType);
            this.listingFieldObject.isReference = referenceFieldTypes.includes(fieldType);
            this.listingFieldObject.MVEX__Data_Type__c = fieldType;

            if (fieldType === 'REFERENCE') {
                this.listingFieldObject.objectApiName = selectedField.referenceTo;
            } else {
                if (this.listingFieldObject.isPicklist && selectedField.picklistValues.length > 0) {
                    this.listingFieldObject.picklistValues = selectedField.picklistValues.map(picklistValue => {
                        return { label: picklistValue, value: picklistValue };
                    });
                } else {
                    this.listingFieldObject.picklistValues = null;
                }
            }
        }
    }

    /**
    * Method Name: handleConditionOperatorChange
    * @description: this method is used to handle condition operator change
    * Date: 17/06/2024
    * Created By: Rachit Shah
    */
    handleConditionOperatorChange(event) {
        this.selectedConditionOperator = event.detail.value;
        this.selectedInquiryValue = ''; // Reset value when operator changes to avoid stale data
    }

    /**
    * Method Name: handleListingFieldChange
    * @description: this method is used to handle listing field change
    * Date: 17/06/2024
    * Created By: Rachit Shah
    */
    handleListingFieldChange(event) {
        this.selectedInquiryValue = event.target.value;
    }

    /**
    * Method Name: handleRefChange
    * @description: this method is used to handle field type change for the reference
    * Date: 17/06/2024
    * Created By: Rachit Shah
    */
    handleRefChange(event) {
        try {
            event.stopPropagation();
            let selectedValueId = event.detail.recordId;
            this.selectedInquiryValue = selectedValueId;
            this.selectedRecordName = ''; // Reset

            if (selectedValueId && this.listingFieldObject.objectApiName) {
                getRecordName({ recordId: selectedValueId, objectApiName: this.listingFieldObject.objectApiName })
                    .then(name => {
                        this.selectedRecordName = name;
                    })
                    .catch(error => {
                        errorDebugger('DisplayListing', 'handleRefChange', error, 'warn', 'Error fetching record name');
                    });
            }
        } catch (error) {
            errorDebugger('DisplayListing', 'handleRefChange', error, 'warn', 'Error in handleRefChange');
        }
    }

    /**
    * Method Name: closeAddConditionModal
    * @description: this method is used to close add condition modal
    * Date: 17/06/2024
    * Created By: Rachit Shah
    */
    closeAddConditionModal() {
        this.listingFieldObject.MVEX__Field_Name__c = '';
        this.listingFieldObject.isPrimary = true;
        this.listingFieldObject.isPicklist = false;
        this.listingFieldObject.isReference = false;
        this.selectedConditionOperator = '';
        this.selectedInquiryValue = '';
        this.selectedRecordName = '';
        this.isAddConditionModalVisible = false;
        this.selectedMappingId = null;

        const previouslySelected = this.template.querySelector('.selected');
        if (previouslySelected) {
            previouslySelected.classList.remove('selected');
        }
    }

    handleUseConstantChange(event) {
        this.isConstant = event.target.checked;
        this.selectedInquiryValue = '';
    }

    /**
    * Method Name : saveCondition
    * @description : method to save condition
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    saveCondition() {
        const isFieldValid = this.listingFieldObject.MVEX__Field_Name__c;
        const isOperatorValid = this.selectedConditionOperator;
        // For isNull operator, value selection (True/False) is still required
        const isValueValid = this.selectedInquiryValue; // constant or inquiry field

        if (isFieldValid && isOperatorValid && isValueValid) {
            let label = this.getValueFromLabel(this.listingFieldObject.MVEX__Field_Name__c);
            let displayOperator = this.displayOperator(this.selectedConditionOperator);

            // Determine display value
            let displayValue = this.selectedInquiryValue;
            if (this.selectedConditionOperator === 'isNull') {
                // For isNull, display True or False
                displayValue = this.selectedInquiryValue === 'true' ? 'True' : 'False';
            } else if (!this.isConstant) {
                const inquiryOption = this.inquiryFieldOptions.find(opt => opt.value === this.selectedInquiryValue);
                displayValue = inquiryOption ? inquiryOption.label : this.selectedInquiryValue;
            } else if (this.listingFieldObject.isPicklist && this.listingFieldObject.picklistValues) {
                const picklistOption = this.listingFieldObject.picklistValues.find(opt => opt.value === this.selectedInquiryValue);
                displayValue = picklistOption ? picklistOption.label : this.selectedInquiryValue;
            } else if (this.listingFieldObject.isReference && this.selectedRecordName) {
                displayValue = this.selectedRecordName;
            }

            const newMapping = {
                id: this.selectedMappingId ? this.selectedMappingId : this.mappings.length + 1,
                field: this.listingFieldObject.MVEX__Field_Name__c,
                operator: this.selectedConditionOperator,
                valueField: this.selectedInquiryValue,
                label: label,
                displayOperator: displayOperator,
                type: this.isConstant ? 'constant' : 'field',
                displayValue: displayValue
            };

            if (this.selectedMappingId) {
                const index = this.mappings.findIndex(mapping => mapping.id === this.selectedMappingId);
                if (index !== -1) {
                    this.mappings[index] = newMapping;
                }
                this.selectedMappingId = null;
            } else {
                this.mappings = [...this.mappings, newMapping];
            }

            this.closeAddConditionModal();
            // Reset fields
            this.listingFieldObject = { ...this.listingFieldObject, MVEX__Field_Name__c: '', MVEX__Value__c: '' };
            this.selectedConditionOperator = '';
            this.selectedInquiryValue = '';
            this.isConstant = false;

        } else {
            this.showToast('Error', 'Please fill all required fields', 'error');
        }
    }

    /**
    * Method Name: disconnectedCallback
    * @description: this method is used to remove click event when component destroy
    * Date: 17/06/2024
    * Created By: Rachit Shah
    */
    disconnectedCallback() {
        window?.globalThis?.removeEventListener('click', this.handleClickOutside);
    }

    openConfigureSettings() {
        this.isConfigOpen = true;
    }



    handleCloseModal() {
        this.isConfigOpen = false;
        this.fetchListingConfiguration();
    }
}