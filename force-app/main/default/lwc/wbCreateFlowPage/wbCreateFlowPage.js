import { LightningElement, track, wire } from 'lwc';
// import createWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.createWhatsAppFlow';
// import publishWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.publishWhatsAppFlow';
// import deleteWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.deleteWhatsAppFlow';
// import deprecateWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.deprecateWhatsAppFlow';
// import getPreviewURLofWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.getPreviewURLofWhatsAppFlow';
// import FlowIcon from '@salesforce/resourceUrl/FlowIcon';
// import { loadScript } from 'lightning/platformResourceLoader';
// import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// import MonacoEditor from '@salesforce/resourceUrl/MonacoEditor';
// import PublishPopupImage from '@salesforce/resourceUrl/PublishPopupImage';
// import getJSONData from '@salesforce/apex/WhatsAppFlowController.getJSONData';
// import checkLicenseUsablility from '@salesforce/apex/PLMSController.checkLicenseUsablility';

export default class WbCreateFlowPage extends LightningElement {
    @track selectedCategories = [];

    status = '';
    editor;
    templateType = 'Default';
    jsonString = '';
    isFlowVisible = true;
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

    // get TypeOptions() {
    //     return [
    //         { label: 'Sign up', value: 'SIGN_UP' },
    //         { label: 'Sign in', value: 'SIGN_IN' },
    //         { label: 'Appointment booking', value: 'APPOINTMENT_BOOKING' },
    //         { label: 'Lead generation', value: 'LEAD_GENERATION' },
    //         { label: 'Shopping', value: 'SHOPPING' },
    //         { label: 'Contact us', value: 'CONTACT_US' },
    //         { label: 'Customer support', value: 'CUSTOMER_SUPPORT' },
    //         { label: 'Survey', value: 'SURVEY' },
    //         { label: 'Other', value: 'OTHER' }
    //     ];
    // }

    // get isSaveEnabled(){
    //     return false;
    // }

    // get isPublishedEnabled(){
    //     return this.status == 'Draft' ? true : false;
    // }

    // get isDeleteEnabled(){
    //     return this.status == 'Draft' ? true : false;
    // }

    // get isDeprecateEnabled(){
    //     return this.status == 'Published' ? true : false;
    // }

    // async connectedCallback(){
    //     try {
    //         this.showSpinner = true;
    //     } catch (e) {
    //         console.error('Error in connectedCallback:::', e.message);
    //     }
    // }

    // handleTypeChange(event) {
    //     this.templateType = event.target.value;
    // }

    // handleInputChange(event){
    //     try {
    //         this.flowName = event.target.value;  
    //         if (this.selectedCategories.length > 0 && this.flowName.trim()) {
    //             this.isCreateDisabled = false;
    //         } else {
    //             this.isCreateDisabled = true;
    //         }
    //     } catch (error) {
    //         console.error('Error in handleInputChange : ' , error);
    //     }
    // }

    // handleDiscard() {
    //     this.isFlowVisible = false;
    // }
  
    // handleCatagories(event) {
    //     try {
    //         const selectedCategories = event.detail.selectedValues;
    //         this.selectedCategories = selectedCategories;
    
    //         if (this.selectedCategories.length > 0 && this.flowName.trim()) {
    //             this.isCreateDisabled = false;
    //         } else {
    //             this.isCreateDisabled = true;
    //         }
    //     } catch (error) {
    //         console.error('Error in handleCategories : ' , error);
    //     }
    // }
  
    // handleCreate(){
    //     this.getJSONDataFromApex();
    // }

    // get formatDate(){
    //     const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    //     const today = new Date();
    //     const day = today.getDate();
    //     const month = months[today.getMonth()];
    //     const year = today.getFullYear();
    //     return `Updated ${day} ${month} ${year}`;
    // }

    // getJSONDataFromApex(){
    //     try {
    //         this.isLoading = true;
    //         getJSONData({type: this.templateType})
    //             .then((data) => {
    //                 if(data){
    //                     this.jsonString = data;
    
