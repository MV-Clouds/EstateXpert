import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import getEmailCampaignTemplates from '@salesforce/apex/EmailCampaignController.getEmailCampaignTemplates';
import getMarketingEmails from '@salesforce/apex/EmailCampaignController.getMarketingEmails';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import getMessagingServiceOptions from '@salesforce/apex/EmailCampaignController.getMessagingServiceOptions';


export default class EmailCampaignModal extends NavigationMixin(LightningElement) {
    @track templateOptions = [];
    @track marketingEmails = [];
    @track templates = null;
    @api selectedTemplateId = '';
    @api selectedObjectValue = '';
    @api isEdit = false;
    @api selectedContacts = [];
    @api formData = {
        selectedTemplate: '',
        campaignName: '',
        messagingService: '',
        saveForFuture: false,
        selectedObject : '' 
    };

    @track messageOptions;

    @track isLoading = false;
    @track selectedTemplateIdValue = ''
    @track formDataValue = {};

    get objectOptions (){
        return [
            { label: 'Lead', value: 'Lead' },
            { label: 'Contact', value: 'Contact' }
        ];
    }
    

    get isSaveDisabled() {
        return !this.isFormValid();
    }

    /*
    * Method Name: connectedCallback
    * @description: method to load style using statuc resource
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    connectedCallback() {
        this.selectedTemplateIdValue = this.selectedTemplateId;
        this.formDataValue = { ...this.formData };
        this.loadEmailCampaignTemplates();
        this.loadMessageOptions();
        this.isLoading = true;
        Promise.all([
            loadStyle(this, MulishFontCss)
        ])
            .then(() => {
                console.log('External Css Loaded');
                this.isLoading = false;
            })
            .catch(error => {
                console.log('Error occurring during loading external css', error);
                this.isLoading = false;
            });
    }

    /*
    * Method Name: getEmailCampaignTemplates
    * @description: method to get template options
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    loadEmailCampaignTemplates() {
        getEmailCampaignTemplates()
            .then(data => {
                this.templates = data;
                this.templateOptions = [{ label: 'None', value: '' }, ...data.map(template => {
                    return { label: template.MVEX__Label__c, value: template.Id };
                })];
            })
            .catch(error => {
                this.showToast('Error', 'Failed to fetch template options', 'error');
                console.error(error);
            });
    }

    /*
    * Method Name: loadMessageOptions
    * @description: method to get message service optiona
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    loadMessageOptions() {
        getMessagingServiceOptions()
            .then(data => {
                console.log(JSON.stringify(data));
                this.messageOptions = data.map(option => {
                    return { label: option.label, value: option.value };
                });

            })
            .catch(error => {
                this.showToast('Error', 'Failed to fetch message options', 'error');
                console.error(error);
            })
    }
    /*
    * Method Name: handleCloseModal
    * @description: method to close the modal
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleCloseModal() {
        this.resetFormData();
        if (typeof window !== 'undefined') {
            const closeEvent = new CustomEvent('close');
            this.dispatchEvent(closeEvent);   
        }
    }

    /*
    * Method Name: resetFormData
    * @description: method to reset form
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    resetFormData() {
        this.formDataValue = {
            selectedTemplate: '',
            campaignName: '',
            messagingService: '',
            saveForFuture: false,
            selectedObject : ''
        };
        this.selectedTemplateIdValue = '';
    }


    /*
    * Method Name: handleChange
    * @description: method to handle changes
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleChange(event) {
        const { name, value, checked } = event.target;
        if (name === 'saveForFuture') {
            this.formDataValue = { ...this.formDataValue, [name]: checked };
        } else if (name === 'selectedTemplate') {
            this.selectedTemplateIdValue = value;
            if (value === '') {
                this.resetFormData();
                this.marketingEmails = [];
            } else {
                const selectedOption = this.templateOptions.find(option => option.value === value);
                console.log('selectedOption ==>', selectedOption);

                if (selectedOption) {
                    const selectedTemplate = this.templates.find(template => template.Id === value);
                    console.log('selectedTemplate ==> ', selectedTemplate);
                    if (selectedTemplate) {
                        this.formDataValue = {
                            ...this.formDataValue,
                            selectedTemplate: selectedOption.label,
                        };

                    }
                }
            }
        } else if (name === 'objectSelector') {
            // Add any extra logic you want to perform when objectSelector changes
            console.log('Selected Object:', value);
            this.formDataValue = {
                ...this.formDataValue,
                selectedObject: value
            };
        }  
        else {
            this.formDataValue = { ...this.formDataValue, [name]: value };
        }
    }


    /*
    * Method Name: handleSave
    * @description: method to handle save
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleSave() {
        if (this.isFormValid()) {
            getMarketingEmails({ templateId: this.selectedTemplateIdValue })
                .then(result => {
                    this.marketingEmails = result;
                    const navigationState = {
                        ...this.formDataValue,
                        marketingEmails: this.marketingEmails,
                        selectedTemplateId: this.selectedTemplateIdValue,
                    };

                    if (typeof window !== 'undefined') {
                        const event = new CustomEvent('handledatachange', {
                            bubbles: true,
                            detail: navigationState
                        });
                        this.dispatchEvent(event);
                    }
                })
                .catch(error => {
                    this.showToast('Error', 'Error fetching marketing emails', 'error');
                    console.error(error);
                });
        } else {
            this.showToast('Error', 'All required fields must be filled out', 'error');
        }
    }

    /*
    * Method Name: handleNext
    * @description: method to next functionality
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    handleNext() {
        if (this.isFormValid()) {
            getMarketingEmails({ templateId: this.selectedTemplateIdValue })
                .then(result => {
                    this.marketingEmails = result;
                    const navigationState = {
                        ...this.formDataValue,
                        marketingEmails: this.marketingEmails,
                        selectedTemplateId: this.selectedTemplateIdValue,
                        selectedContacts: this.selectedContacts
                    };
    
                    var cmpDef = {
                        componentDef: 'MVEX:emailCampaignTemplateForm',
                        attributes: {
                            c__navigationState: navigationState,
                        }
                    };
    
                    let encodedDef = btoa(JSON.stringify(cmpDef));
                    console.log('encodedDef : ', encodedDef);
                    this[NavigationMixin.Navigate]({
                        type: "standard__webPage",
                        attributes: {
                            url: "/one/one.app#" + encodedDef
                        },
                        apiName: 'Email_Campaign_Template_Form'
                    });
    
                    this.handleCloseModal();
                })
                .catch(error => {
                    this.showToast('Error', 'Error fetching marketing emails', 'error');
                    console.error(error);
                });
        } else {
            this.showToast('Error', 'Please fill in all required fields', 'error');
        }
    }

    /*
    * Method Name: isFormValid
    * @description: method check require fields
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    isFormValid() {
        console.log('OUTPUT : ', JSON.stringify(this.formDataValue));
        if (
            this.formDataValue.campaignName &&
            this.formDataValue.campaignName.trim() !== '' &&
            this.formDataValue.messagingService && 
            this.formDataValue.selectedObject 
        ) {
            return true;
        }

        return false;
    }

    /*
    * Method Name: showToast
    * @description: method to show toast message
    * Date: 24/06/2024
    * Created By: Rachit Shah
    */
    showToast(title, message, variant) {
        if (typeof window !== 'undefined') {
            const event = new ShowToastEvent({
                title,
                message,
                variant,
            });
            this.dispatchEvent(event);
        }
    }
}