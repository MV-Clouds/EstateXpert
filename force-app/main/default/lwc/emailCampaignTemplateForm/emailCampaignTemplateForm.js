import { LightningElement, track, wire } from 'lwc';
import getContacts from '@salesforce/apex/EmailCampaignController.getContacts';
import getDateFieldsForPicklist from '@salesforce/apex/EmailCampaignController.getDateFieldsForPicklist';
import createCampaignAndEmails from '@salesforce/apex/EmailCampaignController.createCampaignAndEmails';
import updateCampaignAndEmails from '@salesforce/apex/EmailCampaignController.updateCampaignAndEmails';
import getCamapaignAndRelatedData from '@salesforce/apex/EmailCampaignController.getCamapaignAndRelatedData';
import { loadStyle } from 'lightning/platformResourceLoader';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import getQuickTemplates from '@salesforce/apex/EmailCampaignController.getQuickTemplates';
import checkContactDateFields from '@salesforce/apex/EmailCampaignController.checkContactDateFields';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import getCampaign from '@salesforce/apex/EmailCampaignController.getCampaign';
// New import for Broadcast Groups
import getBroadcastGroups from '@salesforce/apex/BroadcastMessageController.getBroadcastGroups';


export default class EmailCampaignTemplateForm extends NavigationMixin(LightningElement) {
    @track contacts = [];
    @track filteredPrimaryContacts = [];
    @track filteredCCContacts = [];
    @track filteredBCCContacts = [];
    @track filteredContactDateFields = [];

    @track selectedPrimaryRecipients = [];
    @track selectedCCRecipients = [];
    @track selectedBCCRecipients = [];
    @track templateId = '';
    @track newDaysAfterStartDate = 0;
    @track campaignId = '';
    @track relatedObject = '';

    @track isLoading = false;
    @track isModalOpen = false;
    @track isPrimaryDropdownVisible = false;
    @track isCCDropdownVisible = false;
    @track isBCCDropdownVisible = false;
    @track inputValueBcc = '';
    @track inputValueCC = '';
    @track inputValuePrimary = '';
    @track contactDateFieldOptions = null;
    @track isDateFieldDropdownVisible = false;
    @track isFieldSelected = false;
    @track emailCampaignTemplate = '';
    @track emailCampaignName = '';
    @track navigationStateString = null;
    @track quickTemplateOptions = null;
    @track quickTemplates = null;
    @track emailsFromTemplate = null;
    @track specificDate = '';
    @track isPreviewModal = false;

    @track templateBody = '';
    @track emails = [];
    @track emailsWithTemplate = [];
    @track deletedEmailList = [];

    @track selectedContactDateField = '';
    @track isEdit = false;

    @track today = new Date().toISOString().split('T')[0];
    @track currentDateTime = new Date();

    @track selectedobject = 'Contact';
    @track templateType = '';
    @track subscription = {};
    @track templateStatus = true;
    @track selectedTemplateId = '';
    @track isRadioGroupDisabled = false;

    // Broadcast Group Properties
    @track broadcastGroupOptions = [];
    @track selectedBroadcastGroups = [];


    @track startDateOptions = [
        { label: 'Sending emails on specific dates', value: 'specificDate' },
        { label: 'Using a contact related date field', value: 'contactDateField' },
    ];
    @track startDateOption = 'specificDate';

    get isSpecificDateOption() {
        return this.startDateOption === 'specificDate';
    }

    get isContactDateFieldOption() {
        return this.startDateOption === 'contactDateField';
    }

    get searchBoxClass() {
        return this.isFieldSelected ? 'slds-hide' : 'slds-show';
    }

    get pillDivClass() {
        return this.isFieldSelected ? 'slds-show display-pill-input-container' : 'slds-hide';
    }

    get isOpenModalDisabled(){
        return this.campaignId!='' ? false : true;
    }
    
    // Broadcast Group Getters
    get showBroadcastGroups() {
        // Show broadcast groups only when no individual primary recipients are selected
        return this.relatedObject && this.selectedPrimaryRecipients.length === 0 && this.filteredBroadcastGroups.length > 0;
    }

    get filteredBroadcastGroups() {
        if (!this.relatedObject || !this.broadcastGroupOptions) {
            return [];
        }
        
        return this.broadcastGroupOptions.filter(group => 
            group.objectName === this.relatedObject
        ).map(group => ({
            ...group,
            selected: this.selectedBroadcastGroups.includes(group.value)
        }));
    }

    get selectedBroadcastGroupsCount() {
        return this.selectedBroadcastGroups.length;
    }

    get estimatedContactsFromGroups() {
        if (!this.selectedBroadcastGroups.length) return 0;
        
        return this.filteredBroadcastGroups
            .filter(group => this.selectedBroadcastGroups.includes(group.value))
            .reduce((total, group) => total + (group.contactCount || 0), 0);
    }
    
