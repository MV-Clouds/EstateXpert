import { LightningElement, api, track } from "lwc";
import previewModalImg from "@salesforce/resourceUrl/previewModal_img";
import getObjectNameField from '@salesforce/apex/TemplateBuilderController.getObjectNameField';
import getRecordsByObject from '@salesforce/apex/TemplateBuilderController.getRecordsByObject';
import summerNoteEditor from '@salesforce/resourceUrl/summerNoteEditor';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';

export default class TemplatePreviewModal extends LightningElement {

    @api templateid;
    @api objectname;
    @api recordId;
    @api templateType;

    _isActive
    @api get isActive(){ return this._isActive}
    set isActive(value){ this._isActive = (value === "true" ||  value === true) ? true : false }

    @track previewModalImg = previewModalImg;
    @track objectRecordList = null;
    @track selectedRecordId = null;
    @track selectedRecordName = null;
    @track isSpinner = false;
    @track showPreview = false;
    @track vfPageSRC; 
    @track errorDetail = {};
    @track objectLabel = '';
    @track recordLabelField;
    @track recordLabelFieldType;
    @track searchByField;
    @track vfGeneratePageSRC;
    @track hasLibraryLoaded = false;
    @track showQuickPreview = false;
    @track updatedBody = '';
    @track templateBody = '';
    
