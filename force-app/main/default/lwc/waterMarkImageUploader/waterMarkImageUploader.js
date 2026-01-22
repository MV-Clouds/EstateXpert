import { LightningElement, track } from 'lwc';
import saveFile from '@salesforce/apex/ImageAndMediaController.saveFile';
import deleteFiles from '@salesforce/apex/ImageAndMediaController.deleteFiles';
import getContentVersionData from '@salesforce/apex/ImageAndMediaController.getContentVersionData';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { errorDebugger } from 'c/globalProperties';

export default class WaterMarkImageUploader extends LightningElement {
    @track isImageData = false;
    @track data = [];
    @track fileName = '';
    @track isSpinner = true;
    @track filesUploaded = [];
    @track file;
    @track fileContents;
    @track fileReader;
    @track content;
    @track fromData = true;
    @track fromUploader = false;
    @track imageSrc;
    @track imageName;
    @track imageSize;
    @track uploaderFlipClass = 'flip-card'; 

    /**
    * Method Name: connectedCallback
    * @description: Used to fetch data.
    * Created Date: 08/08/2024
    * Modified Date: 27/12/2024
    * Created By: Karan Singh
    * Modified By: Karan Singh
    */
    connectedCallback() {
        try {
            loadStyle(this, MulishFontCss);
            this.getData();
        } catch (error) {
            errorDebugger('WaterMarkImageUploader', 'connectedCallback', error, 'warn', 'Error occurred while fetching data');
        }
    }

    /**
    * Method Name: getData
    * @description: Used to fetch data from apex.
    * Created Date: 08/08/2024
    * Modified Date: 27/12/2024
    * Created By: Karan Singh
    * Modified By: Karan Singh
    */
    getData() {
        try {
            this.isSpinner = true;
            getContentVersionData()
            .then(data => {
                if (data != null) {
                    this.data = data.map(item => ({ ...item, flipClass: 'flip-card' }));
                    this.fromData = true;
                    this.fromUploader = false;
                    this.isImageData = true;
                } else {
                    this.isImageData = false;
                }
                this.isSpinner = false;
            }).catch(error => {
                this.toast('Error', error.message, 'error');
                this.isSpinner = false;
            });
        } catch (error) {
            errorDebugger('WaterMarkImageUploader', 'getData', error, 'warn', 'Error occurred while fetching data');
            this.isSpinner = false;
        }
    }

    /**
    * Method Name: handleDrop
    * @description: Used to handle drop files.
    * Created Date: 08/08/2024
    * Modified Date: 27/12/2024
    * Created By: Karan Singh
    * Modified By: Karan Singh
    */
    handleDrop(event) {
        try {
            event.preventDefault();
            const files = event.dataTransfer.files;

            if (this.filesUploaded.length === 1 || this.data.length > 0) {
                this.toast('Error', 'You already have an image uploaded. To upload a new image, please delete the existing one first.', 'error');
                return;
            }

            if (files.length > 0 && files[0].type === 'image/png') {
                if (files[0].size > 4500000) {
                    this.toast('Error', 'File Size is too large', 'error');
                    return;
                }

                this.filesUploaded.push(files[0]);
                this.fileName = files[0].name;
                this.showImagePreview(files[0]);
                this.isImageData = true;
                this.fromData = false;
                this.fromUploader = true;
                this.uploaderFlipClass = 'flip-card';
            }
            else {
                this.toast('Error', 'File type incorrect', 'error');
            }
        } catch (error) {
            errorDebugger('WaterMarkImageUploader', 'handleDrop', error, 'warn', 'Error occurred while handling the drop');
        }
    }

    /**
    * Method Name: allowDrop
    * @description: Used to handle drop files.
    * Created Date: 08/08/2024
    * Modified Date: 27/12/2024
    * Created By: Karan Singh
    * Modified By: Karan Singh
    */
    allowDrop(event) {
        try {
            event.preventDefault();
        } catch (error) {
            errorDebugger('WaterMarkImageUploader', 'allowDrop', error, 'warn', 'Error occurred while handling the drop');
        }
    }

    /**
    * Method Name: handleSelectedFiles
    * @description: Used to collect data from the selected files.
    * Created Date: 08/08/2024
    * Created By: Karan Singh
    */
    handleSelectedFiles(event) {
        try {
            if (this.filesUploaded.length === 1 || this.data.length > 0) {
                this.toast('Error', 'You already have an image uploaded. To upload a new image, please delete the existing one first.', 'error');
                return;
            }

            if (event.target.files.length > 0) {
                if (event.target.files[0].size > 4500000) {
                    this.toast('Error', 'File Size is too large', 'error');
                    return;
                }

                this.filesUploaded.push(event.target.files[0]);
                this.fileName = event.target.files[0].name;
                this.showImagePreview(event.target.files[0]);
                this.isImageData = true;
                this.fromData = false;
                this.fromUploader = true;
                this.uploaderFlipClass = 'flip-card'; // Reset flip class
            }

            this.template.querySelector('.slds-file-selector__input').value = null;
        } catch (error) {
            errorDebugger('WaterMarkImageUploader', 'handleSelectedFiles', error, 'warn', 'Error occurred while handling the selected files');
        }
    }

    /**
    * Method Name: handleDialogueClose
    * @description: Used to Close watermark modal.
    * Created Date: 08/08/2024
    * Modified Date: 27/12/2024
    * Created By: Karan Singh
    * Modified By: Karan Singh
    */
    handleDialogueClose() {
        try {
            this.dispatchEvent(new CustomEvent('close'));
        } catch (error) {
            errorDebugger('WaterMarkImageUploader', 'handleDialogueClose', error, 'warn', 'Error occurred while closing the dialogue');
        }
    }

