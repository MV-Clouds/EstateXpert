import { LightningElement, api, track } from 'lwc';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import EvoCalendarZip from '@salesforce/resourceUrl/evoCalender';
import getPropertyData from '@salesforce/apex/SiteAndBookingController.getPropertyData';
import sendEmailsAndCreateShowings from '@salesforce/apex/SiteAndBookingController.sendEmailsAndCreateShowings';
import createShowings from '@salesforce/apex/SiteAndBookingController.createShowings';
import sendWhatsappMessage from '@salesforce/apex/SiteAndBookingController.sendWhatsappMessage';
import getShowingsFromToday from '@salesforce/apex/SiteAndBookingController.getShowingsFromToday';
import markShowingAsCompleted from '@salesforce/apex/SiteAndBookingController.markShowingAsCompleted';
import updateShowingStatus from '@salesforce/apex/SiteAndBookingController.updateShowingStatus';
import updateShowing from '@salesforce/apex/SiteAndBookingController.updateShowing';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTemplatesByObject from '@salesforce/apex/BroadcastMessageController.getTemplatesByObject';
import getTemplateData from '@salesforce/apex/ChatWindowController.getTemplateData';
import createChat from '@salesforce/apex/ChatWindowController.createChat';
import previewEmailTemplate from '@salesforce/apex/SiteAndBookingController.previewEmailTemplate';
import hasBusinessAccountId from '@salesforce/apex/PropertySearchController.hasBusinessAccountId';

// Define paths
const JQUERY_PATH = `${EvoCalendarZip}/evo-jquery.js`;
const EVO_CALENDAR_JS_PATH = `${EvoCalendarZip}/evo-calendar.js`;
const EVO_CALENDAR_CSS_PATH = `${EvoCalendarZip}/evo-calendar.css`;
const EVO_CALENDAR_NAVY_CSS_PATH = `${EvoCalendarZip}/evo-calendar.royal-navy.css`;

export default class SiteAndBookingManagement extends NavigationMixin(LightningElement) {
    @api recordId;
    @track listing = {};
    @track images = [];
    @track contacts = [];
    @track currentImageIndex = 0;
    @track mapMarkers = [];
    @track error;
    @track isLoading = true;

    // --- MODAL STATE ---
    @track showScheduleModal = false; // For top-left button
    @track showManageModal = false;   // For row-level "Manage" button

    // --- MANAGE MODAL STATE ---
    @track currentContact = {};
    @track currentShowingId = null;
    @track currentContactId = null;
    @track mobileNumber = null;
    
    @track selectedAction = 'Schedule'; // New state driver
    @track selectedDate = '';
    @track selectedTime = '';
    @track selectedDateTime = '';
    @track selectedCommunicationMethod = 'Email';
    @track selectedTemplate = '';
    @track hasBusinessAccountConfigured = false;

    @track templateOptions = [];
    @track templateMap = new Map();
    @track selectedObject = 'MVEX__Showing__c';

    // Preview State
    @track previewEmailHtml = '';
    @track previewEmailSubject = '';

    // Calendar State
    @track calendarEvents = [];
    scheduleCalendarInitialized = false;
    manageCalendarInitialized = false;
    scriptsLoaded = false;

    // Template/Send State
    @track templateData;
    @track isTextHeader;
    @track isImageHeader;
    @track isVideoHeader;
    @track isDocHeader;
    @track headerBody;
    @track templateBody;
    @track footerBody;
    @track buttonList = [];
    @track headerParams = [];
    @track bodyParams = [];

    // --- GETTERS ---

    get communicationMethodOptions() {
        const options = [];
        if (this.hasBusinessAccountConfigured) {
            options.push({ label: 'WhatsApp', value: 'WhatsApp' });
        }
        options.push({ label: 'Email', value: 'Email' });
        return options;
    }

    get isContactDataAvailable() {
        return this.contacts && this.contacts.length > 0;
    }

