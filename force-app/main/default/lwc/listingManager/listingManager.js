import { LightningElement, track, api } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss      from '@salesforce/resourceUrl/MulishFontCss';
import globalTableStyles  from '@salesforce/resourceUrl/GlobalTableCSS';   
import getListingData     from '@salesforce/apex/ListingManagerController.getListingData';
import getMetadataRecords from '@salesforce/apex/ControlCenterController.getMetadataRecords';
import { NavigationMixin } from 'lightning/navigation';
import { errorDebugger }   from 'c/globalProperties';

export default class ListingManager extends NavigationMixin(LightningElement){
    @api objectName = 'MVEX__Listing__c';
    @api recordId;
    @api fieldSet = 'ListingManagerFieldSet';
    @track spinnerShow=true;
    @track showList = true;
    @track showMap = false;
    @track listingData = [];
    @track unchangedListingData = [];
    @track fields = [];
    @track processedListingData = [];    
    @track unchangedProcessListings = [];    
    @track shownProcessedListingData = [];
    @track propertyMediaUrls = [];
    @track sortField = 'Name';
    @track sortOrder = 'asc';
    @track totalSelected=0;
    @track selectedProperties;
    @track selectedListingData;
    @track isPrevDisabled = true;
    @track isNextDisabled = false;
    @track wrapOn = true; // Default to closed (hidden filter)
    @track pageSize = 30;
    @track screenWidth = 0;
    @track currentPage = 1;
    @track visiblePages = 5;
    @track fieldsModal = false;
    @track isAccessible = false;
    @track listingLoading = false;
    isConfigOpen = false;
    hasInitializedFilter = false;

    /**
    * Method Name : totalItems
    * @description : set the list length.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get totalItems() {
        return this.processedListingData.length;
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
            const totalPages   = this.totalPages;
            const currentPage  = this.currentPage;
            const visiblePages = this.visiblePages;
            let pages = [];

            if (totalPages <= visiblePages) {
                for (let i = 1; i <= totalPages; i++) {
                    pages.push({
                        number    : i,
                        isEllipsis: false,
                        className : `pagination-button ${i === currentPage ? 'active' : ''}`
                    });
                }
            } else {
                pages.push({
                    number    : 1,
                    isEllipsis: false,
                    className : `pagination-button ${currentPage === 1 ? 'active' : ''}`
                });

                if (currentPage > 3) {
                    pages.push({ isEllipsis: true });
                }

                const start = Math.max(2, currentPage - 1);
                const end   = Math.min(currentPage + 1, totalPages - 1);

                for (let i = start; i <= end; i++) {
                    pages.push({
                        number    : i,
                        isEllipsis: false,
                        className : `pagination-button ${i === currentPage ? 'active' : ''}`
                    });
                }

                if (currentPage < totalPages - 2) {
                    pages.push({ isEllipsis: true });
                }

                pages.push({
                    number    : totalPages,
                    isEllipsis: false,
                    className : `pagination-button ${currentPage === totalPages ? 'active' : ''}`
                });
            }

            return pages;
        } catch (error) {
            errorDebugger('ListingManager', 'pageNumbers', error, 'warn', 'Error in pageNumbers');
            return null;
        }
    }

    /**
    * Method Name : mobileView
    * @description : set the mobile view when the screen width is the less then the 900.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get mobileView(){
        return window?.globalThis?.innerWidth <= 900 ? true : false;
    }

    /**
    * Method Name : checkAll
    * @description : handle the checkAll checkbox in list view.
    * * Date: 3/06/2024
    * Created By:Vyom Soni
    */
    get checkAll() {
        return this.processedListingData.every(item => item.isChecked);
    }

    /**
    * Method Name : showSection
    * @description : getter for the show no result found text when shownProcessedListingData.length === 0.
    * * Date: 3/06/2024
    * Created By:Vyom Soni
    */
    get showSection() {
        return this.shownProcessedListingData.length === 0;
    }

    /**
    * Method Name : sortDescription
    * @description : set the header sort description.
    * Date: 16/07/2024
    * Created By:Vyom Soni
    */
    get sortDescription() {
        try {
            if (this.sortField !== '') {
                const orderDisplayName = this.sortOrder === 'asc' ? 'Ascending' : 'Descending';
                const field = this.sortField !== 'Name'
                    ? this.fields.find(item => item.fieldName === this.sortField)
                    : { fieldName: 'Name', fieldLabel: 'Listing Name' };

                if (!field) return '';
                return `Sorted by : ${field.fieldLabel} (${orderDisplayName})`;
            }
            return '';
        } catch (error) {
            errorDebugger('ListingManager', 'sortDescription', error, 'warn', 'Error in sortDescription');
            return null;
        }
    }

