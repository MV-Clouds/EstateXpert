import { LightningElement, api, track } from 'lwc';
import getFieldMappingKeys from '@salesforce/apex/KeyMappingController.getFieldMappingKeys';
import getGeneralFields from '@salesforce/apex/KeyMappingController.getGeneralFields';
import getAllContentVersionImgs from '@salesforce/apex/KeyMappingController.getAllContentVersionImgs';
import formattingFieldKeys from '@salesforce/apex/KeyMappingController.formattingFieldKeys';
import getSignatureInfo from '@salesforce/apex/KeyMappingController.getSignatureInfo';
import updateSignatureInfo from '@salesforce/apex/KeyMappingController.updateSignatureInfo';
import { errorDebugger } from 'c/globalProperties';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';

export default class KeyMappingContainer extends LightningElement {

    @api objectName;
    @api saveButtonLabel;
    @api cancelButtonLabel;
    @api previewButtonLabel;
    @api templateType;

    tempId;
    @api get templateId() { return this.tempId };
    set templateId(value) { this.tempId = value };

    showFullHeightButtonFor = ['PDF Template'];
    showMaxSizeLimit = ['PDF Template'];
    copyBase64AvailableFor = [];

    @track field_Vs_KeyList = [];
    @track selectedObjectName;

    @track isMappingOpen = false;
    @track isMappingContainerExpanded;
    @track isMappingTabExpanded;

    @track propertyMediaCount = 1;
    @track allFieldLabels = [];

    mappingTypeTabs = [
        {
            label: 'Object Fields', name: 'objectFields',
            helpText: 'Insert Base Object and Lookup (Related) Object\'s Fields in Template.',
            showCombobox: true, comboboxPlaceholder: 'Select Object...', showDescription: false,
            showSearchbar: true, searchBarPlaceHolder: 'Search Fields...',
        },
        {
            label: 'General Fields', name: 'generalFields',
            helpText: 'Insert & Add Document Creation Date, Document Creation User Info, Organization Info, etc... In Template',
            showCombobox: true, comboboxPlaceholder: 'Select Object...', showDescription: false,
            showSearchbar: true, searchBarPlaceHolder: 'Search General Fields...',
        },
        {
            label: 'Salesforce Images', name: 'sfImages',
            helpText: 'Add Salesforce images Into The Template.',
            showSearchbar: true, searchBarPlaceHolder: 'Search Salesforce Images...',
            showRefresh: true,
        },
        {
            label: 'Property Media Images', name: 'pmImages',
            helpText: 'Add Listing images Into The Template.',
            showSearchbar: false,
            showRefresh: false,
        },
        {   label: 'Signature',     name: 'signature',
            helpText : 'Add Signature into Your file by Mapping Signature Key in The Template.', selected : false,
        }
    ];

    @track activeMappingTabName = 'objectFields';
    @track selectedMappingType = this.mappingTypeTabs.find(ele => ele.name == this.activeMappingTabName);
    @track generalFieldTypes = [];
    @track selectedGeneralFieldType;
    @track generalFieldsToDisplay = [];
    @track contentVersionImages = [];
    @track cvIdVsImageSRC = {};
    @track contentVersionToDisplay = [];
    @track isDataRefreshing = false;

    // Variables used for "Formatting Option"
    @track showFormatKeys = false;
    @track formatDefault = {};
    @track clickedFieldType;
    @track clickedFieldName;
    @track dateFormatKeys = [];
    @track timeFormatKeys = [];
    @track primeFormatKeys = [];
    @track subFormatKeys = [];
    @track isSubFormat = false;
    @track chosenFormat = {};
    @track trueValueReplacer = '';
    @track falseValueReplacer = '';
    @track disableRoundMode = false;
    toggleBtn = false;
    numberFormat = {}

    @track searchFieldValue = null;
    customTimeout;

    @track signatureSize;
    savedSignatureSize = this.signatureSize;

    @track objectFieldKeys   = [];   // e.g. ["{{#Account__c.Name__c}}", …]
    @track generalFieldKeys  = [];   // e.g. ["{{Doc.Company_Name}}", …]
    @track signatureKey      = [];   // e.g. ["{{Sign.EXP *Signature Key*}}"]

    /**
     * boolean to set showFulbrightButtonFor based on template type.
     */
    get showFullHeightButton() {
        return this.showFullHeightButtonFor.includes(this.templateType);
    };

    get listingMediaCount() {
        return 'listingMedia[' + this.propertyMediaCount + ']';
    }


    /**
     * Set Tab Area based on Tab Selection By user..
     */
    get mappingTypeTabArea() {
        return {
            objectFields: this.activeMappingTabName == 'objectFields' ? true : false,
            generalFields: this.activeMappingTabName == 'generalFields' ? true : false,
            sfImages: this.activeMappingTabName == 'sfImages' ? true : false,
            signature: this.activeMappingTabName == 'signature' ? true : false,
            pmImages: this.activeMappingTabName == 'pmImages' ? true : false,
        }
    }

    /**
     * Getter for determining if the combobox should be shown based on the active mapping tab.
     */
    get showCombobox() {
        return this.mappingTypeTabs?.find(ele => ele.name === this.activeMappingTabName)?.showCombobox;
    }

    /**
     * Getter for determining if the search bar should be shown based on the active mapping tab.
     */
    get showSearchBar() {
        return this.mappingTypeTabs?.find(ele => ele.name === this.activeMappingTabName)?.showSearchbar;
    }

    /**
     * Getter for determining if the refresh button should be shown based on the active mapping tab.
     */
    get showRefreshButton() {
        return this.mappingTypeTabs?.find(ele => ele.name === this.activeMappingTabName)?.showRefresh;
    }

    /**
     * Getter for determining if the combobox placeholder based on the active mapping tab.
     */
    get objectComboPlaceHolder() {
        return this.mappingTypeTabs?.find(ele => ele.name === this.activeMappingTabName)?.comboboxPlaceholder;
    }

    /**
     * Getter for determining if the search bar placeholder based on the active mapping tab.
     */
    get searchBarPlaceHolder() {
        return this.mappingTypeTabs?.find(ele => ele.name === this.activeMappingTabName)?.searchBarPlaceHolder;
    }