    /*
    * Method Name: setCurrentPageReference
    * @description: Method to load the data when click on the tab or again come on the tab with redirection
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    @wire(CurrentPageReference)
    setCurrentPageReference(currentPageReference) {
        if (currentPageReference && currentPageReference.attributes.attributes) {
            console.log('currentPageReference ==> ' , currentPageReference);
            console.log('currentPageReference.attributes.attributes ==> ' , currentPageReference.attributes.attributes);
            
            
            const navigationStateString = currentPageReference.attributes.attributes.c__navigationState;
            const recId = currentPageReference.attributes.attributes.c__recordId;
            console.log('recId ==> ' , recId);

            console.log('Navigation State string ');
            console.log(navigationStateString);

            if(recId){
                this.campaignId = recId;
                getCampaign({ campaignId: this.campaignId }).then(result => {
                        if(result && result.MVEX__RelatedObject__c == 'Contact'){
                            this.relatedObject = 'Contact';
                            this.loadContacts();
                        }
                    }
                ).catch(error => {  
                    console.error('Error fetching campaign:', error);
                });
            }
            else if (navigationStateString) {
                
                this.navigationStateString = navigationStateString;

                this.emailCampaignTemplate = this.navigationStateString.selectedTemplate;
                this.emailCampaignName = this.navigationStateString.campaignName;
                this.templateId = this.navigationStateString.selectedTemplateId;
                this.relatedObject = this.navigationStateString.selectedObject;
                this.templateType = this.navigationStateString.templateType;
                
                console.log(typeof this.relatedObject);
                console.log( 'related object ' + this.relatedObject);

                this.emailsFromTemplate = this.navigationStateString.marketingEmails;
                console.log(this.emailsFromTemplate);
                const selectedContactList = this.navigationStateString.selectedContacts;

                console.log('selectedContactList ==> ' , selectedContactList);

                if(selectedContactList){
                    this.selectedPrimaryRecipients = selectedContactList.map(contact => ({
                        label: contact.Name,
                        value: contact.Id,
                        email: contact.Email
                    }));
                }
                
                // Load selected broadcast groups if available (assuming they are passed from the previous step)
                const selectedGroups = this.navigationStateString.selectedBroadcastGroups;
                if(selectedGroups){
                    this.selectedBroadcastGroups = selectedGroups;
                }



                if (this.emailsFromTemplate) {
                    console.log('this.emailsFromTemplate ==> ' , this.emailsFromTemplate);
                    this.emails = this.emailsFromTemplate.map(email => ({
                        id: email.Id, 
                        template: email.MVEX__Template_Id__c,
                        templateType: email.MVEX__Template_Type__c,
                        subject: email.MVEX__Subject__c, 
                        daysAfterStartDate: email.MVEX__Days_After_Start_Date__c, 
                        timeToSend: '',
                        exactDate : '',
                        name : email.Name,
                        disabled : false,
                        selectedListingId : email?.MVEX__Listing__c,
                        isListingSelectionDisabled : (email?.MVEX__Listing__c == null || email?.MVEX__Listing__c == '' ) ? true  : false
                    }));
                    this.emailsWithTemplate = [...this.emails];
                    console.log('this.emailsWithTemplate JSON.stringify ==> ' , JSON.stringify(this.emailsWithTemplate));
                    console.log('emails ==> ' , this.emails);
                }
                this.loadContacts();
                console.log(this.contacts);

            }

        }
    }

    /*
    * Method Name: connectedCallback
    * @description: Method to load the data initally
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    connectedCallback() {
        this.isLoading = true;
        Promise.all([
            loadStyle(this, MulishFontCss)
        ])
        .then(() => {
            this.fetchDateFields();
            this.fetchQuickTemplates();
            this.loadBroadcastGroups();
        })
        .catch(error => {
            console.error('Error loading external CSS', error);
        });
        
        this.handleSubscribe();
        this.registerErrorListener();
    }
    
    /*
    * Method Name: loadBroadcastGroups
    * @description: Method to load broadcast groups from the backend
    * Date: 19/11/2025
    * Created By: Gemini
    */
    loadBroadcastGroups(){
        getBroadcastGroups()
        .then(data => {
            if(data && data.length > 0){
                this.broadcastGroupOptions = data.map(option => ({
                    label: option.Name,
                    value: option.Id,
                    objectName: option.MVEX__Object_Name__c, 
                    contactCount: option.MVEX__Count_of_Members__c || 0,
                    selected: false // Initial state
                }));
            }
        })
        .catch(error => {
            this.showToast('Error', 'Failed to fetch broadcast groups', 'error');
            console.error('Error loading broadcast groups:', error);
        });
    }


    /*
    * Method Name: loadContacts
    * @description: Method to load the contact informations
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    loadContacts() {
         getContacts()
            .then(result => {
                // console.log('result ==> ' , JSON.stringify(result));
                this.contacts = result.map(contact => ({
                    label: contact.Name,
                    value: contact.Id,
                    email: contact.Email
                }));
                this.updateFilteredLists();
                this.loadCamapignData();

            })
            .catch(error => {
                console.error('Error fetching contacts:', error);
            });
    }
    

    /*
    * Method Name: loadCamapignData
    * @description: Method to load campaign data
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    loadCamapignData() {
        if (this.campaignId) {
            getCamapaignAndRelatedData({ campaignId: this.campaignId })
                .then(result => {

                    // Store all selected contacts, including failed ones
                    var primaryContacts1 = [];
                    var ccContacts1 = [];
                    var bccContacts1 = [];
                    var selectedGroups = [];

                    const data = JSON.parse(result);
                    if (data && data?.marketingCampaignMembers.length > 0) {
                        this.isRadioGroupDisabled = true;
                    }
                    if (data && (data?.selectedContactDateField != null || data?.selectedContactDateField != '')) {
                        this.isContactDateFieldOptionDisabled = true;
                    }
        
                    this.emailCampaignName = data.label;
                    const formData = {
                        selectedTemplate: '',
                        campaignName: '',
                        saveForFuture: false,
                        selectedTemplateId: '',
                        messagingService: '',
                        selectedObject : ''
                    };
        
                    this.templateId = data.templateId;
                    this.emailCampaignTemplate = data.templateName;
                    formData.messagingService = data.emailType;
                    formData.campaignName = data.label;
                    formData.selectedTemplate = data.templateName;
                    formData.saveForFuture = data.isMarketingCampaignTemplate;
                    formData.selectedObject = data.relatedObject;
                    this.navigationStateString = formData;
        
                    if (data.startDate != null) {
                        this.specificDate = data.startDate;
                        this.startDateOption = 'specificDate';
                    } else if (data.selectedContactDateField != null) {
                        this.isFieldSelected = true;
                        this.startDateOption = 'contactDateField';
                        this.selectedContactDateField = data.selectedContactDateField;
                    }

                    
                    console.log(data);
                    
                    // 1. Handle Broadcast Groups FIRST
                    if (data.selectedBroadcastGroups) {
                        // FIX: Use '@@@' as the delimiter, matching the Apex save format
                        selectedGroups = data.selectedBroadcastGroups.split('@@@').filter(id => id.length > 0);
                        this.selectedBroadcastGroups = selectedGroups;
                    }

                    // 2. Handle individual Primary Recipients. 
                    // We only load individual recipients if NO groups were selected.
                    if (data.marketingCampaignMembers && this.selectedBroadcastGroups.length === 0) {
                        data.marketingCampaignMembers.forEach(member => {
                            console.log('member ==> ' , member);
                            if (member.MVEX__Contact_Type__c === "Primary") {
                                primaryContacts1.push(member.MVEX__RecipientId__c);
                            }
                        });
                        console.log('primaryContacts1 ==> ' , primaryContacts1);
                        console.log('this.contacts ==> ' , this.contacts);
                        
                        // Populate individual recipients only if no groups were explicitly selected
                        this.selectedPrimaryRecipients = this.contacts.filter(contact => primaryContacts1.includes(contact.value));
                        this.filteredPrimaryContacts = this.filteredPrimaryContacts.filter(contact => !this.selectedPrimaryRecipients.some(selected => selected.value === contact.value));
                    } else if (this.selectedBroadcastGroups.length > 0) {
                        // BUG FIX: If groups were selected, ensure the individual contact list is empty
                        this.selectedPrimaryRecipients = [];
                    }
                    
                    // 3. Handle CC/BCC Recipients (which are always individuals)
                    if (data.cCContacts) {
                        data.cCContacts.split('@@@').forEach(ccContact => {
                            let [id] = ccContact.split(':');
                            ccContacts1.push(id);
                        });
                        this.selectedCCRecipients = this.contacts.filter(contact => ccContacts1.includes(contact.value));
                    }
        
                    if (data.bCCContacts) {
                        data.bCCContacts.split('@@@').forEach(bccContact => {
                            let [id] = bccContact.split(':');
                            bccContacts1.push(id);
                        });
                        this.selectedBCCRecipients = this.contacts.filter(contact => bccContacts1.includes(contact.value));
                    }
        
                    if (data.emailRecords) {
                        console.log('data.emailRecords ==> ' );
                        console.log(data.emailRecords);
                        this.emails = data.emailRecords.map(email => ({
                            id: email.Id,
                            template: email.MVEX__Template_Id__c,
                            templateType: email.MVEX__Template_Type__c,
                            subject: email.MVEX__Subject__c,
                            daysAfterStartDate: email.MVEX__Days_After_Start_Date__c,
                            timeToSend: this.parseTimeString(email.MVEX__TimeToSend__c),
                            exactDate: this?.specificDate,
                            name: email.Name,
                            disabled: this.shouldDisableEmail(data.selectedContactDateField, email?.MVEX__Send_Date_Time__c),
                            selectedListingId : email.MVEX__Listing__c,
                            isListingSelectionDisabled : (email.MVEX__Listing__c == null || email.MVEX__Listing__c == '' ) ? true  : false
                        }));
                        this.emailsWithTemplate = [...this.emails];
                    }
        
                    this.isLoading = false;
                    this.updateFilteredLists();
                    this.updateExactDates();
                })
                .catch(error => {
                    console.error('Error in loading campaign data ==> ', error);
                    this.isLoading = false;
                });
        } else {
            this.isLoading = false;
        }
    }

    /*
    * Method Name: handleBroadcastGroupChange
    * @description: Method to handle broadcast group selection
    * Date: 19/11/2025
    * Created By: Gemini
    */
    handleBroadcastGroupChange(event) {
        const groupId = event.target.dataset.value;
        const isChecked = event.target.checked;

        if (isChecked) {
            if (!this.selectedBroadcastGroups.includes(groupId)) {
                this.selectedBroadcastGroups = [...this.selectedBroadcastGroups, groupId];
            }
        } else {
            this.selectedBroadcastGroups = this.selectedBroadcastGroups.filter(id => id !== groupId);
        }
    }