    /**
     * nameIconClass
     * Maps to globalTableStyles rules:
     *   .listing-manager-icon           → always occupies space, invisible when idle
     *   .sort-icon-active               → branded colour, fully visible
     *   .rotate-asc / .rotate-desc      → smooth CSS rotation, no layout shift
     */
    get nameIconClass() {
        const base = 'listing-manager-icon';
        if (this.sortField === 'Name') {
            const dir = this.sortOrder === 'asc' ? 'rotate-asc' : 'rotate-desc';
            return `${base} sort-icon-active ${dir}`;
        }
        return base;
    }

    /**
     * nameHeaderClass
     * Maps to globalTableStyles rule:
     *   th.sorted-field → subtle highlight on the active sort column
     */
    get nameHeaderClass() {
        const base = 'slds-is-resizable slds-is-sortable slds-cell_action-mode colume2';
        return this.sortField === 'Name' ? `${base} sorted-field` : base;
    }

    /**
     * fieldsWithIconClass
     * Enriches each field descriptor with computed classes that map directly
     * to globalTableStyles — no inline styles, no DOM queries needed.
     */
    get fieldsWithIconClass() {
        if (!this.fields || this.fields.length === 0) return [];

        return this.fields.map(field => {
            const isSorted    = this.sortField === field.fieldName;
            const base        = 'listing-manager-icon';
            const dir         = this.sortOrder === 'asc' ? 'rotate-asc' : 'rotate-desc';
            const iconClass   = isSorted ? `${base} sort-icon-active ${dir}` : base;

            const headerBase  = 'slds-is-resizable slds-is-sortable slds-cell_action-mode colume2';
            const headerClass = isSorted ? `${headerBase} sorted-field` : headerBase;

            return { ...field, iconClass, isSorted, headerClass };
        });
    }

    /**
    * Method Name : totalListings
    * @description : set the total filtered listings.
    * Date: 16/07/2024
    * Created By:Vyom Soni
    */
    get totalListings(){
        return this.processedListingData.length;
    }

    /**
    * Method Name : isSelected
    * @description : set value true if any option is true.
    * Date: 16/07/2024
    * Created By:Vyom Soni
    */
    get isSelected(){
        return this.totalSelected>0;
    }

    /**
    * Method Name : items
    * @description : set 'Items' string when the user select more then 1 options.
    * Date: 16/07/2024
    * Created By:Vyom Soni
    */
    get items(){
        return this.totalSelected > 1 ? 'Items' : 'Item';
    }
    
    /**
    * Method Name : lisitngItems
    * @description : set 'Items' when the filtered items is more then the 1.
    * Date: 16/07/2024
    * Created By:Vyom Soni
    */
    get lisitngItems(){
        return this.processedListingData.length>1 ? 'Items' :'Item';
    }

    get listingSpinnerLoading() {
        return !this.spinnerShow && this.listingLoading;
    }

    /**
    * Method Name : connectedCallback
    * @description : retrieve fields name from the field-set and retrieve listing records.
    * * Date: 3/06/2024
    * Created By:Vyom Soni
    */
    connectedCallback() {
        try {
            // 1. Mulish font — always load first so all sheets inherit it
            loadStyle(this, MulishFontCss);

            //
            loadStyle(this, globalTableStyles);

            this.updateScreenWidth();
            if (!import.meta.env.SSR) {
                window?.globalThis?.addEventListener('resize', this.updateScreenWidth);
            }

            this.getAccessible();
        } catch (error) {
            errorDebugger('ListingManager', 'connectedCallback', error, 'warn', 'Error in connectedCallback');
        }
    }

    /**
    * Method Name : renderedCallback
    * @description : Initialize filter toggle button state only once
    * * Date: 26/02/2026
    * Created By:Vyom Soni
    */
    renderedCallback(){
        try{
            // Only initialize filter state once on first render
            if (!this.hasInitializedFilter && this.wrapOn) {
                const toggleBtn = this.template.querySelector('.filter-toggle-btn');
                const filterDiv = this.template.querySelector('.innerDiv1 .filterDiv');
                const div1      = this.template.querySelector('.innerDiv1');

                if (toggleBtn && filterDiv && div1) {
                    filterDiv.classList.add('removeInnerDiv1');
                    div1.classList.add('removeInnerDiv1');

                    if (this.screenWidth >= 900) {
                        div1.style.width   = '0';
                        div1.style.opacity = '0';
                    }

                    this.hasInitializedFilter = true;
                }
            }
        } catch (error) {
            errorDebugger('ListingManager', 'renderedCallback', error, 'warn', 'Error in renderedCallback');
        }
    }