    /**
     * Getter for determining if the combobox options based on the active mapping tab.
     */
    get comboBoxOptions() {
        if (this.activeMappingTabName == 'objectFields') {
            return this.relatedObjectList;
        }
        else if (this.activeMappingTabName == 'generalFields') {
            return this.generalFieldTypes;
        }
        return [];
    }

    /**
     * Getter for determining if the selectedValue based on the active mapping tab to display on ui.
     */
    get selectedValue() {
        if (this.activeMappingTabName == 'objectFields') {
            return this.selectedObjectName;
        }
        else if (this.activeMappingTabName == 'generalFields') {
            return this.selectedGeneralFieldType;
        }
        return null;
    }

    /**
     * Getter to determine to show or not in combo box based on the active mapping tab.
     */
    get showComboDescription() {
        return this.mappingTypeTabs?.find(ele => ele.name === this.activeMappingTabName)?.showDescription;
    }

    /**
     * Getter to set format option based on clicked field type
     */
    get formateOptions() {
        return {
            isPrimaryFormateCombobox: this.clickedFieldType === 'DATETIME' || this.clickedFieldType === 'DATE' || this.clickedFieldType === 'TIME',
            isCheckboxFormate: this.clickedFieldType === 'CHECKBOX',
            isTextFormate: this.clickedFieldType === 'TEXT',
            isNumberFormat: this.clickedFieldType === 'CURRENCY' || this.clickedFieldType === 'NUMBER',
        }
    }

    /**
     * Getter to set format help text based on clicked field type
     */
    get formatHelpText() {
        if (this.clickedFieldType == 'DATE') {
            return 'Select format for your Date Field';
        }
        else if (this.clickedFieldType == 'DATETIME') {
            return 'Select Date and Time Format for your DateTime Field';
        }
        else if (this.clickedFieldType == 'TIME') {
            return 'Select format for your Time Field';
        }
        else if (this.clickedFieldType == 'CHECKBOX') {
            return 'Set Display text based on checkbox status';
        }
        else if (this.clickedFieldType == 'TEXT') {
            return 'Set Text Length by Character';
        }
        else if (this.clickedFieldType == 'CURRENCY' || this.clickedFieldType == 'NUMBER' || this.clickedFieldType == 'PERCENTAGE') {
            return `Format Options for ${this.clickedFieldType} field`;
        } 
        return null;
    }

    /**
     * Getter to Enable/Disable signature update button
     */
    get isSignatureSetBtn(){
        return this.savedSignatureSize === this.signatureSize;
    }

    /**
     * Getter to show/hide image max size limit info
     */
    get isImgMaxSizeLimit() {
        return this.showMaxSizeLimit.includes(this.templateType);
    }

    get hidePropertyImagesForOtherObjects() {
        console.log('objectName => ', this.objectName);
        return this.objectName == 'MVEX__Listing__c' || this.objectName == 'MVEX__Inquiry__c' ? false : true;
        
    }

    connectedCallback() {
        console.log('templatetype => ', this.templateType);
        try {
            loadStyle(this, MulishFontCss)
                .then(() => {
                    console.log('External Css Loaded');
                })
                .catch(error => {
                    console.log('Error occuring during loading external css', error);
                });

            if (this.templateId) {
                this.fetchFieldMapping();
                this.fetchGeneralFields();
                this.fetchAllContentVersionImages();
                this.fetchFormatMappingKeys();
                this.fetchSignatureInfo();
            }
            window?.globalThis?.addEventListener('resize', this.resizeFunction);

            if (this.hidePropertyImagesForOtherObjects) {
                const index = this.mappingTypeTabs.indexOf(this.mappingTypeTabs.find(ele => ele.name == 'pmImages'));
                if (index !== -1) this.mappingTypeTabs.splice(index, 1);
            }
            else {
                this.fetchAllActiveTemps()
            }
        } catch (error) {
            errorDebugger('FieldMappingKey', 'connectedCallback', error, 'warn');
        }
    }

    renderedCallback() {
        if (this.isInit) {
            this.resizeFunction();
            this.isInit = false;
        }

        if(!this.customTimeout){
            this.customTimeout = this.template.querySelector('c-custom-timeout');
        }
    }

    // Use Arrow Function...
    resizeFunction = () => {

    };

    /**
     * Fetches the field mapping data for the specified object.
     * 
     * This method makes an asynchronous call to retrieve field mapping keys for the given object.
     */
    fetchFieldMapping() {
        try {
            getFieldMappingKeys({ sourceObjectAPI: this.objectName, getParentFields: true, templateId: this.templateId })
                .then(result => {
                    this.isDataRefreshing = false;
                    console.log('getFieldMappingKeys result  : ', result);
                    if (result.isSuccess) {
                        // Set... Base Object, Related Parent Object and It's Fields with mapping key
                        this.propertyMediaCount = result.listingMediaCount;
                        this.object_Label = result.objectLabelAPI.label;
                        var relatedObjectList = [];
                        var fieldMappingKeysList = [];
                        var allLabels = []; // Collect all field labels here

                        result.fieldMappingsWithObj.forEach(obj => {
                            relatedObjectList.push({ label: obj.label, value: obj.name });
                            obj.fieldMappings.forEach(ele => {
                                fieldMappingKeysList.push(ele.name);
                                allLabels.push(ele.label); // Add every field label
                            })
                        });

                        this.relatedObjectList = JSON.parse(JSON.stringify(relatedObjectList));
                        this.fieldMappingsWithObj = result.fieldMappingsWithObj;
                        this.setMappingKeysForObjFields();
                        this.setMappingTab();
                        this._buildAllMappingKeys();
                    }
                    else {
                        errorDebugger('FieldMappingKey', 'fetchFieldMapping', null, 'warn', `error in getFieldMappingKeys apex call : ${result.returnMessage}`);
                        this.showMessagePopup('Error', 'Error While Fetching Field Mapping Data', result.returnMessage);
                    }
                })
                .catch(error => {
                    this.isDataRefreshing = false;
                    console.log('error in getFieldMappingKeys apex call : ', error);
                    errorDebugger('FieldMappingKey', 'fetchFieldMapping', error, 'warn', `error in getFieldMappingKeys apex call `);
                })
        } catch (error) {
            console.log('error in fetchFieldMapping : ', error);
            errorDebugger('FieldMappingKey', 'fetchFieldMapping', error, 'warn');
        }
    }