    get isWhatsAppSelected() {
        return this.selectedCommunicationMethod === 'WhatsApp';
    }

    // Options for the new action-driving combobox
    get actionOptions() {
        const status = this.currentContact.ShowingStatus || 'Not Scheduled';
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
        if(options.length === 0 && status === 'Completed') {
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
        this.checkBusinessAccountConfig();
        loadScript(this, JQUERY_PATH)
            .then(() => {
                if (!window.jQuery) { throw new Error('jQuery failed to load'); }
                return loadScript(this, EVO_CALENDAR_JS_PATH);
            })
            .then(() => {
                if (!window.jQuery.fn.evoCalendar) { throw new Error('EvoCalendar plugin failed to load'); }
                return Promise.all([
                    loadStyle(this, MulishFontCss),
                    loadStyle(this, EVO_CALENDAR_CSS_PATH),
                    loadStyle(this, EVO_CALENDAR_NAVY_CSS_PATH)
                ]);
            })
            .then(() => {
                this.scriptsLoaded = true;
                this.loadAllTemplates();
                this.loadPropertyData();
                this.loadAllShowings(); // Load events for *both* calendars
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load resources: ' + error.message, 'error');
                console.error('Error loading resources:', error);
                this.isLoading = false;
            });
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
            // Update default communication method based on configuration
            if (!result) {
                this.selectedCommunicationMethod = 'Email';
            } else {
                this.selectedCommunicationMethod = 'WhatsApp';
            }
        } catch (error) {
            console.error('Error checking business account configuration:', error);
            this.hasBusinessAccountConfigured = false;
            this.selectedCommunicationMethod = 'Email';
        }
    }

    renderedCallback() {
        if (this.scriptsLoaded) {
            // Initialize "View Schedule" modal calendar
            if (this.showScheduleModal && !this.scheduleCalendarInitialized) {
                this.initializeScheduleCalendar();
            }
            // Initialize "Manage Showing" modal calendar
            // if (this.showManageModal && !this.manageCalendarInitialized && this.showDateTimeInputs) {
            //     this.initializeManageCalendar();
            // }
        }

        // Render Email Preview Safely
        if (this.previewEmailHtml && !this.isWhatsAppSelected && this.showManageModal) {
            const container = this.template.querySelector('.email-preview');
            if (container && container.innerHTML !== this.previewEmailHtml) {
                container.innerHTML = this.previewEmailHtml;
            }
        }
    }
    
    // --- DATA LOADING ---

    loadPropertyData() {
        getPropertyData({ listingId: this.recordId })
            .then(data => {
                this.listing = data.listing?.length > 0 ? data.listing[0] : {};
                this.images = data.images.map(file => file.MVEX__BaseUrl__c);
                this.contacts = data.contacts.map(contact => {
                    const scheduleDate = contact.ScheduleDate ? new Date(contact.ScheduleDate) : (contact.RescheduleDate ? new Date(contact.RescheduleDate) : null);
                    
                    // Create a copy for JSON.stringify to avoid circular refs
                    const contactData = { ...contact }; 
                    
                    return {
                        ...contact,
                        Json: JSON.stringify(contactData), // Stringify the contact data for the button
                        FormattedScheduleDate: scheduleDate ? scheduleDate.toLocaleString('en-US', {
                            year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'
                        }) : '',
                        isShowingDisabled: !contact.ShowingId
                    };
                });
                this.mapMarkers = [{
                    location: {
                        Street: this.listing?.MVEX__Listing_Address__c?.street || '',
                        City: this.listing?.MVEX__Listing_Address__c?.city || '',
                        StateCode: this.listing?.MVEX__Listing_Address__c?.countryCode || '',
                        Country: this.listing?.MVEX__Listing_Address__c?.country || ''
                    },
                    title: this.listing?.MVEX__Address__c || ''
                }];
                this.error = undefined;
                this.startCarousel();
            })
            .catch(error => {
                this.error = error.body?.message || 'Unknown error';
                this.listing = {}; this.images = []; this.contacts = []; this.mapMarkers = [];
                this.showToast('Error', 'Failed to load property data: ' + error.body?.message, 'error');
            })
            .finally(() => {
                this.isLoading = false; 
            });
    }

