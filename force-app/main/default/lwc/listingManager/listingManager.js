import { LightningElement,track,api} from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import designcss from '@salesforce/resourceUrl/listingManagerCss';
import getListingData from '@salesforce/apex/ListingManagerController.getListingData';
import getMetadataRecords from '@salesforce/apex/ControlCenterController.getMetadataRecords';
import { NavigationMixin } from 'lightning/navigation';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { errorDebugger } from 'c/globalProperties';

export default class ListingManager extends NavigationMixin(LightningElement){
    @api objectName = 'MVEX__Listing__c';
    @api recordId;
    @api fieldSet = 'ListingManagerFieldSet';
    @track spinnerShow=true;
    @track showList = true;
    @track showTile = false;
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
    @track wrapOn = false;
    @track pageSize = 30;
    @track screenWidth = 0;
    @track currentPage = 1;
    @track visiblePages = 5;
    @track fieldsModal = false;
    @track isAccessible = false;
    @track listingLoading = false;
    isConfigOpen = false;

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
        try{
            const totalPages = this.totalPages;
            const currentPage = this.currentPage;
            const visiblePages = this.visiblePages;
        
            let pages = [];
        
            if (totalPages <= visiblePages) {
                for (let i = 1; i <= totalPages; i++) {
                    pages.push({
                        number: i,
                        isEllipsis: false,
                        className: `pagination-button ${i === currentPage ? 'active' : ''}`
                    });
                }
            } else {
                pages.push({
                    number: 1,
                    isEllipsis: false,
                    className: `pagination-button ${currentPage === 1 ? 'active' : ''}`
                });
        
                if (currentPage > 3) {
                    pages.push({ isEllipsis: true });
                }
        
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
                    pages.push({ isEllipsis: true });
                }

                pages.push({
                    number: totalPages,
                    isEllipsis: false,
                    className: `pagination-button ${currentPage === totalPages ? 'active' : ''}`
                });
            }
        