    /**
     * Fetch General Field and its key
     * Creation Date, Creation user and organization keys are fetch throughout this apex call
     */
    fetchGeneralFields() {
        try {
            getGeneralFields()
                .then(result => {
                    this.isDataRefreshing = false;
                    var generalFieldTypes_temp = [];
                    if (result.isSuccess == true && result.fieldMappingsWithObj) {
                        result.fieldMappingsWithObj.forEach(ele => {
                            generalFieldTypes_temp.push({ label: ele.label, value: ele.name, fieldMappings: ele.fieldMappings })
                        })
                        this.generalFieldTypes = JSON.parse(JSON.stringify(generalFieldTypes_temp));
                        this.setGeneralFieldsToDisplay();
                        this._buildAllMappingKeys();
                    }
                    else {
                        errorDebugger('FieldMappingKey', 'fetchGeneralFields', null, 'warn', `error in fetchGeneralFields apex : ${result.returnMessage}`);
                    }
                })
                .catch(error => {
                    this.isDataRefreshing = false;
                    errorDebugger('FieldMappingKey', 'fetchGeneralFields', error, 'warn', `error in fetchGeneralFields apex `);
                })
        } catch (error) {
            errorDebugger('FieldMappingKey', 'fetchGeneralFields', error, 'warn');
        }
    }

    /**
     * Fetch all Image from ContentVersion to add into template
     * Note : For Google Doc Template, we get ContentDownloadUrl from ContentDistribution as Google doc Only support public url
     * While : For PDF Template we get VersionDataUrl which is not public url
     */
    fetchAllContentVersionImages() {
        try {
            getAllContentVersionImgs({ templateType: this.templateType })
                .then(result => {
                    this.isDataRefreshing = false;
                    console.log('getAllContentVersionImgs result => ', result);
                    if (result.isSuccess == true) {
                        this.contentVersionImages = result.cdImages;
                        // this.cvIdVsImageSRC = result.cvIdVsImageSRC;
                        this.contentVersionImages.forEach(ele => {
                            ele['fileSize'] = ele.ContentVersion.ContentSize + ' Bytes';
                            if (ele.ContentVersion.ContentSize < 1000000) {
                                ele['fileSize'] = (ele.ContentVersion.ContentSize / 1000).toFixed(2) + ' KB';
                            } else if (ele.ContentVersion.ContentSize < 1000000000) {
                                ele['fileSize'] = (ele.ContentVersion.ContentSize / 1000000).toFixed(2) + ' MB';
                            } else {
                                ele['fileSize'] = (ele.ContentVersion.ContentSize / 1000000000).toFixed(2) + ' GB';
                            }
                            ele.Title = ele.ContentVersion.Title;
                            ele.FileExtension = ele.ContentVersion.FileExtension;
                            ele.FileType = ele.ContentVersion.FileType;
                            ele.ContentSize = ele.ContentVersion.ContentSize;
                            ele.imageSRC = ele.ContentDownloadUrl;
                        });
                        this.setContVerImgToDisplay();
                    }
                    else {
                        errorDebugger('FieldMappingKey', 'fetchAllContentVersionImages', null, 'warn', `error in getAllContentVersionImgs Apex : ${result.returnMessage}`)
                    }
                })
                .catch(error => {
                    this.isDataRefreshing = false;
                    errorDebugger('FieldMappingKey', 'fetchAllContentVersionImages', error, 'warn')
                })
        } catch (error) {
            errorDebugger('FieldMappingKey', 'fetchAllContentVersionImages', error, 'warn')
        }
    }

    /**
     * Fetch all formatting field to set formatting for date, time , datetime, text, checkbox, number, currency and percentage field
     */
    fetchFormatMappingKeys() {
        try {
            formattingFieldKeys()
                .then(result => {
                    this.isDataRefreshing = false;
                    console.log('formattingFieldKeys result => ', result);
                    if (result.isSuccess == true) {
                        if (result.fieldFormatting && result.fieldFormatting.length) {
                            this.dateFormatKeys = result.fieldFormatting.find(ele => ele.formatType == 'DATE').fieldMappings;
                            this.timeFormatKeys = result.fieldFormatting.find(ele => ele.formatType == 'TIME').fieldMappings;
                            this.signatureKey = result.signatureKey;
                        }
                        this._buildAllMappingKeys();
                    }
                    else {
                        errorDebugger('FieldMappingKey', 'fetchFormatMappingKeys', null, 'warn', `Error in ${result.returnMessage}`);
                    }
                })
        } catch (error) {
            errorDebugger('FieldMappingKey', 'fetchFormatMappingKeys', error, 'warn');
        }
    }

    /**
     * Method to fetch signature size stored in template record field.
     */
    fetchSignatureInfo(){
        try {
            getSignatureInfo({templateId : this.templateId})
            .then(result => {
                this.isDataRefreshing = false;
                this.signatureSize = Math.max(result, 1);               // To avoid value lesser than 1
                this.savedSignatureSize = this.signatureSize;
            })
        } catch (error) {
            errorDebugger('FieldMappingKeyV2', 'fetchSignatureInfo', error ,'warn');
        }
    }