    /**
    * Method Name : disconnectedCallback
    * @description : remove the resize event.
    * * Date: 3/06/2024
    * Created By:Vyom Soni
    */
    disconnectedCallback() {
        if (!import.meta.env.SSR) {
            window?.globalThis?.removeEventListener('resize', this.updateScreenWidth);
        }
    }

    // ─── Data Loading ─────────────────────────────────────────────────────────

    getAccessible() {
        getMetadataRecords()
            .then(data => {
                const feature     = data.find(item => item.DeveloperName === 'Listing_Manager');
                this.isAccessible = feature ? Boolean(feature.MVEX__isAvailable__c) : false;

                if (this.isAccessible) {
                    this.getListingDataMethod();
                } else {
                    this.spinnerShow = false;
                }
            })
            .catch(error => {
                console.error('Error fetching accessible fields', error);
                this.isAccessible = false;
                this.spinnerShow  = false;
            });
    }

    /**
    * Method Name : getListingDataMethod
    * @description : retrieve the data listing data from the salesforce
    * * Date: 3/06/2024
    * Created By:Vyom Soni
    */
    getListingDataMethod(){
        this.spinnerShow = true;

        getListingData()
            .then(result => {
                this.listingData       = result.listings;
                this.propertyMediaUrls = result.medias;
                this.pageSize          = result.pageSize;
                this.fields            = result.selectedFields.map(field => ({
                    fieldLabel: field.label,
                    fieldName : field.fieldApiname,
                    cardView  : field.cardView,
                    format    : field.format
                }));

                this.listingData.forEach(listing => {
                    const propId      = listing.MVEX__Property__c;
                    listing.media_url = this.propertyMediaUrls[propId]
                        ? this.propertyMediaUrls[propId]
                        : '/resource/MVEX__blankImage';
                    listing.isChecked = false;
                    listing.isActive  = listing.MVEX__Status__c === 'Active';
                });

                console.log('Listing Data:', this.listingData);

                this.unchangedListingData = this.listingData;
                this.processListings();
            })
            .catch(error => {
                errorDebugger('ListingManager', 'getListingDataMethod', error, 'warn', 'Error in getListingDataMethod');
            })
            .finally(() => {
                this.spinnerShow = false;
            });
    }

    /**
    * Method Name : processListings
    * @description : set the listing data inorder of the fields data
    * * Date: 3/06/2024
    * Created By:Vyom Soni
    */
    processListings() {
        try {
            const mapField = field => {
                let value;
                if (field.fieldName.includes('.')) {
                    const [obj, key] = field.fieldName.split('.');
                    value = listing[obj] ? listing[obj][key] : '-';  // eslint-disable-line no-undef
                } else {
                    value = listing[field.fieldName] || '-';  // eslint-disable-line no-undef
                }
                if (field.format && value) value = this.applyFieldFormat(value, field.format);
                return { fieldName: field.fieldName, value };
            };

            this.processedListingData = this.listingData.map(listing => {
                const mapF = field => {
                    let value;
                    if (field.fieldName.includes('.')) {
                        const [obj, key] = field.fieldName.split('.');
                        value = listing[obj] ? listing[obj][key] : '-';
                    } else {
                        value = listing[field.fieldName] || '-';
                    }
                    if (field.format && value) value = this.applyFieldFormat(value, field.format);
                    return { fieldName: field.fieldName, value };
                };

                const orderedFields  = this.fields.map(mapF);
                const cardViewFields = this.fields.filter(f => f.cardView === 'true').map(mapF);

                return {
                    Id              : listing.Id,
                    Name            : listing.Name,
                    media_url       : listing.media_url,
                    Listing_Price__c: listing.MVEX__Listing_Price__c,
                    Bathrooms__c    : listing.MVEX__Bathrooms__c,
                    City__c         : listing.MVEX__City__c,
                    Street__c       : listing.MVEX__Street__c,
                    Address__c      : listing.MVEX__Address__c,
                    isChecked       : listing.isChecked,
                    isActive        : listing.isActive,
                    cardViewFields,
                    orderedFields,
                };
            });

            this.unchangedProcessListings = this.processedListingData;
            this.sortData();
            this.updateShownData();
            this.spinnerShow = false;
        } catch (error) {
            errorDebugger('ListingManager', 'processListings', error, 'warn', 'Error in processListings');
            return null;
        }
    }