    //                     const catagories = Array.from(this.selectedCategories);  
    
    //                     createWhatsAppFlow({ flowName: this.flowName, categories: catagories, flowJson: this.jsonString, templateType: this.templateType })
    //                         .then((result) => {
    //                             if (!result.startsWith('Failed')) {
    //                                 this.flowId = result;
    //                                 this.status = 'Draft';
    //                                 this.formatJSONDataonUI();
    //                                 this.getFlowPreview();
    //                                 this.showToast('Success', 'Flow created successfully', 'success');
    //                                 // this.isJsonVisible = true;
    //                                 // this.iscreateflowvisible = false; 
    //                             } else {
    //                                 console.error(result);
    //                                 this.showToast(result);
    //                                 this.isLoading = false;
    //                             }
    //                         }).catch(error => {
    //                             console.error('Error in creating Flow : ',error);
    //                             this.showToast('Error', 'Failed to create flow', 'error');
    //                             this.isLoading = false;
    //                         });
    //                 } else {
    //                     console.error('Error loading JSON data:', error);
    //                     this.showToast('Error', 'Failed to load Flow JSON data', 'error');
    //                     this.isLoading = false;
    //                 }
    //             })
    //             .catch((error) => {
    //                 console.error('error in json fetch' , error);
    //                 this.showToast('Error', 'Failed to load Flow JSON data', 'error');
    //                 this.isLoading = false;
    //             });
    //     } catch (error) {
    //         console.error('Error loading JSON data:', error);
    //         this.showToast('Error', 'Failed to load Flow JSON data', 'error');
    //         this.isLoading = false;
    //     }
    // }

    // formatJSONDataonUI(){
    //     try {
    //         this.isLoading = true;
    //         Promise.all([
    //             loadScript(this, MonacoEditor + '/min/vs/loader.js')
    //         ])
    //         .then(() => {
    //             require.config({ paths: { vs: MonacoEditor + '/min/vs' } });
    //             this.isJsonVisible = true;
    //             this.iscreateflowvisible = false; 
    //             require(['vs/editor/editor.main'], () => {
    //                 this.initializeEditor();
    //             });
    //             this.isLoading = false;
    //         })
    //         .catch(error => {
    //             console.error('Error loading Monaco Editor:', error);
    //             this.isLoading = false;
    //         })
    //     } catch (error) {
    //         console.error('Error loading Monaco Editor:', error);
    //         this.isLoading = false;
    //     }
    // }
    
    // initializeEditor() {
    //     try {
    //         this.editor = monaco.editor.create(this.template.querySelector('.editor'), {
    //             value: this.jsonString,
    //             language: 'json',
    //             theme: 'vs-light',
    //             automaticLayout: true,
    //             readOnly: true,
    //             minimap: { enabled: false }
    //         });
    
    //         this.editor.onDidChangeModelContent(() => {
    //             this.jsonString = this.editor.getValue();
    //         });
    //         this.isLoading = false;
    //     } catch (error) {
    //         console.error('Error in initializing Editor:', error);
    //         this.isLoading = false;
    //     }
    // }

    // getFlowPreview(){
    //     try {
    //         if(this.flowId != '') {
    //             this.isLoading = true;
    //             getPreviewURLofWhatsAppFlow({ flowId : this.flowId })
    //                 .then((data) => {
    //                     if(data != 'failed'){
    //                         this.flowPreviewURL = data;
    //                     } else {
    //                         console.error('Error in getting Flow Preview URL:', error);
    //                     }
    //                 })
    //                 .catch(error => {
    //                     console.error('Error in getting Flow Preview URL:', error);
    //                 })
    //                 .finally(() => {
    //                     this.isLoading = false;
    //                 });
    //         } else {
    //             console.error('Flow id not found');
    //             this.isLoading = false;
    //         }
    //     } catch (error) {
    //         console.error('Error in getting Flow Preview URL:', error);
    //         this.isLoading = false;
    //     }
    // }

