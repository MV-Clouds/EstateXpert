import { LightningElement, api, track } from "lwc";
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle, loadScript } from "lightning/platformResourceLoader";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getS3ConfigSettings from "@salesforce/apex/ImageAndMediaController.getS3ConfigSettings";
import AWS_SDK from "@salesforce/resourceUrl/AWSSDK";
import summerNoteEditor from "@salesforce/resourceUrl/summerNoteEditor";
import docGeniusLogoSvg from "@salesforce/resourceUrl/docGeniusLogo";
import getTemplateData from '@salesforce/apex/TemplateBuilderController.getTemplateData';
import saveTemplateApex from '@salesforce/apex/TemplateBuilderController.saveTemplateApex';
import saveTempDataRecordsInBatch from '@salesforce/apex/TemplateBuilderController.saveTempDataRecordsInBatch';
import { initializeSummerNote } from './editorConf.js';
import { navigationComps, nameSpace, pageFormats, unitMultiplier, unitConverter, errorDebugger } from 'c/globalProperties';
// import generateTemplate from '@salesforce/apex/GeminiTemplateGenerator.generateTemplate';
// import editTemplateWithGemini from '@salesforce/apex/GeminiTemplateGenerator.editTemplateWithGemini';

export default class TemplateEditor extends NavigationMixin(LightningElement) {

    @track confData;
    @track s3;


    @api templateId;                                // Template Id 
    @api objectName;                                // Source Object API name
    @api activeTabName;
    @api templateType                           // To define active tab

    @track defaultTab = 'contentTab';               // To open default on component load
    @track startchat = true;                        // To used in chatbot
    @track isSpinner = false;                       // To show hide spinner
    @track isPreview = false;                       // To Show hide preview modal
    isInitialRender = true;                         // To check dom and editor rended or not

    @track bodyData = '';                           // To store template main content data.
    @track headerData = '';                         // To store template header data.

    @track templateRecord = {}                      // Store template record field data,
    @track tempRecordBackup = {}                    // for backup to revert template data on cancel click,

    @track vfPageSRC = ''                           // DocGenerate VF page src to generate preview or file,

    @track isMappingContainerExpanded = false;      // #fieldMapping...

    contentEditor;                                  // store initialize main content editor for further process
    headerEditor;                                   // store initialize header editor for further process
    footerEditor;                                   // store initialize footer editor for further process

    valueInserted = false;                          // To check template content data insert or not in editor to stop spinner,
    dataLoaded = false;                             // To check data fetch or not from backed to stop spinner,
    searchFieldValue = '';

    isCloseConfirmation = false                     // To define user click on close button and confirmation popup open
    noTemplateFound = false;                        // To check weather template available for not

    editorDataChanges = false;                      // To identify any editor data change or not

    listingImageCount = 0;                          // To store count of inserted related list table

    // @track aiPrompt = '';
    // @track isGenerating = false;
    @track objectFieldKeys   = [];
    @track generalFieldKeys  = [];
    @track signatureKey      = [];

    /**
     * variable to store page configuration to display on UI, used in HTML
     * value into this variable assigned from Template_Page__c record fetched from backed..
     */
    @track pageConfigs = {
        pageMargins: [
            { name: 'top', value: 1 },
            { name: 'bottom', value: 1 },
            { name: 'left', value: 1 },
            { name: 'right', value: 1 },
        ],
        pageSize: [
            { name: 'A4', value: 'a4', size: '8.27" x 11.69"', selected: true },
            { name: 'A5', value: 'a5', size: '5.83" x 8.27"', selected: false },
            { name: 'Letter', value: 'letter', size: '8.5" x 11"', selected: false },
            { name: 'Legal', value: 'legal', size: '8.5" x 14"', selected: false },
            { name: 'Executive', value: 'executive', size: '7.25" x 10.5"', selected: false },
            { name: 'Statement', value: 'statement', size: '5.5" x 8.25"', selected: false },
        ],
        pageOrientation: [
            { name: 'Portrait', value: 'portrait', selected: true },
            { name: 'Landscape', value: 'landscape', selected: false },
        ],
        unitOptions: [
            { name: 'inch', value: 'in', selected: true },
            { name: 'cm', value: 'cm', selected: false },
            { name: 'px', value: 'px', selected: false },
        ],
        unit: 'in',
        header: {
            show: true,
            marginTop: 10,
        },
        footer: {
            show: true,
            marginBottom: 10,
        }

    }

    /**
     * Used to store value fetched from Template_Page__c record.
     */
    @track pageConfigRecord = {};
    currentPageWidth = 792;             // in PX...
    currentPageHeight = 1120;           // in PX...

    lastRelatedListTableCount = 0;      // Count of inserted relate list (child object) table
    maxRelatedLIstTableLimit = 10;      // Maximum limit of relate list (child object) table

    maxImageSize = 3 * 1024 * 1024;         // Max image size to upload using editor
    allowFileExtensions = ".png,.jpg,.jpeg,.avif,.webp,.heic,.ico,.jfif,.jps,.jpe";       // Allow file extension using editor  

    isPageSetup = false;                    // To defined page setup is open or not
    @track activePageConfigs = [];          // To set by default open page config accordions

    @track isChatOpen = false;
    @track aiPrompt = '';
    @track isGenerating = false;

    @track isEditMode = false;          // false → New, true → Edit
    @track currentTemplateHtml = '';    // header+body+footer (plain HTML)
    @track chatMessages = [];

    // This returns: "ai-chat-container open" or "ai-chat-container"
    get chatContainerClass() {
        return 'ai-chat-container' + (this.isChatOpen ? ' open' : '');
    }

    // Send button disabled when empty or generating
    get isSendButtonDisabled() {
        return this.isGenerating || !this.aiPrompt || this.aiPrompt.trim() === '';
    }

    get placeholderText() {
        return this.isEditMode
            ? 'Tell me how to improve the current template...'
            : 'Ask me to generate or improve your template...';
    }

    get isSendButtonDisabled() {
        return this.isGenerating || !this.aiPrompt?.trim();
    }

    get setdocGeniusLogoSvg() {
        return docGeniusLogoSvg;
    }

    get showTempDetail() {
        return Object.keys(this.templateRecord).length ? true : false;
    }

    get inputStep() {
        switch (this.pageConfigs.unit) {
            case "px":
                return 1;

            case "in":
                return 0.1;

            case "cm":
                return 0.5;
        }
        return 0
    }

    _resolvedPromise = 0;
    get resolvedPromise() { return this._resolvedPromise };
    set resolvedPromise(value) {
        if (value == 2) {
            this.isSpinner = false;
        }
        this._resolvedPromise = value;
    }

    get isForEmail() {
        return this.templateType == 'Marketing Template' ? true : false;
    }

    get storageKey() {
        return `docgenius_template_${this.templateId}_ai_history`;
    }

    get isNewMode() { return !this.isEditMode; }

    connectedCallback() {
        try {
            this.getS3ConfigDataAsync();
            this.currentTab = this.activeTabName ? this.activeTabName : this.defaultTab;
            
            if (this.templateId) {
                this.isSpinner = true;
                this.getTemplateValues();
            }
            else {
                this.noTemplateFound = true;
            }
            this.loadHistoryFromStorage();
            if (typeof window !== 'undefined') {   
                window?.addEventListener('resize', this.resizeFunction);
            }

        } catch (error) {
            errorDebugger('TemplateEditor', 'connectedCallback', error, 'warn');
        }
    }