    /**
     * Sets the active mapping tab based on the user click triggered.
     * Adds 'selected' class to the active tab and removes it from other tabs to set Css of active tab.
     * Calls handleKeySearch method after updating the active tab.
     * 
     * @param {Event} event - The event object triggered by the user action.
     */
    setMappingTab(event) {
        try {
            if (event && event.currentTarget && this.activeMappingTabName !== event.currentTarget.dataset.name) {
                this.template.querySelector('[data-combox="relatedObj"]')?.clearSearch();
                this.activeMappingTabName = event.currentTarget.dataset.name;
                console.log('this.activeMappingTabName => ', this.activeMappingTabName);
                var tabSelection = this.template.querySelectorAll('.tabSelection');
                if (tabSelection) {
                    tabSelection.forEach(ele => {
                        if (ele.dataset.name == this.activeMappingTabName) {
                            ele.classList.add('selected');
                            this.searchFieldValue = null;
                        }
                        else if (ele.classList.contains('selected')) {
                            ele.classList.remove('selected');
                        }
                    });
                };

                var index = this.mappingTypeTabs.indexOf(this.mappingTypeTabs.find(ele => ele.name == this.activeMappingTabName));
                this.selectedMappingType = this.mappingTypeTabs[index];

                this.handleKeySearch();
            } else {
                var tabSelection1 = this.template.querySelectorAll('.tabSelection');
                if (tabSelection1) {
                    tabSelection1.forEach(ele => {
                        if (ele.dataset.name == this.activeMappingTabName) {
                            ele.classList.add('selected');
                            this.searchFieldValue = null;
                        }
                        else if (ele.classList.contains('selected')) {
                            ele.classList.remove('selected');
                        }
                    });
                };
            }


        } catch (error) {
            errorDebugger('FieldMappingKey', 'setMappingTab', error, 'warn');
        }
    }

    /**
     * Generic method to call when user select any option from Object fields, child objects or general Field,
     * Set Mapping keys to display based on selection
     * @param {*} event 
     */
    handleOptionSelect(event) {
        try {
            if (this.activeMappingTabName == 'objectFields') {
                this.handleRelatedObjSelect(event);
            }
            else if (this.activeMappingTabName == 'generalFields') {
                this.handleGeneralFieldTypeSelection(event);
            }
        } catch (error) {
            errorDebugger('FieldMappingKey', 'handleOptionSelect', error, 'warn');
        }
    }

    /**
     * Set mapping key to display when user select any source or its related object.
     * This Method call from 'handleOptionSelect',
     * @param {*} event 
     */
    handleRelatedObjSelect(event) {
        try {
            if (event.detail.length) {
                this.selectedObjectName = event.detail[0];
            }
            else {
                this.selectedObjectName = null;
            }
            this.setMappingKeysForObjFields();

            
        } catch (error) {
            errorDebugger('FieldMappingKey', 'handleRelatedObjSelect', error, 'warn');
        }
    }

    /**
     * Set mapping key to display when user select any general field type.
     * This Method call from 'handleOptionSelect'.
     * @param {*} event 
     */
    handleGeneralFieldTypeSelection(event) {
        try {
            this.selectedGeneralFieldType = event.detail[0];
            this.setGeneralFieldsToDisplay();
        } catch (error) {
            errorDebugger('FieldMappingKey', 'handleGeneralFieldTypeSelection', error, 'warn');
        }
    }

    /**
     * Generic method which triggers when user search from searchbar.
     * this will for all tab on which search bar is available.
     * @param {*} event 
     */
    handleKeySearch(event) {
        try {
            this.searchFieldValue = event ? event.target.value : null;
            if (this.activeMappingTabName == 'objectFields') {
                this.setMappingKeysForObjFields();
            }
            else if (this.activeMappingTabName == 'generalFields') {
                this.setGeneralFieldsToDisplay();
            }
            else if (this.activeMappingTabName == 'sfImages') {
                this.setContVerImgToDisplay();
            }
        } catch (error) {
            errorDebugger('FieldMappingKey', 'handleKeySearch', error, 'warn');
        }
    }

    /**
     * refresh Data when click on button
     */
    refreshData() {
        try {
            this.isDataRefreshing = true;
            if (this.activeMappingTabName === 'sfImages') {
                this.fetchAllContentVersionImages()
            }
        } catch (error) {
            errorDebugger('FieldMappingKey', 'refreshData', error, 'warn');
        }
    }

    /**
     * Method to organize list of mapping keys of source object's and its related object's fields to display on ui.
     * This method run each time when user search for field from 'Object Field' tab
     */
    setMappingKeysForObjFields() {
        try {
            this.field_Vs_KeyList = this.selectedObjectName ?
                this.fieldMappingsWithObj.find(ele => ele.name === this.selectedObjectName).fieldMappings :
                this.fieldMappingsWithObj.find(ele => ele.name === this.objectName).fieldMappings;

            // If Search value is not null, filter Field_Vs_KeysList based on search value...
            if (this.searchFieldValue !== undefined && this.searchFieldValue !== null && this.searchFieldValue != '') {
                this.field_Vs_KeyList = this.field_Vs_KeyList.filter((ele) => {
                    return ele.label.toLowerCase().includes(this.searchFieldValue.toLowerCase()) || ele.key.toLowerCase().includes(this.searchFieldValue.toLowerCase());
                })
            }

            this.field_Vs_KeyList = this.sortFormateKeys(this.field_Vs_KeyList, 'label');

        } catch (error) {
            errorDebugger('FieldMappingKey', 'setMappingKeysForObjFields', error, 'warn');
        }
    }

    /**
     * Method to organize list of mapping keys of 'General Fields' to display on ui.
     * This method run each time when user search for field from 'General Field' tab
     */
    setGeneralFieldsToDisplay() {
        try {
            this.generalFieldsToDisplay = this.selectedGeneralFieldType ? this.generalFieldTypes.find(ele => ele.value == this.selectedGeneralFieldType).fieldMappings : this.generalFieldTypes[0].fieldMappings;

            if (this.searchFieldValue) {
                this.generalFieldsToDisplay = this.generalFieldsToDisplay.filter((ele) => {
                    return ele.label.toLowerCase().includes(this.searchFieldValue?.toLowerCase()) || ele.key.toLowerCase().includes(this.searchFieldValue?.toLowerCase());
                });
            }

            this.generalFieldsToDisplay = this.sortFormateKeys(this.generalFieldsToDisplay, 'label');
        } catch (error) {
            errorDebugger('FieldMappingKey', 'setGeneralFieldsToDisplay', error, 'warn');
        }
    }

