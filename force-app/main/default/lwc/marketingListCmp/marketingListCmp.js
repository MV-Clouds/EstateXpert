import { LightningElement, track, api } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import designcss from '@salesforce/resourceUrl/MulishFontCss';
import getMetadataRecords from '@salesforce/apex/ControlCenterController.getMetadataRecords';
import getContactData from '@salesforce/apex/MarketingListCmpController.getContactData';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import USER_CURRENCY from '@salesforce/i18n/currency';
import USER_LOCALE from '@salesforce/i18n/locale';
import FORM_FACTOR from '@salesforce/client/formFactor';

export default class MarketingListCmp extends NavigationMixin(LightningElement) {
    @api objectName = 'Contact';
    @api recordId;
    refreshSubscription = {};
    refreshChannelName = '/event/MVEX__RefreshEvent__e';
    realtimeRefreshTimer = null;
    isSilentSync = false;
    isManualRefreshing = false;
    @track data;
    @track spinnerShow = true;
    @track showList = true;
    @track contactData = [];
    @track fields = [];
    @track processedContactData = [];
    @track unchangedProcessContact = [];
    @track pendingFilterEvent = null; // Store filter event if received before data loads
    @track lastFilterEvent = null; // Store last applied filter event to persist across data reloads
    @track appliedFilters = [
        {
            id: 'MVEX__Contact_Type__c',
            label: 'Contact Type',
            value: 'Buyer',
            displayText: 'Contact Type: Buyer'
        }
    ];
    @track showAllFilters = false;
    @track sortField = 'Name';
    @track sortOrder = 'asc';
    @track totalSelected = 0;
    @track isPrevDisabled = true;
    @track isNextDisabled = false;
    @track pageNumber = 1;
    @track pageSize = 30;
    @track shownProcessedContactData = [];
    @track selectedContactList = [];
    @track isContactSelected = true;
    isConfigOpen = false;

    //new variables
    @track wrapOn = true; // Default to closed (hidden filter)
    @track screenWidth = 0;
    @track currentPage = 1;
    @track visiblePages = 5;
    @track fieldsModal = false;
    isSortApplied = false;

    @track isAccessible = false;
    @track listingLoading = false;

    /**
    * Method Name : totalPages
    * @description : set the totalpages count.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get totalItems() {
        return this.processedContactData.length;
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
    * Method Name : showPagination
    * @description : show the pagination only if totalpages are greater than 1.
    */
    get showPagination() {
        return this.totalPages > 1;
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
    * Method Name : filterIconColor
    * @description : Return filter icon color based on active state.
    * Black when closed (wrapOn = true), White when open (wrapOn = false)
    */
    get filterIconColor() {
        return this.wrapOn ? '#000000' : '#ffffff';
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
            console.log('Error pageNumbers->' + error);
            return null;
        }
    }

    /**
    * Method Name : mobileView
    * @description : set the mobile view when the screen width is the less then the 900.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get mobileView() {
        return window?.globalThis?.innerWidth <= 900 ? true : false;
    }

    get isMobileOrTablet() {
        return FORM_FACTOR === 'Small' || FORM_FACTOR === 'Medium';
    }


    /**
   * Method Name : checkAll
   * @description : handle the checkAll checkbox in list view.
   * Date: 22/06/2024
   * Created By:Vyom Soni
   */
    get checkAll() {
        return this.processedContactData.every(item => item.isChecked);
    }

    /**
   * Method Name : showSection
   * @description : getter for the show no result found text when shownProcessedContactData.length === 0.
   * Date: 22/06/2024
   * Created By:Vyom Soni
   */
    get showSection() {
        return this.shownProcessedContactData.length === 0;
    }

    get hasAppliedFilters() {
        return Array.isArray(this.appliedFilters) && this.appliedFilters.length > 0;
    }

    get displayedAppliedFilters() {
        if (!this.appliedFilters || !Array.isArray(this.appliedFilters)) {
            return [];
        }
        if (this.showAllFilters || this.appliedFilters.length <= 3) {
            return this.appliedFilters;
        }
        return this.appliedFilters.slice(0, 3);
    }

    get hasMoreFilters() {
        return Array.isArray(this.appliedFilters) && this.appliedFilters.length > 3 && !this.showAllFilters;
    }

    get remainingFilterCount() {
        if (!Array.isArray(this.appliedFilters) || this.appliedFilters.length <= 3) {
            return 0;
        }
        return this.appliedFilters.length - 3;
    }