    renderedCallback() {
        try {
            if (this.isInitialRender) {
                // this.isSpinner = true;
                // ------------------------------------- Editor  -------------------------------------------
                Promise.all([
                    loadScript(this, summerNoteEditor + '/jquery-3.7.1.min.js'),
                ])
                    .then(() => {
                        Promise.all([
                            loadStyle(this, summerNoteEditor + '/summernote-lite.css'),
                            loadScript(this, summerNoteEditor + '/summernote-lite.js'),
                            loadScript(this, AWS_SDK),
                        ])
                            .then(() => {
                                this.isInitialRender = false;
                                this.initialize_Content_Editor();
                                this.initialize_Header_Editor();
                                this.initialize_Footer_Editor();

                                var self = this;
                                if (typeof window !== 'undefined') {
                                    $(document).on("keydown", function (event) {
                                        // if user press clt + s on keyboard
                                        if ((event.key == 's' || event.key == 'S') && (event.ctrlKey || event.metaKey)) {
                                            self.saveTemplateData();
                                        }
                                    });
                                }
                            })
                            .catch(err => {
                                errorDebugger('TemplateEditor', 'renderedCallback', err, 'warn', 'Error To Load summerNoteEditor');
                            })
                    })
                    .catch(error => {
                        errorDebugger('TemplateEditor', 'renderedCallback', error, 'warn', 'Error To Load Jquery');
                    })
                
                this.setActiveTab();
                this._renderChatMessages();
                this.template.querySelector(`[data-name="custom_timeout"]`)?.addEventListener('animationend', this.customTimeoutMethod)
            }

            if (this.noTemplateFound) {
                this.showMessagePopup('Error', 'Error While Fetching Template', 'Template Not Found');
            }
        }
        catch (error) {
            errorDebugger('TemplateEditor', 'renderedCallback', error, 'warn');
        }
    }

    getS3ConfigDataAsync() {
        try {
            getS3ConfigSettings()
                .then(result => {
                    this.showSpinner = false;
                    console.log('result--> ', result);
                    if (result.status) {
                        this.confData = result.awsConfigData;
                        this.initializeAwsSdk(this.confData);
                    }
                }).catch(error => {
                    this.showSpinner = false;
                    console.log('error in apex -> ', error.stack);
                });
        } catch (error) {
            this.showSpinner = false;
            console.log('error in getS3ConfigDataAsync -> ', error.stack);
            
        }
    }

    initialize_Content_Editor() {
        try {
            this.contentEditor = this.template.querySelector(`[data-name="templateContent"]`);
            this.isLoadedSuccessfully = initializeSummerNote(this, docGeniusLogoSvg, 'templateContent');

            if (this.isLoadedSuccessfully == true) {
                this.resizeFunction();
                this.setDataInMainEditor();
                this.resolvedPromise++
            }
            else {
                this.showMessagePopup('Error', 'Error', 'There is Some issue to Load Editor Properly, Please reload current page or try after some time.')
                this.resolvedPromise++
            }
        } catch (error) {
            errorDebugger('TemplateEditor', 'initialize_Content_Editor', error, 'warn');
        }
    }

    initialize_Header_Editor() {
        try {
            this.headerEditor = this.template.querySelector(`[data-name="headerEditor"]`);
            let isLoadedSuccessfully = initializeSummerNote(this, docGeniusLogoSvg, 'headerEditor');

            if (!isLoadedSuccessfully) {
                this.showMessagePopup('Error', 'Error', 'There is Some issue to Load Editor Properly, Please reload current page or try after some time.')
            }
        } catch (error) {
            errorDebugger('TemplateEditor', 'initialize_Header_Editor', error, 'warn');
        }
    }

    initialize_Footer_Editor() {
        try {
            this.footerEditor = this.template.querySelector(`[data-name="footerEditor"]`);
            let isLoadedSuccessfully = initializeSummerNote(this, docGeniusLogoSvg, 'footerEditor');

            if (!isLoadedSuccessfully) {
                this.showMessagePopup('Error', 'Error', 'There is Some issue to Load Editor Properly, Please reload current page or try after some time.')
            }
        } catch (error) {
            errorDebugger('TemplateEditor', 'initialize_Footer_Editor', error, 'warn');
        }
    }

    // Use Arrow Function...
    resizeFunction = () => {
        this.setEditorArea();
    };

    getTemplateValues() {
        try {
            getTemplateData({ templateId: this.templateId })
                .then(result => {
                    if (result.isSuccess) {
                        this.templateRecord = result.template;
                        this.templateRecord.createDateOnly = this.templateRecord.CreatedDate.split("T")[0];
                        this.tempRecordBackup = JSON.parse(JSON.stringify(this.templateRecord));
                        this.bodyData = '';
                        this.headerData = '';
                        this.footerData = '';
                        this.pageConfigRecord = result.pageConfigs;
                        this.pageConfigRecBackup = JSON.parse(JSON.stringify(this.pageConfigRecord));

                        // Collect Value in Single variable...
                        result.template.MVEX__Template_Data__r?.forEach(ele => {
                            if (ele.MVEX__Value_Type__c == 'Body Value') {
                                this.bodyData += ele.MVEX__Template_Value_Simple__c ? ele.MVEX__Template_Value_Simple__c : '';
                            }
                            else if (ele.MVEX__Value_Type__c == 'Header Value') {
                                this.headerData = ele.Template_Value_Simple__c ? ele.MVEX__Template_Value_Simple__c : '';
                            }
                            else if (ele.MVEX__Value_Type__c == 'Footer Value') {
                                this.footerData = ele.MVEX__Template_Value_Simple__c ? ele.MVEX__Template_Value_Simple__c : '';
                            }
                        });

                        this.dataLoaded = true;
                        this.setPageConfigVariable();
                        this.setDataInMainEditor();
                        this.setDataInHeader();
                        this.setDataInFooter();

                        delete this.templateRecord['MVEX__Template_Data__r'];

                        this.resolvedPromise++
                    }
                    else {
                        this.resolvedPromise++
                        this.noTemplateFound = true;
                        this.showMessagePopup('Error', 'Error While Fetching Template Data', result.returnMessage);
                    }
                })
                .catch(error => {
                    this.resolvedPromise++
                    errorDebugger('TemplateEditor', 'getTemplateValues', error, 'warn', 'Error in getTemplateData APEX Method.');
                })
        } catch (error) {
            errorDebugger('TemplateEditor', 'getTemplateValues', error, 'warn');
        }
    }

    setDataInMainEditor() {
        try {
            if (this.contentEditor && this.dataLoaded && !this.valueInserted) {
                $(this.contentEditor).summernote('code', this.bodyData);
                this.setEditorPageSize();
                this.valueInserted = true;
            }
        } catch (error) {
            errorDebugger('TemplateEditor', 'setDataInMainEditor', error, 'warn');
        }
    }

    setDataInHeader() {
        if (this.headerEditor && this.dataLoaded) {
            $(this.headerEditor).summernote('code', this.headerData);
        }
    }

    setDataInFooter() {
        if (this.footerEditor && this.dataLoaded) {
            $(this.footerEditor).summernote('code', this.footerData);
            this.setPageHeaderFooterMargin()
        }
    }

    // ==> Save methods
    saveTemplateData(event) {
        this.listingImageCount = event.detail;
        if (this.lastRelatedListTableCount <= this.maxRelatedLIstTableLimit) {
            if (this.templateRecord?.MVEX__Template_Name__c) {
                this.isSpinner = true;
                this.saveTemplateValue('save');
            }
            else {
                this.showMessagePopup('error', 'Template Name Empty!', `Template Name is Required, You can not save template without a name.`);
            }
        }
        else {
            this.showMessagePopup('error', 'Warning !', `Related List Table Limit Exceeded. You Can Not Add More Then ${this.maxRelatedLIstTableLimit} Related List Tables.`);
        }
    }

