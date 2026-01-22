import { LightningElement, track, api } from 'lwc';
import createWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.createWhatsAppFlow';
import publishWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.publishWhatsAppFlow';
import updateWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.updateWhatsAppFlow';
import deleteWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.deleteWhatsAppFlow';
import deprecateWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.deprecateWhatsAppFlow';
import getPreviewURLofWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.getPreviewURLofWhatsAppFlow';
import FlowIcon from '@salesforce/resourceUrl/FlowIcon';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import MonacoEditor from '@salesforce/resourceUrl/MonacoEditor';
import PublishPopupImage from '@salesforce/resourceUrl/PublishPopupImage';
import getJSONData from '@salesforce/apex/WhatsAppFlowController.getJSONData';
import getWhatsAppFlowById from '@salesforce/apex/WhatsAppFlowController.getWhatsAppFlowById';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { NavigationMixin } from 'lightning/navigation';

export default class CreateFlowManagement extends NavigationMixin(LightningElement) {
    @track selectedCategories = [];
    @track showLicenseError = false;

    @api isEditMode;
    @api selectedFlowId;

    @track status = 'Initialize';
    @track isUnsavedChanges = false;
    editor;
    templateType = 'Default';
    jsonString = '';
    isCreateDisabled = true;
    publishImageUrl = PublishPopupImage;
    iscreateflowvisible = true; 
    dropdownClose = true;
    showPublishPopup = false;
    showDeletePopup = false;
    showDeprecatePopup = false;
    isJsonVisible=false;
    flowName = '';
    flowId = '';
    flowPreviewURL = '';
    maxFlowNamelength = 200;
    flowIconUrl = FlowIcon;
    isLoading = false;
    flows = [];
    LastUpdatedDate = '';

    get TypeOptions() {
        return [
            { label: 'Sign up', value: 'SIGN_UP' },
            { label: 'Sign in', value: 'SIGN_IN' },
            { label: 'Appointment booking', value: 'APPOINTMENT_BOOKING' },
            { label: 'Lead generation', value: 'LEAD_GENERATION' },
            { label: 'Shopping', value: 'SHOPPING' },
            { label: 'Contact us', value: 'CONTACT_US' },
            { label: 'Customer support', value: 'CUSTOMER_SUPPORT' },
            { label: 'Survey', value: 'SURVEY' },
            { label: 'Other', value: 'OTHER' }
        ];
    }

    get isEdit(){
        return (this.isEditMode || this.isJsonVisible);
    }

    get isSaveEnabled(){
        return (this.status == 'Initialize' || this.isEditMode);
    }

    get isPublishedEnabled(){
        return (this.status == 'Draft');
    }

    get disablePublish(){
        return (this.isUnsavedChanges ? true : false);
    }

    get isDeleteEnabled(){
        return this.status == 'Draft' ? true : false;
    }

    get isDeprecateEnabled(){
        return (this.status == 'Published' ? true : false);
    }

    connectedCallback(){
        try {
            loadStyle(this, MulishFontCss)
            .then(() => {
                console.log('External Css Loaded');
            })
            .catch(error => {
                console.log('Error occuring during loading external css', error);
            });
            if (this.isEdit && this.selectedFlowId) {
                this.flowId = this.selectedFlowId;
                this.getJSONDataFromApexForEdit();
            }
        } catch (e) {
            console.error('Error in connectedCallback:::', e.message);
        }
    }

    handleTypeChange(event) {
        this.templateType = event.target.value;
    }

    handleInputChange(event){
        try {
            this.flowName = event.target.value;  
            if (this.selectedCategories.length > 0 && this.flowName.trim()) {
                this.isCreateDisabled = false;
            } else {
                this.isCreateDisabled = true;
            }
        } catch (error) {
            console.error('Error in handleInputChange : ' , error);
        }
    }

    handleDiscard() {
        let cmpDef = {
            componentDef: "MVEX:wbAllFlowsPage",
            attributes: {
                isEditMode: this.isEditMode,
                selectedFlowId: this.selectedFlowId
            }
        };

        let encodedDef = btoa(JSON.stringify(cmpDef));
            this[NavigationMixin.Navigate]({
            type: "standard__webPage",
            attributes: {
                url:  "/one/one.app#" + encodedDef                                                         
            }
        });
    }
  
    handleCatagories(event) {
        try {
            const selectedCategories = event.detail.selectedValues;
            this.selectedCategories = selectedCategories;
    
            if (this.selectedCategories.length > 0 && this.flowName.trim()) {
                this.isCreateDisabled = false;
            } else {
                this.isCreateDisabled = true;
            }
        } catch (error) {
            console.error('Error in handleCategories : ' , error);
        }
    }
  
    handleCreate(){
        this.getJSONDataFromApex();
    }

