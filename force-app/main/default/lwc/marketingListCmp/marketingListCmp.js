import { LightningElement, track, api } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import designcss from '@salesforce/resourceUrl/MulishFontCss';
import getMetadataRecords from '@salesforce/apex/ControlCenterController.getMetadataRecords';
import getContactData from '@salesforce/apex/MarketingListCmpController.getContactData';
import getListViewId from '@salesforce/apex/MarketingListCmpController.getListViewId';
import { NavigationMixin } from 'lightning/navigation';
import sendEmail from '@salesforce/apex/MarketingListCmpController.sendEmail';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import summerNote_Editor from '@salesforce/resourceUrl/summerNoteEditor';
import getQuickTemplates from '@salesforce/apex/EmailCampaignController.getQuickTemplates';
import processBroadcastMessageWithObject from '@salesforce/apex/MarketingListCmpController.processBroadcastMessageWithObject';
import getMessagingServiceOptions from '@salesforce/apex/EmailCampaignController.getMessagingServiceOptions';
import getTemplatesByObject from '@salesforce/apex/BroadcastMessageController.getTemplatesByObject';
import createChatRecods from '@salesforce/apex/BroadcastMessageController.createChatRecods';
import getUserConfig from '@salesforce/apex/ObjectConfigController.getUserConfig';
import hasBusinessAccountId from '@salesforce/apex/PropertySearchController.hasBusinessAccountId';
import USER_CURRENCY from '@salesforce/i18n/currency';
import USER_LOCALE from '@salesforce/i18n/locale';
import FORM_FACTOR from '@salesforce/client/formFactor';

export default class MarketingListCmp extends NavigationMixin(LightningElement) {
    @api objectName = 'Contact';
    @api recordId;
    @track configuredPhoneField = 'Phone';
    refreshSubscription = {};
    refreshChannelName = '/event/MVEX__RefreshEvent__e';
    realtimeRefreshTimer = null;
    isSilentSync = false;
    isManualRefreshing = false;
    @track data;
    @track addModal = false;
    @track spinnerShow = true;
    @track showList = true;
    @track contactData = [];
    @track fields = [];
    @track processedContactData = [];
    @track unchangedProcessContact = [];
    @track filteredSelectedContacts = [];
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
    allSelectedContacts = [];
    @track sortField = 'Name';
    @track sortOrder = 'asc';
    @track totalSelected = 0;
    @track isPrevDisabled = true;
    @track isNextDisabled = false;
    @track pageNumber = 1;
    @track pageSize = 30;
    @track shownProcessedContactData = [];
    @track isModalOpen = false;
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

    // rachit changes
    @track sendMethod = '';
    @track selectedTemplate = '';
    @track isTemplateBody = false;
    @track isFirstScreen = true;
    @track footerButtonLabel = 'Next';

    @track messageOptions = [];

    @track getQuickTemplates = [];
    @track showTemplate = false;
    @track isMainModal = true;

    @track messageText = '';
    @track broadcastGroupName = '';
    @track tempBroadcastGroupName = '';
    @track listViewId = '';

    @track popUpLastPage = false;
    @track popUpConfirmPage = false;
    @track popupHeader = 'Create Broadcast Group';
    @track templateOptions = [];
    @track selectedDateTime = '';
    @track selectedObject = 'Contact';
    @track broadcastGroupId = null;
    @track templateMap = new Map();
    @track isAccessible = false;
    @track hasBusinessAccountConfigured = false;
    selectedTemplate = '';
    allSelectedContact = [];
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
     * Method Name : checkAllBroadcast
     * @description : Getter to check if all contacts in the broadcast group table are selected
     * Date: 13/06/2025
     * Created By: [Your Name]
     */
    get checkAllBroadcast() {
        return this.selectedContactList.every(item => item.isChecked);
    }

    // Getter to provide a record ID for the preview component
    get previewRecordId() {
        if (this.selectedContactList && this.selectedContactList.length > 0) {
            return this.selectedContactList[0].Id;
        }
        return null;
    }

    get selectedContactsWithoutEmail() {
        if (!this.selectedContactList || this.selectedContactList.length === 0) {
            return [];
        }
        return this.selectedContactList.filter(contact => !this.getContactEmail(contact));
    }