    /*
    * Method Name: fetchDateFields
    * @description: Method to fetch data fields for the contact
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */

    fetchDateFields() {
        getDateFieldsForPicklist()
            .then(result => {

                console.log('result ==> ' , result);
                console.table(result);

                this.contactDateFieldOptions = result.map(option => ({
                    label: option.label,
                    value: option.value
                }));
                this.filteredContactDateFields = this.contactDateFieldOptions;
            })
            .catch(error => {
                console.error('Error fetching date fields', error);
            });
    }

    /*
    * Method Name: fetchQuickTemplates
    * @description: Method to fetch template records from the backend
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    fetchQuickTemplates() {
        getQuickTemplates()
            .then(result => {

                console.log('Template Type ==> ' , this.templateType);
                console.log('Email Campaign list ==> ' , result.emailTemplates);

                if(this.templateType === 'EmailTemplate') {
                    // Filter templates based on Email Campaign type
                    this.quickTemplates = result.emailTemplates.map(option => {
                        return { label: option.Name, value: option.Id, body: option.HtmlValue, subject: option.Subject, objectApiName : option.RelatedEntityType };
                    });
                    this.quickTemplateOptions = this.quickTemplates.map(option => {
                        return { label: option.label, value: option.value };
                    });

                    return;
                } 
                

                // Filter templates based on relatedObject (Contact)
                let filteredTemplates = [];
                if (this.relatedObject === 'Contact') {
                    filteredTemplates = result.marketingTemplates.filter(
                        option => option.objectApiName === 'Contact' || option.objectApiName === 'MVEX__Listing__c'
                    );
                } else {
                    filteredTemplates = result.marketingTemplates;
                }

                // console.log('result ==> ' , result);
                this.quickTemplates = [
                    { label: 'None', value: '', body: '' },
                    ...filteredTemplates.map(option => {
                        return { label: option.templateName, value: option.templateId, body: option.body , subject: option.subject , objectApiName :option.objectApiName };
                    })
                ];
                console.log(this.quickTemplates);
                this.quickTemplateOptions = [
                    { label: 'None', value: '', body: '' },
                    ...filteredTemplates.map(option => {
                        return { label: option.templateName, value: option.templateId };
                    })
                ];
            })
            .catch(error => {
                console.error('Error fetching templates:', error);
            });
    }

    /*
    * Method Name: shouldDisableEmail
    * @description: Method to disable email if time is less then current time
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    shouldDisableEmail(selectedContactDateField, sendDateTime) {
        if (selectedContactDateField) {
            console.log('shouldDisableEmail selectedContactDateField ==> ' , selectedContactDateField);
            return true;
        }
        console.log(selectedContactDateField);
        console.log('sendDateTime ==> ' , sendDateTime);
        const currentDateTime = new Date();
        const emailDateTime = new Date(sendDateTime);
        console.log( 'currentDateTime ==> ' , currentDateTime);
        console.log('emailDateTime ==> ' , emailDateTime);
        console.log('currentDateTime > emailDateTime ==> ' , currentDateTime > emailDateTime);
        return currentDateTime > emailDateTime;
    }
    
    /*
    * Method Name: parseTimeString
    * @description: Method to make formate for the time string
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    parseTimeString(timeString) {
        try {       
            if (!timeString) return '';
        
            const [hours, minutes, secondsAndMillis] = timeString.split(':');
            const [seconds, milliseconds] = secondsAndMillis.split('.');
        
            const formattedTime = `${hours}:${minutes}:${seconds}.${milliseconds}`;
            const timeToSend = formattedTime.replace('Z', '');
        
            return timeToSend;
        } catch (error) {
            console.log('Error parsing time string:', error);
        }

        return ''
    }
    
    /*
    * Method Name: parseDateString
    * @description: Method to make formate for the date string
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    parseDateString(dateString) {
        console.log(dateString);
        if (!dateString) return '';
        const parsedDate = new Date(dateString);
    
        if (!isNaN(parsedDate)) {
            const options = { year: 'numeric', month: '2-digit', day: '2-digit' };
            const localDate = new Intl.DateTimeFormat('default', options).format(parsedDate);
            console.log('localDate ==> ' , localDate);
            const [year, month, day] = localDate.split('/');
            console.log(`${day}-${month}-${year}`);
            return `${day}-${month}-${year}`;
        }
        
        return '';
    }
    
    /*
    * Method Name: handleSubscribe
    * @description: Method to recive message from the platform event
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleSubscribe() {
        const channel = '/event/MVEX__RefreshEvent__e';
        subscribe(channel, -1, (response) => {
            this.handleMessage();
            this.subscription = response;
        })
    }

    /*
    * Method Name: handleMessage
    * @description: Method to handle message for the make disbaled after sending mail
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleMessage() {
        console.log('event received');
        console.log('this.subscription ==> ' , this.subscription);
        const currentTime = new Date();
        this.emails = this.emails.map(email => {
            const emailDate = new Date(`${email.exactDate}T${email.timeToSend}`);
            if (emailDate < currentTime) {
                email.disabled = true;
            }
            return email;
        });
    
        this.emailsWithTemplate = this.emailsWithTemplate.map(email => {
            const emailDate = new Date(`${email.exactDate}T${email.timeToSend}`);
            if (emailDate < currentTime) {
                email.disabled = true;
            }
            return email;
        });
     
    }

    /*
    * Method Name: handleModalClose
    * @description: Method to close modal
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleModalClose(){
        this.isModalOpen = false;
    }

    /*
    * Method Name: handleSpecificDateChange
    * @description: Method to handle change for the specific date
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleSpecificDateChange(event){
        this.specificDate = event.target.value;
        this.updateExactDates();
    }

    /*
    * Method Name: handleContactDateFieldSearchChange
    * @description: Method to find searched contact from input
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleContactDateFieldSearchChange(event) {
        const searchTerm = event.target.value.toLowerCase();
        this.filteredContactDateFields = this.contactDateFieldOptions.filter(option =>
            option.label.toLowerCase().includes(searchTerm)
        );
    }

    /*
    * Method Name: handleTemplateDataChange
    * @description: Method to impletene data from custom event
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleTemplateDataChange(event){
        const eventData = event.detail;
        this.navigationStateString = eventData;
        console.log('eventData ==> ' , eventData);
        

        if(this.templateId != eventData.selectedTemplateId) {
            this.templateId = eventData.selectedTemplateId;
            this.emailCampaignTemplate = eventData.selectedTemplate;
            this.emailsFromTemplate = eventData.marketingEmails;


            if (this.emailsFromTemplate) {
                this.emails = this.emailsFromTemplate.map(email => ({
                    id: email.Id, 
                    template: email.MVEX__Template_Id__c,
                    templateType: email.MVEX__Template_Type__c,
                    subject: email.MVEX__Subject__c, 
                    daysAfterStartDate: email.MVEX__Days_After_Start_Date__c, 
                    timeToSend: '',
                    name : email.Name
                }));
                this.emailsWithTemplate = [...this.emails];
            }
        }
        
        this.emailCampaignName = eventData.campaignName;
        this.isModalOpen = false;
    }
    
    /*
    * Method Name: handleContactDateFieldSearchFocus
    * @description: Method to show dropdown blur section
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleContactDateFieldSearchFocus() {
        this.isDateFieldDropdownVisible = true;
    }
    
    handlePreventDefault(event){
        event.preventDefault();
    }

    handleBlur(){
        this.isPrimaryDropdownVisible = false;
        this.isBCCDropdownVisible = false;
        this.isCCDropdownVisible = false;
    }

    /*
    * Method Name: handlePrimarySearchInputChange
    * @description: Method to handle filter for the primary contact
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handlePrimarySearchInputChange(event) {
        this.inputValuePrimary = event.target.value;
        this.filterContacts(event, 'Primary');
    }

    /*
    * Method Name: handlePrimarySearchInputFocus
    * @description: Method to show dropdownblur section
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handlePrimarySearchInputFocus() {
        this.isPrimaryDropdownVisible = true;
    }

    /*
    * Method Name: handleSelectPrimaryContact
    * @description: Method to handle selection for the primary contact
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleSelectPrimaryContact(event) {
        this.selectContact(event, 'Primary');
        const inputs = this.template.querySelectorAll('.blur-class');
        inputs.forEach(input => input.blur());

        this.isPrimaryDropdownVisible = false;
        
        // Clear broadcast groups when individual contacts are selected
        this.selectedBroadcastGroups = [];

    }

    /*
    * Method Name: removePrimaryRecipient
    * @description: Method to remove contact from the primary contact
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    removePrimaryRecipient(event) {
        this.removeRecipient(event, 'Primary');
    }


    /*
    * Method Name: handleCCSearchInputChange
    * @description: Method to handle sarch for cc contacts
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleCCSearchInputChange(event) {
        this.inputValueCC = event.target.value;
        this.filterContacts(event, 'CC');
    }

    /*
    * Method Name: handleCCSearchInputChange
    * @description: Method to visible blur section for cc contacts
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleCCSearchInputFocus() {
        this.isCCDropdownVisible = true;
    }

    /*
    * Method Name: handleSelectCCContact
    * @description: Method to select contact from cc contacts
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleSelectCCContact(event) {
        this.selectContact(event, 'CC');

        const inputs = this.template.querySelectorAll('.blur-class');
        inputs.forEach(input => input.blur());
        this.isCCDropdownVisible = false;

    }

    /*
    * Method Name: removeCCRecipient
    * @description: Method to remove contact from cc contacts
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    removeCCRecipient(event) {
        this.removeRecipient(event, 'CC');
    }

    /*
    * Method Name: handleBCCSearchInputChange
    * @description: Method to handle search for the bcc
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleBCCSearchInputChange(event) {
        this.inputValueBcc = event.target.value;
        this.filterContacts(event, 'BCC');
    }

    /*
    * Method Name: handleBCCSearchInputFocus
    * @description: Method to show blur dropdown section for bcc contacts
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleBCCSearchInputFocus() {
        this.isBCCDropdownVisible = true;
    }

    /*
    * Method Name: handleSelectBCCContact
    * @description: Method to select contact for bcc contacts
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleSelectBCCContact(event) {
        this.selectContact(event, 'BCC');
        const inputs = this.template.querySelectorAll('.blur-class');
        inputs.forEach(input => input.blur());
        this.isBCCDropdownVisible = false;

    }

    /*
    * Method Name: removeBCCRecipient
    * @description: Method to remove contact for bcc contacts
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    removeBCCRecipient(event) {
        this.removeRecipient(event, 'BCC');
    }

    /*
    * Method Name: filterContacts
    * @description: Method to filtercontacts based on event and type
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    filterContacts(event, type) {
        const searchTerm = event.target.value.toLowerCase();
        let filteredList;
    
        if (searchTerm) {
            filteredList = this.contacts.filter(contact =>
                contact.label.toLowerCase().includes(searchTerm)
            );
        } else {
            filteredList = [...this.contacts];
        }
    
        if (type === 'Primary') {
            this.filteredPrimaryContacts = filteredList.filter(contact =>
                !(this.selectedPrimaryRecipients.some(selectedContact => selectedContact.value === contact.value) || this.selectedCCRecipients.some(selectedContact => selectedContact.value === contact.value) || this.selectedBCCRecipients.some(selectedContact => selectedContact.value === contact.value) )
            );
        }
        else if (type === 'CC') {
            this.filteredCCContacts = filteredList.filter(contact =>
                !(this.selectedPrimaryRecipients.some(selectedContact => selectedContact.value === contact.value) || this.selectedCCRecipients.some(selectedContact => selectedContact.value === contact.value) || this.selectedBCCRecipients.some(selectedContact => selectedContact.value === contact.value) )
            );
        } else if (type === 'BCC') {
            this.filteredBCCContacts = filteredList.filter(contact =>
                !(this.selectedPrimaryRecipients.some(selectedContact => selectedContact.value === contact.value) || this.selectedCCRecipients.some(selectedContact => selectedContact.value === contact.value) || this.selectedBCCRecipients.some(selectedContact => selectedContact.value === contact.value) )
            );
        }
    }


    /*
    * Method Name: selectContact
    * @description: Method to select contact in corrosponding list
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    selectContact(event, type) {
        const contactId = event.currentTarget.dataset.id;
        const selectedContact = this.contacts.find(contact => contact.value === contactId);

        if (type === 'Primary' && selectedContact && !this.selectedPrimaryRecipients.some(recipient => recipient.value === contactId)) {
            this.selectedPrimaryRecipients = [...this.selectedPrimaryRecipients, selectedContact];
            // Clear broadcast groups when individual contacts are selected
            this.selectedBroadcastGroups = [];
        } else if (type === 'CC' && selectedContact && !this.selectedCCRecipients.some(recipient => recipient.value === contactId)) {
            this.selectedCCRecipients = [...this.selectedCCRecipients, selectedContact];
        } else if (type === 'BCC' && selectedContact && !this.selectedBCCRecipients.some(recipient => recipient.value === contactId)) {
            this.selectedBCCRecipients = [...this.selectedBCCRecipients, selectedContact];
        }

        this.inputValueBcc = '';
        this.inputValueCC = '';
        this.inputValuePrimary = '';
        this.updateFilteredLists();
    }

    /*
    * Method Name: selectContact
    * @description: Method to remove contact in corrosponding list
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    removeRecipient(event, type) {
        const recipientId = event.currentTarget.dataset.id;

        if (type === 'Primary') {
            this.selectedPrimaryRecipients = this.selectedPrimaryRecipients.filter(recipient => recipient.value !== recipientId);
        }else if (type === 'CC') {
            this.selectedCCRecipients = this.selectedCCRecipients.filter(recipient => recipient.value !== recipientId);
        } else if (type === 'BCC') {
            this.selectedBCCRecipients = this.selectedBCCRecipients.filter(recipient => recipient.value !== recipientId);
        }

        this.updateFilteredLists();
    }

    /*
    * Method Name: updateFilteredLists
    * @description: Method to update the filterlist
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    updateFilteredLists() {
        const selectedPrimaryIds = new Set(this.selectedPrimaryRecipients.map(recipient => recipient.value));
        const selectedCCIds = new Set(this.selectedCCRecipients.map(recipient => recipient.value));
        const selectedBCCIds = new Set(this.selectedBCCRecipients.map(recipient => recipient.value));
        // console.log('selectedBCCIds ==> ' , selectedBCCIds);
    
        this.filteredPrimaryContacts = this.contacts.filter(contact =>
            !(selectedPrimaryIds.has(contact.value) || selectedCCIds.has(contact.value) || selectedBCCIds.has(contact.value))
        );
    
        this.filteredCCContacts = this.contacts.filter(contact =>
            !(selectedPrimaryIds.has(contact.value) || selectedCCIds.has(contact.value) || selectedBCCIds.has(contact.value))
        );
    
        this.filteredBCCContacts = this.contacts.filter(contact =>
            !(selectedPrimaryIds.has(contact.value) || selectedCCIds.has(contact.value) || selectedBCCIds.has(contact.value))
        );
    
    }

    /*
    * Method Name: toggleDateFieldDropdown
    * @description: Method to show date or contact field
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    toggleDateFieldDropdown() {
        this.isDateFieldDropdownVisible = !this.isDateFieldDropdownVisible;
    }

    /*
    * Method Name: handleDateFieldSelect
    * @description: Method to show date field of contact
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleDateFieldSelect(event) {
        const selectedValue = event.detail.value;
        console.log('selectedValue ==> ' , selectedValue);
        this.selectedContactDateField = selectedValue;
        this.isDateFieldDropdownVisible = false;
        this.isFieldSelected = true; 
    }

    /*
    * Method Name: updateExactDates
    * @description: Method to update exact date
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    updateExactDates() {
        if (this.specificDate) {
            this.emails = this.emails.map(email => {
                const days = parseInt(email.daysAfterStartDate, 10) || 0;
                const exactDate = new Date(this.specificDate);
                exactDate.setDate(exactDate.getDate() + days);
                email.exactDate = exactDate.toISOString().split('T')[0];
                return email;
            });

            this.emailsWithTemplate = this.emailsWithTemplate.map(email => {
                const days = parseInt(email.daysAfterStartDate, 10) || 0;
                const exactDate = new Date(this.specificDate);
                exactDate.setDate(exactDate.getDate() + days);
                email.exactDate = exactDate.toISOString().split('T')[0];
                return email;
            });
        }
    }
    
    /*
    * Method Name: handleRemove
    * @description: Method remove selected field
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleRemove() {
        this.isFieldSelected = false; 
    }

    /*
    * Method Name: handleEdit
    * @description: Method to edit the campaign information
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleEdit(){
        // console.log('Edit button is clicked');
        this.isEdit = true;
        this.isModalOpen = true;

    }

    handleDataFieldBlur(){
        this.isDateFieldDropdownVisible = false;
    }

    /*
    * Method Name: handleStartDateOptionChange
    * @description: Method to visible date field 
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleStartDateOptionChange(event) {
        this.startDateOption = event.detail.value;
        this.specificDate = '';
        this.selectedContactDateField = '';
        this.isFieldSelected = false;

        this.emails = this.emails.map(email => {
            email.exactDate = '';
            return email;
        });

        this.emailsWithTemplate = this.emailsWithTemplate.map(email => {
            email.exactDate = '';
            return email;
        });
    }

    handleContactDateFieldChange(event) {
        console.log('event.detail.value ==> ' , event.detail.value);
        this.selectedContactDateField = event.detail.value;
    }
    
    /*
    * Method Name: handleAddNewEmail
    * @description: Method to add new email 
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleAddNewEmail() {
        const newId = this.emails.length + 1;

        this.emails = [...this.emails, { id: newId, name:'', template: '', subject: '', daysAfterStartDate: 0, timeToSend: '', exactDate: this.specificDate, disabled: false, isListingSelectionDisabled : true ,selectedListingId : ''}];
        this.emailsWithTemplate = [...this.emailsWithTemplate, { id: newId, name:'', template: '', subject: '', daysAfterStartDate: 0, timeToSend: '', exactDate: this.specificDate, disabled: false, isListingSelectionDisabled:true ,selectedListingId : ''}];
        }

    /*
    * Method Name: handleDeleteEmail
    * @description: Method to delete email 
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleDeleteEmail(event) {
        try {
            const emailId = event.currentTarget.dataset.id;
            this.deletedEmailList.push(emailId);
            this.emails = this.emails.filter(email => email.id != emailId);
            this.emailsWithTemplate = this.emailsWithTemplate.filter(email => email.id != emailId);
        } catch (error) {
            console.log('error => ' , error);
        }

    }

    /*
    * Method Name: handleTemplateChange
    * @description: Method to handle template and corrospoding subject change
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleTemplateChange(event) {
        const emailId = event.target.dataset.id;
        const selectedTemplateId = event.detail.value;
        
        const selectedTemplate = this.quickTemplates.find(template => template.value == selectedTemplateId);

        console.log(selectedTemplate);

        // console.log('selectedTemplate ==> ' , selectedTemplate);
        // console.log('selectedTemplate JSON.stringify ==> ' , JSON.stringify(selectedTemplate));

        this.emails = this.emails.map(email => {
            console.log('email.id ==> ' , email.id);
            console.log('emailId ==> ' , emailId);
            
            if (email.id == emailId) {
                email.subject = selectedTemplate.subject;
                email.isListingSelectionDisabled  = selectedTemplate.objectApiName == 'Listing__c' ? false : true;
                email.templateType = this.templateType == 'EmailTemplate' ? 'EmailTemplate' : 'EstateXpertTemplate';
                console.log(selectedTemplate.selectedListingId);
                email.selectedListingId = '';
                const picker = this.template.querySelector(`lightning-record-picker[data-id="${emailId}"]`);
                if (picker) {
                    picker.clearSelection();
                } else {
                    console.warn(`Record picker with data-id ${emailId} not found.`);
                }
                console.log(selectedTemplate.selectedListingId);
            }
            return email;
        });

        this.emails = [...this.emails];

        this.emailsWithTemplate = this.emailsWithTemplate.map(email => {
            console.log('email.id ==> ' , email.id);
            console.log('emailId ==> ' , emailId);

            if (email.id == emailId) {
                email.template = selectedTemplate.value;
                email.subject = selectedTemplate.subject;
                email.templateType = this.templateType == 'EmailTemplate' ? 'EmailTemplate' : 'EstateXpertTemplate';
                console.log(email.selectedListingId);
                email.selectedListingId = '';
                email.isListingSelectionDisabled  = selectedTemplate.objectApiName == 'MVEX__Listing__c' ? false : true;
                console.log(email.selectedListingId);
            }
            return email;
        });

        this.emailsWithTemplate = [...this.emailsWithTemplate];
        

        console.log('this.emailsWithTemplate ==> ' , JSON.stringify(this.emailsWithTemplate));

        
    }

    
    /*
    * Method Name: handleListingSelect
    * @description: Method to handle selectedListing
    * Date: 21/05/2025
    * Created By: Yash Parekh
    */
    handleListingSelect(event){
        const emailId = event.target.dataset.id;
        console.log('in handleListing sleect');
        console.log();

        // console.log('selectedTemplate ==> ' , selectedTemplate);
        // console.log('selectedTemplate JSON.stringify ==> ' , JSON.stringify(selectedTemplate));
        
        

        this.emails = this.emails.map(email => {
            console.log('email.id ==> ' , email.id);
            console.log('emailId ==> ' , emailId);
            
            if (email.id == emailId) {
                email.selectedListingId = event.detail.recordId
            }
            return email;
        });

        this.emailsWithTemplate = this.emailsWithTemplate.map(email => {
            console.log('email.id ==> ' , email.id);
            console.log('emailId ==> ' , emailId);

            if (email.id == emailId) {
                email.selectedListingId = event.detail.recordId
                console.log(email.selectedListingId);
            }
            return email;
        });

        console.log('this.emailsWithTemplate ==> ' , JSON.stringify(this.emailsWithTemplate));

        
    }
    

