import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAllObjectNames from '@salesforce/apex/TemplateBuilderController.getAllObjectNames';
import insertTemplate from '@salesforce/apex/TemplateBuilderController.insertTemplate';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';

export default class CustomModal extends NavigationMixin(LightningElement) {

    @track objectOptions;
    @track backupObjectOptions;
    @track templateTypeOptions;
    @track templateNameValue = '';
    @track descriptionValue = '';
    @track selectedObjectAPIName = '';
    @track selectedObjectLabel = '';
    @track currentRecordIdValue = '';
    @track templateTypeSelectValue = '';
    @track isPicklistDisabled = false;
    @track subjectValue = '';

    /**
    * Method Name: get isMarketingTemplate()
    * @returns {Boolean} - Returns true if the template type is marketing template
    * @description: Used to check if the template type is marketing template
    * Created Date: 12/06/2024
    * Created By: Rachit Shah
    */
    get isEmailTemplate() {
        return this.templateTypeSelectValue === 'Marketing Template';
    }

    /**
    * Method Name: connectedCallback
    * @description: Method to remove default things if there is new templatencreation
    * Created Date: 12/06/2024
    * Created By: Rachit Shah
    */
    connectedCallback(){    
        try {
            loadStyle(this, MulishFontCss)
            .then(() => {
                console.log('External Css Loaded');
            })
            .catch(error => {
                console.log('Error occuring during loading external css', error);
            });
            this.fetchObjectNames();
        } catch (error) {
            console.log('Error in connectedCallback -> ' + error);
        }
    }

    /**
    * Method Name: fetchObjectNames
    * @description: Method to retrieve objectName for picklist value
    * Created Date: 12/06/2024
    * Created By: Rachit Shah
    */
    fetchObjectNames() {
        try {
            getAllObjectNames()
                .then(data => {
                    console.log('OUTPUT : ', data);
                    if (data.status === 'success') {
                        this.objectOptions = Object.keys(data.objectData).map(key => ({
                            label: data.objectData[key],
                            value: key
                        }))
                        .sort((a, b) => a.label.localeCompare(b.label));
                        this.templateTypeOptions = data.picklistValues.map(value => ({
                            label: value,
                            value: value
                        }));
                        this.backupObjectOptions = [...this.objectOptions];
                    } else {
                        this.showToast('Error', data.status, 'error');
                    }
                })
                .catch(error => {
                    console.error('Error fetching object names:', error.stack);
                });
        } catch (error) {
            console.log('Error in fetchObjectNames -> ', error.stack);
        }
    }

    /**
    * Method Name: closeModal
    * @description: Method to close the modal
    * Created Date: 12/06/2024
    * Created By: Rachit Shah
    */
    closeModal() {
        try {
            if (typeof window !== 'undefined') {
                const closeEvent = new CustomEvent('close');
                this.dispatchEvent(closeEvent);
            }
        } catch (error) {
            console.log('Error in closeModal -> ', error.stack);
        }
    }

    /**
    * Method Name: handleSave
    * @description: Method to save the details and pass to another component
    * Created Date: 12/06/2024
    * Created By: Rachit Shah
    */
    handleSave() {
        try {
            if (this.templateNameValue && this.selectedObjectAPIName && this.templateTypeSelectValue && this.selectedObjectAPIName) {

                if(this.templateTypeSelectValue === 'Marketing Template' && this.subjectValue == ''){
                    this.showToast('Error', 'Please fill in all required fields', 'error');
                    return;
                }

                const template = {
                    MVEX__Object_API_Name__c : this.selectedObjectAPIName,
                    MVEX__Object_Name__c : this.selectedObjectLabel,
                    MVEX__Template_Name__c : this.templateNameValue,
                    MVEX__Description__c : this.descriptionValue,
                    MVEX__Template_pattern__c : this.templateTypeSelectValue,
                    MVEX__Subject__c	: this.subjectValue,
                    MVEX__Template_Status__c	: true,
                };

                insertTemplate({ template : template})
                .then((res) => {
                    console.log('Template saved successfully:', res);
                    this.showToast('Success', 'Template saved successfully', 'success');
                    this.currentRecordIdValue = res;
                    this.navigationTotab();
                })
                .catch(error => {
                    console.error('Error saving template:', error);
                });
            } else {
                this.showToast('Error', 'Please fill in all required fields', 'error');
            }
        } catch (error) {
            console.log('Error in handleSave -> ', error.stack);
        }
    }

    /**
    * Method Name: navigationTotab
    * @description: Method to navigate to template editor tab
    * Created Date: 12/06/2024
    * Created By: Rachit Shah
    */
    navigationTotab(){
        try {
            let cmpDef = {
                componentDef: "MVEX:templateEditor",
                attributes: {
                    objectName: this.selectedObjectAPIName,
                    templateId: this.currentRecordIdValue,
                    templateType: this.templateTypeSelectValue
                }
            };

            let encodedDef = btoa(JSON.stringify(cmpDef));
                this[NavigationMixin.Navigate]({
                type: "standard__webPage",
                attributes: {
                    url:  "/one/one.app#" + encodedDef                                                         
                }
            });
            this.closeModal();
        } catch (error) {
            console.log('Error in navigationTotab -> ', error.stack);
        }
    }

    /**
    * Method Name: handleInputChange
    * @description: Method to save values in variable when any input changes
    * Created Date: 12/06/2024
    * Created By: Rachit Shah
    */
    handleInputChange(event) {
        try {
            const field = event.target.name;
            const value = event.target.value;

            if (field === 'templateName') {
                this.templateNameValue = value?.trim();
            } else if (field === 'description') {
                this.descriptionValue = value?.trim();
            } else if (field === 'objectSelect') {
                this.selectedObjectAPIName = value;
                const selectedOption = this.objectOptions.find(option => option.value === value);
                const selectedLabel = selectedOption ? selectedOption.label : '';
                this.selectedObjectLabel = selectedLabel;
                console.log('Selected Object:', selectedLabel, value);
            }else if (field === 'templateType') {
                this.templateTypeSelectValue = value;
                
                if(this.templateTypeSelectValue === 'Marketing Template'){
                    this.selectedObjectAPIName = '';
                    this.selectedObjectLabel = '';
                    this.isPicklistDisabled = false;
                    console.log('Object Options: ', this.objectOptions);
                    
                    this.objectOptions  = this.objectOptions.filter(option => 
                        ['contact', 'lead', 'MVEX__Listing__c', 'MVEX__Inquiry__c'].some(type => 
                            type.toLowerCase() === option.value.toLowerCase()
                        )
                    )
                }
                
                else{
                    this.selectedObjectAPIName = '';
                    this.selectedObjectLabel = '';
                    this.isPicklistDisabled = false;
                    this.objectOptions = [...this.backupObjectOptions];
                }
            }
            else if (field === 'subject') {
                this.subjectValue = value?.trim();
            }
        } catch (error) {
            console.log('Error in handleInputChange ==> ', error.stack);
        }
    }


    /**
    * Method Name: showToast
    * @description: Method to show toast message for success or error
    * Created Date: 12/06/2024
    * Created By: Rachit Shah
    */
    showToast(title, message, variant) {
        try {
            if (typeof window !== 'undefined') {
                const toastEvent = new ShowToastEvent({
                    title: title,
                    message: message,
                    variant: variant
                });
                this.dispatchEvent(toastEvent);
            }
        } catch (error) {
            console.log('Error in showToast ==> ', error.stack);
        }
    }
}