    /**
    * Method Name : applyFieldFormat
    * @description : Method to apply formatting based on the format value from dateOptions and dateTimeOptions
    * Date: 14/10/2024
    * Created By:Vyom Soni
    */
    applyFieldFormat(fieldValue, format) {
        const date    = new Date(fieldValue);
        const day     = String(date.getDate()).padStart(2, '0');
        const month   = String(date.getMonth() + 1).padStart(2, '0');
        const year    = date.getFullYear();
        const hours24 = String(date.getHours()).padStart(2, '0');
        const minutes = String(date.getMinutes()).padStart(2, '0');
        const h24n    = Number(hours24);
        const hours12 = h24n > 12 ? String(h24n - 12).padStart(2, '0') : hours24;
        const period  = h24n >= 12 ? 'PM' : 'AM';

        const formats = {
            ddmmyyyy  : `${day}-${month}-${year}`,
            mmddyyyy  : `${month}-${day}-${year}`,
            yyyymmdd  : `${year}-${month}-${day}`,
            ddmmyyy24 : `${day}-${month}-${year} ${hours24}:${minutes}`,
            mmddyyyy24: `${month}-${day}-${year} ${hours24}:${minutes}`,
            yyyymmdd24: `${year}-${month}-${day} ${hours24}:${minutes}`,
            ddmmyyy12 : `${day}-${month}-${year} ${hours12}:${minutes} ${period}`,
            mmddyyyy12: `${month}-${day}-${year} ${hours12}:${minutes} ${period}`,
            yyyymmdd12: `${year}-${month}-${day} ${hours12}:${minutes} ${period}`,
        };

        return formats[format] ?? fieldValue;
    }

    /**
    * Method Name : handleFilteredListings
    * @description : set the data comming from the filter cmp
    * Date: 14/06/2024
    * Created By:Vyom Soni
    */
    handleFilteredListings(event){
        try{
            this.sortField = 'Name';
            this.sortOrder = 'asc';

            const resetChecked = item => ({ ...item, isChecked: false });
            this.processedListingData     = this.processedListingData.map(resetChecked);
            this.unchangedProcessListings = this.unchangedProcessListings.map(resetChecked);

            const ids = new Set(event.detail.filterlistings.map(f => f.Id));
            this.processedListingData = this.unchangedProcessListings.filter(p => ids.has(p.Id));
            this.listingData          = this.unchangedListingData.filter(p => ids.has(p.Id));

            this.currentPage = 1;
            this.sortData();
            this.updateShownData();
            this.updateSelectedProperties();
        } catch (error) {
            errorDebugger('ListingManager', 'handleFilteredListings', error, 'warn', 'Error in handleFilteredListings');
        }
    }

    /**
    * Method Name : handleReset
    * @description : handle the reset event from filter coponent
    * Date: 14/06/2024
    * Created By:Vyom Soni
    */
    handleReset(event){
        try{
            if(event.detail.filterlistings == true){
                this.sortField = 'Name';
                this.sortOrder = 'asc';

                const resetChecked = item => ({ ...item, isChecked: false });
                this.processedListingData     = this.processedListingData.map(resetChecked);
                this.unchangedProcessListings = this.unchangedProcessListings.map(resetChecked);
                this.processedListingData     = this.unchangedProcessListings;
                this.listingData              = this.unchangedListingData;
                this.currentPage              = 1;

                this.sortData();
                this.updateShownData();
                this.updateSelectedProperties();
            }
        } catch (error) {
            errorDebugger('ListingManager', 'handleReset', error, 'warn', 'Error in handleReset');
        }
    }

    /**
    * Method Name : handleAddModalChange
    * @description : handle child component modal visibility
    * Date: 14/10/2024
    * Created By:Vyom Soni
    */
    handleAddModalChange(event){
        this.fieldsModal = event.detail;
    }

    /**
    * Method Name : handleLoading
    * @description : handle the loading event from the filter cmp
    * Date: 19/02/2026
    */
    handleLoading(event){
        this.listingLoading = event.detail;
    }