    async saveTemplateValue(actionName) {
        try {
            /**
            * To get editor content, do not use .summernote('code') directly, 
            * Please create dom element and add innerHTML into it and then get that element's innerHTML as editor content,
            * This is doing in order to maintain formatting with extracted child table,
            * If we directly use .summernote('code') method to get editor content, it result in unmatched attribute position for child table during the document creation...
            */

            let headerEle, footerEle, bodyEle;

            if (typeof window !== 'undefined') {   
                headerEle = document.createElement('div');
                headerEle.innerHTML = $(this.headerEditor).summernote('code');
                
                footerEle = document.createElement('div');
                footerEle.innerHTML = $(this.footerEditor).summernote('code');
                
                bodyEle = document.createElement('div');
                bodyEle.innerHTML = $(this.contentEditor).summernote('code');
            }

            if (this.templateType === 'Marketing Template') {
                await this.uploadBase64ImagesToAWS(bodyEle);
            }

            this.headerData = headerEle.innerHTML;
            this.bodyData = bodyEle.innerHTML;
            this.footerData = footerEle.innerHTML;

            // extract mapping keys...
            let extractedMappingKeys = this.extractMappingKeys();

            // Separate Template Data By Long TExt area Length....
            let splitLength = 130000;       // character length to store in long text area....
            // (1 record (Portion) = 130000 character = 0.13 MB => 30 records = 3.9 MB )
            let batchSize = 30;             // number of template data records (portions) in single batch...
            let totalBatches = 0;

            let headerDataRecords = [];
            let footerDataRecords = [];
            let bodyDataRecords = [];

            // separate header value by 130000 characters...
            let headerDataPortions = Math.ceil(this.headerData.length / splitLength);
            for (let i = 1; i <= headerDataPortions; i++) {
                let startIndex = (i - 1) * splitLength;
                let endIndex = i == headerDataPortions ? this.headerData.length : (i * splitLength);
                headerDataRecords.push(this.headerData.substring(startIndex, endIndex));
            }

            // separate footer value by 130000 characters...
            let footerDataPortions = Math.ceil(this.footerData.length / splitLength);
            for (let i = 1; i <= footerDataPortions; i++) {
                let startIndex = (i - 1) * splitLength;
                let endIndex = i == footerDataPortions ? this.footerData.length : (i * splitLength);
                footerDataRecords.push(this.footerData.substring(startIndex, endIndex));
            }

            // separate body value by 130000 characters...
            let bodyDataPortions = Math.ceil(this.bodyData.length / splitLength);
            for (let i = 1; i <= bodyDataPortions; i++) {
                let startIndex = (i - 1) * splitLength;
                let endIndex = i == bodyDataPortions ? this.bodyData.length : (i * splitLength);
                bodyDataRecords.push(this.bodyData.substring(startIndex, endIndex));
            }

            // merge body, header, footer and extracted key values in single object to send to apex...
            let templateValuePortion = {
                'Header Value': headerDataRecords,
                'Footer Value': footerDataRecords,
                'Extracted Mapping Keys': [JSON.stringify(extractedMappingKeys)],
            }

            let bodyDataBatchesByMB = [];
            // if total data portion is lesser than 30 =>  30 * 1,30,000 = 3.9 MB
            // means total data is lesser than 4 MB (around 3.64MB)... so send all data in one apex call...
            if ((headerDataPortions + footerDataPortions + bodyDataPortions) < batchSize) {
                templateValuePortion['Body Value'] = bodyDataRecords;
            }
            else {
                // else data may be larger data 4MB... so Send Body Value is batches....
                totalBatches = Math.ceil(bodyDataRecords.length / batchSize);
                for (let i = 1; i <= totalBatches; i++) {
                    let start = (i - 1) * batchSize;
                    let end = i * batchSize > bodyDataRecords.length ? bodyDataRecords.length : (i * batchSize) - 1;
                    const currentBatchRecords = {};
                    for (let j = start; j <= end; j++) {
                        currentBatchRecords[j + 1] = bodyDataRecords[j];
                    }
                    bodyDataBatchesByMB.push(currentBatchRecords);
                }
            }

            let totalProcesses = totalBatches + 1;
            let completedProcess = 0;

            // Call Apex Method to save Template...
            saveTemplateApex({ templateRecord: this.templateRecord, templateValues: templateValuePortion, pageConfigs: this.pageConfigRecord, listingCount: this.listingImageCount })
                .then((result) => {
                    if (result) {
                        completedProcess++;
                        this.handleOngoingAction(actionName, completedProcess, totalProcesses);
                        this.tempRecordBackup = JSON.parse(JSON.stringify(this.templateRecord));
                        this.pageConfigRecBackup = JSON.parse(JSON.stringify(this.pageConfigRecord));
                    }
                    else {
                        completedProcess++;
                        this.isSpinner = this.stopSpinner(completedProcess, totalProcesses);
                        errorDebugger('TemplateEditor', 'saveTemplateValue', result, 'warn', 'Error in saveTemplateApex APEX Method');
                    }
                })
                .catch(error => {
                    errorDebugger('TemplateEditor', 'saveTemplateValue', error.stack, 'warn');
                    completedProcess++;
                    this.isSpinner = this.stopSpinner(completedProcess, totalProcesses);
                })

            const tempIdVsValueType = {};
            tempIdVsValueType[this.templateRecord.Id] = 'Body Value';
            // will execute when we required to save data in batch (totalBatches < 0)...
            for (let i = 1; i <= totalBatches; i++) {
                const isLastBatch = i == totalBatches ? true : false;
                saveTempDataRecordsInBatch({ templateDataList: bodyDataBatchesByMB[i - 1], tempIdVsValueType: tempIdVsValueType, isLastBatch: isLastBatch })
                    .then((result) => {
                        if (result) {
                            completedProcess++;
                            this.handleOngoingAction(actionName, completedProcess, totalProcesses);
                        }
                        else {
                            completedProcess++;
                            this.isSpinner = this.stopSpinner(completedProcess, totalProcesses);
                            errorDebugger('TemplateEditor', 'saveTemplateValue', {'message' : result.returnMessage}, 'warn', 'Error in saveTempDataRecordsInBatch APEX Method');
                        }
                    })
                    .catch((error) => {
                        completedProcess++;
                        this.isSpinner = this.stopSpinner(completedProcess, totalProcesses);
                        errorDebugger('TemplateEditor', 'saveTemplateValue', error, 'warn', 'Error in saveTempDataRecordsInBatch APEX Method');
                    })
            }

        } catch (error) {
            this.isSpinner = false;
            errorDebugger('TemplateEditor', 'saveTemplateValue', error, 'warn', `Error during ${actionName}`);
        }
    }

    async uploadBase64ImagesToAWS(bodyEle) {
        if (typeof bodyEle === 'string') {
            bodyEle = this.template.querySelector(bodyEle);
        }
        const images = bodyEle.querySelectorAll('img');

        // Check if there are no images in the body element
        if (images.length === 0) {
            return; // Exit if no images are found
        }

        for (let i = 0; i < images.length; i++) {
            const img = images[i];
            const src = img.getAttribute('src');
            if (src && src.startsWith('data:image/')) {
                const base64String = src;
                const awsUrl = await this.uploadToAWS(base64String);

                img.setAttribute('src', awsUrl);
            }
        }
    }

    initializeAwsSdk(confData) {
        try {
            let AWS = window?.globalThis?.AWS;

            AWS.config.update({
                accessKeyId: confData.MVEX__AWS_Access_Key__c,
                secretAccessKey: confData.MVEX__AWS_Secret_Access_Key__c
            });

            AWS.config.region = confData.MVEX__S3_Region_Name__c;

            this.s3 = new AWS.S3({
                apiVersion: "2006-03-01",
                params: {
                    Bucket: confData.MVEX__S3_Bucket_Name__c
                }
            });


        } catch (error) {
            this.showSpinner = false;
            console.log("error initializeAwsSdk ", error);
            errorDebugger('TemplateEditor', 'saveTemplateValue', error.stack, 'error');
        }
    }

    async uploadToAWS(base64Data) {
        try {
            // Extract the content type (e.g., 'image/jpeg', 'image/png') from the base64 data
            const contentType = base64Data.substring(base64Data.indexOf(':') + 1, base64Data.indexOf(';'));

            // Extract the base64 string (the actual image data)
            const base64String = base64Data.split(',')[1];

            // Check if the base64 string is valid
            if (!base64String) {
                throw new Error('Invalid base64 string.');
            }

            // Convert the base64 string to a Uint8Array
            const byteCharacters = this._base64ToByteArray(base64String);

            const blobData = new Blob([byteCharacters], { type: contentType });

            // Generate a unique file name with the correct file extension
            const extension = contentType.split('/')[1]; // e.g., 'jpeg', 'png'
            const uniqueFileName = `image_${new Date().getTime()}.${extension}`;

            // AWS S3 upload parameters
            let params = {
                Key: uniqueFileName,
                ContentType: contentType, // Use the correct content type
                Body: blobData,           // Use the Blob as the Body
                ACL: "public-read"
            };

            // Upload to S3
            let upload = this.s3.upload(params);
            const result = await upload.promise();

            // Construct the file URL
            const bucketName = this.confData.MVEX__S3_Bucket_Name__c;
            const fileURL = `https://${bucketName}.s3.amazonaws.com/${result.Key}`;
            return fileURL;

        } catch (error) {
            console.error("Error in uploadToAWS: ", error.message);
            throw error;
        }
    }