    /**
    * Method Name: toast
    * @description: Generic toast message.
    * @param {string} title - Title of toast message.
    * @param {string} message - Description of toast message.
    * @param {string} variant - Variant of toast message.
    * Created Date: 08/08/2024
    * Modified Date: 27/12/2024
    * Created By: Karan Singh
    * Modified By: Karan Singh
    */
    toast(title, message, variant) {
        try {
            if (typeof window !== 'undefined') {
                const toastEvent = new ShowToastEvent({
                    title,
                    message,
                    variant
                });
                this.dispatchEvent(toastEvent);
            }
        } catch (error) {
            errorDebugger('WaterMarkImageUploader', 'toast', error, 'warn', 'Error occurred while showing the toast');
        }
    }

    /**
    * Method Name: handleSave
    * @description: Used to create contentversion record.
    * Created Date: 08/08/2024
    * Created By: Karan Singh
    */
    handleSave() {
        this.isSpinner = true;
        try {
            if (this.filesUploaded.length > 0) {
                this.uploadHelper();
            }
            else {
                this.toast('Error', 'Please select file to upload!!', 'error');
                this.isSpinner = false;
            }
        } catch (error) {
            errorDebugger('WaterMarkImageUploader', 'handleSave', error, 'warn', 'Error occurred while saving the file');
            this.isSpinner = false;
        }
    }

    /**
    * Method Name: uploadHelper
    * @description: Used to create contentversion record.
    * Created Date: 08/08/2024
    * Created By: Karan Singh
    */
    uploadHelper() {
        try {
            this.file = this.filesUploaded[0];
            this.fileReader = new FileReader();
            // set onload function of FileReader object  
            this.fileReader.onloadend = (() => {
                this.fileContents = this.fileReader.result;
                let base64 = 'base64,';
                this.content = this.fileContents.indexOf(base64) + base64.length;
                this.fileContents = this.fileContents.substring(this.content);
                this.saveToFile();
            });
            this.fileReader.readAsDataURL(this.file);
        } catch (error) {
            errorDebugger('WaterMarkImageUploader', 'uploadHelper', error, 'warn', 'Error occurred while uploading the file');
            this.isSpinner = false;
        }
    }

    /**
    * Method Name: saveToFile
    * @description: Used to create contentversion record.
    * Created Date: 08/08/2024
    * Modified Date: 27/12/2024
    * Created By: Karan Singh
    * Modified By: Karan Singh
    */
    saveToFile() {
        try {
            saveFile({ strFileName: this.file.name, base64Data: encodeURIComponent(this.fileContents) })
            .then(() => {
                this.filesUploaded = [];
                this.toast('Success', this.file.name + ' - Uploaded Successfully!!!', 'success');
                this.getData();
            })
            .catch(error => {
                this.toast('Error while uploading File', error.message, 'error');
                this.isSpinner = false;
            });
        } catch (error) {
            errorDebugger('WaterMarkImageUploader', 'saveToFile', error, 'warn', 'Error occurred while saving the file');
            this.isSpinner = false;
        }
    }

    showImagePreview(file) {
        try {
            this.imageSrc = URL.createObjectURL(file);
            this.imageName = file.name;
            this.imageSize = (file.size / 1024).toFixed(2) + ' kb'; // Convert to KB
        } catch (error) {
            errorDebugger('WaterMarkImageUploader', 'showImagePreview', error, 'warn', 'Error occurred while showing the image preview');
        }
    }

    flipCard(event) {
        try {
            const dataname = event.currentTarget.dataset.name;
            const id = event.currentTarget.dataset.id;

            if (dataname === 'uploaderdata') {
                this.uploaderFlipClass = this.uploaderFlipClass === 'flip-card' ? 'flip-card flipped' : 'flip-card';
            } else {
                this.data = this.data.map(item => {
                    if (item.Id === id) {
                        return { ...item, flipClass: item.flipClass === 'flip-card' ? 'flip-card flipped' : 'flip-card' };
                    }
                    return item;
                });
            }
        } catch (error) {
            errorDebugger('WaterMarkImageUploader', 'flipCard', error, 'warn', 'Error occurred while flipping the card');
        }
    }

    confirmDelete(event) {
        try {
            const dataname = event.currentTarget.dataset.name;
            if (dataname === 'uploaderdata') {
                this.toast('Success', 'Image has been removed successfully.', 'success');
                this.isImageData = false;
                this.isSpinner = false;
                this.data = [];
                this.filesUploaded = [];
                this.uploaderFlipClass = 'flip-card'; // Reset flip class
            } else {
                this.isSpinner = true;
                const cvId = event.currentTarget.dataset.id;
                deleteFiles({ contentVersionRecId: cvId })
                    .then(() => {
                        this.toast('Success', 'Image has been deleted successfully.', 'success');
                        this.isImageData = false;
                        this.isSpinner = false;
                        this.data = [];
                        this.filesUploaded = [];
                    })
                    .catch(error => {
                        this.toast('Error while deleting File', error.message, 'error');
                        this.isSpinner = false;
                    });
            }
        } catch (error) {
            errorDebugger('WaterMarkImageUploader', 'confirmDelete', error, 'warn', 'Error occurred while confirming deletion');
        }
    }

    cancelDelete(event) {
        try {
            const dataname = event.currentTarget.dataset.name;
            const id = event.currentTarget.dataset.id;

            if (dataname === 'uploaderdata') {
                this.uploaderFlipClass = 'flip-card'; // Flip back
            } else {
                this.data = this.data.map(item => {
                    if (item.Id === id) {
                        return { ...item, flipClass: 'flip-card' };
                    }
                    return item;
                });
            }
        } catch (error) {
            errorDebugger('WaterMarkImageUploader', 'cancelDelete', error, 'warn', 'Error occurred while canceling deletion');
        }
    }
}