    /**
    * Method Name : handleMenuTabClick
    * @description : handle the menu clicks in the header
    *  Date: 3/06/2024
    * Created By:Vyom Soni
    */
    handleMenuTabClick(evt){
        try{
            let target = evt.currentTarget.dataset.tabId;
            this.showList = false;
            this.showMap  = false;

            if (target === '1') this.showList = true;
            else if (target === '2') this.showMap = true;

            this.template.querySelectorAll('.tab-div').forEach(tabEl => {
                tabEl.classList.remove('active-tab-div');
                const path = tabEl.querySelector('path');
                if (path) path.style.fill = '#131314';
            });

            const selectedTab  = this.template.querySelector(`[data-tab-id="${target}"]`);
            selectedTab.classList.add('active-tab-div');
            const selectedPath = selectedTab.querySelector(`path[data-tab-index="${target}"]`);
            if (selectedPath) selectedPath.style.fill = '#fff';
        } catch (error) {
            errorDebugger('ListingManager', 'handleMenuTabClick', error, 'warn', 'Error in handleMenuTabClick');
        }
    }

    /**
    * Method Name : redirectToRecord
    * @description : redirect to listing record recordPage
    * Date: 3/06/2024
    * Created By:Vyom Soni
    */
    redirectToRecord(event){
        try{
            const recordId = event.target.dataset.id;
            this[NavigationMixin.Navigate]({
                type      : 'standard__recordPage',
                attributes: {
                    recordId     : recordId,
                    objectApiName: 'MVEX__Listing__c',
                    actionName   : 'view'
                }
            });
        } catch (error) {
            errorDebugger('ListingManager', 'redirectToRecord', error, 'warn', 'Error in redirectToRecord');
        }
    }

    updateScreenWidth = () => {
        this.screenWidth = window.innerWidth;
    }

    wrapFilter() {
        try {
            const toggleBtn = this.template.querySelector('.filter-toggle-btn');
            const filterDiv = this.template.querySelector('.innerDiv1 .filterDiv');
            const div1      = this.template.querySelector('.innerDiv1');
            const div2      = this.template.querySelector('.innerDiv2');

            if (this.wrapOn) {
                toggleBtn.classList.add('active');
                filterDiv.classList.remove('removeInnerDiv1');
                div1.classList.remove('removeInnerDiv1');

                if (this.screenWidth >= 900) {
                    div1.style.width   = '22%';
                    div1.style.opacity = '1';
                    div2.style.width   = '78%';
                } else {
                    div1.style.height  = 'fit-content';
                    div1.style.width   = '100%';
                    div1.style.opacity = '1';
                    div2.style.height  = '30rem';
                    div2.style.width   = '100%';
                }
                this.wrapOn = false;
            } else {
                toggleBtn.classList.remove('active');

                if (this.screenWidth >= 900) {
                    div1.style.width   = '0';
                    div1.style.opacity = '0';
                    div2.style.width   = '100%';

                    setTimeout(() => {
                        if (this.wrapOn) {
                            filterDiv.classList.add('removeInnerDiv1');
                            div1.classList.add('removeInnerDiv1');
                        }
                    }, 150);
                } else {
                    filterDiv.classList.add('removeInnerDiv1');
                    div1.style.height  = '0';
                    div1.style.opacity = '0';
                    div1.style.width   = '100%';
                    div2.style.height  = '100%';
                    div2.style.width   = '100%';
                }
                this.wrapOn = true;
            }
        } catch (error) {
            errorDebugger('ListingManager', 'wrapFilter', error, 'warn', 'Error in wrapFilter');
        }
    }

/**
    * Method Name : updateShownData
    * @description : update the shownProcessedLisitingData when pagination is applied.
    * date: 20/08/2024
    * Created By:Vyom Soni
    */
    updateShownData() {
        try {
            const start = (this.currentPage - 1) * this.pageSize;
            const end   = Math.min(start + this.pageSize, this.totalItems);
            this.shownProcessedListingData = this.processedListingData.slice(start, end);
        } catch (error) {
            errorDebugger('ListingManager', 'updateShownData', error, 'warn', 'Error in updateShownData');
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
            this.updateShownData();
            this.scrollToTop();
            this.sortData();
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
            this.updateShownData();
            this.scrollToTop();
            this.sortData();
        }
    }
 
    /**
    * Method Name : handlePageChange
    * @description : handle the direct click on page number.
    * date: 20/08/2024
    * Created By:Vyom Soni
    */
    handlePageChange(event) {
        const page = parseInt(event.target.getAttribute('data-id'), 10);
        if (page !== this.currentPage) {
            this.currentPage = page;
            this.updateShownData();
            this.scrollToTop();
            this.sortData();
        }
    }