    /**
     * Method to organize list of Salesforce Images to display on ui.
     * This method run each time when user search for salesforce images from 'Merge Template' tab
     */
    setContVerImgToDisplay() {
        try {
            this.contentVersionToDisplay = this.contentVersionImages;

            if (this.searchFieldValue) {
                this.contentVersionToDisplay = this.contentVersionImages.filter((ele) => {
                    return ele.Title.toLowerCase().includes(this.searchFieldValue.toLowerCase()) || ele.FileType.toLowerCase().includes(this.searchFieldValue.toLowerCase())
                })
            }

            this.contentVersionToDisplay = this.sortFormateKeys(this.contentVersionToDisplay, 'Title');
        } catch (error) {
            errorDebugger('FieldMappingKey', 'setContVerImgToDisplay', error, 'warn');
        }
    }

    /**
     * Method to Increase/Decrease height of Mapping key Area..
     */
    toggleMappingTableHeight() {
        try {
            const mergingTypeSelection = this.template.querySelector('.mergingTypeSelection');
            const selectedTab_Outer = this.template.querySelector('.selectedTab_Outer');
            const buttonSection = this.template.querySelector('.buttonSection');
            if (this.isMappingTabExpanded) {
                this.isMappingTabExpanded = false;
                mergingTypeSelection.style = ``;
                selectedTab_Outer.style = ``;
                buttonSection.style = ``;
            }
            else {
                this.isMappingTabExpanded = true;
                mergingTypeSelection.style = `max-height : 0px; overflow : hidden;`;
                selectedTab_Outer.style = `margin-top : -2.25rem`;
                buttonSection.style = `margin : 0px; width : 100%; border-radius : 0px; max-height: 3.25rem;`;
            }
        } catch (error) {
            errorDebugger('FieldMappingKey', 'toggleMappingTableHeight', error, 'warn');
        }
    }


    /**
     * Method to show/hide the Mapping container
     */
    showHideMappingContainer() {
        try {
            this.isMappingOpen = !this.isMappingOpen;
            var toggleFieldMapping = this.template.querySelector('.toggleFieldMapping');
            if (toggleFieldMapping) {
                toggleFieldMapping.style = this.isMappingOpen ? `width : 0px !important; padding: 0px; opacity : 0;` : '';
            }

            if (this.isMappingOpen) {
                this.template.host.classList.add('openFieldMapping');
            }
            else {
                this.template.host.classList.remove('openFieldMapping');
            }
            // this.dispatchEvent(new CustomEvent('togglemapping'));
        } catch (error) {
            errorDebugger('FieldMappingKey', 'showHideMappingContainer', error, 'warn');
        }
    }

    /**
     * API Method to Show/Hide Mapping container,
     * This method trigged from parent component to show and hide key Mapping Container based on state.
     * @param {*} state 
     */
    @api toggleMappingContainer(state) {
        try {
            this.toggleBtn = state;
            var toggleFieldMapping = this.template.querySelector('.toggleFieldMapping');
            toggleFieldMapping.style = this.isMappingOpen ? `width : 0px !important; padding: 0px; opacity : 0;` : '';

            // add and remove floating CSS for container as per requirement to make container slider....
            if (state) {
                this.template.host.classList.add('floatContainer');
            }
            else {
                this.template.host.classList.remove('floatContainer');
            }
            this.setToggleBtnVisibility();
        } catch (error) {
            errorDebugger('FieldMappingKey', 'toggleMappingContainer', error, 'warn');
        }
    }

    /**
     * Method to show/hide key Mapping Toggle button
     */
    setToggleBtnVisibility() {
        var toggleFieldMapping = this.template.querySelector('.toggleFieldMapping');
        if (window.innerWidth > 1350) {
            if (this.toggleBtn) toggleFieldMapping?.classList.add('show');
            else toggleFieldMapping.classList.remove('show');
        }
        else {
            toggleFieldMapping && toggleFieldMapping.classList.add('show');
        }
    }

    /**
     * Method to Increase/Decrease height of Mapping key container..
     */
    toggleMappingContainerHeight() {
        this.isMappingContainerExpanded = !this.isMappingContainerExpanded
        this.dispatchEvent(new CustomEvent('fullheight'));
    }

    /**
     * Method to copy mapping key and show animation on copy button click
     * @param {*} event 
     */
    handleCopyFieldKey(event) {
        try {
            event.stopPropagation();
            var fieldName = event.currentTarget.dataset.fieldname;
            var fieldKey = event.currentTarget.dataset.fieldkey;

            const textarea = document.createElement('textarea');
            textarea.value = fieldKey;
            document.body.appendChild(textarea);
            textarea.select();

            navigator.clipboard.write([
                new ClipboardItem({
                    // 'text/html': new Blob([span.outerHTML], { type: 'text/html' }),
                    'text/plain': new Blob([textarea.value], { type: 'text/plain' })
                })
            ]);
            document.body.removeChild(textarea);

            const fieldKeyTD = this.template.querySelectorAll(`[data-name="fieldTD"]`);
            fieldKeyTD.forEach(ele => {
                if (ele.dataset.fieldname == fieldName) {
                    ele.classList.add('copied');
                    // setTimeout(() => {
                    //     ele.classList.remove('copied');
                    // }, 1001);
                    this.customTimeout?.setCustomTimeoutMethod(() => {
                        ele.classList.remove('copied');
                    }, 1001);
                }
                else {
                    ele.classList.remove('copied');
                }
            });

        } catch (error) {
            errorDebugger('FieldMappingKey', 'handleCopyFieldKey', error, 'warn');
        }
    }


    // ==== ==== ==== Field Formatting Methods -- START -- ==== ==== ====

