import { LightningElement, track, wire } from "lwc";
import { CurrentPageReference } from 'lightning/navigation';
import getListingAndTemplates from '@salesforce/apex/TemplateBuilderController.getListingAndTemplates';
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

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.recordId = currentPageReference.state.recordId;
        }
    }

    get loadingInfo(){
        var info = `To generate a preview, please select any Template first.`;
        return this.isSpinner == false ? info : `Generating Preview...`
    }

    connectedCallback(){
        try {
            loadStyle(this, listingpdfcss)
            .then(() => {
                console.log('External Css Loaded');
            })
            .catch(error => {
                console.log('Error occuring during loading external css', error);
            });
            this.getTemplateRecordsToDisplay();
            this.vfPageMessageHandler();

        } catch (error) {
            console.log('error in TemplatePreviewModal > connectedCallback', error.stack);
        }
    }

    getTemplateRecordsToDisplay() {
        getListingAndTemplates({ recordId: this.recordId }).then((result) => {
            console.log('result', result);
            this.listingName = result.listingName;
            if(result.templates.length > 0){
                this.picklistOrdered = result.templates.map(template => ({
                    label: template.MVEX__Template_Name__c,
                    value: template.Id
                }));
                
                this.picklistOrdered = this.picklistOrdered.sort((a, b) => {
                    if (a.label < b.label) {
                        return -1;
                    } else if (a.label > b.label) {
                        return 1;
                    } else {
                        return 0;
                    }
                });
            } else {
                this.isDataAvailable = false;
            }
            
        }).catch((error) => {
            console.error('Error getting template records to display', error);
        });
    }

    vfPageMessageHandler(){
        if (typeof window !== 'undefined') {
            window.addEventListener('message', this.simpleTempFileGenResponse);
        }
    }

    simpleTempFileGenResponse = (message) => {
        try{ 
            if(message.data.messageFrom == 'docGenerate'){
                console.log('docGenerate completedChannel : ', message.data.completedChannel);    
                console.log('docGenerate status: ', message.data.status);    
                console.log('docGenerate error: ', message.data.error);
                let pdfStatus = message.data.status;
                if (!pdfStatus) {
                    this.showToast('Error', 'Error in generating PDF.', 'error');
                }
            }
        } catch(e){
            console.log('error in TemplatePreviewModal > simpleTempFileGenResponse --> ', e.stack);
        }
    }

    generatePreview(){
        try {
            this.isSpinner = true;
            this.showPreview = true;

            var previousSRC = this.vfPageSRC;

            var paraData = {
                'templateId' : this.templateid,
                'MVEX__Object_API_Name__c' : "MVEX__Listing__c",
                'recordId' : this.recordId,
                'useMode' : 'preview',
            }
            var paraDataStringify = JSON.stringify(paraData);

            var newSRC = '/apex/DocGeneratePage?paraData=' + paraDataStringify;

            if(newSRC !== previousSRC){
                this.vfPageSRC = newSRC;
            }
            else{
                this.vfPageSRC = '/apex/DocGeneratePage';

                this.template.querySelector('[data-id="previewTimeout"]')?.setCustomTimeoutMethod(() => {
                    this.vfPageSRC = newSRC;
                }, 100);
            }
            
        } catch (error) {
            console.warn('error in TemplatePreviewModal > previewData', error.message);
        }
    }

    contentLoaded(){
        try {
            this.isSpinner = false;
        } catch (error) {
            console.log('error in TemplatePreviewModal > contentLoaded', error.stack);
        }
    }

    downloadFile(){
        try{
            const previewTimeout = this.template.querySelector('[data-id="previewTimeout"]');

            if (!this.selectedValue) {
                this.showToast('Error', 'Please select template first.', 'error');
                return;
            }

            this.isSpinner = true;
            let previousSRC = this.vfGeneratePageSRC;
            let paraData2 = {
                'templateId' : this.templateid,
                'recordId' : this.recordId,
                'selectedExtension' : '.pdf',
                'selectedChannels' : 'Download',
                'fileName' : this.listingName
            }
            let paraDataStringify2 = JSON.stringify(paraData2);
            let newSRC = '/apex/DocGeneratePage?paraData=' + encodeURIComponent(paraDataStringify2);

            if(newSRC !== previousSRC){
                this.vfGeneratePageSRC = newSRC;
            } else{
                this.vfGeneratePageSRC = '/apex/DocGeneratePage';
                previewTimeout?.setCustomTimeoutMethod(() => {
                    this.vfGeneratePageSRC = newSRC;
                }, 300);
            }
        }
        catch(e){
            console.log('error in TemplatePreviewModal > downloadFile --> ', e.stack);
        }
    }

    fileDownloaded(){
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
            const event = new ShowToastEvent({
                title: title,
                message: message,
                variant: variant,
            });
            this.dispatchEvent(event);
        }
    }

    handleClear(event) {
        if (!event.target.value.length) {
            this.selectedValue = null;
        }
    }

    runTimeoutMethod(event){
        if(event?.detail?.function){
            event.detail.function();
        }
    }

    disconnectedCallback(){
        if (typeof window !== 'undefined') {
            window.removeEventListener('message', this.simpleTempFileGenResponse);
        }
    }

}