    /*
    * Method Name: handleDaysAfterStartDateChange
    * @description: Method to handle days after start day change
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleDaysAfterStartDateChange(event) {
        const emailId = event.target.dataset.id;
        this.newDaysAfterStartDate = event.target.value;
    
        this.emails = this.emails.map(email => {
            if (email.id == emailId) {
                email.daysAfterStartDate = this.newDaysAfterStartDate;
            }
            return email;
        });
            
        this.emailsWithTemplate = this.emailsWithTemplate.map(email => {
            if (email.id == emailId) {
                email.daysAfterStartDate = this.newDaysAfterStartDate;
            }
            return email;
        });

        this.updateExactDates();
    }


    openMemberModal(){
        var compDefinition = {
            componentDef: "MVEX:campaignMembersTable",
            attributes: {
                campaignId: this.campaignId
            }
        };
        // Base64 encode the compDefinition JS object
        var encodedCompDef = btoa(JSON.stringify(compDefinition));
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__webPage',
            attributes: {
                url: '/one/one.app#' + encodedCompDef
            }
        }).then(url => {
            window?.globalThis?.open(url, "_blank");
        });
    }


    /*
    * Method Name: handleNameChange
    * @description: Method to handle email name change
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleNameChange(event){
        const emailId = event.target.dataset.id;
        const emailName = event.target.value;

        // console.log('emailName ==> ' , emailName);
        
        this.emails = this.emails.map(email => {
            if (email.id == emailId) {
                email.name = emailName;
            }
            return email;
        });

        this.emailsWithTemplate = this.emailsWithTemplate.map(email => {
            if (email.id == emailId) {
                email.name = emailName;
            }
            return email;
        });
    }


    /*
    * Method Name: handleTimeToSendChange
    * @description: Method to handle time change
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleTimeToSendChange(event) {
        try {
            const emailId = event.target.dataset.id;
            // console.log('emailId-->', emailId);
    
            const newTimeToSend = event.target.value;
            console.log('newTimeToSend ==> ' , newTimeToSend);
            const inputElement = this.template.querySelector(`.timeCmp[data-id="${emailId}"]`);

            if(newTimeToSend == null){

                this.showToast('Error', 'Selected time cannot be blank', 'error');

                if (inputElement) {
                    inputElement.setCustomValidity("Select time");
                }

                this.emails = this.emails.map(email => {
                    if (email.id == emailId) {
                        email.timeToSend = newTimeToSend;
                    }
                    return email;
                });

                this.emailsWithTemplate = this.emailsWithTemplate.map(email => {
                    if (email.id == emailId) {
                        email.timeToSend = newTimeToSend;
                    }
                    return email;
                });
                                
            }
            
            const email = this.emails.find(email => email.id == emailId);
    
            const selectedDate = new Date(email.exactDate);
            const currentTime = new Date();
            console.log('currentTime ==> ' , currentTime);
    
            const isToday = selectedDate.toDateString() === currentTime.toDateString();
    
            const newTimeParts = newTimeToSend.split(':');
            const newTimeDate = new Date();
            newTimeDate.setHours(newTimeParts[0], newTimeParts[1], newTimeParts[2] || 0, 0);
    
            const isPastTime = isToday && newTimeDate < currentTime;

            if (isPastTime) {
                this.showToast('Error', 'Selected time cannot be before current time for today.', 'error');
    
                if (inputElement) {
                    inputElement.setCustomValidity("Select future time");
                }
    
                return;
            }

            if (inputElement) {
                inputElement.setCustomValidity("");
            } 

            this.emails = this.emails.map(email => {
                if (email.id == emailId) {
                    email.timeToSend = newTimeToSend;
                }
                return email;
            });
        
            this.emailsWithTemplate = this.emailsWithTemplate.map(email => {
                if (email.id == emailId) {
                    email.timeToSend = newTimeToSend;
                }
                return email;
            });

        } catch (error) {
            console.log('error ==>', error);
        }
    }

    /*
    * Method Name: handlepreviewBtn
    * @description: Method to handle preview change
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handlepreviewBtn(event){
        try {
            console.log('in handlepreviewBtn method');
            const emailId = event.currentTarget.dataset.id;
            console.log('emailId ==> ' , emailId);
            console.log('this.emailsWithTemplate ==> ' , JSON.stringify(this.emailsWithTemplate));
            console.log('this.emailsWithTemplate.length ==> ' , this.emailsWithTemplate.length);

            const email = this.emailsWithTemplate.find(e => e.id == emailId);
            console.log('email ==> ' , JSON.stringify(email));
            if(email){
                const templateId = email.template;
                console.log('templateId ==> ' , templateId);
                this.selectedTemplateId = email.template;
                console.log('this.selectedTemplateId ==> ' , this.selectedTemplateId);
                
            }

            this.isPreviewModal = true;
        } catch (error) {
            console.log('Error ==> ' , error.stack);
        }
    }

    /*
    * Method Name: handleCloseModal
    * @description: Method to handle close modal
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleCloseModal(){
        this.isPreviewModal = false;
    }

    /*
    * Method Name: handleCancel
    * @description: Method to handle cancel button
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleCancel() {
        this.navigateToDisplayCampaigns();
    }

    /*
    * Method Name: handleSave
    * @description: Method to handle save functionality
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleSave() {
        this.isLoading = true;
        console.log('this.emailsWithTemplate ==> ' , JSON.stringify(this.emailsWithTemplate));
        let emails =  (this.selectedContactDateField == null || this.selectedContactDateField == '') ? this.emailsWithTemplate.filter(email => (email.disabled == false)) : this.emailsWithTemplate ;
        console.log('emails ==> ' , JSON.stringify(emails));
        if(this.emailsWithTemplate.length == 0){
            this.showToast('Error' , 'Add atleast One Email for Scheduling' ,'error');
            this.isLoading = false;
            return;
        }

        if (!this.validateInputs()) {
            this.showToast('Error', 'Please ensure all required fields are filled.', 'error');
            this.isLoading = false;
            return;
        }

        if(this.specificDate != '' && this.specificDate < this.today){
            this.showToast('Error', 'Please Select Future Date', 'error');
            this.isLoading = false;
            return;
        }

        const currentTime = new Date();
        let hasInvalidTime = false;
    
        emails.forEach(email => {
            const emailDate = new Date(email.exactDate);
            if (emailDate.toDateString() === currentTime.toDateString()) {
                const timeParts = email.timeToSend.split(':');
                const emailTime = new Date();
                emailTime.setHours(timeParts[0], timeParts[1], timeParts[2] || 0, 0);
                if (emailTime < currentTime) {
                    hasInvalidTime = true;
                }
            }
        });

        if (hasInvalidTime) {
            this.showToast('Error', 'Selected time cannot be before the current time for today.', 'error');
            this.isLoading = false;
            return;
        }

        const uniqueDateTimeValues = new Set();
        let hasDuplicateDateTime = false;
    
        emails.forEach(email => {
            const dateTimeKey = `${email.daysAfterStartDate}-${email.timeToSend}`;
            if (uniqueDateTimeValues.has(dateTimeKey)) {
                hasDuplicateDateTime = true;
                return;
            } else {
                uniqueDateTimeValues.add(dateTimeKey);
            }
        });
    
        if (hasDuplicateDateTime) {
            this.showToast('Error', 'There are duplicate "Days After Start Date" and "Time to Send" values. Please ensure each email has a unique combination of these values.', 'error');
            this.isLoading = false;
            return;
        }

        // Calculate total recipients
        const estimatedTotalPrimary = this.selectedPrimaryRecipients.length + this.estimatedContactsFromGroups;
        const totalRecipients = estimatedTotalPrimary + this.selectedBCCRecipients.length + this.selectedCCRecipients.length;
        
        if (this.navigationStateString.messagingService === 'outlook' && totalRecipients > 20){
            this.showToast('Error', 'In Outlook there is a limit of 20 recipients. Please select a smaller group of recipients or use another messaging service.', 'error');
            this.isLoading = false;
            return;
        } else if(this.navigationStateString.messagingService === 'gmail' && totalRecipients > 100){
            this.showToast('Error', 'In Gmail there is a limit of 100 recipients. Please select a smaller group of recipients or use another messaging service.', 'error');
            this.isLoading = false;
            return;
        }
        else if(totalRecipients > 100){
            this.showToast('Error', 'In Salesforce there is a limit of 100 recipients. Please select a smaller group of recipients or use another messaging service.', 'error');
            this.isLoading = false;
            return;
        }

        try {
            const emailsWithTemplate = (this.selectedContactDateField == null || this.selectedContactDateField == '')  ? this.emailsWithTemplate.filter(email => email.disabled == false) : this.emailsWithTemplate;
            console.log('emailsWithTemplate ==> ' , JSON.stringify(emailsWithTemplate));
            console.log('specificDate ==> ' , this.specificDate);
            const campaignEmailData = {
                templateId : this.templateId,
                campaignId : this.campaignId,
                relatedObject : this.relatedObject, 
                campaignName: this.emailCampaignName,
                messagingService : this.navigationStateString.messagingService,
                saveForFuture: this.navigationStateString.saveForFuture,
                selectedPrimaryRecipients: this.transformRecipientsPrimary(this.selectedPrimaryRecipients),
                selectedCCRecipients: this.transformRecipients(this.selectedCCRecipients),
                selectedBCCRecipients: this.transformRecipients(this.selectedBCCRecipients),
                emails: emailsWithTemplate,
                specificDate : this.specificDate,
                selectedContactDateField : this.selectedContactDateField,
                deletedEmailList : this.deletedEmailList,
                // Include selected broadcast groups
                selectedBroadcastGroups: this.selectedBroadcastGroups
            };

            console.log('campaignEmailData ==> ' , JSON.stringify(campaignEmailData));

            if (this.selectedContactDateField) {
                console.log('selectedContactDateField ==> ' , this.selectedContactDateField);
                checkContactDateFields({ contactsJson: JSON.stringify(this.selectedPrimaryRecipients), selectedContactDateField: this.selectedContactDateField })
                    .then(contactDateFieldValues => {
                        console.log('contactDateFieldValues ==> ' , contactDateFieldValues);
                        // const isPreviousDate = this.dateMapHasDateLessThanToday(contactDateFieldValues);
                        // if (isPreviousDate) {
                        //     this.showToast('Error', 'Some contacts date field value is less than today.', 'error');
                        //     this.isLoading = false;
                        //     return;
                        // } else {
                            this.saveCampaignEmailData(campaignEmailData);
                        // }
                    })
                    .catch(error => {
                        console.error('Error in checking contact date fields:', error);
                        this.showToast('Error', 'Failed to check contact date field values.', 'error');
                        this.isLoading = false;
                    });
            } else {
                this.saveCampaignEmailData(campaignEmailData);
            }
        } catch (error) {
            console.log('Error ==> ' , error);
            this.isLoading = false;
        }
    }

    /*
    * Method Name: dateMapHasDateLessThanToday
    * @description: Method to check current and previous date
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    dateMapHasDateLessThanToday(contactDateFieldValues) {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
    
        return Object.values(contactDateFieldValues).some(dateString => {
            const dateToCheck = new Date(dateString);
            dateToCheck.setHours(0, 0, 0, 0);
            console.log('dateToCheck ==> ' , dateToCheck);
            console.log('today ==> ' , today);
            return dateToCheck < today;
        });
    }

    /*
    * Method Name: saveCampaignEmailData
    * @description: Method to save camapign data
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    saveCampaignEmailData(campaignEmailData) {
        const jsonCampaignEmailData = JSON.stringify(campaignEmailData);
        
        console.log('jsonCampaignEmailData ==> ' , jsonCampaignEmailData);
        console.log('this.campaignId ==> ' , this.campaignId);

        if (this.campaignId) {
            updateCampaignAndEmails({ jsonCampaignEmailData })
                .then(() => {
                    this.showToast('Success', 'Campaign and Emails are saved successfully', 'success');
                    this.isLoading = false;
                    this.navigateToDisplayCampaigns();
                })
                .catch(error => {
                    console.error('Error in updating campaign and emails:', error);
                    this.showToast('Error', 'Failed to update campaign and emails.', 'error');
                    this.isLoading = false;
                });
        } else {
            createCampaignAndEmails({ jsonCampaignEmailData })
                .then(() => {
                    this.showToast('Success', 'Campaign and Emails are saved successfully', 'success');
                    this.isLoading = false;
                    this.navigateToDisplayCampaigns();
                })
                .catch(error => {
                    console.error('Error creating campaign and emails:', error);
                    this.showToast('Error', 'Failed to create campaign and emails.', 'error');
                    this.isLoading = false;
                });
        }
    }
    
    /*
    * Method Name: navigateToDisplayCampaigns
    * @description: Method to navigate to display component
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    navigateToDisplayCampaigns() {
        const cmpDef = {
            componentDef: 'MVEX:displayCampaigns'
        };
    
        let encodedDef = btoa(JSON.stringify(cmpDef));
        this[NavigationMixin.Navigate]({
            type: "standard__webPage",
            attributes: {
                url: "/one/one.app#" + encodedDef
            }
        });
    }

    /*
    * Method Name: validateInputs
    * @description: Method to validate all the input
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    /**
 * Validates the campaign inputs before saving.
 * @returns {Boolean} True if inputs are valid, false otherwise.
 */
    validateInputs() {
        console.log('Validating inputs');
        // Check if individual recipients OR groups are selected
        const hasRecipients = this.selectedPrimaryRecipients.length > 0 || this.selectedBroadcastGroups.length > 0;
        const isDateSelected = this.specificDate || this.selectedContactDateField;
        const emails = this.emailsWithTemplate.filter(email => !email.disabled);
        const areEmailsValid = emails.every(email =>
            email.name && email.template && email.daysAfterStartDate != null && email.timeToSend && (email.isListingSelectionDisabled || email.selectedListingId)
        );
        const isValid = hasRecipients && isDateSelected && areEmailsValid;
        console.log('validateInputs result:', isValid);
        return isValid;
    }

    /*
    * Method Name: transformRecipientsPrimary
    * @description: create map for the primary contacts
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    transformRecipientsPrimary(recipients){
        return recipients.map(recipient => recipient.value);
    }

    /*
    * Method Name: transformRecipients
    * @description: create map for the cc and bcc contacts
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    transformRecipients(recipients) {
        return recipients.map(recipient => `${recipient.value}:${recipient.email}`);
    }

    /*
    * Method Name: showToast
    * @description: method to show toast
    * Date: 24/06/2024
    * Created By: Rachit Shah
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

    /*
    * Method Name: registerErrorListener
    * @description: method to register platform event
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    registerErrorListener() {
        onError(error => {
            console.error('Received error from server:', error);
        });
    }

    /*
    * Method Name: disconnectedCallback
    * @description: method to unregister platform event
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    disconnectedCallback() {
        unsubscribe(this.subscription, response => {
            console.log('Unsubscribed from platform event channel', response);
        });
    }
}