    // Helper function to convert base64 string to Uint8Array
    _base64ToByteArray(base64) {
        const binaryString = window?.globalThis?.atob(base64); // Ensure you handle the base64 correctly here
        const len = binaryString.length;
        const bytes = new Uint8Array(len);
        for (let i = 0; i < len; i++) {
            bytes[i] = binaryString.charCodeAt(i);
        }
        return bytes;
    }


    handleOngoingAction(actionName, completedProcess, totalProcesses) {
        try {
            this.isSpinner = this.stopSpinner(completedProcess, totalProcesses);
            if (!this.isSpinner) {
                if (actionName == 'save') {
                    this.showToast('Success', 'Template Saved Successfully.', 'success');
                }
                else if (actionName == 'preview') {
                    this.template.querySelector(`[data-name="custom_timeout"]`).classList.add('dummyAnimation');
                    this.isPreview = true;
                }
            }
        } catch (error) {
            errorDebugger('TemplateEditor', 'handleOngoingAction', error, 'warn');
        }
    }

    stopSpinner(completedProcess, totalProcesses) {
        return completedProcess == totalProcesses ? false : true;
    }

    handleCloseEdit() {
        try {
            this.isCloseConfirmation = true;
            this.showMessagePopup('Warning', 'Do You Want to Leave?', `Your unsaved changes will be discarded once you leave the this page.`);

        } catch (error) {
            errorDebugger('TemplateEditor', 'handleCloseEdit', error, 'warn');
        }
    }

    closeEditTemplate() {
        try {
            $(this.contentEditor)?.summernote('destroy');
            this.navigateToComp(navigationComps.home);

        } catch (error) {
            errorDebugger('TemplateEditor', 'closeEditTemplate', error, 'warn');
        }
    }

    cancelEditTemplate() {
        this.templateRecord = JSON.parse(JSON.stringify(this.tempRecordBackup));
        this.pageConfigRecord = JSON.parse(JSON.stringify(this.pageConfigRecBackup));

        this.setPageConfigVariable();
        this.currentTab = 'contentTab';
        this.setActiveTab();
    }

    handleSaveNPreview(event) {
        this.listingImageCount = event.detail;
        if (this.lastRelatedListTableCount <= this.maxRelatedLIstTableLimit) {
            if (this.templateRecord?.MVEX__Template_Name__c) {
                this.isSpinner = true;
                this.saveTemplateValue('preview');
            }
            else {
                this.showMessagePopup('error', 'Template Name Empty!', `Template Name is Required, You can not save template without a name.`);
            };
        }
        else {
            this.showMessagePopup('error', 'Warning !', `Related List Table Limit Exceeded. You Can Not Add More Then ${this.maxRelatedLIstTableLimit} Related List Tables.`);
        }
    }

    vfPageLoaded() {
        try {
            this.isSpinner = false;
            // const iframe = this.template.querySelector('iframe');
            // const pdfViewer = iframe.querySelector('pdf-viewer');
        } catch (error) {
            errorDebugger('TemplateEditor', 'vfPageLoaded', error, 'warn');
        }
    }

    closeTemplatePreview() {
        try {
            this.isPreview = false;
        } catch (error) {
            errorDebugger('TemplateEditor', 'closeTemplatePreview', error, 'warn');
        }
    }

    // ==== Toggle Tabs Methods - START - ========
    activeTab(event) {
        try {
            if (event) {
                this.currentTab = event.currentTarget.dataset.name;
            }
            this.setActiveTab();
        } catch (error) {
            errorDebugger('TemplateEditor', 'activeTab', error, 'warn');
        }
    }

    setActiveTab() {
        try {
            const activeTabBar = this.template.querySelector(`.activeTabBar`);
            const tabS = this.template.querySelectorAll('.tab');

            tabS.forEach(ele => {
                if (ele.dataset.name == this.currentTab) {
                    ele.classList.add('activeT');
                    activeTabBar.style = ` transform: translateX(${ele.offsetLeft}px);
                                    width : ${ele.clientWidth}px;`;
                }
                else {
                    ele.classList.remove('activeT');
                }
            })

            const sections = this.template.querySelectorAll('.tabArea');
            sections.forEach(ele => {
                if (ele.dataset.section == this.currentTab) {
                    ele.classList.remove('deactiveTabs');
                    this.setKeyMappingVisibility(JSON.parse(ele.dataset.keyMapping.toLowerCase()));
                    this.setToolbarAreaVisibility(JSON.parse(ele.dataset.toolbar.toLowerCase()));
                }
                else if (ele.dataset.section == 'aiGenerateTab') {
                    // Explicitly hide key mapping and toolbar for AI Generate tab
                    ele.classList.add('deactiveTabs');
                    // this.setKeyMappingVisibility(false);
                    // this.setToolbarAreaVisibility(false);
                }
                else {
                    ele.classList.add('deactiveTabs');
                }
            });

            // this.currentTab === 'basicTab' && this.setDummyPageSize();
        } catch (error) {
            errorDebugger('TemplateEditor', 'setActiveTab', error, 'warn');
        }
    }

    setKeyMappingVisibility(isTrue) {
        const keyMappingSection = this.template.querySelector('c-key-mapping-container');
        if (isTrue) {
            keyMappingSection?.classList.add('displayFieldMappings');
        }
        else {
            keyMappingSection?.classList.remove('displayFieldMappings');
        }
    }

    setToolbarAreaVisibility(isTrue) {
        const tabSection = this.template.querySelector('.tabSection');
        if (isTrue) {
            tabSection?.classList.remove('hideToolbar');
        }
        else {
            tabSection?.classList.add('hideToolbar');
        }
    }
    // ==== Toggle Tabs Methods - END - ========

    // #fieldMapping...
    toggleMappingContainerHeight() {
        try {
            const keyMappingContainer = this.template.querySelector('c-key-mapping-container');
            if (this.isMappingContainerExpanded) {
                this.isMappingContainerExpanded = false;
                keyMappingContainer.style = ``;
            }
            else {
                this.isMappingContainerExpanded = true;
                keyMappingContainer.style = ` height : calc(100% - 0.9rem);
                                                top : 0.1rem;`;
            }
        } catch (error) {
            errorDebugger('TemplateEditor', 'toggleMappingContainerHeight', error, 'warn');
        }
    }

    handleEditDetail(event) {
        try {
            const targetInput = event.currentTarget.dataset.name;
            if (event.target.type === 'checkbox') {
                this.templateRecord[targetInput] = event.target.checked;
            }
            else {
                this.templateRecord[targetInput] = (event.target.value).trim();
            }
        } catch (error) {
            errorDebugger('TemplateEditor', 'handleEditDetail', error, 'warn');
        }
    }

    // ==== === === === PAGE Config and PAGE Size Setup Method --- START --- ==== ===== ===== =====

    // Function -- run when change page config values from UI...
    // To set page config on in pageConfigs variable and pageConfigRecord Object ...
    managePageConfigs(event) {
        try {
            const pageConfig = event.currentTarget.dataset.config;
            const configName = event.currentTarget.dataset.name;
            const value = event.target.value;

            if (pageConfig == 'pageOrientation' || pageConfig == 'pageSize') {
                this.pageConfigs[pageConfig].forEach(ele => {
                    ele.selected = ele.name == configName ? true : false;
                })

                this.pageConfigRecord.MVEX__Page_Orientation__c = pageConfig == 'pageOrientation' ? value : this.pageConfigRecord.MVEX__Page_Orientation__c;
                this.pageConfigRecord.MVEX__Page_Size__c = pageConfig == 'pageSize' ? value : this.pageConfigRecord.MVEX__Page_Size__c;

            }
            else if (pageConfig == 'unitOptions') {
                this.pageConfigs[pageConfig].forEach(ele => {
                    ele.selected = ele.value == value ? true : false;
                });
                this.pageConfigs['unit'] = value;

                this.convertConfigValue(this.pageConfigRecord.MVEX__Unit_of_Page_Configs__c, value);
                this.pageConfigRecord.MVEX__Unit_of_Page_Configs__c = value;

            }
            else if (pageConfig == 'pageMargins') {
                this.pageConfigs[pageConfig].find(ele => ele.name == configName).value = value;

            }
            else if (pageConfig == 'header' || pageConfig == 'footer') {
                if (configName == 'show') {
                    this.pageConfigs[pageConfig][configName] = event.target.checked;
                }
                else {
                    this.pageConfigs[pageConfig][configName] = value ? value : 0;
                }
            }

            this.setPageMarginValue();                  // Do not remove it, it is added intentionally
            this.setHeaderFooterMargin();               // Do not remove it, it is added intentionally
            this.setEditorPageSize();
            (pageConfig != 'pageMargins') && this.setPageMarginValue();
            (pageConfig != 'header' && pageConfig != 'footer') && this.setHeaderFooterMargin();
        } catch (error) {
            errorDebugger('TemplateEditor', 'managePageConfigs', error, 'warn');
        }
    }