    get formatDate(){
        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        const today = this.LastUpdatedDate ? new Date(this.LastUpdatedDate) : new Date();
        const day = today.getDate();
        const month = months[today.getMonth()];
        const year = today.getFullYear();
        return `Updated ${day} ${month} ${year}`;
    }

    getJSONDataFromApex(){
        try {
            this.isLoading = true;
            getJSONData({type: this.templateType})
                .then((data) => {
                    if(data){
                        this.jsonString = data;
                        this.formatJSONDataonUI();
                        // this.getFlowPreview();
                    } else {
                        console.error('Error loading JSON data:');
                        this.showToast('Error', 'Failed to load Flow JSON data', 'error');
                        this.isLoading = false;
                    }
                })
                .catch((error) => {
                    console.error('error in json fetch' , error);
                    this.showToast('Error', 'Failed to load Flow JSON data', 'error');
                    this.isLoading = false;
                });
        } catch (error) {
            console.error('Error loading JSON data:', error);
            this.showToast('Error', 'Failed to load Flow JSON data', 'error');
            this.isLoading = false;
        }
    }

    getJSONDataFromApexForEdit() {
        this.isLoading = true;
        getWhatsAppFlowById({ flowId: this.flowId })
            .then((data) => {
                if (data) {
                    this.jsonString = data[0].MVEX__Flow_JSON__c;
                    this.status = data[0].MVEX__Status__c;
                    this.flowName = data[0].MVEX__Flow_Name__c;
                    this.LastUpdatedDate = data[0].LastModifiedDate;
                    this.formatJSONDataonUI();
                } else {
                    console.error('Error loading JSON data for edit:');
                    this.showToast('Error', 'Failed to load Flow JSON data for edit', 'error');
                    this.isLoading = false;
                }
            })
            .catch((error) => {
                console.error('Error in fetching WhatsApp Flow by ID:', error);
                this.showToast('Error', 'Failed to load Flow JSON data for edit', 'error');
                this.isLoading = false;
            });
    }

    formatJSONDataonUI(){
        try {
            this.isLoading = true;
            this.isJsonVisible = true;
            this.iscreateflowvisible = false; 
            loadScript(this, MonacoEditor + '/min/vs/loader.js')
            .then(() => {
                require.config({ paths: { vs: MonacoEditor + '/min/vs' } });
                require(['vs/editor/editor.main'], () => {
                    this.initializeEditor();
                });
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error loading Monaco Editor:', error);
                this.isLoading = false;
            })
        } catch (error) {
            console.error('Error loading Monaco Editor:', error);
            this.isLoading = false;
        }
    }
    
    initializeEditor() {
        try {
            this.editor = monaco.editor.create(this.template.querySelector('.editor'), {
                value: this.jsonString,
                language: 'json',
                theme: 'vs-light',
                automaticLayout: true,
                readOnly: false,
                minimap: { enabled: false }
            });
    
            this.editor.onDidChangeModelContent(() => {
                this.jsonString = this.editor.getValue();
                this.isUnsavedChanges = true;
            });
            this.isLoading = false;
        } catch (error) {
            console.error('Error in initializing Editor:', error);
            this.isLoading = false;
        }
    }

    getFlowPreview(){
        try {
            if(this.flowId != '') {
                this.isLoading = true;
                getPreviewURLofWhatsAppFlow({ flowId : this.flowId })
                    .then((data) => {
                        if(data != 'failed'){
                            this.flowPreviewURL = data;
                        } else {
                            console.error('Error in getting Flow Preview URL:');
                        }
                    })
                    .catch(error => {
                        console.error('Error in getting Flow Preview URL:', error);
                    })
                    .finally(() => {
                        this.isLoading = false;
                    });
            } else {
                console.error('Flow id not found');
                this.isLoading = false;
            }
        } catch (error) {
            console.error('Error in getting Flow Preview URL:', error);
            this.isLoading = false;
        }
    }

    onRunClick() {
        try {
            this.isLoading = true;
            this.jsonString = this.editor.getValue();
            // console.log('json string in on run click==> ',this.jsonString);
            // updateJson({jsonPayload: this.jsonString});
            // Save the current JSON to the database
            // saveWhatsAppFlow({jsonPayload: this.jsonString});
            
            // Validate JSON in the editor
            const model = this.editor.getModel();
            const markers = monaco.editor.getModelMarkers({ owner: 'json' }); // Get JSON-specific markers

            const errorMarkers = markers.filter(marker => marker.severity === monaco.MarkerSeverity.Error);
            if (errorMarkers.length > 0) {
                this.showToast('Error', 'Invalid JSON: Please fix the syntax errors in the editor', 'error');
                this.isLoading = false;
                return;
            }

            const previewComponent = this.template.querySelector('c-wb-flow-preview');
            if (previewComponent) {
                previewComponent.runPreview(); 
            } else {
                console.error('WbPreviewFlow component not found');
            }
            this.getFlowPreview();
        } catch (error) {
            console.error('Error validating JSON:', error);
            this.showToast('Error', 'Failed to validate JSON', 'error');
            this.isLoading = false;
        }
    }

