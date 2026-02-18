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
import getMetadata from '@salesforce/apex/DynamicMappingCmp.getMetadata';
import getFieldMap from '@salesforce/apex/PropertySearchController.getObjectFields';
import getConfigObjectFields from '@salesforce/apex/RecordManagersCmpController.getObjectFields'; // Fixed import
import { errorDebugger } from 'c/globalProperties';

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
    @track condtiontype = '';
    @track selectedMappingId = null;

    @track isShowModal = false;

    @track selectedConditionType = 'Custom Logic Is Met';
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
        { label: 'Not Equal To', value: 'notEqualTo' }
    ];
    @track listingFieldOptions = [];
    @track visiblePages = 5;
    @track divElement;

    @track listingColumns = [];
    @track isConfigOpen = false;
    @track defaultColumns = [
        { label: 'Image', fieldName: 'media_url', type: 'image' },
        { label: 'Name', fieldName: 'name', type: 'text' },
        { label: 'Listing Type', fieldName: 'mvex__listing_type__c', type: 'text' },
        { label: 'City', fieldName: 'mvex__city__c', type: 'text' },
        { label: 'Bedrooms', fieldName: 'mvex__bedrooms__c', type: 'number' },
        { label: 'Bathrooms', fieldName: 'mvex__bathrooms__c', type: 'number' },
        { label: 'Price', fieldName: 'mvex__listing_price__c', type: 'currency' },
        { label: 'Actions', fieldName: 'actions', type: 'action' }
    ];

    conditionOptions = [
        { label: 'All Condition Are Met', value: 'All Condition Are Met' },
        { label: 'Any Condition Is Met', value: 'Any Condition Is Met' },
        { label: 'Custom Logic Is Met', value: 'Custom Logic Is Met' },
        { label: 'Related List', value: 'Related List' },
        { label: 'No Filter', value: 'None' },
    ];

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
    connectedCallback() {
        loadStyle(this, MulishFontCss);
        this.isLoading = true;
        this.getListingFields();
        this.fetchListingConfiguration(); // This will call fetchMetadataRecords internally
        loadStyle(this, mapCss_V1)
            .then(() => {
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                errorDebugger('DisplayListing', 'loadStyle:connectedCallback', error, 'warn', 'Error while loading css and fetching data');
            });
        window?.globalThis?.addEventListener('click', this.handleClickOutside);
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
        getFieldMap({ objectName: 'MVEX__Listing__c' })
            .then(result => {
                this.listingFieldOptions = result.fields;
                this.listingpicklistOptions = result.fields.map(field => {
                    return { label: field.label, value: field.value };
                }).sort((a, b) => a.label.localeCompare(b.label));
            })
            .catch(error => errorDebugger('DisplayListing', 'getListingFields', error, 'warn', 'Error in getListingFields'));
    }

    fetchMetadataRecords() {
        this.isLoading = true;
        getMetadata()
            .then((result) => {
                if (result && result.length > 0) {
                    let allFilters = result[0] ? result[0].split(';') : [];
                    const listingLogic = result[1];
                    const listingCondition = result[2];
                    const inquiryLogic = result[3];
                    this.filters = allFilters.filter(filter => filter.includes('MVEX__Listing__c'));

                    if(listingLogic == 'empty'){
                        this.logicalExpression = inquiryLogic;
                    }else {
                        this.logicalExpression = listingLogic;
                    }
                    
                    this.condtiontype = listingCondition;
                }
                this.fetchListings();
                this.isLoading = false;
            })
            .catch((error) => {
                errorDebugger('DisplayListing', 'fetchMetadataRecords', error, 'warn', 'Error in fetchMetadataRecords');
                this.showToast('Error', 'Error fetching metadata', 'error');
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
    getConfigObjectFields({ objectApiName: 'MVEX__Listing__c', featureName: 'Listing_Configuration' })
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
                            format: field.format
                        })),
                        { label: 'Actions', fieldName: 'actions', type: 'action' }
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
            this.fetchMetadataRecords();
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
* Method Name : processListingData
* @description : process listing data for dynamic columns
*/
processListingData(listings) {
    const cols = this.tableColumns;
    
    return (listings || []).map(listing => {
        const row = { ...listing };
        row.displayFields = cols.map(col => {
            const fieldValue = listing[col.fieldName.toLowerCase()];
            return {
                key: col.fieldName,
                value: fieldValue,
                hasValue: fieldValue !== null && fieldValue !== undefined && fieldValue !== '',
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

            this.mappings = this.filters.map((mappingStr, index) => {
                let [object, field, operator, valueField] = mappingStr.split(':');
                let fieldLabel = '';
                field = field.toLowerCase();
                valueField = valueField.toLowerCase();

                if (object === 'MVEX__Listing__c') {
                    fieldLabel = this.getValueFromLabel(field);

                    return {
                        id: index + 1,
                        field: field,
                        operator: operator,
                        displayOperator: this.displayOperator(operator),
                        valueField: inquiry[valueField] ? inquiry[valueField] : '',
                        label: fieldLabel
                    };
                }

                return null;
            }).filter(mapping => mapping !== null);

            console.log('applyFiltersData: mappings', JSON.stringify(this.mappings));
            console.log('applyFiltersData: logicalExpression', this.logicalExpression);
            console.log('applyFiltersData: condtiontype', this.condtiontype);

            const parsedFilters = this.filters.map(filter => {
                const [object, field, operator, valueField] = filter.split(':');
                return { object, field: field.toLowerCase(), operator, valueField: valueField.toLowerCase() };
            });

            if (this.condtiontype === 'custom') {
                if (!this.logicalExpression || this.logicalExpression.trim() === '') {
                    this.logicalExpression = parsedFilters.map((_, index) => index + 1).join(' AND ');
                }

                // Validate logical expression
                const mappinglength = this.mappings.length;
                const regex = /\d+\s*(?:AND|OR)\s*\d+/i;

                if (!regex.test(this.logicalExpression)) {
                    this.showToast('Error', 'Invalid condition syntax in custom logic. Use numbers, AND, OR, spaces, and parentheses only.', 'error');
                    this.pagedFilteredListingData = this.totalListing;
                    this.isPropertyAvailable = this.pagedFilteredListingData.length > 0;
                    this.totalRecords = this.pagedFilteredListingData.length;
                    this.currentPage = 1;
                    this.updateMapMarkers();
                    return;
                }

                const numbers = this.logicalExpression.match(/\d+/g);
                if (numbers) {
                    const numberSet = new Set(numbers.map(Number));
                    const invalidIndex = Array.from(numberSet).some(num => num >= mappinglength + 1 || num < 1);

                    if (invalidIndex) {
                        this.showToast('Error', `Condition uses invalid index. Use indices from 1 to ${mappinglength}.`, 'error');
                        this.pagedFilteredListingData = this.totalListing;
                        this.isPropertyAvailable = this.pagedFilteredListingData.length > 0;
                        this.totalRecords = this.pagedFilteredListingData.length;
                        this.currentPage = 1;
                        this.updateMapMarkers();
                        return;
                    }

                    if (numberSet.size !== mappinglength) {
                        this.showToast('Error', 'Condition must include all indices.', 'error');
                        this.pagedFilteredListingData = this.totalListing;
                        this.isPropertyAvailable = this.pagedFilteredListingData.length > 0;
                        this.totalRecords = this.pagedFilteredListingData.length;
                        this.currentPage = 1;
                        this.updateMapMarkers();
                        return;
                    }

                    // Basic syntax check for balanced parentheses
                    let openParens = 0;
                    for (let char of this.logicalExpression) {
                        if (char === '(') openParens++;
                        if (char === ')') openParens--;
                        if (openParens < 0) {
                            this.showToast('Error', 'Unbalanced parentheses in custom logic expression.', 'error');
                            this.pagedFilteredListingData = this.totalListing;
                            this.isPropertyAvailable = this.pagedFilteredListingData.length > 0;
                            this.totalRecords = this.pagedFilteredListingData.length;
                            this.currentPage = 1;
                            this.updateMapMarkers();
                            return;
                        }
                    }
                    if (openParens !== 0) {
                        this.showToast('Error', 'Unbalanced parentheses in custom logic expression.', 'error');
                        this.pagedFilteredListingData = this.totalListing;
                        this.isPropertyAvailable = this.pagedFilteredListingData.length > 0;
                        this.totalRecords = this.pagedFilteredListingData.length;
                        this.currentPage = 1;
                        this.updateMapMarkers();
                        return;
                    }
                } else {
                    this.showToast('Error', 'Condition syntax is correct but contains no indices.', 'error');
                    this.pagedFilteredListingData = this.totalListing;
                    this.isPropertyAvailable = this.pagedFilteredListingData.length > 0;
                    this.totalRecords = this.pagedFilteredListingData.length;
                    this.currentPage = 1;
                    this.updateMapMarkers();
                    return;
                }

                this.pagedFilteredListingData = this.totalListing.filter(listing => {
                    let filterResults = [];

                    parsedFilters.forEach((filter, index) => {
                        let fieldValue, filterValue;

                        if (filter.object === 'MVEX__Listing__c') {
                            // Validate field existence
                            if (!(filter.field in listing)) {
                                console.warn(`applyFiltersData: Field ${filter.field} not found in listing`, listing);
                                filterResults[index + 1] = false;
                                return;
                            }
                            if (!(filter.valueField in inquiry)) {
                                console.warn(`applyFiltersData: Value field ${filter.valueField} not found in inquiry`, inquiry);
                                filterResults[index + 1] = false;
                                return;
                            }

                            fieldValue = listing[filter.field];
                            filterValue = inquiry[filter.valueField];

                            // Ensure values are defined
                            fieldValue = fieldValue !== undefined && fieldValue !== null ? fieldValue : '';
                            filterValue = filterValue !== undefined && filterValue !== null ? filterValue : '';

                            switch (filter.operator) {
                                case 'lessThan':
                                    filterResults[index + 1] = isNaN(parseFloat(fieldValue)) || isNaN(parseFloat(filterValue)) ? false : parseFloat(fieldValue) < parseFloat(filterValue);
                                    break;
                                case 'greaterThan':
                                    filterResults[index + 1] = isNaN(parseFloat(fieldValue)) || isNaN(parseFloat(filterValue)) ? false : parseFloat(fieldValue) > parseFloat(filterValue);
                                    break;
                                case 'equalTo':
                                    filterResults[index + 1] = String(fieldValue) === String(filterValue);
                                    break;
                                case 'contains':
                                    filterResults[index + 1] = String(fieldValue).includes(String(filterValue));
                                    break;
                                case 'notEqualTo':
                                    filterResults[index + 1] = String(fieldValue) !== String(filterValue);
                                    break;
                                case 'notContains':
                                    filterResults[index + 1] = !String(fieldValue).includes(String(filterValue));
                                    break;
                                default:
                                    filterResults[index + 1] = false;
                            }
                        } else {
                            filterResults[index + 1] = false;
                        }
                    });

                    console.log(`applyFiltersData: filterResults for listing ${listing.id}`, filterResults);

                    // Transform AND/OR to &&/|| for eval
                    const evalExpression = this.logicalExpression
                        .replace(/\bAND\b/gi, '&&')
                        .replace(/\bOR\b/gi, '||');
                    console.log(`applyFiltersData: evalExpression for listing ${listing.id}`, evalExpression);
                    const evaluationResult = eval(evalExpression.replace(/\d+/g, match => filterResults[match]));
                    console.log(`applyFiltersData: evaluationResult for listing ${listing.id}`, evaluationResult);

                    return evaluationResult;
                });

                console.log('applyFiltersData: filtered listings count', this.pagedFilteredListingData.length);

                this.isPropertyAvailable = this.pagedFilteredListingData.length > 0;
                this.totalRecords = this.pagedFilteredListingData.length;
                this.currentPage = 1;

                this.updateMapMarkers();
            }
            else if (this.condtiontype === 'any') {
                this.selectedConditionType = 'Any Condition Is Met';
                this.logicalExpression = '';
                this.applyModalFilters();
            }
            else if (this.condtiontype === 'all') {
                this.selectedConditionType = 'All Condition Are Met';
                this.logicalExpression = '';
                this.applyModalFilters();
            }
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
                const selectedField = this.listingFieldOptions.find(field => field.value === currentMapping.field);

                if (selectedField) {
                    const fieldType = (selectedField.type || '').toUpperCase();

                    const primaryFieldTypes = ['TEXT', 'DATETIME', 'DATE', 'NUMBER', 'EMAIL'];
                    const picklistFieldTypes = ['PICKLIST', 'BOOLEAN', 'MULTIPICKLIST'];
                    const referenceFieldTypes = ['REFERENCE'];

                    // Update the object using a spread to ensure LWC detects the state change
                    this.listingFieldObject = {
                        ...this.listingFieldObject,
                        MVEX__Field_Name__c: currentMapping.field,
                        MVEX__Data_Type__c: fieldType,
                        isPrimary: primaryFieldTypes.includes(fieldType),
                        isPicklist: picklistFieldTypes.includes(fieldType),
                        isReference: referenceFieldTypes.includes(fieldType)
                    };

                    if (fieldType === 'REFERENCE') {
                        this.listingFieldObject.objectApiName = selectedField.referenceTo;
                    } else if (this.listingFieldObject.isPicklist && selectedField.picklistValues) {
                        this.listingFieldObject.picklistValues = selectedField.picklistValues.map(picklistValue => {
                            return { label: picklistValue, value: picklistValue };
                        });
                    } else {
                        this.listingFieldObject.picklistValues = null;
                    }

                    // Sync the operator and value to the inputs
                    this.selectedConditionOperator = currentMapping.operator;
                    this.selectedInquiryValue = currentMapping.valueField;
                }
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

            this.pagedFilteredListingData = this.totalListing.filter(listing => {
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
        this.isShowModal = true;
    }

    /**
    * Method Name: hideModalBox
    * @description: this method is used to hide modal 
    * Date: 17/06/2024
    * Created By: Rachit Shah
    */
    hideModalBox() {
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
        this.selectedConditionType = event.detail.value;
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
            if (this.mappings.length === 0) {
                this.pagedFilteredListingData = [...this.totalListing];
                // this.listingData = this.pagedFilteredListingData;
                this.isPropertyAvailable = this.pagedFilteredListingData.length > 0;
                this.totalRecords = this.pagedFilteredListingData.length;
                this.currentPage = 1;
                this.logicalExpression = '';
                this.hideModalBox();
                return;
            }

            if (this.selectedConditionType === 'All Condition Are Met') {
                this.pagedFilteredListingData = this.totalListing.filter(listing => {
                    return this.mappings.every(mapping => {
                        let listingValue = listing[mapping.field.toLowerCase()];
                        let filterValue = mapping.valueField;

                        switch (mapping.operator) {
                            case 'greaterThan':
                                listingValue = listingValue !== undefined ? listingValue : 0;
                                filterValue = filterValue !== undefined ? filterValue : 0;
                                return parseFloat(listingValue) > parseFloat(filterValue);
                            case 'lessThan':
                                listingValue = listingValue !== undefined ? listingValue : 0;
                                filterValue = filterValue !== undefined ? filterValue : 0;
                                return parseFloat(listingValue) < parseFloat(filterValue);
                            case 'equalTo':
                                listingValue = listingValue !== undefined ? listingValue : '';
                                filterValue = filterValue !== undefined ? filterValue : '';
                                return listingValue === filterValue;
                            case 'contains':
                                listingValue = listingValue !== undefined ? listingValue : '';
                                filterValue = filterValue !== undefined ? filterValue : '';
                                return listingValue.includes(filterValue);
                            case 'notEqualTo':
                                listingValue = listingValue !== undefined ? listingValue : '';
                                filterValue = filterValue !== undefined ? filterValue : '';
                                return listingValue !== filterValue;
                            case 'notContains':
                                listingValue = listingValue !== undefined ? listingValue : '';
                                filterValue = filterValue !== undefined ? filterValue : '';
                                return !listingValue.includes(filterValue);
                            default:
                                return false;
                        }
                    });
                });
            }
            else if (this.selectedConditionType === 'Any Condition Is Met') {
                this.pagedFilteredListingData = this.totalListing.filter(listing => {
                    return this.mappings.some(mapping => {
                        let fieldValue = listing[mapping.field.toLowerCase()];

                        switch (mapping.operator) {
                            case 'equalTo':
                                fieldValue = fieldValue !== undefined ? fieldValue : '';
                                return fieldValue === mapping.valueField;
                            case 'greaterThan':
                                fieldValue = fieldValue !== undefined ? fieldValue : 0;
                                return parseFloat(fieldValue) > parseFloat(mapping.valueField);
                            case 'lessThan':
                                fieldValue = fieldValue !== undefined ? fieldValue : 0;
                                return parseFloat(fieldValue) < parseFloat(mapping.valueField);
                            case 'contains':
                                fieldValue = fieldValue !== undefined ? fieldValue : '';
                                return fieldValue && fieldValue.includes(mapping.valueField);
                            case 'notEqualTo':
                                fieldValue = fieldValue !== undefined ? fieldValue : '';
                                return fieldValue !== mapping.valueField;
                            case 'notContains':
                                fieldValue = fieldValue !== undefined ? fieldValue : '';
                                return fieldValue && !fieldValue.includes(mapping.valueField);
                            default:
                                return false;
                        }
                    });
                });
            }
            else if (this.selectedConditionType === 'Related List') {
                this.pagedFilteredListingData = this.totalListing
                .filter(listing => {
                    return listing.mvex__inquiries__r && listing.mvex__inquiries__r.some(inquiry => inquiry.Id === this.recordId);
                })
                .map(property => {
                    return {
                        ...property,
                        media_url: property.media_url ? property.media_url : NoImageFound,
                        mvex__listing_type__c: property.mvex__listing_type__c ? property.mvex__listing_type__c : 'Sale',
                    };
                });
            }
            else if (this.selectedConditionType === 'None') {
                this.pagedFilteredListingData = this.totalListing;
            }
            else {
                const inputElement = this.template.querySelector('lightning-input[data-id="condition-input"]');

                if (this.logicalExpression.trim() === '') {
                    inputElement.setCustomValidity('Expression cannot be empty');
                    inputElement.reportValidity();
                    return;
                }

                const mappinglength = this.mappings.length;

                const regex = /\d+\s*(?:AND|OR)\s*\d+/i;

                if (!regex.test(this.logicalExpression)) {
                    inputElement.setCustomValidity('Invalid condition syntax. Use numbers, AND, OR, spaces, and parentheses only.');
                    inputElement.reportValidity();
                    return;
                }

                const numbers = this.logicalExpression.match(/\d+/g);
                if (numbers) {
                    const numberSet = new Set(numbers.map(Number));
                    const invalidIndex = Array.from(numberSet).some(num => num >= mappinglength + 1 || num < 1);

                    if (invalidIndex) {
                        inputElement.setCustomValidity('Condition uses invalid index. Use indices from 1 to ' + mappinglength + '.');
                        inputElement.reportValidity();
                        return;
                    }

                    if (numberSet.size !== mappinglength) {
                        inputElement.setCustomValidity('Condition must include all indices.');
                        inputElement.reportValidity();
                        return;
                    }

                    // Basic syntax check for balanced parentheses
                    let openParens = 0;
                    for (let char of this.logicalExpression) {
                        if (char === '(') openParens++;
                        if (char === ')') openParens--;
                        if (openParens < 0) {
                            inputElement.setCustomValidity('Unbalanced parentheses in custom logic expression.');
                            inputElement.reportValidity();
                            return;
                        }
                    }
                    if (openParens !== 0) {
                        inputElement.setCustomValidity('Unbalanced parentheses in custom logic expression.');
                        inputElement.reportValidity();
                        return;
                    }

                    inputElement.setCustomValidity('');
                    inputElement.reportValidity();
                } else {
                    inputElement.setCustomValidity('Condition syntax is correct but contains no indices');
                    inputElement.reportValidity();
                    return;
                }

                this.pagedFilteredListingData = this.totalListing.filter(listing => {
                    let filterResults = [];

                    this.mappings.forEach((mapping, index) => {
                        let fieldValue = listing[mapping.field.toLowerCase()];
                        let filterValue = mapping.valueField;

                        switch (mapping.operator) {
                            case 'lessThan':
                                fieldValue = fieldValue !== undefined ? fieldValue : 0;
                                filterValue = filterValue !== undefined ? filterValue : 0;
                                filterResults[index + 1] = parseFloat(fieldValue) < parseFloat(filterValue);
                                break;
                            case 'greaterThan':
                                fieldValue = fieldValue !== undefined ? fieldValue : 0;
                                filterValue = filterValue !== undefined ? filterValue : 0;
                                filterResults[index + 1] = parseFloat(fieldValue) > parseFloat(filterValue);
                                break;
                            case 'equalTo':
                                fieldValue = fieldValue !== undefined ? fieldValue : '';
                                filterValue = filterValue !== undefined ? filterValue : '';
                                filterResults[index + 1] = fieldValue === filterValue;
                                break;
                            case 'contains':
                                fieldValue = fieldValue !== undefined ? fieldValue : '';
                                filterValue = filterValue !== undefined ? filterValue : '';
                                filterResults[index + 1] = fieldValue && fieldValue.includes(filterValue);
                                break;
                            case 'notEqualTo':
                                fieldValue = fieldValue !== undefined ? fieldValue : '';
                                filterValue = filterValue !== undefined ? filterValue : '';
                                filterResults[index + 1] = fieldValue !== filterValue;
                                break;
                            case 'notContains':
                                fieldValue = fieldValue !== undefined ? fieldValue : '';
                                filterValue = filterValue !== undefined ? filterValue : '';
                                filterResults[index + 1] = fieldValue && !fieldValue.includes(filterValue);
                                break;
                            default:
                                return false;
                        }
                    });

                    const evalExpression = this.logicalExpression
                        .replace(/\bAND\b/gi, '&&')
                        .replace(/\bOR\b/gi, '||');
                    const evaluationResult = eval(evalExpression.replace(/\d+/g, match => filterResults[match]));
                    return evaluationResult;
                });
            }

            // this.listingData = this.pagedFilteredListingData;
            this.isPropertyAvailable = this.pagedFilteredListingData.length > 0;
            this.totalRecords = this.pagedFilteredListingData.length;
            this.currentPage = 1;
            this.hideModalBox();
            this.searchTerm = '';
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
        event.stopPropagation();
        let selectedValueId = event.detail.recordId;
        this.selectedInquiryValue = selectedValueId;
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
        this.isAddConditionModalVisible = false;
        this.selectedMappingId = null;

        const previouslySelected = this.template.querySelector('.selected');
        if (previouslySelected) {
            previouslySelected.classList.remove('selected');
        }
    }

    /**
    * Method Name: saveCondition
    * @description: this method is save condition from add modal to main modal
    * Date: 17/06/2024
    * Created By: Rachit Shah
    */
    saveCondition() {
        if (this.listingFieldObject.MVEX__Field_Name__c && this.selectedInquiryValue && this.selectedConditionOperator) {
            let displaylabel = this.getValueFromLabel(this.listingFieldObject.MVEX__Field_Name__c);

            if (!this.selectedMappingId) {
                this.mappings.push({
                    id: this.mappings.length + 1,
                    field: this.listingFieldObject.MVEX__Field_Name__c,
                    operator: this.selectedConditionOperator,
                    displayOperator: this.displayOperator(this.selectedConditionOperator),
                    valueField: this.selectedInquiryValue ? this.selectedInquiryValue : '',
                    label: displaylabel,
                });
            }
            else {
                this.mappings = this.mappings.map(mapping => {
                    if (mapping.id === this.selectedMappingId) {
                        mapping.field = this.listingFieldObject.MVEX__Field_Name__c;
                        mapping.operator = this.selectedConditionOperator;
                        mapping.displayOperator = this.displayOperator(this.selectedConditionOperator);
                        mapping.valueField = this.selectedInquiryValue ? this.selectedInquiryValue : '';
                        mapping.label = displaylabel;
                    }
                    return mapping;
                });
            }
            this.closeAddConditionModal();
        }
        else {
            this.showToast('Error', 'Select all required fields', 'error');
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

    openConfigureSettings(){
        this.isConfigOpen = true;
    }

    handleCloseModal() {
        this.isConfigOpen = false;
        this.fetchListingConfiguration();
    }
}