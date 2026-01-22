import { LightningElement, track, api } from 'lwc';
import sendEmail from '@salesforce/apex/SupportRequestController.sendEmail';
import deleteContentDocument from '@salesforce/apex/SupportRequestController.deleteContentDocument';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import ContactusImage from '@salesforce/resourceUrl/ContactusImage';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { errorDebugger } from 'c/globalProperties';

export default class SupportRequestCmp extends NavigationMixin(LightningElement) {
  @api redirectfrom;
  @track supportname = '';
  @track email = '';
  @track subject = '';
  @track message = '';
  @track name_msg = true;
  @track email_msg = true;
  @track message_msg = true;
  @track subject_msg = true;
  @track priority_msg = true;
  @track email_validation = false;
  @track filesData = [];
  @track FName = [];
  @track FBase64 = [];
  @track totalsize = parseInt(0);
  @track filename;
  @track filedata;
  @track totalnumberoffiles = 0;
  @track ContactusImage = ContactusImage;
  @track priorityOptions = [{ label: 'Low', value: 'Low' }, { label: 'Medium', value: 'Medium' }, { label: 'High', value: 'High' }];
  @track isFocused = false;
  @track selectedPriority = 'Medium';
  @track attachments = [];
  @track showSpinner = false;
  @track contentDocumentIds = [];

  connectedCallback() {
    try {
      loadStyle(this, MulishFontCss);
    } catch (error) {
      errorDebugger('SupportRequestCmp', 'connectedCallback', error, 'warn', 'Error occurred while loading the style');
    }
  }

  handleFocus1() {
    this.isFocused = !this.isFocused;
  }

  handleSelectPriority(event) {
    this.selectedPriority = event.currentTarget.dataset.id;
    this.priority_msg = true;
  }

  /**
  * Method Name : Support_name
  * @description : set the support name value
  * date:22/07/2024
  * Created By: Vyom Soni
  */
  Support_name(event) {
    this.supportname = event.target.value;
    this.supportname = this.supportname.trim();
    this.name_msg = true;
  }

  /**
  * Method Name : Support_email
  * @description : set the support email value
  * date:22/07/2024
  * Created By: Vyom Soni
  */
  Support_email(event) {
    this.email = event.target.value;
    this.email_msg = true;
    let pattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    this.validation1 = pattern.test(this.email);
    if (this.validation1 == false) {
      this.email_msg = false;
    }
  }

  /**
  * Method Name : Support_message
  * @description : set the support message value
  * date:22/07/2024
  * Created By: Vyom Soni
  */
  Support_message(event) {
    this.message = event.target.value;
    this.message = this.message.trim();
    this.message_msg = true;
  }

  /**
  * Method Name : Support_subject
  * @description : set the support subject value
  * date:22/07/2024
  * Created By: Vyom Soni
  */
  Support_subject(event) {
    this.subject = event.target.value;
    this.subject = this.subject.trim();
    this.subject_msg = true;
  }

  /**
  * Method Name : onSubmit
  * @description : handle the from submit button
  * date:22/07/2024
  * Created By: Vyom Soni
  */
  onSubmit() {
    if (this.supportname == undefined || this.supportname == '') {
      this.name_msg = false;
    }
    if (this.email == undefined || this.email == '') {
      this.email_msg = false;
    }
    if (this.subject == undefined || this.subject == '') {
      this.subject_msg = false;
    }
    if (this.message == undefined || this.message == '') {
      this.message_msg = false;
    }
    if (this.supportname != '' && this.validation1 != false && this.email != '' && this.subject != '' && this.message != '' && this.priority_msg == true) {
      this.email_msg = true;
      this.sendEmailCallMethod();
    }
  }