    get canCollapseFilters() {
        return this.showAllFilters && Array.isArray(this.appliedFilters) && this.appliedFilters.length > 3;
    }

    toggleShowAllFilters(event) {
        if (event) {
            event.stopPropagation();
        }
        this.showAllFilters = !this.showAllFilters;
    }

    get listingSpinnerLoading() {
        return !this.spinnerShow && this.listingLoading;
    }

    /**
    * Method Name : totalContacts
    * @description : set the total filtered contacts.
    * Date: 16/07/2024
    * Created By:Vyom Soni
    */
    get totalContacts() {
        return this.processedContactData.length;
    }

    /**
    * Method Name : isSelected
    * @description : set value true if any option is true.
    * Date: 16/07/2024
    * Created By:Vyom Soni
    */
    get isSelected() {
        return this.totalSelected > 0;
    }

    /**
    * Method Name : items
    * @description : set 'Items' string when the user select more then 1 options.
    * Date: 16/07/2024
    * Created By:Vyom Soni
    */
    get items() {
        return this.totalSelected > 1 ? 'Items' : 'Item';
    }

    /**
    * Method Name : contactItems
    * @description : set 'Items' when the filtered items is more then the 1  .
    * Date: 16/07/2024
    * Created By:Vyom Soni
    */
    get contactItems() {
        return this.processedContactData.length > 1 ? 'Items' : 'Item';

    }

    /**
     * Method Name : connectedCallback
     * @description : retrieve fields name from the field-set and retrieve Contact records.
     * Date: 22/06/2024
     * Created By:Vyom Soni
     */
    connectedCallback() {
        this.screenWidth = window?.globalThis?.innerWidth;
        window?.globalThis?.addEventListener('resize', this.handleResize);
        loadStyle(this, designcss)
            .then(() => {
                console.log('Styles loaded successfully');
            })
            .catch(error => {
                console.error('Error loading styles', error);
            });
        this.handleSubscribeRefresh();
        this.getAccessible();
    }

    handleLoading(event) {
        if (this.isSilentSync) {
            return;
        }
        this.listingLoading = event.detail;
    }

    /**
    * Method Name: handleSubscribeRefresh
    * @description: Subscribes to MVEX__RefreshEvent__e platform event to detect contact changes
    */
    handleSubscribeRefresh() {
        const messageCallback = (response) => {
            console.log('RefreshEvent received in marketingListCmp:', response);
            const payload = response?.data?.payload;
            const featureName = payload?.MVEX__Feature_Name__c || payload?.Feature_Name__c;
            
            // Verify feature name before doing any operation
            if (featureName && (featureName.toLowerCase() === 'marketing_list' || featureName.toLowerCase() === 'marketing_list_fields')) {
                this.handleRealtimeRefresh();
            }
        };

        subscribe(this.refreshChannelName, -1, messageCallback)
            .then(response => {
                this.refreshSubscription = response;
            })
            .catch(error => {
                console.warn('Subscription error for ' + this.refreshChannelName + ':', error);
                if (this.refreshChannelName.includes('MVEX__')) {
                    this.refreshChannelName = '/event/RefreshEvent__e';
                    subscribe(this.refreshChannelName, -1, messageCallback)
                        .then(resp => {
                            this.refreshSubscription = resp;
                        })
                        .catch(err => console.error('Fallback subscription error:', err));
                }
            });

        onError(error => {
            console.warn('empApi error:', error);
        });
    }

    /**
    * Method Name: handleUnsubscribeRefresh
    * @description: Unsubscribes from refresh platform event channel
    */
    handleUnsubscribeRefresh() {
        if (this.refreshSubscription && this.refreshSubscription.id) {
            unsubscribe(this.refreshSubscription, response => {
                console.log('Unsubscribed from refresh event channel:', response);
            });
        }
    }

