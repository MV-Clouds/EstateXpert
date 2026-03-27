import { LightningElement, track, wire } from "lwc";
import { CurrentPageReference } from 'lightning/navigation';
import getListingAndTemplates from '@salesforce/apex/TemplateBuilderController.getListingAndTemplates';
import searchContactsWithEmail from '@salesforce/apex/TemplateBuilderController.searchContactsWithEmail';
import sendEmailWithPDF from '@salesforce/apex/TemplateBuilderController.sendEmailWithPDF';
import { CloseActionScreenEvent } from 'lightning/actions';
import { loadStyle } from 'lightning/platformResourceLoader';
import listingpdfcss from '@salesforce/resourceUrl/listingpdfcss';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ListingPDFGenerator extends LightningElement {

    @track templateid;
    @track recordId;
    @track isSpinner = false;
    @track vfPageSRC;
    @track isInitalRender = true;
    @track readonly = true;
    @track dropDown = false;
    @track searchResults;
    @track selectedSearchResult;
    @track picklistOrdered;
    @track isStep1 = true;
    @track isStep2 = false;
    @track selectedValue = null;
    @track vfGeneratePageSRC;
    @track isDataAvailable = true;
    @track vfEmailPageSRC;

    @track isStep3 = false;
    @track previousStep = 1;

    // Contact search
    @track contactSearchTerm = '';
    @track contactSearchResults = [];
    @track selectedContacts = [];
    @track showContactDropdown = false;
    @track isContactSearching = false;
    @track _contactSearchTimer;

    // Email compose
    @track emailSubject = '';
    @track emailBody = '';
    @track freeTypedEmail = '';

    get showFreeEmailOption() {
        return this.freeTypedEmail && !this.isContactSearching;
    }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.recordId = currentPageReference.state.recordId;
        }
    }

    get loadingInfo() {
        return this.isSpinner === false
            ? 'To generate a preview, please select any Template first.'
            : 'Generating Preview...';
    }

    get contactInputPlaceholder() {
        return this.selectedContacts.length === 0 ? 'Search contacts by name...' : '';
    }

    get hasContactResults() {
        return this.contactSearchResults && this.contactSearchResults.length > 0;
    }

    get attachmentLabel() {
        const tpl = this.picklistOrdered?.find(t => t.value === this.templateid);
        return tpl ? `${tpl.label}.pdf` : 'Template.pdf';
    }

    connectedCallback() {
        try {
            loadStyle(this, listingpdfcss)
                .then(() => { console.log('External Css Loaded'); })
                .catch(error => { console.log('Error occuring during loading external css', error); });
            this.getTemplateRecordsToDisplay();
            this.vfPageMessageHandler();
        } catch (error) {
            console.log('error in TemplatePreviewModal > connectedCallback', error.stack);
        }
    }

    disconnectedCallback() {
        if (typeof window !== 'undefined') {
            window.removeEventListener('message', this.simpleTempFileGenResponse);
        }
        if (this._contactSearchTimer) {
            clearTimeout(this._contactSearchTimer);
        }
    }
    getTemplateRecordsToDisplay() {
        getListingAndTemplates({ recordId: this.recordId }).then((result) => {
            console.log('result', result);
            this.listingName = result.listingName;
            if (result.templates.length > 0) {
                this.picklistOrdered = result.templates.map(template => ({
                    label: template.MVEX__Template_Name__c,
                    value: template.Id
                }));
                this.picklistOrdered = this.picklistOrdered.sort((a, b) => {
                    if (a.label < b.label) return -1;
                    if (a.label > b.label) return 1;
                    return 0;
                });
            } else {
                this.isDataAvailable = false;
            }
        }).catch((error) => {
            console.error('Error getting template records to display', error);
        });
    }

    vfPageMessageHandler() {
        if (typeof window !== 'undefined') {
            window.addEventListener('message', this.simpleTempFileGenResponse);
        }
    }

    simpleTempFileGenResponse = (message) => {
        try {
            console.log('message', message);
            if (message.data.messageFrom === 'docGenerate') {
                const { completedChannel, status, error, pdfBase64 } = message.data;
                console.log('message.data', message.data);

                if (!status) {
                    this.isSpinner = false;
                    this.showToast('Error', 'Error generating PDF.', 'error');
                    return;
                }

                if (completedChannel === 'Email' && pdfBase64) {
                    // PDF is ready — now call Apex with the base64 data
                    this.dispatchEmailWithBase64(pdfBase64);
                }

                if (completedChannel === 'Download') {
                    this.isSpinner = false;
                }
            }
        } catch (e) {
            console.error('Error in simpleTempFileGenResponse', e);
            this.isSpinner = false;
        }
    }

    generatePreview() {
        try {
            this.isSpinner = true;
            this.showPreview = true;

            var previousSRC = this.vfPageSRC;
            var paraData = {
                'templateId': this.templateid,
                'MVEX__Object_API_Name__c': 'MVEX__Listing__c',
                'recordId': this.recordId,
                'useMode': 'preview',
            };
            var paraDataStringify = JSON.stringify(paraData);
            var newSRC = '/apex/MVEX__DocGeneratePage?paraData=' + paraDataStringify;

            if (newSRC !== previousSRC) {
                this.vfPageSRC = newSRC;
            } else {
                this.vfPageSRC = '/apex/MVEX__DocGeneratePage';
                this.template.querySelector('[data-id="previewTimeout"]')?.setCustomTimeoutMethod(() => {
                    this.vfPageSRC = newSRC;
                }, 100);
            }
        } catch (error) {
            console.warn('error in TemplatePreviewModal > previewData', error.message);
        }
    }

    contentLoaded() {
        try {
            this.isSpinner = false;
        } catch (error) {
            console.log('error in TemplatePreviewModal > contentLoaded', error.stack);
        }
    }

    downloadFile() {
        try {
            const previewTimeout = this.template.querySelector('[data-id="previewTimeout"]');

            if (!this.selectedValue) {
                this.showToast('Error', 'Please select template first.', 'error');
                return;
            }

            this.isSpinner = true;
            let previousSRC = this.vfGeneratePageSRC;
            let paraData2 = {
                'templateId': this.templateid,
                'recordId': this.recordId,
                'selectedExtension': '.pdf',
                'selectedChannels': 'Download',
                'fileName': this.attachmentLabel
            };
            let paraDataStringify2 = JSON.stringify(paraData2);
            let newSRC = '/apex/MVEX__DocGeneratePage?paraData=' + encodeURIComponent(paraDataStringify2);

            if (newSRC !== previousSRC) {
                this.vfGeneratePageSRC = newSRC;
            } else {
                this.vfGeneratePageSRC = '/apex/MVEX__DocGeneratePage';
                previewTimeout?.setCustomTimeoutMethod(() => {
                    this.vfGeneratePageSRC = newSRC;
                }, 300);
            }
        } catch (e) {
            console.log('error in TemplatePreviewModal > downloadFile --> ', e.stack);
        }
    }

    fileDownloaded() {
        this.isSpinner = false;
    }

    closeActionScreen() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showPicklistOptions() {
        if (!this.searchResults) {
            this.searchResults = this.picklistOrdered;
        }
        this.dropDown = true;
        this.readonly = false;
    }

    search(event) {
        const input = event.target.value.toLowerCase();
        const result = this.picklistOrdered.filter((picklistOption) =>
            picklistOption.label.toLowerCase().includes(input)
        );
        this.searchResults = result;
    }

    hidePicklistOptions() {
        this.dropDown = false;
    }

    preventHide(event) {
        event.preventDefault();
    }

    selectSearchResult(event) {
        this.templateid = event.currentTarget.dataset.value;
        this.selectedSearchResult = this.picklistOrdered.find(
            (picklistOption) => picklistOption.value === this.templateid
        );
        this.selectedValue = this.selectedSearchResult ? this.selectedSearchResult.label : null;
        this.clearSearchResults();
        this.dropDown = false;
        this.readonly = true;
    }

    clearSearchResults() {
        this.searchResults = null;
    }

    goToStep2() {
        if (this.selectedValue) {
            this.isStep1 = false;
            this.isStep2 = true;
            this.vfGeneratePageSRC = null;
            this.generatePreview();
        } else {
            this.showToast('Error', 'Please select template first.', 'error');
        }
    }

    goToStep1() {
        this.isStep1 = true;
        this.isStep2 = false;
        this.vfGeneratePageSRC = null;
    }

    showToast(title, message, variant) {
        if (typeof window !== 'undefined') {
            const event = new ShowToastEvent({ title, message, variant });
            this.dispatchEvent(event);
        }
    }

    handleClear(event) {
        if (!event.target.value.length) {
            this.selectedValue = null;
        }
    }

    runTimeoutMethod(event) {
        if (event?.detail?.function) {
            event.detail.function();
        }
    }

    goToStep3() {
        if (!this.selectedValue) {
            this.showToast('Error', 'Please select a template first.', 'error');
            return;
        }
        this.previousStep = this.isStep1 ? 1 : 2;
        this.isStep1 = false;
        this.isStep2 = false;
        this.isStep3 = true;

        // Set default subject and body
        this.emailSubject = `Listing Document – ${this.listingName || 'Property'}`;
        this.emailBody = `Hi,\n\nPlease find attached the listing document for your reference.\n\nKind regards`;

        // Reset contact state each time
        this.selectedContacts = [];
        this.contactSearchTerm = '';
        this.contactSearchResults = [];
        this.showContactDropdown = false;
    }

    goBackFromEmail() {
        this.isStep3 = false;
        if (this.previousStep === 2) {
            this.isStep2 = true;
        } else {
            this.isStep1 = true;
        }
    }
    focusContactSearch() {
        const input = this.template.querySelector('[data-id="contactSearchInput"]');
        if (input) input.focus();
    }

    handleContactSearch(event) {
        const term = event.target.value;
        this.contactSearchTerm = term;

        // Handle space/enter to add email pill directly
        if (term.endsWith(' ') || term.endsWith(',')) {
            const trimmed = term.slice(0, -1).trim();
            if (this.isValidEmail(trimmed)) {
                this.addEmailAsPill(trimmed);
                return;
            }
        }

        if (!term || term.trim().length < 2) {
            this.showContactDropdown = false;
            this.contactSearchResults = [];
            this.freeTypedEmail = '';
            return;
        }

        // If it looks like a valid email, store it for "use this email" option
        this.freeTypedEmail = this.isValidEmail(term.trim()) ? term.trim() : '';

        clearTimeout(this._contactSearchTimer);
        this._contactSearchTimer = setTimeout(() => {
            this.runContactSearch(term.trim());
        }, 300);
    }

    handleContactKeydown(event) {
        if (event.key === 'Enter' && this.contactSearchTerm.trim()) {
            const term = this.contactSearchTerm.trim();
            if (this.isValidEmail(term)) {
                this.addEmailAsPill(term);
            }
        }
    }

    runContactSearch(searchTerm) {
        this.isContactSearching = true;
        this.showContactDropdown = true;

        const excludeIds = this.selectedContacts.map(c => c.id);

        searchContactsWithEmail({ searchTerm, excludeIds })
            .then((results) => {
                this.contactSearchResults = results.map(c => ({
                    id: c.Id,
                    name: c.Name,
                    email: c.Email,
                    initials: this.getInitials(c.Name)
                }));
                this.isContactSearching = false;
                // Keep dropdown open even if empty (to show free-type option)
                this.showContactDropdown = true;
            })
            .catch((error) => {
                console.error('Error searching contacts', error);
                this.isContactSearching = false;
                this.contactSearchResults = [];
                this.showContactDropdown = true;
            });
    }

    addEmailAsPill(email) {
        const alreadyAdded = this.selectedContacts.some(c => c.email === email);
        if (!alreadyAdded) {
            this.selectedContacts = [
                ...this.selectedContacts,
                {
                    id: 'manual_' + email,   // synthetic id for non-SF contacts
                    name: email,
                    email: email,
                    initials: email.charAt(0).toUpperCase()
                }
            ];
        }
        this.contactSearchTerm = '';
        this.freeTypedEmail = '';
        this.contactSearchResults = [];
        this.showContactDropdown = false;
    }

    selectFreeEmail(event) {
        event.preventDefault();
        const email = event.currentTarget.dataset.email;
        if (email) this.addEmailAsPill(email);
    }

    isValidEmail(value) {
        return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
    }

    selectContact(event) {
        const id = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name;
        const email = event.currentTarget.dataset.email;
        const initials = event.currentTarget.dataset.initials;

        // Prevent duplicates
        const alreadyAdded = this.selectedContacts.some(c => c.id === id);
        if (!alreadyAdded) {
            this.selectedContacts = [
                ...this.selectedContacts,
                { id, name, email, initials }
            ];
        }

        // Reset search
        this.contactSearchTerm = '';
        this.contactSearchResults = [];
        this.showContactDropdown = false;
    }

    removeContact(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedContacts = this.selectedContacts.filter(c => c.id !== id);
    }

    hideContactDropdown() {
        // Small delay so selectContact mousedown fires first
        setTimeout(() => {
            this.showContactDropdown = false;
        }, 150);
    }

    preventContactHide(event) {
        event.preventDefault();
    }

    handleSubjectChange(event) {
        this.emailSubject = event.target.value;
    }

    handleBodyChange(event) {
        this.emailBody = event.target.value;
    }


    generatePDFForEmail() {
        let paraData = {
            templateId: this.templateid,
            recordId: this.recordId,
            selectedExtension: '.pdf',
            selectedChannels: 'Email',
            fileName: this.attachmentLabel || 'Listing'
        };

        const newSRC = '/apex/MVEX__DocGeneratePage?paraData='
            + encodeURIComponent(JSON.stringify(paraData));

        // Reset first so LWC detects the change if same URL
        this.vfEmailPageSRC = null;

        setTimeout(() => {
            this.vfEmailPageSRC = newSRC;
        }, 50);
    }

    sendEmail() {
        if (!this.selectedContacts || this.selectedContacts.length === 0) {
            this.showToast('Error', 'Please select at least one contact.', 'error');
            return;
        }
        if (!this.emailSubject?.trim()) {
            this.showToast('Error', 'Please enter an email subject.', 'error');
            return;
        }
        if (!this.emailBody?.trim()) {
            this.showToast('Error', 'Please enter an email body.', 'error');
            return;
        }

        this.isSpinner = true;
        this.generatePDFForEmail();
    }

    dispatchEmailWithBase64(pdfBase64) {
        // Split into SF contacts and manual emails
        const contactIds = this.selectedContacts
            .filter(c => !c.id.toString().startsWith('manual_'))
            .map(c => c.id);

        const manualEmails = this.selectedContacts
            .filter(c => c.id.toString().startsWith('manual_'))
            .map(c => c.email);

        sendEmailWithPDF({
            contactIds,
            manualEmails,          // <-- new param
            subject: this.emailSubject,
            body: this.emailBody,
            templateId: this.templateid,
            recordId: this.recordId,
            fileName: this.attachmentLabel || 'Listing',
            pdfBase64
        })
            .then(() => {
                this.isSpinner = false;
                this.showToast('Success', 'Email sent successfully!', 'success');
                this.closeActionScreen();
            })
            .catch((error) => {
                this.isSpinner = false;
                const msg = error?.body?.message || 'An error occurred while sending the email.';
                this.showToast('Error', msg, 'error');
            });
    }

    getInitials(name) {
        if (!name) return '?';
        const parts = name.trim().split(' ');
        if (parts.length === 1) return parts[0].charAt(0).toUpperCase();
        return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase();
    }
}