    /**
    * Method Name : totalItems
    * @returns {String} - Returns label for the record picker
    * @description : Used to set the label for the record picker
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    get label(){
        return `Select ${this.objectLabel} record`;
    }

    /**
    * Method Name : placeHolder
    * @returns {String} - Returns placeholder for the record picker
    * @description : Used to set the placeholder for the record picker
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    get placeHolder(){
        return `Search ${this.objectLabel} by Name or Id...`;
    }

    /**
    * Method Name : helpText
    * @returns {String} - Returns help text for the record picker
    * @description : Used to set the help text for the record picker
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    get helpText(){
       return `Select ${this.objectLabel} Record To Dispay Data on Template.`;
    }

    /**
    * Method Name : disableRecordPicker
    * @returns {Boolean} - Returns true if recordId is not null.
    * @description : Used to disable record picker if recordId is not null.
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    get disableRecordPicker(){
        return this.recordId ? true : false;
    }

    /**
    * Method Name : disablePreviewBtn
    * @returns {Boolean} - Returns true if selectedRecordId is null.
    * @description : Used to disable preview button if selectedRecordId is null.
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    get disablePreviewBtn(){
        return !this.selectedRecordId;
    }

    /**
    * Method Name : disableGenerateBtn
    * @returns {Boolean} - Returns true if selectedRecordId is null or isActive is false or templateType is Marketing Template.
    * @description : Used to disable generate button if selectedRecordId is null or isActive is false or templateType is Marketing Template.
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    get disableGenerateBtn(){
        return !this.selectedRecordId || !this.isActive || this.templateType == 'Marketing Template';
    }

    /**
    * Method Name : loadingInfo
    * @returns {String} - Returns loading info text.
    * @description : Used to set the loading info text.
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    get loadingInfo(){
        var info = `To generate a preview, please select any ${this.objectLabel} record first.`;
        return this.isSpinner === false ? info : `Generating Preview...`
    }

    /**
    * Method Name : isSimpleTemplatePreview
    * @returns {Boolean} - Returns true if template type is PDF Template.
    * @description : Used to check if template type is PDF Template.
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    get isSimpleTemplatePreview(){
        return this.templateType === 'PDF Template' ? true : false;
    }

    /**
    * Method Name : connectedCallback
    * @description : Used to get the object name field of the record.
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    connectedCallback(){
        try {
            if (this.recordId) {
                this.selectedRecordId = this.recordId;
                this.generatePreview();
            } else {
                this.isSpinner = true;
                getObjectNameField({objectApiName: this.objectname})
                .then(result => {
                    console.log('getObjectNameField :  ', result);
                    this.objectLabel = result.label;
                    this.recordLabelField = result.nameField;
                    if(result.nameFieldType === 'NUMBER' || result.nameFieldType === 'PERCENTAGE' || result.nameFieldType === 'CURRENCY'){
                        this.recordLabelFieldType = 'number';
                    }
                    else{
                        this.recordLabelFieldType = 'text';
                    }
                })
                .catch(() => {
                    this.recordLabelField = 'Id';
                    this.recordLabelFieldType = 'text';
                })
                .finally(() => {
                    this.searchByField = `${this.recordLabelField}`;
                    this.isSpinner = false;
                })
            }
        } catch (error) {
            console.warn('error in TemplatePreviewModal > connectedCallback', error.message);
        }
    }

    /**
    * Method Name : renderedCallback
    * @description : Used to load summernote library.
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    renderedCallback(){
        try {
            if (!this.hasLibraryLoaded && this.templateType === 'Marketing Template') {
                Promise.all([
                    loadScript(this, summerNoteEditor + '/jquery-3.7.1.min.js'),
                ])
                .then(() => { 
                    Promise.all([
                        loadStyle(this, summerNoteEditor + '/summernote-lite.css'),
                        loadScript(this, summerNoteEditor + '/summernote-lite.js'),
                    ])
                    .then(() => {
                        this.hasLibraryLoaded = true;
                    })
                    .catch(err => {
                        console.log('Error loading style:', err.stack);
                    })
                })
                .catch(error => { 
                    console.log('Error loading style 001:', error.stack);
                })
            }
        }
        catch(error){
            console.log('Error loading style 002:', error.stack);
        }
    }

    /**
    * Method Name : generatePreview
    * @description : Used to generate preview of template.
    * @param {String} - event
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    onRecordSelect(event){
        try {
            if(event.detail && event.detail.length){
                this.selectedRecordId = event.detail[0].Id;
                this.selectedRecordName = event.detail[0].Name;
            }
            else{
                this.selectedRecordId = null;
            }
        } catch (error) {
            console.warn('error in TemplatePreviewModal > onRecordSelect', error.message);
        }
    }

    /**
    * Method Name : handleRecordPickerError
    * @description : Used to handle error of record picker.
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    handleRecordPickerError(event){
        console.warn('handleRecordPickerError : ', event.detail);
    }

    /**
    * Method Name : generatePreview
    * @description : Used to generate preview of template.
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    generatePreview(){
        try {
            if(this.templateType === 'PDF Template'){
                this.isSpinner = true;
                this.showPreview = false;

                var previousSRC = this.vfPageSRC;
    
                var paraData = {
                    'templateId' : this.templateid,
                    'MVEX__Object_API_Name__c' : this.objectname,
                    'recordId' : this.selectedRecordId,
                    'useMode' : 'preview',
                }
                var paraDataStringify = JSON.stringify(paraData);

                var newSRC = '/apex/MVEX__DocGeneratePage?paraData=' + paraDataStringify;
    
                if(newSRC !== previousSRC){
                    this.vfPageSRC = newSRC;
                    this.showPreview = true;
                }
                else{
                    this.vfPageSRC = '/apex/MVEX__DocGeneratePage';

                    this.template.querySelector('[data-id="previewTimeout"]')?.setCustomTimeoutMethod(() => {
                        this.vfPageSRC = newSRC;
                        this.showPreview = true;
                    }, 400);
                }
            } else if (this.templateType === 'Marketing Template') {
                this.showQuickPreview = true;
                this.isSpinner = true;
                getRecordsByObject({recordId: this.selectedRecordId, templateId: this.templateid})
                .then(result => {
                    this.isSpinner = false;
                    console.log('getRecordsByObject :  ', result);
                    let bodyHtml = result.templateBody;
                    const mappingValueString = result.mappingKeyVsMappingValues ? JSON.parse(result.mappingKeyVsMappingValues) : {};
                    const salesforceImagesCV = result.salesforceImages ? JSON.parse(result.salesforceImages) : {};

                    for(let key in mappingValueString){
                        bodyHtml = bodyHtml.replaceAll(key, mappingValueString[key]);

                    }

                    for(let src in salesforceImagesCV){
                        bodyHtml = bodyHtml.replaceAll(src, salesforceImagesCV[src]);
                    }

                    this.templateBody = bodyHtml;

                    this.updateRichTextContent();
                })
                .catch(error => {
                    this.isSpinner = false;
                    console.log('Error fetching records:', error.stack);
                })
            }
        } catch (error) {
            console.warn('error in TemplatePreviewModal > previewData', error.message);
        }
    }

    /**
    * Method Name : contentLoaded
    * @description : Used to hide spinner when content is loaded.
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    contentLoaded(){
        try {
            this.isSpinner = false;
        } catch (error) {
            console.warn('error in TemplatePreviewModal > contentLoaded', error.message);
        }
    }
  
    /**
    * Method Name : fileDownloaded
    * @description : Used to hide spinner when file is downloaded.
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    fileDownloaded(){
        try {
            this.isSpinner = false;
            this.showPreview = false;
        } catch (error) {
            console.log('error in TemplatePreviewModal > fileDownloaded', error.message);  
        }
    }

    /**
    *  Method Name : generateDocument
    * @description : Used to generate document.
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    generateDocument(){
        try{
            const previewTimeout = this.template.querySelector('[data-id="previewTimeout"]');

            this.showPreview = true;
            this.isSpinner = true;
            let previousSRC = this.vfGeneratePageSRC;
            let paraData2 = {
                'templateId' : this.templateid,
                'recordId' : this.selectedRecordId,
                'selectedExtension' : '.pdf',
                'selectedChannels' : 'Download',
                'fileName' : this.selectedRecordName
            }
            let paraDataStringify2 = JSON.stringify(paraData2);
            let newSRC = '/apex/MVEX__DocGeneratePage?paraData=' + encodeURIComponent(paraDataStringify2);

            if(newSRC !== previousSRC){
                this.vfGeneratePageSRC = newSRC;
            } else{
                this.vfGeneratePageSRC = '/apex/MVEX__DocGeneratePage';

                previewTimeout?.setCustomTimeoutMethod(() => {
                    this.vfGeneratePageSRC = newSRC;
                }, 300);
            }
        }
        catch(e){
            console.log('Error in generateDocument : ', e.stack);
        }
    }

    /**
    * Method Name : closeTemplatePreview
    * @description: Used to close the modal
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    closeTemplatePreview(){
        try {
            this.showPreview = true;
            this.dispatchEvent(new CustomEvent('closemodal'));
        } catch (error) {
            console.warn('error in TemplatePreviewModal > closeTemplatePreview', error.message);
        }
    }

    /**
    * Method Name : closeGenerate
    * @description: Used to close the modal
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    closeGenerate(){
        try {
            this.isGenerate = false;
        } catch (error) {
            console.log('error in TemplatePreviewModal > closeGenerate', error.message); 
        }
    }

    /**
    * Method Name : runTimeoutMethod
    * @description: Method used to run time out method of timeout method
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    runTimeoutMethod(event){
        try {
            if(event?.detail?.function){
                event.detail.function();
            }
        } catch (error) {
            console.log('error in TemplatePreviewModal > runTimeoutMethod', error.message); 
        }
    }

    /**
    * Method Name : updateRichTextContent
    * @description: Method used to update rich text content convert template body to html element and update html element to rich text content
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    updateRichTextContent() {
        try {
            const richText = this.template.querySelector('.richText');
            if (richText) {
                richText.innerHTML = this.setTempValue(this.templateBody);
                console.log('richText', richText.innerHTML);
            }
        } catch (error) {
            console.log('error in updateRichTextContent : ', error.message);
        }
    }

    /**
    * Method Name: setTempValue
    * @description: Method to convert template body to html element
    * @param: value - String, template body
    * @return: html element
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    setTempValue(value){
        return `<div class=" note-editor2 note-frame2">
                    <div class="note-editing-area2">
                        <div aria-multiline="true" role="textbox" class="note-editable2">
                            ${value}
                        </div>
                    </div> 
                </div>`
    }

    /**
    * Method Name: disconnectedCallback
    * @description: Method to remove event listener on template preview modal
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    disconnectedCallback() {
        try {
            const richTextElement = this.template.querySelector('.richText');
            if (richTextElement) {
                $(richTextElement).summernote('destroy');
            }
        } catch (error) {
            console.error('Error destroying Summernote editor:', error);
        }
    }
}