    get selectedContactsWithoutPhone() {
        if (!this.selectedContactList || this.selectedContactList.length === 0) {
            return [];
        }
        return this.selectedContactList.filter(contact => !this.getContactPhone(contact));
    }

    get isSendEmailDisabled() {
        if (!this.selectedContactList || this.selectedContactList.length === 0) {
            return false;
        }
        return this.selectedContactsWithoutEmail.length > 0;
    }

    get isSendMessageDisabled() {
        if (!this.selectedContactList || this.selectedContactList.length === 0) {
            return true;
        }
        return this.selectedContactsWithoutPhone.length > 0;
    }

    get sendEmailButtonTitle() {
        if (!this.selectedContactList || this.selectedContactList.length === 0) {
            return 'Send Emails';
        }
        const noEmail = this.selectedContactsWithoutEmail;
        if (noEmail.length === 1) {
            return `Contact "${noEmail[0].Name || 'Selected contact'}" has no email address. Unselect this contact to enable Send Emails.`;
        } else if (noEmail.length > 1) {
            const names = noEmail.slice(0, 3).map(c => c.Name || 'Contact').join(', ');
            const suffix = noEmail.length > 3 ? '...' : '';
            return `${noEmail.length} selected contacts (${names}${suffix}) have no email address. Unselect them to enable Send Emails.`;
        }
        return 'Send Emails';
    }