    // Function Set Page Margin value from pageConfig variable to pageConfigRecord Object for the backend side work...
    setPageMarginValue() {
        try {
            let pageMarginsTop = this.pageConfigs['pageMargins'][0].value;
            let pageMarginsBottom = this.pageConfigs['pageMargins'][1].value;
            let pageMarginsLeft = this.pageConfigs['pageMargins'][2].value;
            let pageMarginsRight = this.pageConfigs['pageMargins'][3].value;

            let k = unitMultiplier(this.pageConfigRecord.MVEX__Unit_of_Page_Configs__c) * 1.3334;

            pageMarginsTop = pageMarginsTop ? pageMarginsTop : 0;
            pageMarginsTop = Math.max(pageMarginsTop, 0);

            pageMarginsBottom = pageMarginsBottom ? pageMarginsBottom : 0;
            pageMarginsBottom = Math.max(pageMarginsBottom, 0);

            pageMarginsLeft = pageMarginsLeft ? pageMarginsLeft : 0;
            pageMarginsLeft = Math.max(pageMarginsLeft, 0);

            pageMarginsRight = pageMarginsRight ? pageMarginsRight : 0;
            pageMarginsRight = Math.max(pageMarginsRight, 0);

            // restrict margin/padding to exceed page page width/height....
            // when margin value is more than page width/height - opposite margin value... restrict to increase margin value...

            // configName == 'top' 
            pageMarginsTop = Math.min(pageMarginsTop, (this.currentPageHeight / k - pageMarginsBottom))
            pageMarginsTop = Math.max(pageMarginsTop, 0);
            (this.pageConfigs['pageMargins'][0].value = pageMarginsTop);

            // configName == 'bottom'
            pageMarginsBottom = Math.min(pageMarginsBottom, (this.currentPageHeight / k - pageMarginsTop))
            pageMarginsBottom = Math.max(pageMarginsBottom, 0);
            (this.pageConfigs['pageMargins'][1].value = pageMarginsBottom);

            // configName == 'left'
            pageMarginsLeft = Math.min(pageMarginsLeft, (this.currentPageWidth / k - pageMarginsRight))
            pageMarginsLeft = Math.max(pageMarginsLeft, 0);
            (this.pageConfigs['pageMargins'][2].value = pageMarginsLeft);

            // configName == 'right'
            pageMarginsRight = Math.min(pageMarginsRight, (this.currentPageWidth / k - pageMarginsLeft))
            pageMarginsRight = Math.max(pageMarginsRight, 0);
            (this.pageConfigs['pageMargins'][3].value = pageMarginsRight);

            this.pageConfigRecord.MVEX__Page_Margin__c = pageMarginsTop + ';' + pageMarginsBottom + ';' + pageMarginsLeft + ';' + pageMarginsRight;
        } catch (error) {
            errorDebugger('TemplateEditor', 'setPageMarginValue', error, 'warn');
        }
    }

    // Set Header(top) and footer(bottom) editor margin in config variable...
    setHeaderFooterMargin() {
        try {
            let k = unitMultiplier(this.pageConfigRecord.MVEX__Unit_of_Page_Configs__c) * 1.3334;
            let pageHeight = this.currentPageHeight / k;

            if (this.pageConfigs.header.marginTop > pageHeight * 0.4) {
                this.pageConfigs.header.marginTop = pageHeight * 0.4
            }
            else if (this.pageConfigs.header.marginTop < 0) {
                this.pageConfigs.header.marginTop = 0;
            }

            if (this.pageConfigs.footer.marginBottom > pageHeight * 0.4) {
                this.pageConfigs.footer.marginBottom = pageHeight * 0.4;
            }
            else if (this.pageConfigs.footer.marginBottom < 0) {
                this.pageConfigs.footer.marginBottom = 0;
            }

            this.pageConfigRecord.MVEX__Show_Header__c = this.pageConfigs.header.show;
            this.pageConfigRecord.MVEX__Header_margin_top__c = this.pageConfigs.header.marginTop;

            this.pageConfigRecord.MVEX__Show_Footer__c = this.pageConfigs.footer.show;
            this.pageConfigRecord.MVEX__Footer_margin_bottom__c = this.pageConfigs.footer.marginBottom;

            this.setPageHeaderFooterMargin();

        } catch (error) {
            errorDebugger('TemplateEditor', 'setHeaderFooterMargin', error, 'warn');
        }
    }

    // Set Header(top) and footer(bottom) editor margin in editor page...
    setPageHeaderFooterMargin() {
        if (typeof window !== 'undefined') {
            const root = document?.querySelector(':root');
            let unit = this.pageConfigRecord.MVEX__Unit_of_Page_Configs__c;

            root.style.setProperty('--headerMarginsTop', `${this.pageConfigs.header.marginTop}${unit}`);
            root.style.setProperty('--footerMarginsBottom', `${this.pageConfigs.footer.marginBottom}${unit}`);
        }
    }

    convertConfigValue(previousUnit, currentUnit) {
        try {
            this.pageConfigs.pageMargins.forEach(ele => {
                ele.value = unitConverter(previousUnit, currentUnit, ele.value);
            })

            this.pageConfigs.header.marginTop = unitConverter(previousUnit, currentUnit, this.pageConfigs.header.marginTop);
            this.pageConfigs.footer.marginBottom = unitConverter(previousUnit, currentUnit, this.pageConfigs.footer.marginBottom);

        } catch (error) {
            errorDebugger('TemplateEditor', 'convertConfigValue', error, 'warn');
        }
    }

    // === ==== === Function to Set template page record's value in pageConfig variable to display in UI/Front-End.. === === ===
    setPageConfigVariable() {
        try {
            this.pageConfigs['pageMargins'][0].value = this.pageConfigRecord.MVEX__Page_Margin__c.split(';')[0];
            this.pageConfigs['pageMargins'][1].value = this.pageConfigRecord.MVEX__Page_Margin__c.split(';')[1];
            this.pageConfigs['pageMargins'][2].value = this.pageConfigRecord.MVEX__Page_Margin__c.split(';')[2];
            this.pageConfigs['pageMargins'][3].value = this.pageConfigRecord.MVEX__Page_Margin__c.split(';')[3];

            this.pageConfigs['pageOrientation'].forEach(ele => {
                ele['selected'] = ele.value == this.pageConfigRecord.MVEX__Page_Orientation__c ? true : false;
            });

            this.pageConfigs['pageSize'].forEach(ele => {
                ele['selected'] = ele.value == this.pageConfigRecord.MVEX__Page_Size__c ? true : false;
            });

            this.pageConfigs['unitOptions'].forEach(ele => {
                ele['selected'] = ele.value == this.pageConfigRecord.MVEX__Unit_of_Page_Configs__c ? true : false;
            });

            this.pageConfigs['unit'] = this.pageConfigRecord.MVEX__Unit_of_Page_Configs__c;

            if (this.contentEditor && this.dataLoaded) {
                this.setEditorPageSize();
            }

            this.pageConfigs.header.show = this.templateType == 'Marketing Template' ? false : this.pageConfigRecord.MVEX__Show_Header__c;
            this.pageConfigs.header.marginTop = this.pageConfigRecord.MVEX__Header_margin_top__c;

            this.pageConfigs.footer.show = this.templateType == 'Marketing Template' ? false : this.pageConfigRecord.MVEX__Show_Footer__c;
            this.pageConfigs.footer.marginBottom = this.pageConfigRecord.MVEX__Footer_margin_bottom__c;

        } catch (error) {
            errorDebugger('TemplateEditor', 'setPageConfigVariable', error, 'warn');
        }
    }