            return pages;
        }catch(error){
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
        try{
            if(this.sortField !== ''){
                const orderDisplayName = this.sortOrder === 'asc' ? 'Ascending' : 'Descending';
                
                let field = null;
                if(this.sortField != 'Name'){
                    field = this.fields.find(item => item.fieldName === this.sortField);
                }else{
                    field = {fieldName:'Name',fieldLabel:'Listing Name'};
                }
                if (!field) {
                    return '';
                }

                const fieldDisplayName = field.fieldLabel;
                return `Sorted by : ${fieldDisplayName} (${orderDisplayName})`;
            }else{
                return '';
            }
        }catch(error){
            errorDebugger('ListingManager', 'sortDescription', error, 'warn', 'Error in sortDescription');
            return null;
        }
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

    /**
    * Method Name : connectedCallback
    * @description : retrieve fields name from the field-set and retrieve listing records.
    * * Date: 3/06/2024
    * Created By:Vyom Soni
    */
    connectedCallback(){
        try{
            loadStyle(this, MulishFontCss);
            this.updateScreenWidth();
            if (!import.meta.env.SSR) {
                window?.globalThis?.addEventListener('resize', this.updateScreenWidth);
            }
            loadStyle(this, designcss);
            this.getAccessible();

        }catch(error){
            errorDebugger('ListingManager', 'connectedCallback', error, 'warn', 'Error in connectedCallback');
        }
    }

    getAccessible() {
        getMetadataRecords()
        .then(data => {
            const listingManagerFeature = data.find(
                item => item.DeveloperName === 'Listing_Manager'
            );
            this.isAccessible = listingManagerFeature ? Boolean(listingManagerFeature.MVEX__isAvailable__c) : false;
            if (this.isAccessible) {
                this.getListingDataMethod();
            } else {
                this.spinnerShow = false;
            }
        })
        .catch(error => {
            console.error('Error fetching accessible fields', error);
            this.isAccessible = false;
            this.spinnerShow = false;
        });
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
    * Method Name : getListingDataMethod
    * @description : retrieve the data listing data from the salesforce
    * * Date: 3/06/2024
    * Created By:Vyom Soni
    */
    getListingDataMethod(){
        this.spinnerShow = true;
        getListingData()
            .then(result => {
                this.listingData = result.listings;
                this.propertyMediaUrls = result.medias;this.listingData = result.listings;
                this.propertyMediaUrls = result.medias;
                this.pageSize = result.pageSize;
                this.fields = result.selectedFields.map(field => ({
                    fieldLabel: field.label,
                    fieldName: field.fieldApiname,
                    cardView: field.cardView,
                    format : field.format
                }));
        
                this.listingData.forEach((listing)=>{
                    const prop_id = listing.MVEX__Property__c;
                    listing.media_url = this.propertyMediaUrls[prop_id] ? this.propertyMediaUrls[prop_id] : '/resource/MVEX__blankImage';
                    listing.isChecked = false;
                    listing.isActive = listing.MVEX__Status__c === 'Active' ? true : false;
                })

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
        try{
            this.processedListingData = this.listingData.map(listing => {
            let orderedFields = this.fields.map(field => {
                let fieldValue;
                if (field.fieldName.includes('.')) {
                    let fieldParts = field.fieldName.split('.');
                    let relatedObject = listing[fieldParts[0]];
                    fieldValue = relatedObject ? relatedObject[fieldParts[1]] : '-';
                } else {
                    fieldValue = listing[field.fieldName] || '-';
                }

                if (field.format && fieldValue) {
                    fieldValue = this.applyFieldFormat(fieldValue, field.format);
                }

                return {
                    fieldName: field.fieldName,
                    value: fieldValue
                };
            });

            let cardViewFields = this.fields
                .filter(field => field.cardView === 'true')
                .map(field => {
                    let fieldValue;
                    if (field.fieldName.includes('.')) {
                        let fieldParts = field.fieldName.split('.');
                        let relatedObject = listing[fieldParts[0]];
                        fieldValue = relatedObject ? relatedObject[fieldParts[1]] : '-';
                    } else {
                        fieldValue = listing[field.fieldName] || '-';
                    }

                    if (field.format && fieldValue) {
                        fieldValue = this.applyFieldFormat(fieldValue, field.format);
                    }

                    return {
                        fieldName: field.fieldName,
                        value: fieldValue
                    };
                });
                return {
                    Id: listing.Id,
                    Name: listing.Name,
                    media_url: listing.media_url,
                    Listing_Price__c:listing.MVEX__Listing_Price__c,
                    Bathrooms__c:listing.MVEX__Bathrooms__c,
                    City__c:listing.MVEX__City__c,
                    Street__c:listing.MVEX__Street__c,
                    isChecked: listing.isChecked,
                    Address__c:listing.MVEX__Address__c,
                    cardViewFields,
                    orderedFields,
                    isActive: listing.isActive,
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
        let date = new Date(fieldValue);
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

            const allHeaders = this.template.querySelectorAll('.slds-icon-utility-arrowdown svg');
            allHeaders.forEach(icon => icon.classList.remove('rotate-asc', 'rotate-desc'));

            const resetCheckedFlag = item => ({ ...item, isChecked: false });
            this.processedListingData = this.processedListingData.map(resetCheckedFlag);
            this.unchangedProcessListings = this.unchangedProcessListings.map(resetCheckedFlag);

            const filteredListingIds = new Set(event.detail.filterlistings.map(filtered => filtered.Id));
            this.processedListingData = this.unchangedProcessListings.filter(processListing =>
                filteredListingIds.has(processListing.Id)
            );
            this.listingData = this.unchangedListingData.filter(processListing =>
                filteredListingIds.has(processListing.Id)
            );

            this.currentPage = 1;
            this.sortData();
            this.updateShownData();
            this.updateSelectedProperties();
        }catch(error){
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
                const allHeaders = this.template.querySelectorAll('.slds-icon-utility-arrowdown svg');
                allHeaders.forEach(icon => icon.classList.remove('rotate-asc', 'rotate-desc'));

                const resetCheckedFlag = item => ({ ...item, isChecked: false });
                this.processedListingData = this.processedListingData.map(resetCheckedFlag);
                this.unchangedProcessListings = this.unchangedProcessListings.map(resetCheckedFlag);
                this.processedListingData = this.unchangedProcessListings;
                this.listingData = this.unchangedListingData;
                this.currentPage = 1;

                this.sortData();
                this.updateShownData();
                this.updateSelectedProperties();
            }
        }catch(error){
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
    * Method Name : handleListingSelect
    * @description : handle data from the tile cmp
    * Date: 14/06/2024
    * Created By:Vyom Soni
    */
    handleListingSelect(event){
        this.processedListingData = event.detail;
        this.updateShownData();
        this.updateSelectedProperties();
    }

    get listingSpinnerLoading(){
        return !this.spinnerShow && this.listingLoading;
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
            this.showTile = false;
            this.showMap = false;
            if(target == "1"){
                this.showList = true;
            }else if(target == "2"){
                this.showTile = true;
            }else if(target == "3"){
                this.showMap = true;
            }
            this.template.querySelectorAll(".tab-div").forEach(tabEl => {
                tabEl.classList.remove("active-tab-div");
                const pathEl = tabEl.querySelector('path');
                if (pathEl) {
                    pathEl.style.fill = '#131314';
                }
            });
            const selectedTab = this.template.querySelector(`[data-tab-id="${target}"]`);
            selectedTab.classList.add("active-tab-div");
            const selectedPath = selectedTab.querySelector('path[data-tab-index="' + target + '"]');
            if (selectedPath) {
                selectedPath.style.fill = '#fff';
            }
        }catch(error){
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
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: 'MVEX__Listing__c',
                    actionName: 'view'
                }
            })
        }catch(error){
            errorDebugger('ListingManager', 'redirectToRecord', error, 'warn', 'Error in redirectToRecord');
        }
    }

    /**
    * Method Name : updateShownData
    * @description : update the shownProcessedLisitingData when pagination is applied.
    * date: 20/08/2024
    * Created By:Vyom Soni
    */
    updateShownData() {
        try{
            const startIndex = (this.currentPage - 1) * this.pageSize;
            const endIndex = Math.min(startIndex + this.pageSize, this.totalItems);
            this.shownProcessedListingData = this.processedListingData.slice(startIndex, endIndex);
        }catch(error){
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
        const selectedPage = parseInt(event.target.getAttribute('data-id'), 10);
        if (selectedPage !== this.currentPage) {
            this.currentPage = selectedPage;
            this.updateShownData();
            this.scrollToTop();
            this.sortData();
        }
    }

    /**
    * Method Name : checkBoxValueChange
    * @description : handle the checkbox change
    * date: 3/06/2024
    * Created By:Vyom Soni
    */
    checkBoxValueChange(event){
        try{
            const checkboxId = Number(event.target.dataset.id);
            this.shownProcessedListingData[checkboxId].isChecked = event.target.checked;
            this.processedListingData.forEach(item1=>{
                this.shownProcessedListingData.forEach(item2=>{
                    if(item1.Id == item2.Id){
                        item1.isChecked = item2.isChecked;
                    }
                })
               })
            this.unchangedProcessListings.forEach(item1=>{
                this.shownProcessedListingData.forEach(item2=>{
                    if(item1.Id == item2.Id){
                        item1.isChecked = item2.isChecked;
                    }
                })
               })
            this.listingData.forEach(item1=>{
                this.shownProcessedListingData.forEach(item2=>{
                    if(item1.Id == item2.Id){
                        item1.isChecked = item2.isChecked;
                    }
                })
               })
               this.updateSelectedProperties();
        }catch (error){
            errorDebugger('ListingManager', 'checkBoxValueChange', error, 'warn', 'Error in checkBoxValueChange');
        }
    }

    /**
    * Method Name : selectAllCheckbox
    * @description : select the all checkbox
    * date: 3/06/2024
    * Created By:Vyom Soni
    */
    selectAllCheckbox(event){
        try{
            const isChecked = event.target.checked;
            this.sortField = '';
            this.sortOrder = 'asc';
            const allHeaders = this.template.querySelectorAll('.slds-icon-utility-arrowdown svg');
            allHeaders.forEach(icon => {
                icon.classList.remove('rotate-asc', 'rotate-desc');
            });
            this.listingData = this.listingData.map(item => {
                return { ...item, isChecked: isChecked };
            });
            this.processedListingData = this.processedListingData.map(item => {
                return { ...item, isChecked: isChecked };
            });
            this.unchangedProcessListings = this.unchangedProcessListings.map(item => {
                return { ...item, isChecked: isChecked };
            });
            
            this.updateShownData();
            this.updateSelectedProperties();
        }catch(error){
            errorDebugger('ListingManager', 'selectAllCheckbox', error, 'warn', 'Error in selectAllCheckbox');
        }
    }
    
    /**
    * Method Name : goTONewListing
    * @description : Redirect the new listing page
    * date: 3/06/2024
    * Created By:Vyom Soni
    */
    goTONewListing() {
        try {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'MVEX__Listing__c',
                    actionName: 'new'
                },
                state: {
                    c__customParam: 'ListingManager'
                }
            });
        } catch (error) {
            errorDebugger('ListingManager', 'goTONewListing', error, 'warn', 'Error in goTONewListing');
        }
    }

    /**
    * Method Name : updateSelectedProperties
    * @description : update the properties as selected
    * date: 3/06/2024
    * Created By:Vyom Soni
    */
    updateSelectedProperties() {
        try{
            this.selectedProperties = this.processedListingData.filter(listing => listing.isChecked);
            this.totalSelected = this.selectedProperties.length;
        }catch(error){
            errorDebugger('ListingManager', 'updateSelectedProperties', error, 'warn', 'Error in updateSelectedProperties');
        }
    }

    /**
    * Method Name : sortClick
    * @description : this methods apply the sorting on the all fields
    * date: 3/06/2024
    * Created By:Vyom Soni
    */
    sortClick(event) {
        try{
            const fieldName = event.currentTarget.dataset.id;
            if (this.sortField === fieldName) {
                this.sortOrder = this.sortOrder === 'asc' ? 'desc' : 'asc';
            } else {
                this.sortField = fieldName;
                this.sortOrder = 'asc';
            }
            this.sortData();
            this.updateSortIcons();
            this.updateShownData();
        }catch(error){
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
        try{
            this.processedListingData = [...this.processedListingData].sort((a, b) => {
                let aValue, bValue;
    
                if (this.sortField === 'Name') {
                    aValue = a.Name;
                    bValue = b.Name;
                } else {
                    aValue = a.orderedFields.find(field => field.fieldName === this.sortField).value;
                    bValue = b.orderedFields.find(field => field.fieldName === this.sortField).value;
                }
    
                if (typeof aValue === 'string' && typeof bValue === 'string') {
                    aValue = aValue.toLowerCase();
                    bValue = bValue.toLowerCase();
                }
    
                let compare = 0;
                if (aValue > bValue) {
                    compare = 1;
                } else if (aValue < bValue) {
                    compare = -1;
                }
    
                return this.sortOrder === 'asc' ? compare : -compare;
            });
        }catch(error){
            errorDebugger('ListingManager', 'sortData', error, 'warn', 'Error in sortData');
            return null;
        }
    }

    /**
    * Method Name : updateSortIcons
    * @description : this method update the sort icons in the wrapbutton
    * date : 3/06/2024
    * Created By:Vyom Soni
    */
    updateSortIcons() {
        try{
            const allHeaders = this.template.querySelectorAll('.slds-icon-utility-arrowdown svg');
            allHeaders.forEach(icon => {
                icon.classList.remove('rotate-asc', 'rotate-desc');
            });
    
            const currentHeader = this.template.querySelector('[data-index="' + this.sortField + '"]');
            if (currentHeader) {
                currentHeader.classList.add(this.sortOrder === 'asc' ? 'rotate-asc' : 'rotate-desc');
            }
        }catch(error){
            errorDebugger('ListingManager', 'updateSortIcons', error, 'warn', 'Error in updateSortIcons');
        }
    }

    /**
    * Method Name : scrollToTop
    * @description : scroll to top in list
    * * Date: 3/06/2024
    * Created By:Vyom Soni
    */
    scrollToTop() {
        try{
            const tableDiv = this.template.querySelector('.tableDiv');
            if (tableDiv) {
                tableDiv.scrollTop = 0;
            }
        }catch(error){
            errorDebugger('ListingManager', 'scrollToTop', error, 'warn', 'Error in scrollToTop');
        }
    }

    /**
    * Method Name : wrapFilter
    * @description : this method is used for the wrap the filter
    * date: 3/06/2024
    * Created By:Vyom Soni
    */
    wrapFilter() {
        try{
            if (this.wrapOn) {
                const svgElement = this.template.querySelector('.innerDiv1 .filterWrap svg');
                svgElement.classList.remove('imgRotate');
    
                const filterDiv = this.template.querySelector('.innerDiv1 .filterDiv');
                filterDiv.classList.remove('removeInnerDiv1');
    
                if(this.screenWidth >= 900){
                    const div1 = this.template.querySelector('.innerDiv1');
                    div1.style.width = '22%';
                    div1.style.height = '100%';

                    const div2 = this.template.querySelector('.innerDiv2');
                    div2.style.width = '78%';
                    div2.style.height = '100%';
                }else{
                    const div1 = this.template.querySelector('.innerDiv1');
                    div1.style.height = 'fit-content';
                    div1.style.width = '100%';
    
                    const div2 = this.template.querySelector('.innerDiv2');
                    div2.style.height = '30rem';
                    div2.style.width = '100%';
                }
                this.wrapOn = false;
            } else {
                const svgElement = this.template.querySelector('.innerDiv1 .filterWrap svg');
                svgElement.classList.add('imgRotate');

                const filterDiv = this.template.querySelector('.innerDiv1 .filterDiv');
                filterDiv.classList.add('removeInnerDiv1');

                if(this.screenWidth >= 900){
                    const div1 = this.template.querySelector('.innerDiv1');
                    div1.style.width = 'fit-content';
                    div1.style.height = '100%';
                    const div2 = this.template.querySelector('.innerDiv2');
                    div2.style.height = '100%';
                    div2.style.width = '100%';
                }else{
                    const div1 = this.template.querySelector('.innerDiv1');
                    div1.style.height = 'fit-content';
                    div1.style.width = '100%';
                    const div2 = this.template.querySelector('.innerDiv2');
                    div2.style.height = '100%';
                    div2.style.width = '100%';
                }
                this.wrapOn = true;
            }
        }catch(error){
            errorDebugger('ListingManager', 'wrapFilter', error, 'warn', 'Error in wrapFilter');
        }
    }

    /**
    * Method Name : handleRecordManager
    * @description : Method Redirect to the record manager component
    * date: 14/10/2024
    * Created By:Vyom Soni
    */
    // handleRecordManager(){
    //     let componentDef = {
    //         componentDef: "c:recordConfigBodyCmp",
    //         attributes: {
    //             isFromListingManager: true
    //         }
    //     };
        
    //     let encodedComponentDef = btoa(JSON.stringify(componentDef));
    //     this[NavigationMixin.Navigate]({
    //         type: 'standard__webPage',
    //         attributes: {
    //             url: '/one/one.app#' + encodedComponentDef
    //         }
    //     });
    // }

    openConfigureSettings(){
        this.isConfigOpen = true;
    }

    handleCloseModal() {
        this.isConfigOpen = false;
        this.getListingDataMethod();
    }

    /**
    * Method Name : backToControlCenter
    * @description : Method Redirect to the control center
    * date: 14/10/2024
    * Created By:Vyom Soni
    */
    backToControlCenter(event) {
        try {
            event.preventDefault();
            this[NavigationMixin.Navigate]({
                type: "standard__navItemPage",
                attributes: {
                    apiName: "Control_Center",
                },
            });
        } catch (error) {
            errorDebugger('ListingManager', 'backToControlCenter', error, 'warn', 'Error in backToControlCenter');
        }
    }

    redirectToVisitBooking(event){
        try{
            let recordId = event.currentTarget.dataset.id;
            let componentDef = {
                componentDef: "c:siteAndBookingManagement",
                attributes: {
                    recordId: recordId
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
            errorDebugger('ListingManager', 'redirectToVisitBooking', error, 'warn', 'Error in redirectToVisitBooking');
        }
    }

    redirectToOffers(event){
        try{
            let recordId = event.currentTarget.dataset.id;
            let componentDef = {

                componentDef: "c:offerManager",
                 attributes: {
                    listingId: recordId
                 }
            };

            let encodedComponentDef = btoa(JSON.stringify(componentDef));
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url:
                    '/one/one.app#' + encodedComponentDef
                }
            });
        
        } catch (error) {
            errorDebugger('ListingManager', 'redirectToOffers', error, 'warn', 'Error in redirectToOffers');
        }
    }
}