    onPublishClick(){
        this.showPublishPopup = true;
    }

    // Close Popup
    closePublishPopup() {
        this.showPublishPopup = false;
    }

    // Handle Publish Button Click
    handlePublish() {
        try {
            this.isLoading = true;
            this.showPublishPopup = false;
            publishWhatsAppFlow({flowId : this.flowId})
                .then((result) => {
                    if(!result.startsWith('Failed')){
                        this.showToast('Success', 'Flow published successfully', 'success');
                        this.status='Published';
                        this.isUnsavedChanges = false;
                        this.handleDiscard();
                    } else {
                        console.error('Error in publishing WhatsApp Flow');
                    }
                })
                .catch((error) => {
                    this.showToast('Error', 'Failed to publish flow', 'error');
                    console.error('Failed to publish flow : ' , error);
                })
                .finally(() => {
                    this.isLoading = false;
                })
        } catch (error) {
            this.showToast('Error', 'Failed to publish flow', 'error');
            console.error('Failed to publish flow : ' , error);
            this.isLoading = false;
        }
    }

    onDeleteClick(){
        this.showDeletePopup = true;
    }

    handleDelete(){
        try {
            this.isLoading = true;
            this.showDeletePopup = false;
            deleteWhatsAppFlow({flowId : this.flowId})
                .then((result) => {
                    if(!result.startsWith('Failed')){
                        this.showToast('Success', 'Flow deleted successfully', 'success');
                        this.handleDiscard();
                    } else {
                        this.showToast('Error', 'Failed to delete flow', 'error');
                        console.error('Error in deleting WhatsApp Flow');
                    }
                    })
                .catch((error) => {
                    this.showToast('Error', 'Failed to delete flow', 'error');
                    console.error('Failed to delete flow : ' , error);
                })
                .finally(() => {
                    this.isLoading = false;
                })
        } catch (error) {
            this.showToast('Error', 'Failed to delete flow', 'error');
            console.error('Failed to delete flow : ' , error);
            this.isLoading = false;
        }
    }

    closeDeletePopup(){
        this.showDeletePopup = false;
    }

    onDeprecateClick(){
        this.showDeprecatePopup = true;
    }

    handleDeprecate(){
        try {
            this.isLoading = true;
            this.showDeletePopup = false;
            deprecateWhatsAppFlow({flowId : this.flowId})
                .then((result) => {
                    if(!result.startsWith('Failed')){
                        this.showToast('Success', 'Flow deprecated successfully', 'success');
                        this.handleDiscard();
                    } else {
                        this.showToast('Error', 'Failed to deprecate flow', 'error');
                        console.error('Error in deleting WhatsApp Flow:');
                    }
                })
                .catch((error) => {
                    this.showToast('Error', 'Failed to delete flow', 'error');
                    console.error('Failed to delete flow : ' , error);
                })
                .finally(() => {
                    this.isLoading = false;
                })
        } catch (error) {
            this.showToast('Error', 'Failed to delete flow', 'error');
            console.error('Failed to delete flow : ' , error);
            this.isLoading = false;
            this.closeDeletePopup();
        }
    }

    onSaveClick(){
        this.isLoading = true;
        if (this.isEditMode) {
            updateWhatsAppFlow({
                flowId: this.flowId,
                flowJson: this.jsonString
            })
            .then(() => {
                this.status = 'Draft';
                this.showToast('Success', 'Flow updated successfully', 'success');
                this.onRunClick();
                this.isUnsavedChanges = false;
            })
            .catch(error => {
                console.error('Error updating WhatsApp Flow:', error);
                this.showToast('Error', 'Failed to update WhatsApp Flow', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
        } else {
            createWhatsAppFlow({
                flowName: this.flowName,
                categories: this.selectedCategories,
                flowJson: this.jsonString,
                templateType: this.templateType
            })
            .then(result => {
                this.flowId = result; 
                this.status = 'Draft';
                this.showToast('Success', 'Flow created successfully', 'success');
            })
            .catch(error => {
                console.error('Error creating WhatsApp Flow:', error);
                this.showToast('Error', 'Failed to create WhatsApp Flow', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
        }
    }

    closeDeprecatePopup(){
        this.showDeletePopup = false;
    }

    onBackClick(){
        this.handleDiscard();
    }

    showToast(title, message, varient) {
        const toastEvent = new ShowToastEvent({title: title, message: message, variant: varient});
        this.dispatchEvent(toastEvent);
    }
}