    // Set all Editor page size based on page config changes...
    setEditorPageSize() {
        try {
            let root;
            if (typeof window !== 'undefined') {   
                root = document?.querySelector(':root');
            }

            let pageMarginsTop = this.pageConfigRecord.MVEX__Page_Margin__c.split(';')[0];
            let pageMarginsBottom = this.pageConfigRecord.MVEX__Page_Margin__c.split(';')[1];
            let pageMarginsLeft = this.pageConfigRecord.MVEX__Page_Margin__c.split(';')[2];
            let pageMarginsRight = this.pageConfigRecord.MVEX__Page_Margin__c.split(';')[3];

            let unit = this.pageConfigRecord.MVEX__Unit_of_Page_Configs__c;
            let pageSize = this.pageConfigRecord.MVEX__Page_Size__c;
            let orientation = this.pageConfigRecord.MVEX__Page_Orientation__c;

            this.currentPageWidth = (orientation == 'portrait' ? pageFormats[pageSize][0] : pageFormats[pageSize][1]) * 1.3334;
            this.currentPageHeight = (orientation == 'portrait' ? pageFormats[pageSize][1] : pageFormats[pageSize][0]) * 1.3334;

            root.style.setProperty('--pageWidth', `${this.currentPageWidth}px`);
            root.style.setProperty('--pageHeight', `${this.currentPageHeight}px`);
            root.style.setProperty('--pageMarginTop', `${pageMarginsTop}${unit}`);
            root.style.setProperty('--pageMarginBottom', `${pageMarginsBottom}${unit}`);
            root.style.setProperty('--pageMarginLeft', `${pageMarginsLeft}${unit}`);
            root.style.setProperty('--pageMarginRight', `${pageMarginsRight}${unit}`);

            this.setEditorArea();
            // this.setDummyPageSize();

        } catch (error) {
            errorDebugger('TemplateEditor', 'setEditorPageSize', error, 'warn');
        }
    }

    // Set keyMapping container and editor area as per page size....
    setEditorArea() {
        try {
            let root;
            if (typeof window !== 'undefined') {
                root = document?.querySelector(':root');
            }
            let keyMappingContainer = this.template.querySelector('c-key-mapping-container');

            if (typeof window !== 'undefined') {   
                if(window.innerWidth > 1350){
                    // Here, Windows.innerWidth represent the width of contentEditorFrame/(.note-frame) width;
                    const mapContainerWidth = (window?.innerWidth >= 1440 ? (35 * 16) : (30 * 16)) + 32;
                    if(window?.innerWidth - this.currentPageWidth < mapContainerWidth){
                        //  If difference Screen width and editor page width is less than key Mapping container width... 
                        // key Mapping container can not set in that place... So Toggle the container
                        keyMappingContainer?.toggleMappingContainer(true);
                        root.style.setProperty('--editingAreaWidth', 'calc(100% - 2rem)');
                    }
                    else{
                        // Show field Mapping Container
                        keyMappingContainer?.toggleMappingContainer(false);
                        
                        root.style.setProperty('--editingAreaWidth', `calc(100% - var(--keyMappingWidth) - 1.25rem)`);
                    }
                }
                else{
                    // Hide field Mapping Container
                    // Show Button ( << Insert Field Button) to Open Field Mapping...
                    keyMappingContainer?.toggleMappingContainer(true);
                    // Set Editor Page CSS....
                    root.style.setProperty('--editingAreaWidth', 'calc(100% - 2rem)');
                }
            }

        } catch (error) {
            errorDebugger('TemplateEditor', 'setEditorArea', error, 'warn');
        }
    }

    setDummyPageSize() {
        try {
            let pageMarginsTop = this.pageConfigRecord.MVEX__Page_Margin__c.split(';')[0];
            let pageMarginsBottom = this.pageConfigRecord.MVEX__Page_Margin__c.split(';')[1];
            let pageMarginsLeft = this.pageConfigRecord.MVEX__Page_Margin__c.split(';')[2];
            let pageMarginsRight = this.pageConfigRecord.MVEX__Page_Margin__c.split(';')[3];

            let unit = this.pageConfigRecord.MVEX__Unit_of_Page_Configs__c;
            let aspectRatio = this.currentPageWidth / this.currentPageHeight;

            const dummyPage = this.template.querySelector('.dummyPage');
            dummyPage.style = `aspect-ratio : ${aspectRatio}`;
            const dummyPageWidth = dummyPage?.clientWidth;
            const m = dummyPageWidth / this.currentPageWidth;
            dummyPage.style = ` padding : ${pageMarginsTop * m}${unit} ${pageMarginsRight * m}${unit} ${pageMarginsBottom * m}${unit} ${pageMarginsLeft * m}${unit} !important;
                                aspect-ratio : ${aspectRatio}`;
        } catch (error) {
            errorDebugger('TemplateEditor', 'setDummyPageSize', error, 'warn');
        }
    }
    // ==== === === === PAGE Config and PAGE Size Setup Method --- END --- ==== ===== ===== =====


    selectAllOnFocus(event) {
        event.target.select();
    }

    // === ==== ==== Child Record table Generation Method -- START --- === === === ====
    openGenChildTablePopup(event) {
        const childObjectTableBuilder = this.template.querySelector('c-child-object-table-builder');
        childObjectTableBuilder && childObjectTableBuilder.openPopup(event);
    }

    closeGenChildTable() {
        const childObjectTableBuilder = this.template.querySelector('c-child-object-table-builder');
        childObjectTableBuilder && childObjectTableBuilder.closePopup();
    }
    // === ==== ==== Child Record table Generation Method -- END --- === === === ====


    // === ==== ==== ==== ==== Method called from EditorConfig JS -- START--  === ==== ==== ==== ==== ====
    //  Method to Calculation Related List (Child Table) --- ---- -----
    calculateRelatedListTable(note) {
        try {
            const keyMappingChildComp = this.template.querySelector('c-key-mapping-container ');
            if (keyMappingChildComp) {
                const page = note.noteEditorFrame.querySelector('.note-editable');
                let relatedListTables = page?.querySelectorAll(`[data-name="childRecords"]`);

                let validTableCount = 0;
                relatedListTables?.forEach(ele => {
                    if (ele.querySelector('[data-name="keyRow"]') &&
                        ele.querySelector('[data-name="infoRow"]')) {
                        validTableCount++;
                    }
                })

                if (validTableCount >= this.maxRelatedLIstTableLimit) {
                    // When Limit Exceed
                    keyMappingChildComp.relatedListTableLimitExceed(true);
                }
                else if (validTableCount != this.lastRelatedListTableCount) {
                    keyMappingChildComp.relatedListTableLimitExceed(false);
                }
                this.lastRelatedListTableCount = validTableCount;
            }
        } catch (error) {
            errorDebugger('TemplateEditor', 'calculateRelatedListTable', error, 'warn');
        }
    }

    setHeaderFooterMaxHeight(note, event) {
        try {
            if(note.selector == 'headerEditor' || note.selector == 'footerEditor'){
                const page = note.noteEditorFrame?.querySelector('.note-editable');
                page.scrollTop = 0;
                const pageRect = page.getBoundingClientRect();

                if(event){
                    let selection
                    if (typeof window !== 'undefined') {   
                        selection = window?.getSelection();
                    }
                    const cursorNode = selection?.anchorNode;
                    const cursorNodeRect = cursorNode && cursorNode.nodeName !== "#text" ? cursorNode.getBoundingClientRect() : null;
                    if(cursorNodeRect?.bottom > pageRect.bottom){
                        event.preventDefault();
                    }
                }
                else{
                    const content = page.querySelectorAll('*');
                    content?.forEach(ele => {
                        const eleRect = ele.getBoundingClientRect();
                        if(eleRect.top > pageRect.bottom){
                            ele.remove();
                        }
                    })
                }

            }
        } catch (error) {
            errorDebugger('TemplateEditor', 'setHeaderFooterMaxHeight', error, 'warn');
        }
    }

    restrictLargeImageInsert(note) {
        try {
            const page = note.noteEditorFrame?.querySelector('.note-editable');
            const images = page?.querySelectorAll('img');
            images?.forEach(ele => {
                if (ele.src.startsWith('data:image/')) {
                    const base64 = ele.src.split(',')[1];
                    const imageSize = base64.length * 3 / 4;
                    if (imageSize > this.maxImageSize) {
                        ele.remove();
                        this.showMessageToast('error', 'Image size larger than 3 MB', 'You can only insert image upto 3 MB.')
                    }
                }
            })
        } catch (error) {
            errorDebugger('TemplateEditor', 'restrictLargeImageInsert', error, 'warn');
        }
    }

