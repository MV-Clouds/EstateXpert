import { LightningElement, api, track } from 'lwc';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import globalStyles from '@salesforce/resourceUrl/globalStyles';
import EvoCalendarZip from '@salesforce/resourceUrl/evoCalender';
import emptyState from '@salesforce/resourceUrl/emptyState';
import getPropertyAndContactData from '@salesforce/apex/SiteAndBookingController.getPropertyAndContactData';
import sendEmailsAndCreateShowings from '@salesforce/apex/SiteAndBookingController.sendEmailsAndCreateShowings';
import getShowingsFromToday from '@salesforce/apex/SiteAndBookingController.getShowingsFromToday';
import markShowingAsCompleted from '@salesforce/apex/SiteAndBookingController.markShowingAsCompleted';
import updateShowingStatus from '@salesforce/apex/SiteAndBookingController.updateShowingStatus';
import updateShowing from '@salesforce/apex/SiteAndBookingController.updateShowing';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import previewEmailTemplate from '@salesforce/apex/SiteAndBookingController.previewEmailTemplate';
import FORM_FACTOR from '@salesforce/client/formFactor';
import TIME_ZONE from '@salesforce/i18n/timeZone';

// Define paths
const JQUERY_PATH = `${EvoCalendarZip}/evo-jquery.js`;
const EVO_CALENDAR_JS_PATH = `${EvoCalendarZip}/evo-calendar.js`;
const EVO_CALENDAR_CSS_PATH = `${EvoCalendarZip}/evo-calendar.css`;
const EVO_CALENDAR_NAVY_CSS_PATH = `${EvoCalendarZip}/evo-calendar.royal-navy.css`;

export default class SiteAndBookingManagement extends NavigationMixin(LightningElement) {
    userTimeZone = TIME_ZONE;
    @api recordId;
    @track listing = {};
    @track images = [];
    @track NoDataImageUrl = emptyState;
    @track contacts = [];
    @track shownContacts = [];
    @track currentPage = 1;
    @track pageSize = 20;
    @track visiblePages = 5;
    @track currentImageIndex = 0;
    @track mapMarkers = [];
    @track isLoading = true;

    // --- MODAL STATE ---
    @track showScheduleModal = false; // For top-left button
    @track showManageModal = false;   // For row-level "Manage" button

    // --- MANAGE MODAL STATE ---
    @track currentContact = {};
    @track currentShowingId = null;
    @track currentContactId = null;

    @track selectedAction = 'Schedule'; // New state driver
    @track selectedDate = '';
    @track selectedTime = '';
    @track selectedDateTime = '';
    @track selectedDuration = '1 Hour';
    @track selectedCommunicationMethod = 'Email';
    @track sortField = 'Name';
    @track sortOrder = 'asc';

    // Preview State
    @track previewEmailHtml = '';
    @track previewEmailSubject = '';

    // Calendar State
    @track calendarEvents = [];
    scheduleCalendarInitialized = false;
    manageCalendarInitialized = false;
    scriptsLoaded = false;

    get isMobileOrTablet() {
        return FORM_FACTOR === 'Small' || FORM_FACTOR === 'Medium';
    }

    // --- GETTERS ---

    get durationOptions() {
        return [
            { label: '15 Minutes', value: '15 Minutes' },
            { label: '30 Minutes', value: '30 Minutes' },
            { label: '45 Minutes', value: '45 Minutes' },
            { label: '1 Hour', value: '1 Hour' },
            { label: '1.5 Hours', value: '1.5 Hours' },
            { label: '2 Hours', value: '2 Hours' }
        ];
    }


    get isContactDataAvailable() {
        return this.contacts && this.contacts.length > 0;
    }

    get totalPages() {
        return Math.ceil(this.totalItems / this.pageSize);
    }

    get totalItems() {
        return this.contacts ? this.contacts.length : 0;
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === Math.ceil(this.totalItems / this.pageSize) || this.totalItems === 0;
    }

    get startIndex() {
        return this.totalItems === 0 ? 0 : (this.currentPage - 1) * this.pageSize + 1;
    }

    get endIndex() {
        return Math.min(this.currentPage * this.pageSize, this.totalItems);
    }

    get recordCountInfo() {
        if (this.totalItems === 0) {
            return 'Showing 0 records';
        }
        return `Showing ${this.startIndex} - ${this.endIndex} of ${this.totalItems}`;
    }