    get sendMessageButtonTitle() {
        if (!this.selectedContactList || this.selectedContactList.length === 0) {
            return 'Select at least one contact to send messages';
        }
        const noPhone = this.selectedContactsWithoutPhone;
        if (noPhone.length === 1) {
            return `Contact "${noPhone[0].Name || 'Selected contact'}" has no phone number. Unselect this contact to enable Send Message.`;
        } else if (noPhone.length > 1) {
            const names = noPhone.slice(0, 3).map(c => c.Name || 'Contact').join(', ');
            const suffix = noPhone.length > 3 ? '...' : '';
            return `${noPhone.length} selected contacts (${names}${suffix}) have no phone number. Unselect them to enable Send Message.`;
        }
        return 'Send Message';
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
        this.checkBusinessAccountConfig();
        this.loadPhoneFieldConfiguration();
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
    * Method Name : checkBusinessAccountConfig
    * @description : method to check if business account ID is configured in custom metadata
    * Date: 03/02/2026
    * Created By: Karan Singh
    */
    async checkBusinessAccountConfig() {
        try {
            const result = await hasBusinessAccountId();
            this.hasBusinessAccountConfigured = result;
        } catch (error) {
            console.error('Error checking business account configuration:', error);
            this.hasBusinessAccountConfigured = false;
        }
    }

    /**
    * Method Name : loadPhoneFieldConfiguration
    * @description : Loads user-configured phone field from metadata for messaging
    */
    loadPhoneFieldConfiguration() {
        getUserConfig()
            .then(data => {
                if (!data) return;
                let phoneField = '';
                if (data.ChatWindowConfigInfo && data.ChatWindowConfigInfo !== '{}') {
                    try {
                        const chatConfig = JSON.parse(data.ChatWindowConfigInfo);
                        if (chatConfig) {
                            const objKey = this.objectName || this.selectedObject || 'Contact';
                            if (chatConfig[objKey] && chatConfig[objKey].phoneField) {
                                phoneField = chatConfig[objKey].phoneField;
                            } else if (chatConfig.Contact && chatConfig.Contact.phoneField) {
                                phoneField = chatConfig.Contact.phoneField;
                            }
                        }
                    } catch (e) {
                        console.error('Error parsing ChatWindowConfigInfo in marketingListCmp:', e);
                    }
                }

                if (!phoneField && data.ObjectConfigInfo && data.ObjectConfigInfo !== '{}') {
                    try {
                        const objConfig = JSON.parse(data.ObjectConfigInfo);
                        if (objConfig && objConfig.phoneField) {
                            phoneField = objConfig.phoneField;
                        }
                    } catch (e) {
                        console.error('Error parsing ObjectConfigInfo in marketingListCmp:', e);
                    }
                }

                if (phoneField) {
                    this.configuredPhoneField = phoneField;
                }
            })
            .catch(error => {
                console.error('Error loading phone field configuration:', error);
            });
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

    getContactEmail(contact) {
        if (!contact) return '';
        if (contact.Email !== undefined && contact.Email !== null && String(contact.Email).trim() !== '') {
            return String(contact.Email).trim();
        }
        const matchingKey = Object.keys(contact).find(k => k.toLowerCase() === 'email');
        if (matchingKey && contact[matchingKey] !== undefined && contact[matchingKey] !== null && String(contact[matchingKey]).trim() !== '') {
            return String(contact[matchingKey]).trim();
        }
        return '';
    }

    getContactPhone(contact) {
        if (!contact) return '';
        const targetField = this.configuredPhoneField || 'Phone';
        if (contact[targetField] !== undefined && contact[targetField] !== null && String(contact[targetField]).trim() !== '') {
            return String(contact[targetField]).trim();
        }
        const lowerTarget = targetField.toLowerCase();
        const matchingKey = Object.keys(contact).find(k => k.toLowerCase() === lowerTarget);
        if (matchingKey && contact[matchingKey] !== undefined && contact[matchingKey] !== null && String(contact[matchingKey]).trim() !== '') {
            return String(contact[matchingKey]).trim();
        }
        if (lowerTarget !== 'phone' && contact.Phone !== undefined && contact.Phone !== null && String(contact.Phone).trim() !== '') {
            return String(contact.Phone).trim();
        }
        return '';
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
                    this.loadQuickTemplates();
                    this.loadMessageOptions();
                    this.loadListViewId();
                    this.loadAllTemplates();
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
    * @description : to display content of templte body.
    * Date: 29/07/2024
    * Created By:Rachit shah
    */
    renderedCallback() {
        try {
            if (!this.isFirstScreen) {
                Promise.all([
                    loadStyle(this, summerNote_Editor + '/summernote-lite-pdf.css'),
                ]).then(() => {
                    const richText = this.template.querySelector('.richText');
                    richText && (richText.innerHTML = this.setTempValue(this.templateBody));
                }).catch(error => {
                    console.log('Error ==> ', error);
                });
            }
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

    loadAllTemplates() {
        getTemplatesByObject()
            .then(result => {
                this.templateMap = new Map(Object.entries(result || {}));
                this.updateTemplateOptions();
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load templates', 'error');
                console.error('Error loadAllTemplates->', error);
            });
    }

    /**
    * Method Name : loadMessageOptions
    * @description : fetch the message options.
    * Date: 29/07/2024
    * Created By:Vyom Soni
    */
    loadMessageOptions() {
        getMessagingServiceOptions()
            .then(data => {
                this.messageOptions = data.map(option => {
                    return { label: option.label, value: option.value };
                });
            })
            .catch(error => {
                this.showToast('Error', 'Failed to fetch message options', 'error');
                console.error(error);
            })
    }

    loadListViewId() {
        getListViewId().then(data => {
            this.listViewId = data;
        }).catch(error => {
            this.showToast('Error', 'Failed to load list view id: ' + error.stack, 'error');
        })
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

    /**
    * Method Name : handleSave
    * @description : method to do save changes
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    handleSave() {
        try {
            this.spinnerShow = true;
            const emailData = {
                sendMethod: this.sendMethod,
                templateId: this.selectedTemplate,
                contacts: this.selectedContactList
            };

            sendEmail({ emailDataJson: JSON.stringify(emailData) })
                .then(() => {
                    this.showToast('Success', 'Emails sent successfully!', 'success');
                    this.closeModal();
                })
                .catch(error => {
                    this.showToast('Error', 'Failed to send emails. ' + error.body.message, 'error');
                })
                .finally(() => {
                    this.spinnerShow = false;
                });
        } catch (error) {
            console.log('Error handleSave->' + error);
            this.spinnerShow = false;
        }
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

            if (isChecked) {
                const changedContact = this.shownProcessedContactData[checkboxId];
                const contactName = changedContact?.Name || 'Selected contact';
                const hasEmail = Boolean(this.getContactEmail(changedContact));
                const hasPhone = Boolean(this.getContactPhone(changedContact));

                if (!hasEmail && !hasPhone) {
                    this.showToast(
                        'Missing Email and Phone',
                        `You have selected "${contactName}" who has neither an email address nor a valid phone number, disabling both "Send Emails" and "Send Message" buttons. Please unselect this contact to enable them.`,
                        'warning'
                    );
                } else if (!hasEmail) {
                    this.showToast(
                        'Missing Email Address',
                        `You have selected "${contactName}" who has no email address, disabling the "Send Emails" button. Please unselect this contact to enable the Send Emails button.`,
                        'warning'
                    );
                } else if (!hasPhone) {
                    this.showToast(
                        'Missing Phone Number',
                        `You have selected "${contactName}" who has no valid phone number, disabling the "Send Message" button. Please unselect this contact to enable the Send Message button.`,
                        'warning'
                    );
                }
            }
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

            if (isChecked) {
                const noEmailContacts = this.processedContactData.filter(c => !this.getContactEmail(c));
                const noPhoneContacts = this.processedContactData.filter(c => !this.getContactPhone(c));

                const hasEmailIssues = noEmailContacts.length > 0;
                const hasPhoneIssues = noPhoneContacts.length > 0;

                if (hasEmailIssues && hasPhoneIssues) {
                    this.showToast(
                        'Missing Contact Information',
                        `Some selected contacts are missing required details (${noEmailContacts.length} missing email, ${noPhoneContacts.length} missing phone number), disabling "Send Emails" and "Send Message" buttons. Please unselect contacts without email or phone to enable them.`,
                        'warning'
                    );
                } else if (hasEmailIssues) {
                    const namesStr = noEmailContacts.length === 1
                        ? `"${noEmailContacts[0].Name || 'Selected contact'}"`
                        : `${noEmailContacts.length} contacts (${noEmailContacts.slice(0, 3).map(c => c.Name || 'Contact').join(', ')}${noEmailContacts.length > 3 ? '...' : ''})`;
                    this.showToast(
                        'Missing Email Address',
                        `You have selected ${namesStr} with no email address, disabling the "Send Emails" button. Please unselect these contacts to enable the Send Emails button.`,
                        'warning'
                    );
                } else if (hasPhoneIssues) {
                    const namesStr = noPhoneContacts.length === 1
                        ? `"${noPhoneContacts[0].Name || 'Selected contact'}"`
                        : `${noPhoneContacts.length} contacts (${noPhoneContacts.slice(0, 3).map(c => c.Name || 'Contact').join(', ')}${noPhoneContacts.length > 3 ? '...' : ''})`;
                    this.showToast(
                        'Missing Phone Number',
                        `You have selected ${namesStr} with no phone number, disabling the "Send Message" button. Please unselect these contacts to enable the Send Message button.`,
                        'warning'
                    );
                }
            }
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
        this.allSelectedContacts = [...this.selectedContactList];
        this.filteredSelectedContacts = [...this.selectedContactList];
        this.totalSelected = this.selectedContactList.length;
        this.isContactSelected = this.selectedContactList.length <= 0;
    }

    @track selectedContactSortField = 'Name';
    @track selectedContactSortOrder = 'asc';

    /**
    * Method Name : sortSelectedContact
    * @description : this methods apply the sorting on the selected contacts fields
    */
    sortSelectedContact(event) {
        try {
            const fieldName = event.currentTarget.dataset.id;
            if (this.selectedContactSortField === fieldName) {
                this.selectedContactSortOrder = this.selectedContactSortOrder === 'asc' ? 'desc' : 'asc';
            } else {
                this.selectedContactSortField = fieldName;
                this.selectedContactSortOrder = 'asc';
            }
            this.sortSelectedContactsData();
            this.updateSelectedSortIcons();
        } catch (error) {
            console.log('Error sortSelectedContact->' + error);
        }
    }

    sortSelectedContactsData() {
        try {
            this.filteredSelectedContacts = [...this.filteredSelectedContacts].sort((a, b) => {
                let aValue = a[this.selectedContactSortField] || '';
                let bValue = b[this.selectedContactSortField] || '';

                if (typeof aValue === 'string') aValue = aValue.toLowerCase();
                if (typeof bValue === 'string') bValue = bValue.toLowerCase();

                let compare = 0;
                if (aValue > bValue) compare = 1;
                else if (aValue < bValue) compare = -1;

                return this.selectedContactSortOrder === 'asc' ? compare : -compare;
            });
        } catch (error) {
            console.log('Error sortSelectedContactsData->' + error);
        }
    }

    updateSelectedSortIcons() {
        try {
            // Remove icon rotation
            const allIcons = this.template.querySelectorAll('.popup-table .slds-icon-utility-arrowdown svg');
            allIcons.forEach(icon => {
                icon.classList.remove('rotate-asc', 'rotate-desc');
            });

            // Remove active class from all headers
            const allHeaders = this.template.querySelectorAll('.popup-table .sorting_header');
            allHeaders.forEach(header => {
                header.classList.remove('active-sort');
            });

            // Set active header
            const currentHeader = this.template.querySelector('.popup-table [data-id="' + this.selectedContactSortField + '"]');
            if (currentHeader) {
                currentHeader.classList.add('active-sort');

                const icon = currentHeader.querySelector('svg');
                if (icon) {
                    icon.classList.add(this.selectedContactSortOrder === 'asc' ? 'rotate-asc' : 'rotate-desc');
                }
            }
        } catch (error) {
            console.log('Error in updateSelectedSortIcons --> ' + error);
        }
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
    * Method Name : handleAdd
    * @description : this method open the modal
    * Date: 20/07/2024
    * Created By:Vyom Soni
    */
    handleAdd() {
        if (this.isSendEmailDisabled) {
            const names = this.selectedContactsWithoutEmail.map(c => c.Name || 'Contact').join(', ');
            this.showToast('Warning', `Cannot send emails: The following selected contact(s) do not have an email address: ${names}. Please unselect them to proceed.`, 'warning');
            return;
        }
        this.isModalOpen = true;
    }

    /**
    * Method Name : handleModalClose
    * @description : this method close the modal
    * Date: 20/07/2024
    * Created By:Vyom Soni
    */
    handleModalClose() {
        this.isModalOpen = false;
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
    * Method Name : handleSendMethodChange
    * @description : method to handle sender mode
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    handleSendMethodChange(event) {
        this.sendMethod = event.detail.value;
    }

    /**
    * Method Name : loadQuickTemplates
    * @description : method to load contacts
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    loadQuickTemplates() {
        getQuickTemplates()
            .then(result => {
                this.getQuickTemplates = [
                    { label: 'None', value: '', body: '' },
                    ...result.marketingTemplates.map(option => {
                        return { label: option.templateName, value: option.templateId, body: option.body };
                    })
                ];
            })
            .catch(error => {
                console.error('Error loading Gmail template options stack', error.stack);
            });
    }

    /**
    * Method Name : handleGmailTemplateChange
    * @description : method to handle template change
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    handleGmailTemplateChange(event) {
        try {
            this.selectedTemplate = event.detail.value;
            const selectedOption = this.getQuickTemplates.find(option => option.value === this.selectedTemplate);
            if (selectedOption.label == 'None') {
                this.isTemplateBody = false;
            }
            else {
                this.isTemplateBody = true;
                this.templateBody = selectedOption ? selectedOption.body : '';
            }
        } catch (error) {
            console.log('Error handleGmailTemplateChange->' + error);
        }
    }

    /**
    * Method Name : handleFooterButtonClick
    * @description : method to check validation and call save method
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    handleFooterButtonClick() {
        try {
            if (this.isFirstScreen) {
                if (!this.sendMethod || !this.selectedTemplate) {
                    this.showToast('Error', 'Please Ensure all required fields are filled', 'error');
                    return;
                }
                this.isFirstScreen = false;
                this.footerButtonLabel = 'Save';
            } else {
                this.handleSave();
            }
        } catch (error) {
            console.log('Error handleFooterButtonClick->' + error);
        }
    }

    /**
    * Method Name : handleBack
    * @description : method to go in previous sreen
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    handleBack() {
        this.isFirstScreen = true;
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
    * Method Name : setTempValue
    * @description : method to set value for the body
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    setTempValue(value) {
        return `<div class=" note-editor2 note-frame2">
                    <div class="note-editing-area2">
                        <div aria-multiline="true" role="textbox" class="note-editable2">
                            ${value}
                        </div>
                    </div>
                </div>`
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

    updateTemplateOptions() {
        if (!this.selectedObject || !this.templateMap || this.templateMap.size === 0) {
            this.templateOptions = [];
            this.selectedTemplate = '';
            return;
        }

        let combinedTemplates = [];

        // Add object-specific templates
        if (this.templateMap.has(this.selectedObject)) {
            combinedTemplates = [...this.templateMap.get(this.selectedObject)];
        }

        // Add Generic templates
        if (this.templateMap.has('Generic')) {
            combinedTemplates = [...combinedTemplates, ...this.templateMap.get('Generic')];
        }

        // Convert to combobox options format
        this.templateOptions = combinedTemplates.map(template => ({
            label: template.MVEX__Template_Name__c,
            value: template.Id
        }));
        this.selectedTemplate = this.templateOptions.length > 0 ? this.templateOptions[0].value : '';
    }

    handleInputChange(event) {
        const { name, value } = event.target;
        switch (name) {
            case 'name':
                this.broadcastGroupName = value;
                break;
            case 'message':
                this.messageText = value;
                break;
            case 'template':
                this.selectedTemplate = value;
                this.handleRefreshClick();
                break;
            case 'scheduleDateTime':
                this.selectedDateTime = value;
                break;
            default:
                console.warn(`Unexpected input name: ${name}`);
        }
    }

    // Handle send message button click
    async handleSendMessage() {
        if (this.isSendMessageDisabled) {
            if (!this.selectedContactList || this.selectedContactList.length === 0) {
                this.showToast('Warning', 'Please select at least one contact to send messages.', 'warning');
            } else {
                const names = this.selectedContactsWithoutPhone.map(c => c.Name || 'Contact').join(', ');
                this.showToast('Warning', `Cannot send messages: The following selected contact(s) do not have a valid phone number: ${names}. Please unselect them to proceed.`, 'warning');
            }
            return;
        }

        if (!this.templateMap || this.templateMap.size === 0) {
            await this.loadAllTemplates();
        } else {
            this.updateTemplateOptions();
        }

        if (!this.templateOptions || this.templateOptions.length === 0) {
            this.showToast('Warning', 'There is no active WhatsApp template to send to contacts.', 'warning');
            return;
        }

        this.showTemplate = true;
        this.popUpLastPage = false;
        this.popUpConfirmPage = false;
        this.popupHeader = 'Choose Template';
        this.broadcastGroupName = '';
        this.messageText = '';
        this.selectedDateTime = '';
    }

    // Handle closing the template modal
    handleCloseTemplate() {
        this.showTemplate = false;
        this.popUpLastPage = false;
        this.popUpConfirmPage = false;
        this.popupHeader = 'Create Broadcast Group';
        this.broadcastGroupName = '';
        this.messageText = '';
        this.selectedTemplate = '';
        this.selectedDateTime = '';
        this.broadcastGroupId = null;
        this.filteredSelectedContacts = [...this.allSelectedContacts];

    }

    // New helper to auto-create group in background
    async createBroadcastGroupBackground() {
        const now = new Date();
        const timestamp = now.toLocaleDateString() + ' ' + now.toLocaleTimeString();
        const autoGroupName = 'Marketing List - ' + timestamp;
        const autoDesc = 'Broadcast initiated from Marketing List at ' + timestamp;

        const phoneField = this.configuredPhoneField || 'Phone';
        const phoneNumbers = this.selectedContactList
            .map(contact => this.getContactPhone(contact))
            .filter(phone => phone);

        const messageData = {
            objectApiName: this.selectedObject,
            listViewName: this.listViewId,
            phoneNumbers: phoneNumbers,
            description: autoDesc,
            name: autoGroupName,
            isUpdate: false,
            broadcastGroupId: null,
            phoneField: phoneField,
            communicationType: 'WhatsApp'
        };

        try {
            const result = await processBroadcastMessageWithObject({ requestJson: JSON.stringify(messageData) });
            this.broadcastGroupId = result;
            return true;
        } catch (error) {
            this.showToast('Error', 'Background group creation failed: ' + (error.body?.message || error.message), 'error');
            return false;
        }
    }

    // Handle next button on first page (create broadcast group)
    handleNextOnPopup() {
        if (this.messageText.trim() === '' || this.broadcastGroupName.trim() === '') {
            this.showToast('Error', 'Please fill in all required fields', 'error');
            return;
        }

        if (this.tempBroadcastGroupName == this.broadcastGroupName) {
            this.popupHeader = 'Choose Template';
            return;
        }

        const phoneField = this.configuredPhoneField || 'Phone';
        const phoneNumbers = this.selectedContactList
            .map(contact => this.getContactPhone(contact))
            .filter(phone => phone);

        const messageData = {
            objectApiName: this.selectedObject,
            listViewName: this.listViewId,
            phoneNumbers: phoneNumbers,
            description: this.messageText,
            name: this.broadcastGroupName,
            isUpdate: false,
            broadcastGroupId: null,
            phoneField: phoneField
        };

        this.spinnerShow = true;

        processBroadcastMessageWithObject({ requestJson: JSON.stringify(messageData) })
            .then(result => {
                this.broadcastGroupId = result; // Assuming Apex returns the created Broadcast Group ID
                this.showToast('Success', 'Broadcast group created successfully', 'success');
                this.popupHeader = 'Choose Template';
                this.tempBroadcastGroupName = this.broadcastGroupName;
                this.updateTemplateOptions();
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || 'Failed to create broadcast group', 'error');
                console.error('Error handleNextOnPopup->', error);
            })
            .finally(() => {
                this.spinnerShow = false;
            });
    }

    // Handle previous button on second page
    handlePreviousOnPopup() {
        this.popupHeader = 'Create Broadcast Group';
        this.selectedTemplate = '';
        this.popUpConfirmPage = false;
    }

    handleConfirmPopup() {
        this.popUpConfirmPage = true;
    }
    // Handle send button on second page
    async handleSendOnPopup() {
        if (!this.selectedTemplate) {
            this.showToast('Error', 'Please select a template', 'error');
            return;
        }

        this.spinnerShow = true;

        // Auto-create the group in background before sending
        const groupCreated = await this.createBroadcastGroupBackground();
        if (!groupCreated) {
            this.spinnerShow = false;
            return;
        }

        createChatRecods({
            templateId: this.selectedTemplate,
            groupIds: [this.broadcastGroupId],
            isScheduled: false,
            timeOfMessage: ''
        })
            .then(result => {
                if (result) {
                    this.showToast('Success', 'Broadcast sent successfully', 'success');
                    this.handleCloseTemplate();
                    this.clearSelectedContacts();
                    this.navigateToBroadcastComponent(result);
                } else {
                    this.showToast('Error', `Broadcast failed: ${result}`, 'error');
                }
            })
            .catch(error => {
                this.showToast('Error', `Broadcast failed: ${error.body?.message || error.message}`, 'error');
                console.error('Error handleSendOnPopup->', error);
            })
            .finally(() => {
                this.spinnerShow = false;
            });
    }

    navigateToBroadcastComponent(broadcastId) {
        let componentDef = {
            componentDef: "MVEX:broadcastReportComp",
            attributes: {
                recordId: broadcastId
            }
        };

        let encodedComponentDef = btoa(JSON.stringify(componentDef));

        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/one/one.app#' + encodedComponentDef
            }
        });
    }



    // Handle schedule button on second page
    handleSchedulePopup() {
        if (!this.selectedTemplate) {
            this.showToast('Error', 'Please select a template', 'error');
            return;
        }

        this.popUpLastPage = true;
    }

    // Handle previous button on last page
    handlePreviousLastPage() {
        this.popUpLastPage = false;
        this.popUpConfirmPage = false;
        this.popupHeader = 'Choose Template';
    }

    handleRefreshClick() {
        const childComponent = this.template.querySelector('c-template-preview');
        if (childComponent && this.selectedTemplate) {
            childComponent.refreshComponent(this.selectedTemplate);
        }
    }

    handleSearch(event) {
        const searchKey = event.detail.value?.toLowerCase() || '';

        if (!searchKey) {
            // If search is empty, show all selected contacts
            this.filteredSelectedContacts = [...this.allSelectedContacts];
        } else {
            // Filter from the master list of all selected contacts
            this.filteredSelectedContacts = this.allSelectedContacts.filter(contact =>
                (contact.Name && contact.Name.toLowerCase().includes(searchKey)) ||
                (contact.Phone && contact.Phone.toLowerCase().includes(searchKey))
            );
        }
    }

    handleRemoveContact(event) {
        const contactId = event.currentTarget.dataset.id;

        // Remove from master list
        this.allSelectedContacts = this.allSelectedContacts.filter(
            contact => contact.Id !== contactId
        );

        // Update display list (apply current search filter if any)
        const searchInput = this.template.querySelector('lightning-input[data-id="search-input"]');
        const currentSearchKey = searchInput?.value?.toLowerCase() || '';

        if (currentSearchKey) {
            this.filteredSelectedContacts = this.allSelectedContacts.filter(contact =>
                (contact.Name && contact.Name.toLowerCase().includes(currentSearchKey)) ||
                (contact.Phone && contact.Phone.toLowerCase().includes(currentSearchKey))
            );
        } else {
            this.filteredSelectedContacts = [...this.allSelectedContacts];
        }

        this.selectedContactList = [...this.allSelectedContacts];

        // Update the isChecked property in processedContactData
        this.processedContactData = this.processedContactData.map(contact => {
            if (contact.Id === contactId) {
                return { ...contact, isChecked: false };
            }
            return contact;
        });

        // Update the isChecked property in unchangedProcessContact
        this.unchangedProcessContact = this.unchangedProcessContact.map(contact => {
            if (contact.Id === contactId) {
                return { ...contact, isChecked: false };
            }
            return contact;
        });

        // Update the shown data (current page)
        this.updateShownData();

        // Update total selected count
        this.totalSelected = this.selectedContactList.length;
        this.isContactSelected = this.selectedContactList.length <= 0;
    }

    /**
     * Method Name : clearSelectedContacts
     * @description : Clear all selected contacts and update checkboxes
     */
    clearSelectedContacts() {
        // Clear all lists
        this.selectedContactList = [];
        this.allSelectedContacts = [];
        this.filteredSelectedContacts = [];

        // Set isChecked to false for all contacts in processedContactData
        this.processedContactData = this.processedContactData.map(contact => {
            return { ...contact, isChecked: false };
        });

        // Set isChecked to false for all contacts in unchangedProcessContact
        this.unchangedProcessContact = this.unchangedProcessContact.map(contact => {
            return { ...contact, isChecked: false };
        });

        // Update the shown data (current page)
        this.updateShownData();

        // Update total selected count
        this.totalSelected = 0;
        this.isContactSelected = true;
    }

    // Handle schedule and send button on last page
    async handleSchedule() {
        if (!this.selectedDateTime) {
            this.showToast('Error', 'Please select date and time', 'error');
            return;
        }

        const selectedTime = new Date(this.selectedDateTime);
        const now = new Date();

        if (selectedTime < now) {
            this.showToast('Error', 'Selected date and time cannot be in the past', 'error');
            return;
        }

        this.spinnerShow = true;

        // Auto-create the group in background before scheduling
        const groupCreated = await this.createBroadcastGroupBackground();
        if (!groupCreated) {
            this.spinnerShow = false;
            return;
        }

        createChatRecods({
            templateId: this.selectedTemplate,
            groupIds: [this.broadcastGroupId],
            isScheduled: true,
            timeOfMessage: this.selectedDateTime
        })
            .then(result => {
                if (result) {
                    this.showToast('Success', 'Broadcast scheduled successfully', 'success');
                    this.handleCloseTemplate();
                    this.clearSelectedContacts();
                } else {
                    this.showToast('Error', `Scheduling failed: ${result}`, 'error');
                }
            })
            .catch(error => {
                this.showToast('Error', `Scheduling failed: ${error.body?.message || error.message}`, 'error');
                console.error('Error handleSchedule->', error);
            })
            .finally(() => {
                this.spinnerShow = false;
            });
    }

}