    togglePageConfigPopover() {
        try {
            const pageConfigPopover = this.template.querySelector('.pageConfigPopover');
            const pageConfigs = this.template.querySelector('.pageConfigs');
            this.isPageSetup = !this.isPageSetup;
            this.setActivePageConfigs(this.isPageSetup);
            if (this.isPageSetup) {
                pageConfigPopover.classList.remove('close');
                const pageConfigDiv = this.template.querySelector('.pageConfigDiv');
                pageConfigDiv.appendChild(pageConfigs);
                // this.setDummyPageSize();
            }
            else {
                pageConfigPopover.classList.add('close');
                const basicDetails_sub = this.template.querySelector('.basicDetails_sub');
                basicDetails_sub.appendChild(pageConfigs);
            }
        } catch (error) {
            errorDebugger('TemplateEditor', 'togglePageConfigPopover', error, 'warn');
        }
    }
    // === ==== ==== ==== ==== Method called from EditorConfig JS -- END --  === ==== ==== ==== ==== ====

    cancelPageConfig() {
        this.pageConfigRecord = JSON.parse(JSON.stringify(this.pageConfigRecBackup));
        this.setPageConfigVariable();
        this.togglePageConfigPopover();
    }


    setActivePageConfigs(isOpen) {
        if (isOpen) {
            this.activePageConfigs = ['pageMarginConfig', 'pageSizeConfig', 'pageOrientationConfig'];
            // if(this.currentTab == 'contentTab'){
            //     this.activePageConfigs = ['pageMarginConfig', 'pageSizeConfig', 'pageOrientationConfig'];
            // }
            // else if(this.currentTab == 'headerTab'){
            //     this.activePageConfigs = ['pageHeaderConfig'];
            // }
            // else if(this.currentTab == 'footerTab'){
            //     this.activePageConfigs = ['pageFooterConfig'];
            // }
        }
        else {
            this.activePageConfigs = [];
        }
    }

    scrollToTop(note) {
        try {
            if (note.selector == 'headerEditor') {
                const page = note.noteEditorFrame.querySelector('.' + note.selector);
                page && (page.scrollTop = 0);
            }
            else if (note.selector == 'footerEditor') {
                const page = note.noteEditorFrame.querySelector('.' + note.selector);
                page && (page.scrollTop = 0);
            }
        } catch (error) {
            errorDebugger('TemplateEditor', 'scrollToTop', error, 'warn');
        }
    }