    /**
     * Method Set formatting option based on field Type
     * @param {*} event 
     */
    setFormatKeyList(event) {
        try {
            var fieldName = event.currentTarget.dataset.fieldname;
            var fieldType = event.currentTarget.dataset.fieldtype;
            var fieldKey = event.currentTarget.dataset.fieldkey;

            this.showFormatKeys = true;

            this.formatDefault = { label: 'Salesforce Default', name: fieldName, value: fieldName, key: fieldKey };

            // this.clickedFieldType = fieldType == 'BOOLEAN' ? 'CHECKBOX' : fieldType;
            switch (fieldType) {
                case 'BOOLEAN': this.clickedFieldType = 'CHECKBOX';
                    break;

                case 'STRING': this.clickedFieldType = 'TEXT';
                    break;

                case 'INTEGER': this.clickedFieldType = 'NUMBER';
                    break;

                case 'DOUBLE': this.clickedFieldType = 'NUMBER';
                    break;

                case 'PERCENT': this.clickedFieldType = 'PERCENTAGE';
                    break;

                default: this.clickedFieldType = fieldType;
            }

            if (this.clickedFieldType == 'DATE') {
                this.primeFormatKeys = JSON.parse(JSON.stringify(this.dateFormatKeys));
                this.primeFormatKeys.forEach(ele => {
                    ele['value'] = ele.name;
                    ele.name = fieldName + ' ' + ele.formatKey;
                    ele['key'] = fieldKey.replace(fieldName, fieldName + ' ' + ele.formatKey);
                });
            }
            else if (this.clickedFieldType == 'DATETIME') {
                this.primeFormatKeys = JSON.parse(JSON.stringify(this.dateFormatKeys));
                // For DateTime Field Type... Set Date as prime Format
                this.primeFormatKeys.forEach(ele => {
                    ele['value'] = ele.name;
                    ele.name = fieldName + ' ' + ele.formatKey;
                    ele['key'] = fieldKey.replace(fieldName, fieldName + ' ' + ele.formatKey);
                });

                // For DateTime Field Type... Set Time as sub Format
                this.subFormatKeys = JSON.parse(JSON.stringify(this.timeFormatKeys));
                this.subFormatKeys.forEach(ele => {
                    ele['value'] = ele.name;
                });

                this.isSubFormat = true;
            }
            else if (this.clickedFieldType == 'TIME') {
                this.primeFormatKeys = JSON.parse(JSON.stringify(this.timeFormatKeys));
                this.primeFormatKeys.forEach(ele => {
                    ele['value'] = ele.name;
                    ele.name = fieldName + ' ' + ele.formatKey;
                    ele['key'] = fieldKey.replace(fieldName, fieldName + ' ' + ele.formatKey);
                });
            }

            this.chosenFormat = JSON.parse(JSON.stringify(this.formatDefault));           // for Deep clone...

        } catch (error) {
            errorDebugger('FieldMappingKey', 'setFormatKeyList', error, 'warn');
        }
    }

    /**
     * Method to set Prime Format option 
     * @param {*} event 
     */
    handlePrimeFormat(event) {
        try {
            if (event.detail && event.detail.length) {
                this.chosenFormat = JSON.parse(JSON.stringify(this.primeFormatKeys.find(ele => ele.value == event.detail[0])));
            }
            else {
                this.chosenFormat = JSON.parse(JSON.stringify(this.formatDefault));
            }

            if (this.isSubFormat) {
                this.updateChosenFormat();
            }
        } catch (error) {
            errorDebugger('FieldMappingKey', 'handlePrimeFormat', error, 'warn');
        }
    }

    /**
     * Method to Set Sub Format option for data time field
     * @param {*} event 
     */
    handleSubFormat(event) {
        try {
            if (event.detail && event.detail.length) {
                this.chosenSubFormat = event.detail[0];
            }
            else {
                this.chosenSubFormat = null;
            }
            this.updateChosenFormat();
        } catch (error) {
            errorDebugger('FieldMappingKey', 'handleSubFormat', error, 'warn');
        }
    }

    /**
     * Once user select ay format type, update existing mapping key bases on formate type.
     */
    updateChosenFormat() {
        // Update format key in case of sub formatting (i.e. Date and Time)
        try {
            if (this.chosenFormat.key.includes('*')) {
                // Update format key when key includes prime format key
                if (this.chosenSubFormat) {
                    this.chosenFormat.key = this.chosenFormat.key.replace(/(?<=\*)(.*?)(?=\*)/g, this.chosenFormat.value + ' ' + this.chosenSubFormat);
                }
                else {
                    // remove chosenSubFormat from format key when user remove sub format key...
                    this.chosenFormat.key = this.chosenFormat.key.replace(/(?<=\*)(.*?)(?=\*)/g, this.chosenFormat.value);
                }
            }
        } catch (error) {
            errorDebugger('FieldMappingKey', 'updateChosenFormat', error, 'warn');
        }
    }

    /**
     * Set formatting into Mapping key for checkbox field.
     * @param {*} event 
     */
    setCheckBoxFormat(event) {
        try {
            this.trueValueReplacer = event.currentTarget.dataset.name == 'true' ? event.target.value : this.trueValueReplacer;
            this.falseValueReplacer = event.currentTarget.dataset.name == 'false' ? event.target.value : this.falseValueReplacer;

            if (this.trueValueReplacer != '' || this.falseValueReplacer != '') {
                // if valueReplace is empty, set default true or false accordingly.
                var trueValueReplacer = this.trueValueReplacer != '' ? this.trueValueReplacer : 'true';
                var falseValueReplacer = this.falseValueReplacer != '' ? this.falseValueReplacer : 'false';
                if (this.chosenFormat.key.includes('*')) {
                    this.chosenFormat.key = this.chosenFormat.key.replace(/(?<=\*)(.*?)(?=\*)/g, trueValueReplacer + '/' + falseValueReplacer)
                }
                else {
                    this.chosenFormat.key = this.chosenFormat.key.replace(this.chosenFormat.name, this.chosenFormat.name + ' *' + trueValueReplacer + '/' + falseValueReplacer + '*')
                }
            }
            else {
                // when user clear both input.. set format to default one...
                if (this.chosenFormat.key.includes('*')) {
                    this.chosenFormat.key = this.formatDefault.key;
                }
            }
        } catch (error) {
            errorDebugger('FieldMappingKey', 'setCheckBoxFormat', error, 'warn');
        }
    }