    get pageSizeOptions() {
        const sizes = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100];
        return sizes.map(size => ({
            label: String(size),
            value: size,
            isSelected: this.pageSize === size
        }));
    }

    get pageNumbers() {
        try {
            const totalPages = this.totalPages;
            const currentPage = this.currentPage;
            const visiblePages = this.visiblePages;

            let pages = [];

            if (totalPages <= visiblePages) {
                for (let i = 1; i <= totalPages; i++) {
                    pages.push({
                        number: i,
                        isEllipsis: false,
                        className: `exp-pagination-button ${i === currentPage ? 'active' : ''}`
                    });
                }
            } else {
                pages.push({
                    number: 1,
                    isEllipsis: false,
                    className: `exp-pagination-button ${currentPage === 1 ? 'active' : ''}`
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
                        className: `exp-pagination-button ${i === currentPage ? 'active' : ''}`
                    });
                }

                if (currentPage < totalPages - 2) {
                    pages.push({ isEllipsis: true });
                }

                pages.push({
                    number: totalPages,
                    isEllipsis: false,
                    className: `exp-pagination-button ${currentPage === totalPages ? 'active' : ''}`
                });
            }

            return pages;
        } catch (error) {
            return [];
        }
    }

    get currentContactName() {
        return (this.currentContact && this.currentContact.Name && String(this.currentContact.Name).trim())
            ? this.currentContact.Name
            : '-';
    }

    // Options for the new action-driving combobox
    get actionOptions() {
        const status = (this.currentContact.ShowingStatus && this.currentContact.ShowingStatus !== '-') ? this.currentContact.ShowingStatus : 'Not Scheduled';
        let options = [];

        if (status === 'Not Scheduled' || status === 'Cancelled') {
            options.push({ label: 'Schedule New Showing', value: 'Schedule' });
        }

        if (status === 'Waiting For Confirmation') {
            options.push({ label: 'Confirm Showing', value: 'Confirm' });
        }

        if (status === 'Scheduled' || status === 'Rescheduled' || status === 'Waiting For Confirmation') {
            options.push({ label: 'Reschedule Showing', value: 'Reschedule' });
            options.push({ label: 'Cancel Showing', value: 'Cancel' });
        }

        if (status === 'Scheduled' || status === 'Rescheduled') {
            options.push({ label: 'Mark as Completed', value: 'Complete' });
        }

        // Ensure "Confirm" is an option if a showing exists
        if (status !== 'Not Scheduled' && status !== 'Completed' && status !== 'Cancelled' && status !== 'Waiting For Confirmation') {
            if (!options.find(opt => opt.value === 'Confirm')) {
                options.push({ label: 'Confirm Showing', value: 'Confirm' });
            }
        }

        // Add default if nothing else matches
        if (options.length === 0 && status === 'Completed') {
            options.push({ label: 'Marked as Completed', value: 'Complete' });
        }

        return options;
    }

    get showDateTimeInputs() {
        return this.selectedAction === 'Schedule' || this.selectedAction === 'Reschedule';
    }

    get showCommunicationInputs() {
        return this.selectedAction === 'Schedule' || this.selectedAction === 'Reschedule' || this.selectedAction === 'Confirm';
    }

    // Helper for the "Completed/Cancelled" message
    get showCommunicationInputsAndDate() {
        return this.showDateTimeInputs || this.showCommunicationInputs;
    }

    get saveButtonLabel() {
        switch (this.selectedAction) {
            case 'Schedule': return 'Schedule & Send';
            case 'Reschedule': return 'Reschedule & Send';
            case 'Confirm': return 'Confirm & Send';
            case 'Complete': return 'Mark as Completed';
            case 'Cancel': return 'Cancel Showing';
            default: return 'Save';
        }
    }

    // --- LIFECYCLE HOOKS ---

    connectedCallback() {
        this.isLoading = true;
        loadStyle(this, globalStyles);
        loadScript(this, JQUERY_PATH)
            .then(() => {
                if (!window.jQuery) { throw new Error('jQuery failed to load'); }
                return loadScript(this, EVO_CALENDAR_JS_PATH);
            })
            .then(() => {
                if (!window.jQuery.fn.evoCalendar) { throw new Error('EvoCalendar plugin failed to load'); }
                return Promise.all([
                    loadStyle(this, EVO_CALENDAR_CSS_PATH),
                    loadStyle(this, EVO_CALENDAR_NAVY_CSS_PATH)
                ]);
            })
            .then(() => {
                this.scriptsLoaded = true;
                this.loadPropertyAndContactData();
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load resources: ' + error.message, 'error');
                console.error('Error loading resources:', error);
                this.isLoading = false;
            });
    }

    renderedCallback() {
        if (this.scriptsLoaded) {
            // Initialize "View Schedule" modal calendar
            if (this.showScheduleModal && !this.scheduleCalendarInitialized) {
                this.initializeScheduleCalendar();
            }

            // Update sort icons after DOM is rendered
            if (!this.isLoading && this.contacts.length > 0) {
                this.updateSortIcons();
            }
        }

        // Render Email Preview Safely
        if (this.previewEmailHtml && this.showManageModal) {
            const container = this.template.querySelector('.email-preview');
            if (container && container.innerHTML !== this.previewEmailHtml) {
                container.innerHTML = this.previewEmailHtml;
            }
        }
    }

    // --- DATA LOADING ---

    loadPropertyAndContactData() {
        getPropertyAndContactData({ listingId: this.recordId })
            .then(data => {
                this.listing = data.listing?.length > 0 ? data.listing[0] : {};
                this.images = data.images.map(file => file.MVEX__BaseUrl__c);
                this.contacts = data.contacts.map(contact => {
                    const scheduleDate = contact.ScheduleDate ? new Date(contact.ScheduleDate) : (contact.RescheduleDate ? new Date(contact.RescheduleDate) : null);

                    // Create a copy for JSON.stringify to avoid circular refs
                    const contactData = { ...contact };

                    const hasName = Boolean(contact.Name && String(contact.Name).trim());
                    const nameVal = hasName ? String(contact.Name).trim() : '-';
                    const emailVal = contact.Email && String(contact.Email).trim() ? String(contact.Email).trim() : '-';
                    const phoneVal = contact.MobilePhone && String(contact.MobilePhone).trim() ? String(contact.MobilePhone).trim() : '-';
                    const statusVal = contact.ShowingStatus && String(contact.ShowingStatus).trim() ? String(contact.ShowingStatus).trim() : '-';
                    const formattedDate = scheduleDate ? scheduleDate.toLocaleString('en-US', {
                        year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit', timeZone: this.userTimeZone
                    }) : '-';

                    const contactObj = {
                        ...contact,
                        Json: JSON.stringify(contactData), // Stringify the contact data for the button
                        hasName: hasName,
                        Name: nameVal,
                        displayName: nameVal,
                        Email: emailVal,
                        displayEmail: emailVal,
                        MobilePhone: phoneVal,
                        displayPhone: phoneVal,
                        ShowingStatus: statusVal,
                        displayShowingStatus: statusVal,
                        FormattedScheduleDate: formattedDate,
                        displayFormattedScheduleDate: formattedDate,
                        isShowingDisabled: !contact.ShowingId
                    };
                    return contactObj;
                });
                this.currentPage = 1;
                this.sortData();
                this.mapMarkers = [{
                    location: {
                        Street: this.listing?.MVEX__Listing_Address__c?.street || '',
                        City: this.listing?.MVEX__Listing_Address__c?.city || '',
                        StateCode: this.listing?.MVEX__Listing_Address__c?.countryCode || '',
                        Country: this.listing?.MVEX__Listing_Address__c?.country || ''
                    },
                    title: this.listing?.MVEX__Address__c || ''
                }];
                this.startCarousel();
            })
            .catch(error => {
                this.listing = {};
                this.images = [];
                this.contacts = [];
                this.shownContacts = [];
                this.mapMarkers = [];
                const errorMsg = error.body?.message || error.message || 'Unknown error';
                this.showToast('Error', 'Error loading data: ' + errorMsg, 'error');
                console.error('Error loading data:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }



    loadAllShowings() {
        this.isLoading = true;
        getShowingsFromToday()
            .then(result => {
                this.calendarEvents = result.map(showing => ({
                    id: showing.Id,
                    name: showing.ContactName || '-',
                    date: new Date(showing.MVEX__Scheduled_Date__c || showing.MVEX__Reschedule_Date__c).toLocaleDateString('en-US', { year: 'numeric', month: '2-digit', day: '2-digit', timeZone: this.userTimeZone }),
                    description:
                        `<div data-id="${showing.Id}" class="showing-link" ><div class="event-desc-line">Time: ${new Date(showing.MVEX__Scheduled_Date__c || showing.MVEX__Reschedule_Date__c).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', timeZone: this.userTimeZone })}</div>
                            <div class="event-desc-line">Status: ${showing.MVEX__Status__c || '-'}</div>
                            <div class="event-desc-line">Listing: ${showing.ListingName || '-'}</div>
                        </div>`,
                    type: 'event',
                    color: showing.MVEX__Status__c === 'Waiting For Confirmation' ? 'rgb(2 118 211);' : showing.MVEX__Status__c === 'Scheduled' ? '#4CAF50' : showing.MVEX__Status__c === 'Rescheduled' ? 'rgb(255 180 180 / 40%)' : 'rgb(2 118 211 / 40%)'
                }));
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load showings: ' + error.body?.message, 'error');
                console.error('Error loadAllShowings:', error.stack);
            })
            .finally(() => {
                this.isLoading = false; // Final loading stop
            });
    }

    /**
    * @description Sort contacts by specified field
    */
    sortData() {
        this.contacts = [...this.contacts].sort((a, b) => {
            let aValue = a[this.sortField] || '';
            let bValue = b[this.sortField] || '';

            // Handle FormattedScheduleDate as date for proper sorting
            if (this.sortField === 'FormattedScheduleDate') {
                const aDateVal = a.ScheduleDate || a.RescheduleDate || '';
                const bDateVal = b.ScheduleDate || b.RescheduleDate || '';
                if (!aDateVal && !bDateVal) return 0;
                if (!aDateVal) return 1;
                if (!bDateVal) return -1;
                const aDate = new Date(aDateVal);
                const bDate = new Date(bDateVal);
                return this.sortOrder === 'asc' ?
                    (aDate > bDate ? 1 : (aDate < bDate ? -1 : 0)) :
                    (aDate < bDate ? 1 : (aDate > bDate ? -1 : 0));
            }

            const aIsEmpty = !aValue || aValue === '-';
            const bIsEmpty = !bValue || bValue === '-';
            if (aIsEmpty && bIsEmpty) return 0;
            if (aIsEmpty) return 1;
            if (bIsEmpty) return -1;

            if (typeof aValue === 'string' && typeof bValue === 'string') {
                aValue = aValue.toLowerCase();
                bValue = bValue.toLowerCase();
            }

            let compare = 0;
            if (aValue > bValue) compare = 1;
            else if (aValue < bValue) compare = -1;

            return this.sortOrder === 'asc' ? compare : -compare;
        });
        this.updateShownData();
    }

    /**
     * @description Handle column header click for sorting
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
        } catch (error) {
            console.error('Error in sortClick:', error);
        }
    }

    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updateShownData();
            this.scrollToTop();
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updateShownData();
            this.scrollToTop();
        }
    }

    handlePageChange(event) {
        const selectedPage = parseInt(event.target.getAttribute('data-id'), 10);
        if (selectedPage !== this.currentPage) {
            this.currentPage = selectedPage;
            this.updateShownData();
            this.scrollToTop();
        }
    }

    handlePageSizeChange(event) {
        const value = parseInt(event.target.value, 10);
        if (!isNaN(value) && this.pageSize !== value) {
            this.pageSize = value;
            this.currentPage = 1;
            this.updateShownData();
            this.scrollToTop();
        }
    }

    updateShownData() {
        if (!this.contacts || this.contacts.length === 0) {
            this.shownContacts = [];
            return;
        }
        const startIndex = (this.currentPage - 1) * this.pageSize;
        const endIndex = Math.min(startIndex + this.pageSize, this.totalItems);
        this.shownContacts = this.contacts.slice(startIndex, endIndex);
    }

    scrollToTop() {
        const tableContainer = this.template.querySelector('.exp-table-content');
        if (tableContainer) {
            tableContainer.scrollTop = 0;
        }
    }

    updateSortIcons(event) {
        try {
            let svgElements = this.template.querySelectorAll('svg.exp-arrow-icon');
            let clickedSortField = event ? event.currentTarget.dataset.id : this.sortField;

            this.template.querySelectorAll('.exp-sorting-header').forEach(el => {
                el.classList.remove('active-sort');
            });

            if (event) {
                event.currentTarget.classList.add('active-sort');
            } else if (this.sortField) {
                let activeHeader = this.template.querySelector(`th[data-id="${this.sortField}"]`);
                if (activeHeader) activeHeader.classList.add('active-sort');
            }

            svgElements.forEach(svg => {
                const sortFieldParent = svg.dataset.index;
                svg.classList.remove('exp-rotate-asc', 'exp-rotate-desc');
                if (sortFieldParent === clickedSortField) {
                    if (this.sortOrder === 'asc') {
                        svg.classList.add('exp-rotate-asc');
                    } else {
                        svg.classList.add('exp-rotate-desc');
                    }
                }
            });
        } catch (error) {
            console.error('Error in updateSortIcons:', error);
        }
    }

    // --- CALENDAR INITIALIZATION ---

    initializeScheduleCalendar() {
        const calendarEl = this.template.querySelector('.evo-calendar.schedule-calendar');
        if (!calendarEl) { console.error('Schedule calendar element not found'); return; }
        if (!window.jQuery || !window.jQuery.fn.evoCalendar) { console.error('jQuery or EvoCalendar not loaded'); return; }

        try {
            window.jQuery(calendarEl).evoCalendar({
                theme: 'Royal Navy',
                calendarEvents: this.calendarEvents,
                todayHighlight: true,
                sidebarDisplayDefault: true,
                sidebarToggler: true,
                eventListToggler: true,
                eventDisplayDefault: false,
                titleFormat: 'MM yyyy',
                eventHeaderFormat: 'MM d',
            });

            // Ensure sidebar & event list are open
            window.jQuery(calendarEl).evoCalendar('toggleSidebar', true);
            window.jQuery(calendarEl).evoCalendar('toggleEventList', true);

            // Critical: Listen for date selection and force event list open
            window.jQuery(calendarEl).on('selectDate', (event, newDate, data) => {
                // Always open event list when a date is clicked
                window.jQuery(calendarEl).evoCalendar('toggleEventList', true);
                // Optional: Scroll to top of event list
                const eventList = calendarEl.querySelector('.calendar-events');
                if (eventList) {
                    eventList.scrollTop = 0;
                }
            });

            // window.jQuery(calendarEl).on('click', '.showing-link', this.handleShowingLinkClick.bind(this));
            this.scheduleCalendarInitialized = true;
        } catch (error) {
            console.error('Error initializing Schedule Calendar:', error);
            this.showToast('Error', 'Failed to initialize schedule calendar: ' + error.message, 'error');
        }
    }

    initializeManageCalendar() {
        const calendarEl = this.template.querySelector('.evo-calendar.manage-calendar');
        if (!calendarEl) { console.error('Manage calendar element not found'); return; }
        if (!window.jQuery || !window.jQuery.fn.evoCalendar) { console.error('jQuery or EvoCalendar not loaded'); return; }

        try {
            window.jQuery(calendarEl).evoCalendar({
                theme: 'Royal Navy',
                calendarEvents: this.calendarEvents,
                todayHighlight: true,
                sidebarDisplayDefault: true,
                sidebarToggler: true,
                eventListToggler: true,
                eventDisplayDefault: false,
                titleFormat: 'MM yyyy',
                eventHeaderFormat: 'MM d',
            });
            window.jQuery(calendarEl).evoCalendar('toggleSidebar', true);
            window.jQuery(calendarEl).evoCalendar('toggleEventList', true);

            // Add event listener for date selection
            window.jQuery(calendarEl).on('selectDate', (event, newDate) => {
                this.handleDateSelection(newDate);
            });
            window.jQuery(calendarEl).on('click', '.showing-link', this.handleShowingLinkClick.bind(this));

            this.manageCalendarInitialized = true;
        } catch (error) {
            console.error('Error initializing Manage Calendar:', error);
            this.showToast('Error', 'Failed to initialize manage calendar: ' + error.message, 'error');
        }
    }

    // --- MODAL 1: "View Schedule" Handlers ---

    openScheduleModal() {
        this.loadAllShowings();
        this.showScheduleModal = true;
    }

    closeScheduleModal() {
        this.showScheduleModal = false;
        if (this.scheduleCalendarInitialized) {
            const calendarEl = this.template.querySelector('.evo-calendar.schedule-calendar');
            if (calendarEl && window.jQuery.fn.evoCalendar) {
                try { window.jQuery(calendarEl).evoCalendar('destroy'); } catch (e) { console.warn(e); }
            }
            this.scheduleCalendarInitialized = false;
        }
    }

    // --- MODAL 2: "Manage Showing" Handlers ---

    openManageModal(event) {
        try {
            this.loadAllShowings();
            this.currentContact = JSON.parse(event.currentTarget.dataset.contact);
            this.currentShowingId = this.currentContact.ShowingId;
            this.currentContactId = this.currentContact.Id;

            // Set initial action
            const status = (this.currentContact.ShowingStatus && this.currentContact.ShowingStatus !== '-') ? this.currentContact.ShowingStatus : 'Not Scheduled';
            if (status === 'Not Scheduled' || status === 'Cancelled') {
                this.selectedAction = 'Schedule';
            } else if (status === 'Waiting For Confirmation') {
                this.selectedAction = 'Confirm';
            } else if (status === 'Scheduled' || status === 'Rescheduled') {
                this.selectedAction = 'Reschedule';
            } else {
                this.selectedAction = status;
            }

            // Always forward 30 minutes (half hour) from current time when opening the pop-up
            const forwardDate = new Date(Date.now() + 30 * 60 * 1000);
            const userTZ = this.userTimeZone;
            const dtFormatter = new Intl.DateTimeFormat('en-CA', {
                year: 'numeric', month: '2-digit', day: '2-digit',
                hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
                timeZone: userTZ
            });
            const parts = dtFormatter.formatToParts(forwardDate).reduce((acc, p) => { acc[p.type] = p.value; return acc; }, {});
            this.selectedDate = `${parts.year}-${parts.month}-${parts.day}`;
            this.selectedTime = `${parts.hour}:${parts.minute}`; // HH:mm in browser local time

            this.selectedCommunicationMethod = 'Email';
            this.previewEmailHtml = '';
            this.previewEmailSubject = '';

            this.loadEmailPreview();

            this.showManageModal = true;
        } catch (e) {
            console.error('Error opening manage modal:', e, event.currentTarget.dataset.contact);
            this.showToast('Error', 'Could not open modal. ' + e.message, 'error');
        }
    }

    closeManageModal() {
        this.showManageModal = false;
        if (this.manageCalendarInitialized) {
            const calendarEl = this.template.querySelector('.evo-calendar.manage-calendar');
            if (calendarEl && window.jQuery.fn.evoCalendar) {
                try { window.jQuery(calendarEl).evoCalendar('destroy'); } catch (e) { console.warn(e); }
            }
            this.manageCalendarInitialized = false;
        }
        // Reset all state
        this.currentContact = {};
        this.currentShowingId = null;
        this.currentContactId = null;
        this.selectedAction = 'Schedule';
        this.selectedDate = '';
        this.selectedTime = '';
        this.selectedDateTime = '';
        this.previewEmailHtml = '';
    }

    // --- FORM HANDLERS (Inside Manage Modal) ---

    handleActionChange(event) {
        this.selectedAction = event.target.value;
        this.previewEmailHtml = '';

        // Reset calendar initialization state if date/time inputs are shown/hidden
        if (this.manageCalendarInitialized && !this.showDateTimeInputs) {
            const calendarEl = this.template.querySelector('.evo-calendar.manage-calendar');
            if (calendarEl && window.jQuery.fn.evoCalendar) {
                try { window.jQuery(calendarEl).evoCalendar('destroy'); } catch (e) { console.warn(e); }
            }
            this.manageCalendarInitialized = false;
        }

        if (this.showCommunicationInputs) {
            this.loadEmailPreview();
        }
    }

    handleDateSelection(selectedDate) {
        // From calendar click
        const date = new Date(selectedDate);
        this.selectedDate = date.toISOString().slice(0, 10);
        const calendarEl = this.template.querySelector('.evo-calendar.manage-calendar');
        if (calendarEl) {
            window.jQuery(calendarEl).evoCalendar('toggleEventList', true);
        }
    }

    handleDateChange(event) {
        // From date input field
        this.selectedDate = event.target.value;
        this.loadEmailPreview();
    }

    handleTimeChange(event) {
        this.selectedTime = event.target.value;
        this.loadEmailPreview();
    }

    handleDurationChange(event) {
        this.selectedDuration = event.detail.value;
    }


    handleRefreshData() {
        this.isLoading = true;
        // Reset to default sort
        this.sortField = 'Name';
        this.sortOrder = 'asc';
        this.loadPropertyAndContactData();
        this.loadAllShowings();
        this.updateSortIcons();
        this.showToast('Success', 'Successfully refreshed Showing records!', 'success');
    }

    // --- SAVE & EXECUTION LOGIC ---

    /**
     * Converts a date string (YYYY-MM-DD) and time string (HH:mm) that represent
     * a local time in the user's Salesforce timezone into a UTC ISO 8601 string.
     *
     * Strategy: build an approximate UTC candidate, format it back to the user's
     * timezone with Intl to discover the real offset, then apply the correction.
     * This handles DST transitions correctly.
     */
    localDateTimeToUtcISO(dateStr, timeStr) {
        const [year, month, day] = dateStr.split('-').map(Number);
        const [hours, minutes] = timeStr.split(':').map(Number);

        // Step 1: Treat the input as UTC to get a rough epoch
        const approxUtcMs = Date.UTC(year, month - 1, day, hours, minutes, 0, 0);

        // Step 2: Find out what that epoch looks like in the user's timezone
        const fmt = new Intl.DateTimeFormat('en-CA', {
            year: 'numeric', month: '2-digit', day: '2-digit',
            hour: '2-digit', minute: '2-digit', second: '2-digit',
            hour12: false, timeZone: this.userTimeZone
        });
        const parts = fmt.formatToParts(new Date(approxUtcMs))
            .reduce((acc, p) => { acc[p.type] = p.value; return acc; }, {});

        // Step 3: Compute the offset between what we want and what Intl shows
        const displayedUtcMs = Date.UTC(
            Number(parts.year), Number(parts.month) - 1, Number(parts.day),
            Number(parts.hour), Number(parts.minute), Number(parts.second)
        );
        const offsetMs = approxUtcMs - displayedUtcMs; // e.g. +19800000 for IST (+5:30)

        // Step 4: Apply offset to get the real UTC epoch
        return new Date(approxUtcMs + offsetMs).toISOString();
    }

    validateInputs() {
        if (this.showDateTimeInputs) {
            const hasValidEmail = this.currentContact.Email && this.currentContact.Email !== '-' && String(this.currentContact.Email).trim() !== '';
            const hasValidName = this.currentContact.Name && this.currentContact.Name !== '-' && String(this.currentContact.Name).trim() !== '';
            if (!hasValidEmail || !hasValidName) {
                this.showToast('Error', 'The selected inquiry does not have a name or email address.', 'error');
                return false;
            }
            if (!this.selectedDate || !this.selectedTime) {
                this.showToast('Error', 'Please select a date and time.', 'error');
                return false;
            }

            // Build the UTC ISO string from the user's local date + time
            this.selectedDateTime = this.localDateTimeToUtcISO(this.selectedDate, this.selectedTime);

            if (new Date(this.selectedDateTime) < new Date()) {
                this.showToast('Error', 'Schedule date and time cannot be in the past.', 'error');
                return false;
            }
        } else if (this.selectedAction === 'Confirm') {
            // For Confirm action, ensure the existing scheduled date is not in the past
            const existingDateStr = this.currentContact.ScheduleDate || this.currentContact.RescheduleDate;
            if (existingDateStr && new Date(existingDateStr) < new Date()) {
                this.showToast('Error', 'Cannot send confirmation for a past date. Please reschedule instead.', 'error');
                return false;
            }
        }

        return true;
    }

    handleSave() {
        if (!this.validateInputs()) {
            return;
        }

        this.isLoading = true;
        const action = this.selectedAction;

        switch (action) {
            case 'Schedule':
                this.executeSchedule();
                break;
            case 'Reschedule':
                this.executeReschedule();
                break;
            case 'Confirm':
                this.executeConfirm();
                break;
            case 'Complete':
                this.executeComplete();
                break;
            case 'Cancel':
                this.executeCancel();
                break;
            default:
                this.isLoading = false;
                this.showToast('Error', 'Invalid action selected.', 'error');
        }
    }

    executeSchedule() {
        sendEmailsAndCreateShowings({ contactIds: [this.currentContactId], listingId: this.recordId, scheduleDateTime: this.selectedDateTime, durationValue: this.selectedDuration, communicationMethod: this.selectedCommunicationMethod, isReschedule: false })
            .then(() => this.handleApexSuccess('Email sent and showing scheduled successfully.'))
            .catch(error => this.handleApexError(error, 'Error sending email and creating showing.'));
    }

    executeReschedule() {
        updateShowing({ rescheduleDateTime: this.selectedDateTime, durationValue: this.selectedDuration, showingId: this.currentShowingId, communicationMethod: this.selectedCommunicationMethod })
            .then(result => {
                if (result) {
                    sendEmailsAndCreateShowings({ contactIds: [this.currentContactId], listingId: this.recordId, scheduleDateTime: this.selectedDateTime, durationValue: this.selectedDuration, isReschedule: true })
                        .then(() => this.handleApexSuccess('Email sent and showing rescheduled successfully.'))
                        .catch(error => this.handleApexError(error, 'Error sending reschedule email.'));
                } else {
                    throw new Error('Failed to update showing.');
                }
            })
            .catch(error => this.handleApexError(error, 'Error updating showing.'));
    }

    executeConfirm() {
        updateShowingStatus({ showingId: this.currentShowingId, status: 'Scheduled' })
            .then(result => {
                if (result) {
                    sendEmailsAndCreateShowings({ contactIds: [this.currentContactId], listingId: this.recordId, scheduleDateTime: null, isReschedule: false })
                        .then(() => this.handleApexSuccess('Confirmation email sent successfully.'))
                        .catch(error => this.handleApexError(error, 'Error sending confirmation email.'));
                } else {
                    throw new Error('Failed to update showing status.');
                }
            })
            .catch(error => this.handleApexError(error, 'Error updating showing status.'));
    }

    executeComplete() {
        markShowingAsCompleted({ showingId: this.currentShowingId })
            .then(result => {
                if (result) {
                    this.handleApexSuccess('Showing marked as Completed.');
                } else {
                    throw new Error('Failed to mark showing as Completed.');
                }
            })
            .catch(error => this.handleApexError(error, 'Error marking showing as Completed.'));
    }

    executeCancel() {
        updateShowingStatus({ showingId: this.currentShowingId, status: 'Cancelled' })
            .then(result => {
                if (result) {
                    this.handleApexSuccess('Showing has been cancelled.');
                } else {
                    throw new Error('Failed to cancel showing.');
                }
            })
            .catch(error => this.handleApexError(error, 'Error cancelling showing.'));
    }

    // --- HELPER & CALLBACK FUNCTIONS ---

    handleApexSuccess(message) {
        this.showToast('Success', message, 'success');
        this.loadPropertyAndContactData(); // Refresh table
        this.loadAllShowings();  // Refresh calendar events
        this.closeManageModal();
        this.isLoading = false;
    }

    handleApexError(error, defaultMessage) {
        this.isLoading = false;
        const message = error.body?.message || defaultMessage;
        this.showToast('Error', message, 'error');
        console.error(defaultMessage, error);
    }

    loadEmailPreview() {
        this.isLoading = true;
        this.previewEmailHtml = ''; // Clear previous
        const isReschedule = (this.selectedAction === 'Reschedule');
        const dateTimeIso = (this.selectedDate && this.selectedTime) 
            ? this.localDateTimeToUtcISO(this.selectedDate, this.selectedTime) 
            : null;

        previewEmailTemplate({
            showingId: this.currentShowingId || null,
            isReschedule: isReschedule,
            contactId: this.currentContactId || null,
            listingId: this.recordId || null,
            scheduleDateTime: dateTimeIso
        })
            .then(result => {
                this.previewEmailHtml = result.htmlBody || '<p>No content.</p>';
                this.previewEmailSubject = result.subject || 'No Subject';
            })
            .catch(err => {
                let errorMsg = 'Email preview failed: ' + (err.body?.message || err.message);
                if (err.body?.message?.includes('EMAIL_ADDRESS_BOUNCED')) {
                    errorMsg = 'Email preview failed: The inquiry email address is incorrect, and the message bounced back.';
                }
                this.previewEmailHtml = `<p style="color:red;">${errorMsg}</p>`;
                this.showToast('Error', errorMsg, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // --- OTHER HELPERS ---

    handleShowingLinkClick(event) {
        const linkElement = event.target.closest('.showing-link');
        if (!linkElement) return;
        const showingId = linkElement.dataset.id;
        if (!showingId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: showingId, objectApiName: 'Event', actionName: 'view' }
        });
    }

    startCarousel() {
        if (this.images.length > 0) {
            setInterval(() => {
                this.currentImageIndex = (this.currentImageIndex + 1) % this.images.length;
            }, 3000);
        }
    }

    get currentImage() {
        return this.images[this.currentImageIndex] || '';
    }

    get imageCounter() {
        return this.images.length > 0 ? `${this.currentImageIndex + 1} / ${this.images.length}` : '';
    }

    navigateToContact(event) {
        const contactId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: contactId, objectApiName: 'Contact', actionName: 'view' }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title: title, message: message, variant: variant })
        );
    }



    openShowingInNewTab(event) {
        const showingId = event.currentTarget.dataset.showingId;

        if (!showingId) {
            this.showToast('Info', 'No Showing record exists yet.', 'info');
            return;
        }

        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                recordId: showingId,
                objectApiName: 'Event',
                actionName: 'view'
            }
        }).then(url => {
            window.open(url, '_blank');
        });
    }
}