    /**
     * Method Name : handleRealtimeRefresh
     * @description : Smoothly synchronize contact changes in real-time without interrupting user
     */
    handleRealtimeRefresh() {
        try {
            clearTimeout(this.realtimeRefreshTimer);
            this.realtimeRefreshTimer = setTimeout(async () => {
                this.isSilentSync = true;
                const savedPage = this.currentPage;
                const selectedIds = new Set((this.selectedContactList || []).map(p => p.Id));

                // 1. Fetch latest contacts from Apex silently
                await this.getContactDataMethod(true);

                // 2. If filters are active, re-apply them against latest DB state silently
                const filterCmp = this.template.querySelector('c-marketing-list-filter-cmp');
                const hasFilters = this.hasAppliedFilters || (filterCmp && typeof filterCmp.hasActiveFilters === 'function' && filterCmp.hasActiveFilters());
                if (filterCmp && typeof filterCmp.reapplyFilters === 'function' && hasFilters) {
                    filterCmp.reapplyFilters(true);
                } else {
                    // Restore checked status if no filter reapplication was triggered
                    if (selectedIds.size > 0 && Array.isArray(this.processedContactData)) {
                        this.processedContactData.forEach(item => {
                            if (selectedIds.has(item.Id)) {
                                item.isChecked = true;
                            }
                        });
                        this.updateSelectedProperties();
                    }

                    if (Array.isArray(this.processedContactData)) {
                        const maxPage = Math.ceil(this.processedContactData.length / this.pageSize) || 1;
                        this.currentPage = Math.min(savedPage, maxPage);
                        this.updateShownData();
                    }
                }

                setTimeout(() => {
                    this.isSilentSync = false;
                }, 300);

                // Display info toast notification about the real-time update
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Contacts Updated',
                        message: 'The contacts data has been synchronized with the latest changes.',
                        variant: 'info',
                        mode: 'dismissable'
                    })
                );
            }, 300);
        } catch (error) {
            console.error('Error in handleRealtimeRefresh in marketingListCmp:', error);
            this.isSilentSync = false;
        }
    }

    /**
    * Method Name: handleRefreshMarketingList
    * @description: Manually refreshes the contact data while preserving currently applied filters
    */
    handleRefreshMarketingList() {
        this.isManualRefreshing = true;
        this.spinnerShow = true;
        this.getContactDataMethod()
            .then(() => {
                const filterCmp = this.template.querySelector('c-marketing-list-filter-cmp');
                if (filterCmp && typeof filterCmp.reapplyFilters === 'function') {
                    filterCmp.reapplyFilters();
                } else {
                    this.isManualRefreshing = false;
                    this.spinnerShow = false;
                    this.showToast('Success', 'Marketing list refreshed successfully.', 'success');
                }
            })
            .catch(error => {
                this.isManualRefreshing = false;
                this.spinnerShow = false;
                this.showToast('Error', error.body?.message || 'An unknown error occurred', 'error');
            });
    }

    getAccessible() {
        getMetadataRecords()
            .then(data => {
                const marketingListFeature = data.find(
                    item => item.DeveloperName === 'Marketing_List'
                );
                this.isAccessible = marketingListFeature ? Boolean(marketingListFeature.MVEX__isAvailable__c) : false;

                if (this.isAccessible) {
                    this.getContactDataMethod();
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
    * Method Name : renderedCallback
    * @description : to update sort icons when data is loaded.
    * Date: 29/07/2024
    * Created By:Rachit shah
    */
    renderedCallback() {
        try {
            if (!this.isSortApplied && this.processedContactData?.length > 0) {
                this.updateSortIcons();
                this.isSortApplied = true;
            }
        } catch (error) {
            console.log('Error renderedCallback->' + error);
        }
    }

    /**
    * Method Name : disconnectedCallback
    * @description : to display content of templte body.
    * Date: 29/07/2024
    * Created By:Vyom Soni
    */
    disconnectedCallback() {
        window?.globalThis?.removeEventListener('resize', this.handleResize);
        clearTimeout(this.realtimeRefreshTimer);
        this.handleUnsubscribeRefresh();
    }

    /**
     * Method Name : getContactDataMethod
     * @description : retrieve the Contact data from the salesforce
     * Date: 22/06/2024
     * Created By:Vyom Soni
     */
    getContactDataMethod(isSilent = false) {
        if (!isSilent) {
            this.spinnerShow = true;
        }
        return getContactData()
            .then(result => {
                this.contactData = result.contacts;
                this.pageSize = result.pageSize;
                this.fields = result.selectedFields.map(field => ({
                    fieldLabel: field.label,
                    fieldName: field.fieldApiname,
                    fieldType: field.fieldType,
                    cardView: field.cardView,
                    format: field.format,
                    referenceObjectName: field.referenceObjectName,
                    relationshipName: field.relationshipName
                }));

                const selectedIds = new Set((this.selectedContactList || []).map(c => c.Id));

                this.contactData.forEach((con) => {
                    con.isChecked = isSilent && selectedIds.has(con.Id);
                });
                this.processContacts();
                return result;
            })
            .catch(error => {
                this.isManualRefreshing = false;
                if (!isSilent) {
                    this.spinnerShow = false;
                    this.showToast('Error', error.body?.message || 'An unknown error occurred', 'error');
                }
                console.log('error in getContactData -> ' + JSON.stringify(error, null, 2));
                throw error;
            })
            .finally(() => {
                if (!isSilent && !this.isManualRefreshing) {
                    this.spinnerShow = false;
                }
            });
    }


    convertKeysToLowercase(obj) {
        if (obj && typeof obj === 'object') {
            if (Array.isArray(obj)) {
                return obj.map(item => this.convertKeysToLowercase(item));
            } else {
                return Object.keys(obj).reduce((acc, key) => {
                    const newKey = key.toLowerCase();
                    acc[newKey] = this.convertKeysToLowercase(obj[key]);
                    return acc;
                }, {});
            }
        }
        return obj;
    }

    /**
    * Method Name : processContacts
    * @description : set the contact data inorder of the fields data
    * Date: 22/06/2024
    * Created By:Vyom Soni
    */
    processContacts() {
        try {
            this.processedContactData = this.contactData.map(con => {
                let orderedFields = this.fields.map(field => {
                    let isRedirectable = false;
                    let lookupId = null;
                    let objectApiName = null;
                    let rawValue;

                    if (field.fieldName.includes('.')) {
                        let fieldParts = field.fieldName.split('.');
                        let relatedObject = con[fieldParts[0]];
                        rawValue = relatedObject ? relatedObject[fieldParts[1]] : null;

                        if (relatedObject && fieldParts[1] === 'Name') {
                            isRedirectable = true;
                            lookupId = relatedObject.Id;
                            objectApiName = field.referenceObjectName;
                        }
                    } else {
                        rawValue = con[field.fieldName];
                    }

                    let fieldValueraw;

                    // Handle empty/null
                    if (rawValue === null || rawValue === undefined || rawValue === '') {
                        fieldValueraw = '-';
                    }

                    // Currency Handling 
                    else if (field.fieldType === 'CURRENCY') {
                        fieldValueraw = new Intl.NumberFormat(USER_LOCALE, {
                            style: 'currency',
                            currency: con.CurrencyIsoCode || USER_CURRENCY,
                            minimumFractionDigits: 0
                        }).format(rawValue);
                    }

                    // Date Formatting
                    else if (field.format) {
                        fieldValueraw = this.applyFieldFormat(rawValue, field.format);
                    }

                    // Default
                    else {
                        fieldValueraw = rawValue;
                    }

                    return {
                        fieldName: field.fieldName,
                        value: fieldValueraw,
                        rawValue: (rawValue === null || rawValue === undefined || rawValue === '') ? null : rawValue,
                        isRedirectable: isRedirectable,
                        lookupId: lookupId,
                        objectApiName: objectApiName
                    };
                });

                return {
                    ...con,
                    isChecked: con.isChecked,
                    orderedFields
                };
            });
            this.unchangedProcessContact = this.processedContactData;

            // Apply existing filter if one was already active, or pending filter if received before load
            if (!this.isManualRefreshing && this.lastFilterEvent) {
                this.handleFilteredContacts(this.lastFilterEvent);
            } else if (this.pendingFilterEvent) {
                const filterEvent = this.pendingFilterEvent;
                this.pendingFilterEvent = null; // Clear the pending event
                this.handleFilteredContacts(filterEvent);
            } else {
                this.sortData();
                this.updateShownData();
            }

            if (!this.isManualRefreshing && !this.isSilentSync) {
                this.spinnerShow = false;
            }
        } catch (error) {
            console.log('Error processContacts->' + error);
        }
    }

    // Method to apply formatting based on the format value from dateOptions and dateTimeOptions
    applyFieldFormat(fieldValue, format) {
        if (!fieldValue || fieldValue === '-') {
            return '-';
        }

        let date = new Date(fieldValue);

        if (isNaN(date.getTime())) {
            return '-';
        }

        let day = String(date.getDate()).padStart(2, '0');
        let month = String(date.getMonth() + 1).padStart(2, '0'); // Months are zero-based in JS
        let year = date.getFullYear();
        let hours24 = String(date.getHours()).padStart(2, '0');
        let minutes = String(date.getMinutes()).padStart(2, '0');
        let hours12 = hours24 % 12 || 12; // Handle 12:00 correctly
        let period = hours24 >= 12 ? 'PM' : 'AM';
        hours12 = String(hours12).padStart(2, '0');

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
                return fieldValue; // Return unformatted value if no match
        }
    }

    /**
    * Method Name : handleResize
    * @description : call when component is resize.
    * * Date: 3/06/2024
    * Created By:Vyom Soni
    */
    handleResize = () => {
        this.screenWidth = window?.globalThis?.innerWidth;
    }

    /**
    * Method Name : updateShownData
    * @description : update the shownProcessedLisitingData when pagination is applied.
    * date: 20/08/2024
    * Created By:Vyom Soni
    */
    updateShownData() {
        try {
            const startIndex = (this.currentPage - 1) * this.pageSize;
            const endIndex = Math.min(startIndex + this.pageSize, this.totalItems);
            this.shownProcessedContactData = this.processedContactData.slice(startIndex, endIndex);
        } catch (error) {
            console.log('Error updateShownData->' + error);
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
    * Method Name : handleFilteredContacts
    * @description : set the data comming from the filter cmp
    *  Date: 22/06/2024
    * Created By:Vyom Soni
    */
    handleFilteredContacts(event) {
        try {
            this.showAllFilters = false;
            if (event.detail && Array.isArray(event.detail.appliedFilters)) {
                this.appliedFilters = event.detail.appliedFilters;
            }

            // Save last filter event to reapply whenever table data reloads
            this.lastFilterEvent = event;

            // If contact data hasn't loaded yet, store the filter event for later
            if (!this.unchangedProcessContact || this.unchangedProcessContact.length === 0) {
                this.pendingFilterEvent = event;
                return;
            }

            const savedPage = this.isSilentSync ? this.currentPage : 1;
            const selectedIds = new Set((this.selectedContactList || []).map(p => p.Id));

            if (!this.isManualRefreshing && !this.isSilentSync) {
                this.sortField = 'Name';
                this.sortOrder = 'asc';

                // Reset all icons to remove rotation classes
                const allHeaders = this.template.querySelectorAll('.slds-icon-utility-arrowdown svg');
                allHeaders.forEach(icon => icon.classList.remove('rotate-asc', 'rotate-desc'));
                this.isSortApplied = false;
            }

            // Reset or preserve checked flag based on isSilentSync
            const resetCheckedFlag = item => ({
                ...item,
                isChecked: this.isSilentSync && selectedIds.has(item.Id)
            });
            this.processedContactData = this.processedContactData.map(resetCheckedFlag);
            this.unchangedProcessContact = this.unchangedProcessContact.map(resetCheckedFlag);

            // Apply filtered contacts safely
            const filteredContacts = Array.isArray(event?.detail?.filtercontacts) ? event.detail.filtercontacts : [];
            const filteredListingIds = new Set(filteredContacts.map(filtered => filtered.Id).filter(Boolean));
            this.processedContactData = this.unchangedProcessContact.filter(processListing =>
                filteredListingIds.has(processListing.Id)
            );

            // Reset or maintain current page and update view
            const maxPage = Math.ceil(this.processedContactData.length / this.pageSize) || 1;
            this.currentPage = this.isSilentSync ? Math.min(savedPage, maxPage) : 1;
            this.sortData();
            this.updateShownData();
            this.updateSelectedProperties();

            if (this.isManualRefreshing) {
                this.isManualRefreshing = false;
                this.spinnerShow = false;
                this.showToast('Success', 'Marketing list refreshed successfully.', 'success');
            }
        } catch (e) {
            console.error('handleFilteredContacts' + e);
        }
    }

    handleReset(event) {
        try {
            if (event.detail.filtercontacts == true) {
                this.showAllFilters = false;
                if (event.detail && Array.isArray(event.detail.appliedFilters)) {
                    this.appliedFilters = event.detail.appliedFilters;
                    this.lastFilterEvent = event;
                } else {
                    this.appliedFilters = [
                        {
                            id: 'MVEX__Contact_Type__c',
                            label: 'Contact Type',
                            value: 'Buyer',
                            displayText: 'Contact Type: Buyer'
                        }
                    ];
                    this.lastFilterEvent = null;
                }
                this.sortField = 'Name';
                this.sortOrder = 'asc';

                // Reset all icons to remove rotation classes
                const allHeaders = this.template.querySelectorAll('.slds-icon-utility-arrowdown svg');
                allHeaders.forEach(icon => icon.classList.remove('rotate-asc', 'rotate-desc'));

                // Deselect all items in processedListingData and unchangedProcessListings
                const resetCheckedFlag = item => ({ ...item, isChecked: false });
                this.processedContactData = this.processedContactData.map(resetCheckedFlag);
                this.unchangedProcessContact = this.unchangedProcessContact.map(resetCheckedFlag);
                this.processedContactData = this.unchangedProcessContact;
                this.currentPage = 1;
                this.isSortApplied = false;
                this.sortData();
                this.updateShownData();
                this.updateSelectedProperties();
            }
        } catch (error) {
            console.log('Error -> handleFilteredListings' + error);
        }
    }

    handlAddModalChange(event) {
        this.fieldsModal = event.detail;
    }

    /**
    * Method Name : handleContactSelect
    * @description : handle data from the tile cmp
    *  Date: 22/06/2024
    * Created By:Vyom Soni
    * 
    */
    handleContactSelect(event) {
        try {
            this.processedContactData = event.detail;
            this.updateShownData();
            this.updateSelectedProperties();
            this.selectedContactList = this.processedContactData.filter(item => item.isChecked == true);
            this.isContactSelected = this.selectedContactList.length <= 0;
        } catch (error) {
            console.log('Error handleContactSelect->' + error);
        }
    }

    /**
    * Method Name : redirectToRecord
    * @description : redirect to contact record recordPage
    * Date: 22/06/2024
    * Created By:Vyom Soni
    */
    redirectToRecord(event) {
        try {
            const recordId = event.target.dataset.id;
            const objectApiName = event.target.dataset.object || 'Contact';
            if (this.screenWidth > 900) {
                this[NavigationMixin.GenerateUrl]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: recordId,
                        objectApiName: objectApiName,
                        actionName: 'view'
                    }
                }).then(url => {
                    window?.globalThis?.open(url, '_blank');
                });
            } else {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: recordId,
                        objectApiName: objectApiName,
                        actionName: 'view'
                    }
                });
            }
        } catch (error) {
            console.log('Error redirectToRecord->' + error);
        }
    }

    /**
    * Method Name : checkBoxValueChange
    * @description : handle the checkbox change
    * Date: 22/06/2024
    * Created By:Vyom Soni
    */
    checkBoxValueChange(event) {
        try {
            const checkboxId = Number(event.target.dataset.id);
            const isChecked = event.target.checked;
            this.shownProcessedContactData[checkboxId].isChecked = isChecked;
            this.processedContactData.forEach(item1 => {
                this.shownProcessedContactData.forEach(item2 => {
                    if (item1.Id == item2.Id) {
                        item1.isChecked = item2.isChecked;
                    }
                })
            })

            this.selectedContactList = this.processedContactData.filter(item => item.isChecked == true);

            this.isContactSelected = this.selectedContactList.length <= 0;

            this.unchangedProcessContact.forEach(item1 => {
                this.shownProcessedContactData.forEach(item2 => {
                    if (item1.Id == item2.Id) {
                        item1.isChecked = item2.isChecked;
                    }
                })
            })
            this.updateSelectedProperties();
        } catch (e) {
            console.log('Error checkCoxValueChange ->' + e);
        }
    }

    /**
    * Method Name : selectAllCheckbox
    * @description : select the all checkbox
    * Date: 22/06/2024
    * Created By:Vyom Soni
    */
    selectAllCheckbox(event) {
        try {
            const isChecked = event.target.checked;
            this.sortField = 'Name';
            this.sortOrder = 'asc';
            const allHeaders = this.template.querySelectorAll('.slds-icon-utility-arrowdown svg');
            allHeaders.forEach(icon => {
                icon.classList.remove('rotate-asc', 'rotate-desc');
            });
            this.processedContactData = this.processedContactData.map(item => {
                return { ...item, isChecked: isChecked };
            });

            if (isChecked) {
                this.selectedContactList = this.processedContactData;
                this.isContactSelected = false;
            }
            else {
                this.selectedContactList = [];
                this.isContactSelected = true;
            }

            this.unchangedProcessContact = this.unchangedProcessContact.map(item => {
                return { ...item, isChecked: isChecked };
            });
            this.updateShownData();
            this.updateSelectedProperties();
        } catch (error) {
            console.log('Error selectAllCheckbox->' + error);
        }
    }


    /**
    * Method Name : goTOContactPage
    * @description : Open Modal for new contact form
    * Date: 18/07/2024
    * Created By:Vyom Soni
    */
    goTOContactPage() {
        try {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'Contact',
                    actionName: 'new'
                },
                state: {
                    c__customParam: 'MarketingList' // Add your custom parameter here
                }
            });
        } catch (error) {
            console.log('Error in goTOContactPage --> ' + error);
        }
    }

    /**
    * Method Name : newContactHandle
    * @description : Redirect the marketing list component after contact is created
    * Date: 18/07/2024
    * Created By:Vyom Soni
    */
    newContactHandle() {
        var cmpDef;
        cmpDef = {
            componentDef: 'MVEX:marketingListCmp',
        };

        let encodedDef = btoa(JSON.stringify(cmpDef));
        this[NavigationMixin.Navigate]({
            type: "standard__webPage",
            attributes: {
                url: "/one/one.app#" + encodedDef
            }
        });
    }

    /**
    * Method Name : updateSelectedProperties
    * @description : update the properties as selected
    * Date: 22/06/2024
    * Created By:Vyom Soni
    */
    updateSelectedProperties() {
        this.selectedContactList = this.processedContactData.filter(con => con.isChecked);
        this.totalSelected = this.selectedContactList.length;
        this.isContactSelected = this.selectedContactList.length <= 0;
    }

    /**
    * Method Name : sortClick
    * @description : this methods apply the sorting on the all fields
    * Date: 22/06/2024
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
            this.updateSortIcons();
            this.updateShownData();
        } catch (error) {
            console.log('Error sortClick->' + error);
        }
    }

    /**
    * Method Name : sortData
    * @description : this methods apply the sorting on the all fields
    * Date: 22/06/2024
    * Created By:Vyom Soni
    */
    sortData() {
        try {
            // Helper: treat null / undefined / '' / '-' as "no value"
            const isEmpty = (v) => v === null || v === undefined || v === '' || v === '-';

            this.processedContactData = [...this.processedContactData].sort((a, b) => {
                let aValue, bValue;

                if (this.sortField === 'Name') {
                    aValue = a.Name;
                    bValue = b.Name;
                } else {
                    const aField = a.orderedFields.find(field => field.fieldName === this.sortField);
                    const bField = b.orderedFields.find(field => field.fieldName === this.sortField);

                    // For DATE / DATETIME fields sort by raw timestamp, not formatted string
                    const fieldMeta = this.fields.find(f => f.fieldName === this.sortField);
                    const isDateField = fieldMeta &&
                        (fieldMeta.fieldType === 'DATE' || fieldMeta.fieldType === 'DATETIME');

                    if (isDateField) {
                        aValue = aField.rawValue ? Date.parse(aField.rawValue) : null;
                        bValue = bField.rawValue ? Date.parse(bField.rawValue) : null;
                    } else {
                        aValue = aField.value;
                        bValue = bField.value;
                    }
                }

                // Push null/empty to the very end on asc, very front on desc
                const aEmpty = isEmpty(aValue);
                const bEmpty = isEmpty(bValue);
                if (aEmpty && bEmpty) return 0;
                if (aEmpty) return this.sortOrder === 'asc' ? 1 : -1;
                if (bEmpty) return this.sortOrder === 'asc' ? -1 : 1;

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
        } catch (error) {
            console.log('Error sortData->' + error);
        }

    }


    /**
    * Method Name : updateSortIcons
    * @description : this method update the sort icons in the wrapbutton
    * Date: 22/06/2024
    * Created By:Vyom Soni
    */
    // updateSortIcons() {
    //     try {
    //         const allHeaders = this.template.querySelectorAll('.slds-icon-utility-arrowdown svg');
    //         allHeaders.forEach(icon => {
    //             icon.classList.remove('rotate-asc', 'rotate-desc');
    //         });

    //         const currentHeader = this.template.querySelector('[data-index="' + this.sortField + '"]');
    //         if (currentHeader) {
    //             currentHeader.classList.add(this.sortOrder === 'asc' ? 'rotate-asc' : 'rotate-desc');
    //         }
    //     } catch (error) {
    //         console.log('Error updateSprtIcons->' + error);
    //     }
    // }

    updateSortIcons() {
        try {
            // Remove icon rotation
            const allIcons = this.template.querySelectorAll('.table-content .slds-icon-utility-arrowdown svg');
            allIcons.forEach(icon => {
                icon.classList.remove('rotate-asc', 'rotate-desc');
            });

            // Remove active class from all headers
            const allHeaders = this.template.querySelectorAll('.table-content .sorting_header');
            allHeaders.forEach(header => {
                header.classList.remove('active-sort');
            });

            // Set active header
            const currentHeader = this.template.querySelector('.table-content [data-id="' + this.sortField + '"]');
            if (currentHeader) {
                currentHeader.classList.add('active-sort');

                const icon = currentHeader.querySelector('svg');
                if (icon) {
                    icon.classList.add(this.sortOrder === 'asc' ? 'rotate-asc' : 'rotate-desc');
                }
            }

        } catch (error) {
            console.log('Error in updateSortIcons --> ' + error);
        }
    }

    /**
    * Method Name : scrollToTop
    * @description : scroll to top in list
    * Date: 22/06/2024
    * Created By:Vyom Soni
    */
    scrollToTop() {
        try {
            const tableDiv = this.template.querySelector('.table-content');
            if (tableDiv) {
                tableDiv.scrollTop = 0;
            }
        } catch (error) {
            console.log('Error scrollToTop->' + error);
        }
    }


    /**
    * Method Name : showToast
    * @description : show the toast message
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    showToast(title, message, variant) {
        const toastEvent = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        if (!import.meta.env.SSR) {
            this.dispatchEvent(toastEvent);
        }
    }


    /**
   * Method Name : wrapFilter
   * @description : this method is used for the wrap the filter
   * date: 3/06/2024
   * Created By:Vyom Soni
   */
    wrapFilter() {
        try {
            const toggleBtn = this.template.querySelector('.filter-toggle-btn');
            const filterDiv = this.template.querySelector('.innerDiv1 .filterDiv');
            const div1 = this.template.querySelector('.innerDiv1');
            const div2 = this.template.querySelector('.innerDiv2');

            if (this.wrapOn) {
                // Currently hidden, show filter
                toggleBtn.classList.add('active'); // Blue when filter showing
                filterDiv.classList.remove('removeInnerDiv1');
                div1.classList.remove('removeInnerDiv1');

                if (this.screenWidth >= 900) {
                    div1.style.width = '22%';
                    div1.style.opacity = '1';
                    div1.style.marginLeft = '0.75rem';
                    div2.style.width = '78%';
                } else {
                    div1.style.height = 'fit-content';
                    div1.style.width = '100%';
                    div1.style.opacity = '1';
                    div2.style.height = '30rem';
                    div2.style.width = '100%';
                }
                this.wrapOn = false;
            } else {
                // Currently showing, hide filter
                toggleBtn.classList.remove('active'); // White when filter hidden

                if (this.screenWidth >= 900) {
                    div1.style.width = '0';
                    div1.style.opacity = '0';
                    div1.style.marginLeft = '0';
                    div2.style.width = '100%';

                    // Hide filter content and remove margin after animation starts
                    setTimeout(() => {
                        if (this.wrapOn) {
                            filterDiv.classList.add('removeInnerDiv1');
                            div1.classList.add('removeInnerDiv1');
                        }
                    }, 150);
                } else {
                    filterDiv.classList.add('removeInnerDiv1');
                    div1.style.height = '0';
                    div1.style.opacity = '0';
                    div1.style.width = '100%';
                    div2.style.height = '100%';
                    div2.style.width = '100%';
                }
                this.wrapOn = true;
            }
        } catch (error) {
            errorDebugger('MarketingListCmp', 'wrapFilter', error, 'warn', 'Error in wrapFilter');
        }
    }

    openFilterPanel() {
        try {
            if (this.wrapOn) {
                this.wrapFilter();
            } else {
                const filterDiv = this.template.querySelector('.innerDiv1 .filterDiv');
                if (filterDiv) {
                    filterDiv.classList.add('highlight-filter-panel');
                    setTimeout(() => {
                        filterDiv.classList.remove('highlight-filter-panel');
                    }, 1200);
                }
            }
        } catch (error) {
            console.error('Error in openFilterPanel:', error);
        }
    }

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
            console.log('error--> ', error);
        }
    }

    openConfigureSettings() {
        this.isConfigOpen = true;
    }
    handleCloseModal() {
        this.isConfigOpen = false;
        this.getContactDataMethod()
            .then(() => {
                const filterCmp = this.template.querySelector('c-marketing-list-filter-cmp');
                if (filterCmp && typeof filterCmp.reapplyFilters === 'function') {
                    filterCmp.reapplyFilters();
                }
            })
            .catch(error => {
                console.error('Error reloading after close modal:', error);
            });
    }
}