    /**
     * Set formatting into mapping key  for Text field.
     * @param {*} event 
     */
    setTextFormat(event) {
        try {

            if (event.target.value <= 0) {
                event.target.value = '';
            }

            if (event.target.value != '' && event.target.value != null) {
                if (this.chosenFormat.key.includes('*')) {
                    this.chosenFormat.key = this.chosenFormat.key.replace(/(?<=\*)(.*?)(?=\*)/g, `L:${event.target.value}`);
                }
                else {
                    this.chosenFormat.key = this.chosenFormat.key.replace(this.chosenFormat.name, this.chosenFormat.name + ` *L:${event.target.value}*`);
                }
            }
            else if (this.chosenFormat.key.includes('*')) {
                this.chosenFormat.key = this.formatDefault.key;
            }
        } catch (error) {
            errorDebugger('FieldMappingKey', 'setTextFormat', error, 'warn');
        }
    }

    /**
    * Set Formatting key into mapping key for Number field.
    * @param {*} event 
    */
    setNumberFormat(event){
        try {
            const action = event.currentTarget.dataset.action;

            // ... When Method called from format toggle btn ...
            if(action == 'format'){
                if(event.target.checked == true){
                    this.numberFormat['F'] = 'yes';
                }
                else{
                    delete this.numberFormat['F'];
                }
            }
            // ... When Method called from Decimal Places Input  ...
            else if(action == 'decimalPlaces'){
                // SET negative value to Zero...
                if(event.target.value < 0){
                    event.target.value = 0;
                }
                else if(event.target.value > 32){
                    event.target.value = 32;
                }

                // ...Enable / Disable round Mode option based on decimal places value...
                const roundMode = this.template.querySelector(`[data-action="roundMode"]`);
                const roundModeText = this.template.querySelector('[data-text="roundMode"]');

                if(event.target.value != '' && event.target.value != null){
                    this.numberFormat['dP'] = event.target.value;

                    if(roundMode){
                        roundMode.removeAttribute('disabled');
                        roundModeText.classList.remove('roundMode');

                        // add round Mode with decimal places if rM value is not available and value is not none...
                        if(!Object.prototype.hasOwnProperty.call(this.numberFormat, 'rM') && roundMode.value != 'none'){
                            this.numberFormat['rM'] = roundMode.value;
                        }
                    }
                }
                else{
                    delete this.numberFormat['dP'];
                    delete this.numberFormat['rM'];        // remove round Mode if decimal places is null

                    if(roundMode){
                        // if decimal places is not zero... then disable round mode selection as we don't need round node in this case...
                        roundMode.setAttribute('disabled', 'true');
                        roundModeText.classList.add('roundMode');
                    }
                }
            }

            // ... When Method called from Round Mode selection ...
            else if(action == 'roundMode'){
                if(event.target.value != 'none' && event.target.value != '' && event.target.value != null){
                    this.numberFormat['rM'] = event.target.value;
                }
                else{
                    delete this.numberFormat['rM'];
                }
            }

            // ... Update mapping Key ...
            if(Object.keys(this.numberFormat).length){
                const str1 = JSON.stringify(this.numberFormat).replaceAll('"', '');
                const str2 = str1.replaceAll('{', '');
                const str3 = str2.replaceAll('}', ',');

                if(this.chosenFormat.key.includes('*')){
                    this.chosenFormat.key = this.chosenFormat.key.replace(/(?<=\*)(.*?)(?=\*)/g,  `${str3}`);
                }
                else{
                    this.chosenFormat.key = this.chosenFormat.key.replace(this.chosenFormat.name, this.chosenFormat.name + ` *${str3}*`);
                }
            }
            else{
                this.chosenFormat.key = this.formatDefault.key;
            }
            
        } catch (error) {
            errorDebugger('FieldMappingKey', 'setNumberFormat', error ,'warn');            
        }
    }

    /**
     * Close Key Popover on user action.
     * @param {*} event 
     */
    closeKeyPopover(event) {
        try {
            event.stopPropagation();
            this.primeFormatKeys = null;
            this.showFormatKeys = false;
            this.isSubFormat = false;
            this.numberFormat = {};
            this.chosenFormat = {};

        } catch (error) {
            errorDebugger('FieldMappingKey', 'closeKeyPopover', error, 'warn');
        }
    }
    // ==== ==== ==== Field Formatting Methods -- END -- ==== ==== ====

    /**
     * generic method to stop event bubbling from child element to parent
     * @param {*} event 
     */
    stopPropagation(event) {
        event.stopPropagation();
    }

    /**
     * Method to copy salesforce images as HTML tab
     * @param {*} event 
     */
    copySFImgAsHTMl(event) {
        try {
            event.stopPropagation();

            const imgId = event.currentTarget.dataset.id;

            const ImgUrl = this.contentVersionImages.find(ele => ele.Id == imgId)?.imageSRC;

            this.copyImage(ImgUrl, imgId);

        } catch (error) {
            errorDebugger('FieldMappingKey', 'copySFImgAsHTMl', error, 'warn');
        }
    }

    copyPMImgAsHTML(event) {
        try {
            event.stopPropagation();
            let listingno = event.currentTarget.dataset.name;

            const ImgUrl = '/resource/MVEX__tempimage';

            const textarea = document.createElement('textarea');
            textarea.value = ImgUrl;
            document.body.appendChild(textarea);
            textarea.select();

            const img = document.createElement('img');
            img.style.width = '75%';
            img.style.height = '75%';
            img.setAttribute('src', ImgUrl);
            img.setAttribute('data-origin', 'pm');
            img.setAttribute('data-name', listingno);
            img.setAttribute('crossorigin', '*');

            document.body.appendChild(img);

            navigator.clipboard.write([
                new ClipboardItem({
                    'text/html': new Blob([img.outerHTML], { type: 'text/html' }),
                    'text/plain': new Blob([textarea.value], { type: 'text/plain' })
                })
            ]);

            document.body.removeChild(textarea);
            document.body.removeChild(img);

            const displaycontainer = this.template.querySelector('.width_main_css');
            console.log('displaycontainer', displaycontainer);
            if (displaycontainer) {
                displaycontainer.classList.add('copied');
                // setTimeout(() => {
                //     displaycontainer.classList.remove('copied');
                // }, 1001);
                this.customTimeout?.setCustomTimeoutMethod(() => {
                    displaycontainer.classList.remove('copied');
                }, 1001);
            }

            this.propertyMediaCount = this.propertyMediaCount + 1;

        } catch (error) {
            console.log('error in copySFImgAsHTMl : ', error.stack);
        }
    }