    // onRunClick(){
    //     this.getFlowPreview();
    // }

    // onPublishClick(){
    //     this.showPublishPopup = true;
    // }

    // // Close Popup
    // closePublishPopup() {
    //     this.showPublishPopup = false;
    // }

    // // Handle Publish Button Click
    // handlePublish() {
    //     try {
    //         this.isLoading = true;
    //         this.showPublishPopup = false;
    //         publishWhatsAppFlow({flowId : this.flowId})
    //             .then((result) => {
    //                 if(!result.startsWith('Failed')){
    //                     this.showToast('Success', 'Flow published successfully', 'success');
    //                     this.isFlowVisible = false;
    //                 } else {
    //                     console.error('Error in publishing WhatsApp Flow:', error);
    //                 }
    //             })
    //             .catch((error) => {
    //                 this.showToast('Error', 'Failed to publish flow', 'error');
    //                 console.error('Failed to publish flow : ' , error);
    //             })
    //             .finally(() => {
    //                 this.isLoading = false;
    //             })
    //     } catch (error) {
    //         this.showToast('Error', 'Failed to publish flow', 'error');
    //         console.error('Failed to publish flow : ' , error);
    //         this.isLoading = false;
    //     }
    // }

    // onDeleteClick(){
    //     this.showDeletePopup = true;
    // }

    // handleDelete(){
    //     try {
    //         this.isLoading = true;
    //         this.showDeletePopup = false;
    //         deleteWhatsAppFlow({flowId : this.flowId})
    //             .then((result) => {
    //                 if(!result.startsWith('Failed')){
    //                     this.showToast('Success', 'Flow deleted successfully', 'success');
    //                     this.isFlowVisible = false;
    //                 } else {
    //                     this.showToast('Error', 'Failed to delete flow', 'error');
    //                     console.error('Error in deleting WhatsApp Flow:', error);
    //                 }
    //                 })
    //             .catch((error) => {
    //                 this.showToast('Error', 'Failed to delete flow', 'error');
    //                 console.error('Failed to delete flow : ' , error);
    //             })
    //             .finally(() => {
    //                 this.isLoading = false;
    //             })
    //     } catch (error) {
    //         this.showToast('Error', 'Failed to delete flow', 'error');
    //         console.error('Failed to delete flow : ' , error);
    //         this.isLoading = false;
    //     }
    // }

    // closeDeletePopup(){
    //     this.showDeletePopup = false;
    // }

    // onDeprecateClick(){
    //     this.showDeprecatePopup = true;
    // }

    // handleDeprecate(){
    //     try {
    //         this.isLoading = true;
    //         this.showDeletePopup = false;
    //         deprecateWhatsAppFlow({flowId : this.flowId})
    //             .then((result) => {
    //                 if(!result.startsWith('Failed')){
    //                     this.showToast('Success', 'Flow deprecated successfully', 'success');
    //                     this.isFlowVisible = false;
    //                 } else {
    //                     this.showToast('Error', 'Failed to deprecate flow', 'error');
    //                     console.error('Error in deleting WhatsApp Flow:', error);
    //                 }
    //             })
    //             .catch((error) => {
    //                 this.showToast('Error', 'Failed to delete flow', 'error');
    //                 console.error('Failed to delete flow : ' , error);
    //             })
    //             .finally(() => {
    //                 this.isLoading = false;
    //             })
    //     } catch (error) {
    //         this.showToast('Error', 'Failed to delete flow', 'error');
    //         console.error('Failed to delete flow : ' , error);
    //         this.isLoading = false;
    //         this.closeDeletePopup();
    //     }
    // }

    // closeDeprecatePopup(){
    //     this.showDeletePopup = false;
    // }

    // onBackClick(){
    //     this.isFlowVisible = false;
    // }

    // showToast(title, message, varient) {
    //     const toastEvent = new ShowToastEvent({title: title, message: message, variant: varient});
    //     this.dispatchEvent(toastEvent);
    // }
}