  /**
  * Method Name : onSubmit
  * @description : handle the from submit button
  * date:22/07/2024
  * Created By: Vyom Soni
  */
  onClose() {
    try {
      let componentDef = {};
      if (this.redirectfrom != undefined && this.redirectfrom === 'PortalMapping') {
        componentDef = {
          componentDef: "MVEX:portalMappingComponent",
        };
      } else {
        componentDef = {
          componentDef: "MVEX:estateXpertControlCenter",
        };
      }

      let encodedComponentDef = btoa(JSON.stringify(componentDef));
      this[NavigationMixin.Navigate]({
        type: 'standard__webPage',
        attributes: {
          url: '/one/one.app#' + encodedComponentDef
        }
      });
    } catch (error) {
      errorDebugger('SupportRequestCmp', 'onClose', error, 'warn', 'Error occurred while closing the support request');
    }
  }

  onClear() {
    this.supportname = '';
    this.email = '';
    this.subject = ''
    this.message = ''
    this.selectedPriority = 'Medium';
    this.filesData = [];
    this.name_msg = true;
    this.email_msg = true;
    this.subject_msg = true;
    this.message_msg = true;
    this.priority_msg = true;
    const textarea = this.template.querySelector('textarea');
    if (textarea) {
      textarea.value = '';
    }
  }

  createAttachment() {
    let attachment = {
      fileName: this.filename,
      mimeType: 'image/jpeg',
      content: this.filedata
    }
    return attachment;
  }

  /**
  * Method Name : sendEmailCallMethod
  * @description : call the apex method for the send email.
  * date:22/07/2024
  * Created By: Vyom Soni
  */
  sendEmailCallMethod() {
    try {
      this.showSpinner = true;
      sendEmail({
        name: this.supportname,
        email: this.email,
        subject: this.subject,
        body: this.message,
        priority: this.selectedPriority,
        contentDocumentIds: this.contentDocumentIds // Pass ContentDocumentIds
      })
        .then(result => {
          this.showSpinner = false;
          if (result.status) {
            this.showToast('Success', result.message, 'success');
            this.onClose();
          } else {
            this.showToast('Error', result.message, 'error');
          }
        })
        .catch(error => {
          errorDebugger('SupportRequestCmp', 'sendEmailCallMethod', error, 'warn', 'Error occurred while sending the email');
          this.showSpinner = false;
          this.showToast('Error', 'Failed to send email.', 'error');
        });
    } catch (e) {
      errorDebugger('SupportRequestCmp', 'sendEmailCallMethod', e, 'warn', 'Error occurred while sending the email');
      this.showSpinner = false;
    }
  }

  /**
  * Method Name : handleUploadFinished
  * @description : handle the file uploader onchange event check file size for the upload
  * date:22/07/2024
  * Created By: Vyom Soni
  */
  handleUploadFinished(event) {
    try {
      const uploadedFiles = event.detail.files;
      uploadedFiles.forEach(file => {
        this.filesData.push({
          id: file.documentId,
          name: file.name
        });
        this.contentDocumentIds.push(file.documentId);
      });
    } catch (error) {
      errorDebugger('SupportRequestCmp', 'handleUploadFinished', error, 'warn', 'Error occurred while handling the upload finished');
    }
  }

  /**
  * Method Name : removeReceiptImage
  * @description : handle the remove the images from the image list
  * date:22/07/2024
  * Created By: Vyom Soni
  */
  removeReceiptImage(event) {
    try {
      const index = event.currentTarget.dataset.id;
      const fileToDelete = this.filesData[index];
      this.filesData.splice(index, 1);
      this.contentDocumentIds.splice(index, 1);

      deleteContentDocument({ contentDocumentId: fileToDelete.id })
        .then(() => {
          this.showToast('Success', 'File deleted successfully.', 'success');
        })
        .catch(error => {
          errorDebugger('SupportRequestCmp', 'removeReceiptImage', error, 'warn', 'Error occurred while deleting the file');
          this.showToast('Error', 'Failed to delete the file.', 'error');
        });
    } catch (error) {
      errorDebugger('SupportRequestCmp', 'removeReceiptImage', error, 'warn', 'Error occurred while removing the receipt image');
    }
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
}