    increaseCount() {
        this.propertyMediaCount += 1;
    }

    decreaseCount() {
        if (this.propertyMediaCount > 1) {
            this.propertyMediaCount -= 1;
        }
    }

    /**
     * Copy Image using navigator clipboard.
     * @param {*} imgUrl 
     * @param {*} imgID 
     */
    copyImage(imgUrl, imgID) {
        try {
            const img = document.createElement('img');
            img.style.width = '75%';
            img.setAttribute('src', imgUrl);
            img.setAttribute('data-origin', 'sf');
            document.body.appendChild(img);

            navigator.clipboard.write([
                new ClipboardItem({
                    'text/html': new Blob([img.outerHTML], { type: 'text/html' }),
                })
            ]);

            document.body.removeChild(img);

            const mappingImgContainer = this.template.querySelectorAll(`.mappingImgContainer`);
            mappingImgContainer.forEach(ele => {
                if (ele.dataset.imgid == imgID) {
                    ele.classList.add('copied');
                    // setTimeout(() => {
                    //     ele.classList.remove('copied');
                    // }, 1001);
                    this.customTimeout?.setCustomTimeoutMethod(() => {
                        ele.classList.remove('copied');
                    }, 1001);
                }
                else {
                    ele.classList.remove('copied');
                }
            });
        } catch (error) {
            errorDebugger('FieldMappingKey', 'copyImage', error, 'warn');
        }
    }

    /**
     * Method to convert raw(encrypted binary) data into base64.
     * @param {*} data 
     * @returns 
     */
    getArrayBuffer(data) {
        var len = data.length,
            ab = new ArrayBuffer(len),
            u8 = new Uint8Array(ab);

        while (len--) u8[len] = data.charCodeAt(len);
        return ab;
    };

    /**
     * Set highted Selection color on mapping key element's text
     * @param {*} event 
     */
    setHighlightedSelection(event) {
        try {
            // ASet highted Selection color on mapping key element's text
            var range = document.createRange();
            range.selectNode(event.target);
            window.getSelection().removeAllRanges();
            window.getSelection().addRange(range);
        } catch (error) {
            errorDebugger('FieldMappingKey', 'setHighlightedSelection', error, 'warn');
        }
    }

    /**
     * Set Signature size into variable
     * @param {*} event 
     */
    setSignatureSize(event){
        this.signatureSize = event.target.value;
    }

    /**
     * Update Signature size in backed.
     */
    updateSignatureSize(){
        try {
            this.savedSignatureSize = this.signatureSize;
            updateSignatureInfo({templateId : this.templateId, signatureSize : this.signatureSize});
        } catch (error) {
            errorDebugger('FieldMappingKeyV2', 'updateSignatureSize', error ,'warn');            
        }
    }

    /**
     * Dispatch & Trigger 'onclose' event into parent component when user click on close button
     */
    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    sortFormateKeys(list, orderBy) {
        return list.sort((a, b) => {
            return a[orderBy]?.localeCompare(b[orderBy]);
        });
    }


    /**
     * Triggers a preview event using CustomEvent.
     * Also updates the signature size after triggering the event.
     */
    handlePreview() {
        let custEvent = new CustomEvent('preview', {
            detail: this.propertyMediaCount
        });
        this.dispatchEvent(custEvent);
        this.updateSignatureSize();
    }

    handleSave() {
        let custEvent = new CustomEvent('save', {
            detail: this.propertyMediaCount
        });
        this.dispatchEvent(custEvent);
        this.updateSignatureSize();
    }

    /**
     * API Method to get object filed and its mapping key from parent object.
     */
    @api
    getAllMappingFields() {
        try {
            const objectKeys = {};
            objectKeys.objectFieldKeys = [];
            objectKeys.generalFieldsKeys = [];
            objectKeys.mergeTemps = [];

            this.fieldMappingsWithObj.forEach(ele => {
                ele.fieldMappings.forEach(item => {
                    objectKeys.objectFieldKeys.push(item.name);
                });
            });

            this.generalFieldTypes.forEach(ele => {
                ele.fieldMappings.forEach(item => {
                    objectKeys.generalFieldsKeys.push(item.name);
                });
            });

            return objectKeys;
        } catch (error) {
            errorDebugger('FieldMappingKey', 'getAllMappingFields', error, 'warn');
            return null;
        }
    }

    handleTimeout(event){
		try {
			if(event?.detail?.function){
				event?.detail?.function();
			}
		} catch (error) {
			errorDebugger('DocumentLoader', 'handleTimeout', error, 'warn')
		}
	}

    _buildAllMappingKeys() {
        // ---- object fields -------------------------------------------------
        this.objectFieldKeys = [];
        this.fieldMappingsWithObj?.forEach(obj => {
            obj.fieldMappings?.forEach(f => this.objectFieldKeys.push(f.key));
        });

        // ---- general fields ------------------------------------------------
        this.generalFieldKeys = [];
        this.generalFieldTypes?.forEach(type => {
            type.fieldMappings?.forEach(f => this.generalFieldKeys.push(f.key));
        });

        // ---- signature -----------------------------------------------------
        // The signature key is returned from the Apex call `formattingFieldKeys`
        // (it is already stored in `this.signatureKey` – just wrap it)
        this.signatureKey = this.signatureKey ? [this.signatureKey] : [];

        // ---- fire the event for the parent --------------------------------
        this.dispatchEvent(
            new CustomEvent('mappingkeysready', {
                detail: {
                    objectFieldKeys:  this.objectFieldKeys,
                    generalFieldKeys: this.generalFieldKeys,
                    signatureKey:     this.signatureKey
                },
                bubbles: true,
                composed: true
            })
        );
    }

}