    loadAllTemplates() {
        getTemplatesByObject()
            .then(result => {
                this.templateMap = new Map(Object.entries(result));
                this.updateTemplateOptions();
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load templates: ' + error.body?.message, 'error');
                console.error('Error loadAllTemplates:', error);
            });
    }

    loadAllShowings() {
        this.isLoading = true;
        getShowingsFromToday()
            .then(result => {
                this.calendarEvents = result.map(showing => ({
                    id: showing.Id,
                    name: showing.ContactName,
                    date: new Date(showing.MVEX__Scheduled_Date__c || showing.MVEX__Reschedule_Date__c).toLocaleDateString('en-US', { year: 'numeric', month: '2-digit', day: '2-digit' }),
                    description:
                        `<div data-id="${showing.Id}" class="showing-link" ><div class="event-desc-line">Time: ${new Date(showing.MVEX__Scheduled_Date__c || showing.MVEX__Reschedule_Date__c).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })}</div>
                            <div class="event-desc-line">Status: ${showing.MVEX__Status__c}</div>
                            <div class="event-desc-line">Listing: ${showing.ListingName}</div>
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
        this.showScheduleModal = true;
    }

    closeScheduleModal() {
        this.showScheduleModal = false;
        if (this.scheduleCalendarInitialized) {
            const calendarEl = this.template.querySelector('.evo-calendar.schedule-calendar');
            if (calendarEl && window.jQuery.fn.evoCalendar) {
                try { window.jQuery(calendarEl).evoCalendar('destroy'); } catch(e) { console.warn(e); }
            }
            this.scheduleCalendarInitialized = false;
        }
    }

    // --- MODAL 2: "Manage Showing" Handlers ---

    openManageModal(event) {
        try {
            this.currentContact = JSON.parse(event.target.dataset.contact);
            this.currentShowingId = this.currentContact.ShowingId;
            this.currentContactId = this.currentContact.Id;
            this.mobileNumber = this.currentContact.MobilePhone;
            
            // Set initial action
            const status = this.currentContact.ShowingStatus || 'Not Scheduled';
            if (status === 'Not Scheduled' || status === 'Cancelled') {
                this.selectedAction = 'Schedule';
            } else if (status === 'Waiting For Confirmation') {
                this.selectedAction = 'Confirm';
            } else if (status === 'Scheduled' || status === 'Rescheduled') {
                this.selectedAction = 'Reschedule';
            } else {
                this.selectedAction = status;
            }

            // Set initial date/time
            const scheduleDate = this.currentContact.ScheduleDate ? new Date(this.currentContact.ScheduleDate) : (this.currentContact.RescheduleDate ? new Date(this.currentContact.RescheduleDate) : new Date());
            this.selectedDate = scheduleDate.toISOString().slice(0, 10);
            this.selectedTime = scheduleDate.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' }); // HH:mm

            // Set communication method based on configuration and existing data
            const savedMethod = this.currentContact.CommunicationMethod;
            if (savedMethod === 'WhatsApp' && this.hasBusinessAccountConfigured) {
                this.selectedCommunicationMethod = 'WhatsApp';
            } else if (savedMethod === 'Email') {
                this.selectedCommunicationMethod = 'Email';
            } else {
                // Default based on configuration
                this.selectedCommunicationMethod = this.hasBusinessAccountConfigured ? 'WhatsApp' : 'Email';
            }
            
            this.selectedTemplate = '';
            this.previewEmailHtml = '';
            this.previewEmailSubject = '';

            if (this.selectedCommunicationMethod === 'Email') {
                this.loadEmailPreview();
            }

            this.showManageModal = true;
        } catch (e) {
            console.error('Error opening manage modal:', e, event.target.dataset.contact);
            this.showToast('Error', 'Could not open modal. ' + e.message, 'error');
        }
    }

    closeManageModal() {
        this.showManageModal = false;
        if (this.manageCalendarInitialized) {
            const calendarEl = this.template.querySelector('.evo-calendar.manage-calendar');
            if (calendarEl && window.jQuery.fn.evoCalendar) {
                try { window.jQuery(calendarEl).evoCalendar('destroy'); } catch(e) { console.warn(e); }
            }
            this.manageCalendarInitialized = false;
        }
        // Reset all state
        this.currentContact = {};
        this.currentShowingId = null;
        this.currentContactId = null;
        this.mobileNumber = null;
        this.selectedAction = 'Schedule';
        this.selectedDate = '';
        this.selectedTime = '';
        this.selectedDateTime = '';
        this.selectedTemplate = '';
        this.previewEmailHtml = '';
    }

    // --- FORM HANDLERS (Inside Manage Modal) ---

    handleActionChange(event) {
        this.selectedAction = event.target.value;
        this.selectedTemplate = '';
        this.previewEmailHtml = '';

        // Reset calendar initialization state if date/time inputs are shown/hidden
        if (this.manageCalendarInitialized && !this.showDateTimeInputs) {
            const calendarEl = this.template.querySelector('.evo-calendar.manage-calendar');
             if (calendarEl && window.jQuery.fn.evoCalendar) {
                try { window.jQuery(calendarEl).evoCalendar('destroy'); } catch(e) { console.warn(e); }
            }
            this.manageCalendarInitialized = false;
        }
        
        if (this.selectedCommunicationMethod === 'Email' && this.showCommunicationInputs) {
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

    handleCommunicationMethodChange(event) {
        this.selectedCommunicationMethod = event.target.value;
        this.selectedTemplate = '';
        this.previewEmailHtml = '';
        this.previewEmailSubject = '';
        if (this.selectedCommunicationMethod === 'Email' && this.showCommunicationInputs) {
            this.loadEmailPreview();
        }
    }

    handleTemplateChange(event) {
        this.selectedTemplate = event.target.value;
        this.handleRefreshClick(); 
    }

    handleRefreshClick() {
        const childComponent = this.template.querySelector('c-template-preview');
        if (childComponent && this.selectedTemplate) {
            childComponent.refreshComponent(this.selectedTemplate);
        }
    }

    handleRefreshData() {
        this.isLoading = true;
        this.loadPropertyData();
        this.loadAllShowings();
        this.showToast('Success', 'Successfully refreshed Showing records!', 'success');
    }

    // --- SAVE & EXECUTION LOGIC ---

    validateInputs() {
        if (this.showDateTimeInputs) {
            if (!this.selectedDate || !this.selectedTime) {
                this.showToast('Error', 'Please select a date and time.', 'error');
                return false;
            }
            
            const [hours, minutes] = this.selectedTime.split(':');
            const newDateTime = new Date(this.selectedDate);
            newDateTime.setHours(parseInt(hours, 10), parseInt(minutes, 10), 0, 0);
            this.selectedDateTime = newDateTime.toISOString();

            if (newDateTime < new Date()) {
                this.showToast('Error', 'Schedule date and time cannot be in the past.', 'error');
                return false;
            }
        }
        if (this.showCommunicationInputs && this.isWhatsAppSelected && !this.selectedTemplate) {
            this.showToast('Error', 'Please select a WhatsApp template.', 'error');
            return false;
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
        console.log('selected date time: ', this.selectedDateTime);
        if (this.isWhatsAppSelected) {
            createShowings({ contactIds: [this.currentContactId], listingId: this.recordId, scheduleDateTime: this.selectedDateTime, communicationMethod: this.selectedCommunicationMethod })
                .then((result) => {
                    this.currentShowingId = result?.showingIds[0];
                    this.fetchTemplateData(this.selectedTemplate, () => this.handleSend('Waiting For Confirmation'));
                })
                .catch(error => this.handleApexError(error, 'Error creating showing.'));
        } else {
            sendEmailsAndCreateShowings({ contactIds: [this.currentContactId], listingId: this.recordId, scheduleDateTime: this.selectedDateTime, communicationMethod: this.selectedCommunicationMethod, isReschedule: false })
                .then(() => this.handleApexSuccess('Email sent and showing scheduled successfully.'))
                .catch(error => this.handleApexError(error, 'Error sending email and creating showing.'));
        }
    }

    executeReschedule() {
        updateShowing({ rescheduleDateTime: this.selectedDateTime, showingId: this.currentShowingId, communicationMethod: this.selectedCommunicationMethod })
            .then(result => {
                if (result) {
                    if (this.isWhatsAppSelected) {
                        this.fetchTemplateData(this.selectedTemplate, () => this.handleSend('Rescheduled'));
                    } else {
                        sendEmailsAndCreateShowings({ contactIds: [this.currentContactId], listingId: this.recordId, scheduleDateTime: this.selectedDateTime,isReschedule: true })
                            .then(() => this.handleApexSuccess('Email sent and showing rescheduled successfully.'))
                            .catch(error => this.handleApexError(error, 'Error sending reschedule email.'));
                    }
                } else {
                    throw new Error('Failed to update showing.');
                }
            })
            .catch(error => this.handleApexError(error, 'Error updating showing.'));
    }

    executeConfirm() {
        updateShowingStatus({ showingId: this.currentShowingId, status: 'Scheduled' })
            .then(result => {
                if(result) {
                    if (this.isWhatsAppSelected) {
                        this.fetchTemplateData(this.selectedTemplate, () => this.handleSend('Scheduled'));
                    } else {
                        sendEmailsAndCreateShowings({ contactIds: [this.currentContactId], listingId: this.recordId, scheduleDateTime: null,isReschedule: false })
                            .then(() => this.handleApexSuccess('Confirmation email sent successfully.'))
                            .catch(error => this.handleApexError(error, 'Error sending confirmation email.'));
                    }
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
        this.loadPropertyData(); // Refresh table
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

        console.log('loadEmailPreview', this.currentShowingId, this.currentContactId, this.recordId, this.selectedDate, this.selectedTime);
        
        previewEmailTemplate({
            showingId: this.currentShowingId || null,
            isReschedule: isReschedule,
            contactId: this.currentContactId || null,
            listingId: this.recordId || null,
            dateStr: this.selectedDate,
            timeStr: this.selectedTime,
        })
        .then(result => {
            this.previewEmailHtml = result.htmlBody || '<p>No content.</p>';
            this.previewEmailSubject = result.subject || 'No Subject';
        })
        .catch(err => {
            let errorMsg = 'Email preview failed: ' + (err.body?.message || err.message);
            if(err.body?.message?.includes('EMAIL_ADDRESS_BOUNCED')){
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
            attributes: { recordId: showingId, objectApiName: 'MVEX__Showing__c', actionName: 'view' }
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
        const contactId = event.target.dataset.id;
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

    updateTemplateOptions() {
        if (!this.selectedObject || this.templateMap.size === 0) {
            this.templateOptions = [];
            return;
        }
        let combinedTemplates = [];
        if (this.templateMap.has(this.selectedObject)) {
            combinedTemplates = [...this.templateMap.get(this.selectedObject)];
        }
        if (this.templateMap.has('Generic')) {
            combinedTemplates = [...combinedTemplates, ...this.templateMap.get('Generic')];
        }
        this.templateOptions = combinedTemplates.map(template => ({
            label: template.MVEX__Template_Name__c,
            value: template.Id
        }));
    }

    // --- WHATSAPP SEND LOGIC (Unchanged) ---

    fetchTemplateData(templateId, callback) {
        if (!templateId) {
            this.showToast('Error', 'No template ID provided.', 'error');
            this.isLoading = false;
            return;
        }
        this.isLoading = true;
        getTemplateData({ templateId: templateId, contactId: this.currentShowingId, objectApiName: this.selectedObject })
            .then((templateData) => {
                if (!templateData) {
                    this.isLoading = false;
                    this.showToast('Error', 'Selected template not found.', 'error');
                    return;
                }

                this.templateData = templateData.template;
                this.isTextHeader = this.templateData?.MVEX__Header_Type__c === 'Text';
                this.isImageHeader = this.templateData?.MVEX__Header_Type__c === 'Image';
                this.isVideoHeader = this.templateData?.MVEX__Header_Type__c === 'Video';
                this.isDocHeader = this.templateData?.MVEX__Header_Type__c === 'Document';
                const parser = new DOMParser();
                const doc = parser.parseFromString(this.templateData?.MVEX__WBHeader_Body__c || '', 'text/html');
                this.headerBody = doc.documentElement.textContent || '';
                this.templateBody = this.templateData?.MVEX__WBTemplate_Body__c;
                if (this.templateData?.MVEX__Template_Category__c === 'Authentication') {
                    this.templateBody = '{{code}} ' + this.templateBody;
                }
                this.footerBody = this.templateData?.MVEX__WBFooter_Body__c || '';
                if (this.isImageHeader || this.isVideoHeader || this.isDocHeader) {
                    const parser1 = new DOMParser();
                    const doc1 = parser1.parseFromString(this.headerBody, 'text/html');
                    this.headerBody = doc1.documentElement.textContent || '';
                }
                const buttonBody = this.templateData.MVEX__WBButton_Body__c ? JSON.parse(this.templateData.MVEX__WBButton_Body__c) : [];
                this.buttonList = buttonBody.map((buttonLabel, index) => ({
                    id: index,
                    btntext: buttonLabel.text.trim(),
                    btnType: buttonLabel.type,
                    iconName: this.getIconName(buttonLabel.type)
                }));

                this.headerParams = templateData.headerParams || [];
                this.bodyParams = templateData.bodyParams || [];
                this.isLoading = false;
                if (callback) callback();
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', 'Failed to fetch template data: ' + error.body?.message, 'error');
                console.error('Error fetchTemplateData:', error);
            });
    }

    getIconName(btntype) {
        switch (btntype) {
            case 'QUICK_REPLY': return 'utility:reply';
            case 'PHONE_NUMBER': return 'utility:call';
            case 'URL': return 'utility:new_window';
            case 'COPY_CODE': return 'utility:copy';
            case 'Flow': return 'utility:file';
            default: return 'utility:question';
        }
    }

    handleSend(status) {
        this.isLoading = true;
        try {
            createChat({
                chatData: {
                    message: '',
                    templateId: this.selectedTemplate,
                    messageType: 'template',
                    recordId: this.currentShowingId,
                    replyToChatId: null,
                    phoneNumber: this.mobileNumber
                }
            })
            .then(chat => {
                if (chat) {
                    const buttonValue = this.templateData.MVEX__WBButton_Body__c ? JSON.parse(this.templateData.MVEX__WBButton_Body__c) : '';
                    const templatePayload = this.createJSONBody(this.mobileNumber, 'template', {
                        templateName: this.templateData?.MVEX__Template_Name__c,
                        languageCode: this.templateData?.MVEX__Language__c,
                        headerImageURL: this.templateData?.MVEX__WBHeader_Body__c,
                        headerType: this.templateData?.MVEX__Header_Type__c,
                        headerParameters: this.headerParams,
                        bodyParameters: this.bodyParams || '',
                        buttonLabel: this.templateData?.MVEX__Button_Label__c || '',
                        buttonType: this.templateData?.MVEX__Button_Type__c || '',
                        buttonValue: buttonValue
                    });
                    sendWhatsappMessage({
                        jsonData: templatePayload,
                        chatId: chat.Id,
                        showingId: this.currentShowingId,
                        status: status
                    })
                    .then(result => {
                        this.dispatchEvent(new CustomEvent('message', { detail: result }));
                        this.handleApexSuccess('WhatsApp message sent successfully.');
                    })
                    .catch(error => this.handleApexError(error, 'Error sending WhatsApp message.'));
                } else {
                    this.isLoading = false;
                    this.showToast('Error', 'Error creating chat record.', 'error');
                }
            })
            .catch(error => this.handleApexError(error, 'Error creating chat.'));
        } catch (error) {
            this.handleApexError(error, 'Unexpected error while sending message.');
        }
    }

    createJSONBody(to, type, data) {
        try {
            const randomCode = Math.floor(Math.random() * 900000) + 100000;
            const randomCodeStr = String(randomCode);
            let payload = {
                messaging_product: "whatsapp",
                to: to,
                type: type,
                template: { name: data.templateName, language: { code: data.languageCode } }
            };
            let components = [];
            if (data.headerParameters && data.headerParameters.length > 0) {
                let headerParams = data.headerParameters.map((param) => ({ type: "text", text: param }));
                components.push({ type: "header", parameters: headerParams });
            }
            if (data.headerType === 'Image' && data.headerImageURL) {
                components.push({ type: "header", parameters: [{ type: "image", image: { link: data.headerImageURL } }] });
            } else if (data.headerType === 'Document' && data.headerImageURL) {
                components.push({ type: "header", parameters: [{ type: "document", document: { link: data.headerImageURL } }] });
            } else if (data.headerType === 'Video' && data.headerImageURL) {
                components.push({ type: "header", parameters: [{ type: "video", video: { link: data.headerImageURL } }] });
            }
            if (data.bodyParameters && data.bodyParameters.length > 0) {
                let bodyParams = data.bodyParameters.map((param) => ({ type: "text", text: param }));
                components.push({ type: "body", parameters: bodyParams });
            } else if(this.templateData.MVEX__Template_Category__c == 'Authentication'){
                components.push({ type: "body", parameters: [{ type: "text", text: randomCodeStr }] });
            }
            if (data.buttonValue && data.buttonValue.length > 0) {
                data.buttonValue.map((button, index) => {
                    switch (button.type.toUpperCase()) {
                        case "PHONE_NUMBER":
                            components.push({ type: "button", sub_type: "voice_call", index: index, parameters: [{ type: "text", text: button.phone_number }] });
                            break;
                        case "URL": break;
                        case "QUICK_REPLY": break;
                        case "FLOW":
                            components.push({ type: "button", sub_type: "flow", index: index, parameters: [{ type: "payload", payload: "PAYLOAD" }] });
                            break;
                        case 'COPY_CODE':
                        case "COUPON_CODE":
                            components.push({ type: "button", sub_type: "copy_code", index: index, parameters: [{ type :'coupon_code', coupon_code : button.example }] }); 
                            break;
                        case "OTP":
                            if (button.otp_type && button.otp_type.toUpperCase() === "COPY_CODE") {
                                components.push({ type: "button", sub_type: "url", index: index, parameters: [{ type : 'text', text : randomCodeStr }] });
                            } else { console.warn(`OTP button at index ${index} missing otp_code parameter.`); return null; }
                            break;
                        default: console.warn(`Unknown button type: ${button.type}`); return null;
                    }
                }).filter((button) => button !== null);
            }
            if (components.length > 0) {
                payload.template.components = components;
            }
            return JSON.stringify(payload);
        } catch (e) {
            console.error('Error in function createJSONBody:::', e.message);
        }
    }

    openShowingInNewTab(event) {
        const showingId = event.target.dataset.showingId;

        if (!showingId) {
            this.showToast('Info', 'No Showing record exists yet.', 'info');
            return;
        }

        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                recordId: showingId,
                objectApiName: 'MVEX__Showing__c',
                actionName: 'view'
            }
        }).then(url => {
            window.open(url, '_blank');
        });
    }
}