    scrollToTop() {
        try {
            const tableDiv = this.template.querySelector('.tableDiv');
            if (tableDiv) tableDiv.scrollTop = 0;
        } catch (error) {
            errorDebugger('ListingManager', 'scrollToTop', error, 'warn', 'Error in scrollToTop');
        }
    }

    /**
    * Method Name : sortClick
    * @description : this methods apply the sorting on the all fields
    * date: 3/06/2024
    * Created By:Vyom Soni
    */
    sortClick(event) {
        try {
            const fieldName = event.currentTarget.dataset.id;
            if (this.sortField === fieldName) {
                this.sortOrder = this.sortOrder === 'asc' ? 'desc' : 'asc';
            } else {
                this.sortField = fieldName;
                this.sortOrder = 'asc';
            }
            this.sortData();
            this.updateShownData();
        } catch (error) {
            errorDebugger('ListingManager', 'sortClick', error, 'warn', 'Error in sortClick');
        }
    }

    /**
    * Method Name : sortData
    * @description : this methods apply the sorting on the all fields
    * date: 3/06/2024
    * Created By:Vyom Soni
    */
    sortData() {
        try {
            this.processedListingData = [...this.processedListingData].sort((a, b) => {
                let aVal = this.sortField === 'Name'
                    ? a.Name
                    : a.orderedFields.find(f => f.fieldName === this.sortField)?.value;
                let bVal = this.sortField === 'Name'
                    ? b.Name
                    : b.orderedFields.find(f => f.fieldName === this.sortField)?.value;

                if (typeof aVal === 'string') aVal = aVal.toLowerCase();
                if (typeof bVal === 'string') bVal = bVal.toLowerCase();

                const cmp = aVal > bVal ? 1 : aVal < bVal ? -1 : 0;
                return this.sortOrder === 'asc' ? cmp : -cmp;
            });
        } catch (error) {
            errorDebugger('ListingManager', 'sortData', error, 'warn', 'Error in sortData');
            return null;
        }
    }

    // ─── Selection ────────────────────────────────────────────────────────────

    checkBoxValueChange(event) {
        try {
            const idx = Number(event.target.dataset.id);
            this.shownProcessedListingData[idx].isChecked = event.target.checked;

            const sync = arr => arr.forEach(item1 => {
                const match = this.shownProcessedListingData.find(item2 => item2.Id === item1.Id);
                if (match) item1.isChecked = match.isChecked;
            });

            sync(this.processedListingData);
            sync(this.unchangedProcessListings);
            sync(this.listingData);
            this.updateSelectedProperties();
        } catch (error) {
            errorDebugger('ListingManager', 'checkBoxValueChange', error, 'warn', 'Error in checkBoxValueChange');
        }
    }

    selectAllCheckbox(event) {
        try {
            const isChecked = event.target.checked;
            this.sortField  = '';
            this.sortOrder  = 'asc';

            const markAll = arr => arr.map(item => ({ ...item, isChecked }));
            this.listingData              = markAll(this.listingData);
            this.processedListingData     = markAll(this.processedListingData);
            this.unchangedProcessListings = markAll(this.unchangedProcessListings);

            this.updateShownData();
            this.updateSelectedProperties();
        } catch (error) {
            errorDebugger('ListingManager', 'selectAllCheckbox', error, 'warn', 'Error in selectAllCheckbox');
        }
    }

    updateSelectedProperties() {
        try {
            this.selectedProperties = this.processedListingData.filter(l => l.isChecked);
            this.totalSelected      = this.selectedProperties.length;
        } catch (error) {
            errorDebugger('ListingManager', 'updateSelectedProperties', error, 'warn', 'Error in updateSelectedProperties');
        }
    }

    // ─── Navigation ───────────────────────────────────────────────────────────

    goTONewListing() {
        try {
            this[NavigationMixin.Navigate]({
                type      : 'standard__objectPage',
                attributes: { objectApiName: 'MVEX__Listing__c', actionName: 'new' },
                state     : { c__customParam: 'ListingManager' }
            });
        } catch (error) {
            errorDebugger('ListingManager', 'goTONewListing', error, 'warn', 'Error in goTONewListing');
        }
    }

    // ─── Settings Modal ───────────────────────────────────────────────────────

    openConfigureSettings() {
        this.isConfigOpen = true;
    }

    handleCloseModal() {
        this.isConfigOpen = false;
        this.getListingDataMethod();
    }
}