    // === ==== ==== Extract Mapping Methods -- START -- ==== ==== ====
    extractMappingKeys() {
        try {
            const innerHTML = this.headerData + this.bodyData + this.footerData;
            const objectFields = this.extractedKeys(innerHTML, /\{\{#([^{}]+)\}\}/g);
            const generalFields = this.extractedKeys(innerHTML, /\{\{Doc.([^{}]+)\}\}/g);
            const signatureKeys = this.extractedKeys(innerHTML, /\{\{Sign.([^{}]+)\}\}/g)
            const sfImages = this.extractSalesforceImages();

            const signatureKey = '{{Sign.EXP *Signature Key*}}';

            return {
                'objectFields': objectFields,
                'generalFields': generalFields,
                'signatureKeys' : signatureKeys,
                'salesforceImages': sfImages,
                'signatureImage' : innerHTML.includes(signatureKey) ? signatureKey : null,
            }

        } catch (error) {
            errorDebugger('TemplateEditor', 'extractMappingKeys', error, 'warn');
        }
    }

    extractedKeys(innerText, pattern) {
        const extractedKeys = new Set();

        let matcher;
        while (((matcher = pattern.exec(innerText)) !== null)) {
            extractedKeys.add(matcher[0]);
        }

        return Array.from(extractedKeys);
    }

    extractSalesforceImages() {
        try {
            const extractedSfImages = new Set();
            const innerHTML = this.headerData + this.bodyData + this.footerData;

            let div;
            if (typeof window !== 'undefined') {   
                div = document.createElement('div');
                div.innerHTML = innerHTML;
            }

            const images = div.querySelectorAll('img');
            images?.forEach(ele => {
                if(ele.dataset.origin == 'sf' || ele.src.includes('sfc/servlet.shepherd/version/download')){
                    extractedSfImages.add(ele.src);
                }
            })

            return Array.from(extractedSfImages);
        } catch (error) {
            errorDebugger('TemplateEditor', 'extractSalesforceImages', error, 'warn');
            return [];
        }
    }
    // === ==== ==== Extract Mapping Methods -- END --- ==== ==== ====

    customTimeoutMethod = (event) => {
        event.target.classList.remove('dummyAnimation');
        this.isPreview = true;
    }

    handleMsgPopConfirmation(event){
        try {
            if(this.noTemplateFound){
                /**
                 * ... Popup message show WHEN Editor fail to initialize... 
                 * OR
                 * ... Popup message show WHEN Template Id Not Found...
                 */
                this.closeEditTemplate();
            }
            else if(!this.isLoadedSuccessfully){
                window?.globalThis?.location.reload();
            }
            else if(!this.templateRecord.MVEX__Template_Name__c && !this.noTemplateFound){
                // ... Popup Message Appear when user try to save without filling template name...
                this.currentTab = 'basicTab';
                this.setActiveTab();
            }
            else if(this.isCloseConfirmation){
                //... Popup message show WHEN User click on close button select YES...
                if(event.detail){
                    this.closeEditTemplate();
                }
                this.isCloseConfirmation = false;
            }
        } catch (error) {
            errorDebugger('TemplateEditor', 'handleMsgPopConfirmation', error, 'warn');
        }
    }

    showMessagePopup(Status, Title, Message) {
        const messageContainer = this.template.querySelector('c-message-popup')
        if (messageContainer) {
            messageContainer.showMessagePopup({
                status: Status,
                title: Title,
                message: Message,
            });
        }
    }

    showMessageToast(Status, Title, Message, Duration) {
        const messageContainer = this.template.querySelector('c-message-popup')
        if (messageContainer) {
            messageContainer.showMessageToast({
                status: Status,
                title: Title,
                message: Message,
                duration: Duration
            });
        }
    }

    navigateToComp(componentName, paramToPass) {
        try {
            let cmpDef;
            if (paramToPass && Object.keys(paramToPass).length > 0) {
                cmpDef = {
                    componentDef: `${nameSpace}:${componentName}`,
                    attributes: paramToPass
                };
            }
            else {
                cmpDef = {
                    componentDef: `${nameSpace}:${componentName}`,
                };
            }

            let encodedDef = btoa(JSON.stringify(cmpDef));
            this[NavigationMixin.Navigate]({
                type: "standard__webPage",
                attributes: {
                    url: "/one/one.app#" + encodedDef
                }
            });
        } catch (error) {
            errorDebugger('TemplateEditor', 'navigateToComp', error, 'warn');
        }
    }

    eventStopPropagation(event) {
        event.stopPropagation();
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

    handleAIPromptChange(event) {
        this.aiPrompt = event.target.value;
    }

    // async generateWithGemini() {
    //     if (!this.aiPrompt.trim()) {
    //         this.showToast('Error', 'Please enter a prompt', 'error');
    //         return;
    //     }

    //     this.isGenerating = true;
    //     try {
    //         const result = await generateTemplate({
    //             prompt           : this.aiPrompt,
    //             objectApiName    : this.objectName,
    //             objectFieldKeys  : this.objectFieldKeys,
    //             generalFieldKeys : this.generalFieldKeys,
    //             signatureKey     : this.signatureKey,
    //             isForEmail: this.isForEmail
    //         });

    //         // Insert into editors
    //         if (result.header) {
    //             $(this.headerEditor).summernote('code', result.header);
    //         }
    //         if (result.body) {
    //             $(this.contentEditor).summernote('code', result.body);
    //         }
    //         if (result.footer) {
    //             $(this.footerEditor).summernote('code', result.footer);
    //         }

    //         this.showToast('Success', 'AI template generated and inserted!', 'success');

    //         // Switch to content tab to show result
    //         this.currentTab = 'contentTab';
    //         this.setActiveTab();

    //     } catch (error) {
    //         this.showToast('Error', error.body?.message || error.message, 'error');
    //     } finally {
    //         this.isGenerating = false;
    //     }
    // }

    handleMappingKeysReady(event) {
        const { objectFieldKeys, generalFieldKeys, signatureKey } = event.detail;
        this.objectFieldKeys  = objectFieldKeys;
        this.generalFieldKeys = generalFieldKeys;
        this.signatureKey     = signatureKey;
    }

    // Toggle chat
    toggleChat() {
        this.isChatOpen = !this.isChatOpen;

        if (this.isChatOpen) {
            setTimeout(() => {
                const messages = this.template.querySelector('.ai-chat-messages');
                if (messages) {
                    messages.scrollTop = messages.scrollHeight;
                }
                }, 150);
        }
    }

    // Input handler
    handleAIPromptChange(event) {
        this.aiPrompt = event.target.value;
        const textarea = event.target;
        textarea.style.height = 'auto';
        textarea.style.height = textarea.scrollHeight + 'px';
    }

    // Enter = send
    handleKeyDown(event) {
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            // this.sendPrompt();
        }
    }

    // Add message
    addMessageToChat(sender, text) {
        const container = this.template.querySelector('.ai-chat-messages');
        if (!container) return;

        const msg = document.createElement('div');
        msg.className = `ai-message ai-${sender}`;
        msg.innerHTML = `
            <div class="ai-avatar">${sender === 'user' ? 'You' : 'AI'}</div>
            <div class="ai-bubble">${this.escapeHtml(text)}</div>
        `;
        container.appendChild(msg);
        container.scrollTop = container.scrollHeight;
        }

        escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML.replace(/\n/g, '<br>');
    }

    handleModeToggle(event) {
        const btn = event.currentTarget;
        const mode = btn.dataset.mode;               // "new" or "edit"
        const isEdit = (mode === 'edit');

        // 1. Update tracked flag
        this.isEditMode = isEdit;

        // 2. UI – toggle active class on both buttons
        const toggle = this.template.querySelector('.ai-chat-mode-toggle');
        toggle.querySelectorAll('.mode-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        // 3. Clear prompt when switching
        this.aiPrompt = '';
    }

    // async sendPrompt() {
    //     if (!this.aiPrompt?.trim()) return;

    //     const userPrompt = this.aiPrompt.trim();
    //     this.aiPrompt = '';

    //     // 1. USER MESSAGE (now also a version)
    //     this.addUserMessage(userPrompt);

    //     // 2. Capture the *before* state (still useful for AI edit mode)
    //     const beforeState = this.captureCurrentTemplate();

    //     this.isGenerating = true;
    //     try {
    //         let result;
    //         if (this.isEditMode) {
    //             const fullHtml = `${beforeState.header}\n<!-- BODY -->\n${beforeState.body}\n<!-- FOOTER -->\n${beforeState.footer}`;
    //             result = await editTemplateWithGemini({
    //                 userPrompt,
    //                 currentHtml: fullHtml,
    //                 objectApiName: this.objectName,
    //                 objectFieldKeys: this.objectFieldKeys,
    //                 generalFieldKeys: this.generalFieldKeys,
    //                 signatureKey: this.signatureKey,
    //                 isForEmail: this.isForEmail
    //             });
    //         } else {
    //             result = await generateTemplate({
    //                 prompt: userPrompt,
    //                 objectApiName: this.objectName,
    //                 objectFieldKeys: this.objectFieldKeys,
    //                 generalFieldKeys: this.generalFieldKeys,
    //                 signatureKey: this.signatureKey,
    //                 isForEmail: this.isForEmail
    //             });
    //         }

    //         // ---- APPLY AI RESULT -------------------------------------------------
    //         if (result.header !== undefined) $(this.headerEditor).summernote('code', result.header);
    //         if (result.body   !== undefined) $(this.contentEditor).summernote('code', result.body);
    //         if (result.footer !== undefined) $(this.footerEditor).summernote('code', result.footer);

    //         // ---- CAPTURE AFTER ---------------------------------------------------
    //         const afterState = this.captureCurrentTemplate();

    //         // ---- AI VERSION (unchanged) -----------------------------------------
    //         this.addAIVersion(userPrompt, afterState);

    //         this.showToast('Success', this.isEditMode ? 'Template updated!' : 'Template generated!', 'success');
    //     } catch (err) {
    //         this.addUserMessage(`Error: ${err.body?.message || err.message}`);
    //         this.showToast('Error', err.body?.message || err.message, 'error');
    //     } finally {
    //         this.isGenerating = false;
    //         this.scrollToBottom();
    //         this._renderChatMessages();
    //     }
    // }

    

    loadHistoryFromStorage() {
        try {
            const raw = localStorage.getItem(this.storageKey);
            if (raw) {
                const saved = JSON.parse(raw);
                this.chatMessages = saved.messages || [];
                // Restore last version if exists
                const last = this.chatMessages[this.chatMessages.length - 1];
                if (last && last.isHistory && last.template) {
                    setTimeout(() => this.restoreTemplate(last.template), 500);
                }

                // FORCE RENDER AFTER LOAD
                setTimeout(() => this._renderChatMessages(), 100);
            }
        } catch (e) {
            console.warn('Failed to load AI history', e);
        }
    }

    saveHistoryToStorage() {
        try {
            localStorage.setItem(this.storageKey, JSON.stringify({
                messages: this.chatMessages
            })).then(()=>this.loadHistoryFromStorage());
            
        } catch (e) {
            console.warn('Failed to save AI history', e);
        }
    }

    captureCurrentTemplate() {
        return {
            header: $(this.headerEditor).summernote('code') || '',
            body:   $(this.contentEditor).summernote('code') || '',
            footer: $(this.footerEditor).summernote('code') || ''
        };
    }

    addUserMessage(text) {
        const version = this.captureCurrentTemplate();               // <-- NEW
        const msg = {
            id        : Date.now(),
            text      : this.escapeHtml(text),
            isUser    : true,
            isHistory : true,                                 // <-- NEW: treat user prompt as a version
            timestamp : this.formatTime(),
            template  : version                               // <-- NEW
        };
        this.chatMessages = [...this.chatMessages, msg];
        this.scrollToBottom();
        this.saveHistoryToStorage();          // persists immediately
        this._renderChatMessages();           // make the Restore button appear
    }

    addAIVersion(prompt, templateState) {
        const msg = {
            id: Date.now(),
            text: `<strong>${this.escapeHtml(prompt)}</strong>`,
            isHistory: true,
            timestamp: this.formatTime(),
            template: templateState
        };
        this.chatMessages = [...this.chatMessages, msg];
        this.scrollToBottom();
        this.saveHistoryToStorage();
        this._renderChatMessages();
    }

    handleRestore(event) {
        const id = event.target.closest('button').dataset.id;
        const entry = this.chatMessages.find(m => m.id == id);
        if (!entry || !entry.template) return;

        this.restoreTemplate(entry.template);
        this.showToast('Restored', `Reverted to version from ${entry.timestamp}`, 'success');
    }

    restoreTemplate(state) {
        $(this.headerEditor).summernote('code', state.header);
        $(this.contentEditor).summernote('code', state.body);
        $(this.footerEditor).summernote('code', state.footer);
    }

    formatTime() {
        const d = new Date();
        return d.toLocaleString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
    }

    scrollToBottom() {
        this.template.querySelector('.ai-chat-messages')?.scrollTo(0, 999999);
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    _renderChatMessages() {
        // Clear any pending render
        if (this._renderTimeout) {
            clearTimeout(this._renderTimeout);
        }

        this._renderTimeout = setTimeout(() => {
            this.chatMessages.forEach(msg => {
                const container = this.template.querySelector(`[data-msg-id="${msg.id}"]`);
                if (!container || container.dataset.rendered) return;

                container.innerHTML = msg.text;

                if (msg.isHistory) {
                    const btn = container.parentElement.querySelector('.ai-restore-btn');
                    if (btn) {
                        btn.removeEventListener('click', this._restoreHandler);
                        btn.addEventListener('click', this._restoreHandler);
                    }
                }

                container.dataset.rendered = 'true';
            });
        }, 50);
    }

    _restoreHandler = (event) => {
        const id = event.currentTarget.dataset.id;
        const entry = this.chatMessages.find(m => m.id == id);
        if (!entry?.template) return;

        this.restoreTemplate(entry.template);
        this.showToast('Restored', `Reverted to version from ${entry.timestamp}`, 'success');
    };
}