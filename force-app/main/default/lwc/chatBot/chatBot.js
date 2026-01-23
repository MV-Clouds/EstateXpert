import { LightningElement } from 'lwc';
// import getGeminiResponse from '@salesforce/apex/GeminiChatService.getGeminiResponse';
// import getListingFields from '@salesforce/apex/GeminiChatService.getListingFields';
import sendFeedbackEmail from '@salesforce/apex/GeminiChatService.sendFeedbackEmail';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import SUPPORT_EMAILS from '@salesforce/label/c.supportEmail';

export default class ChatBot extends LightningElement {
    userInput = '';
    isLoading = false;
    conversationState = 'WELCOME';
    messages = [];
    propertyCriteria = {};
    showChat = true;
    formSubject = '';
    formDescription = '';
    uploadedImages = [];

    handleFormInputChange(event) {
        const field = event.target.dataset.field;
        this[field] = event.target.value;
    }

    handleImageChange(event) {
        const files = Array.from(event.target.files);
        const maxTotalSize = 4 * 1024 * 1024; // 4MB in bytes
        const validFormats = ['image/jpeg', 'image/jpg', 'image/png'];
        let totalSize = this.uploadedImages.reduce((sum, img) => sum + img.file.size, 0);

        files.forEach(file => {
            if (!validFormats.includes(file.type)) {
                this.showToast('Error', `${file.name} is not a valid image format (jpg, jpeg, or png only).`, 'error');
                return;
            }
            if (totalSize + file.size > maxTotalSize) {
                this.showToast('Error', `Cannot add ${file.name}. Total image size exceeds 4MB.`, 'error');
                return;
            }
            const reader = new FileReader();
            reader.onload = () => {
                this.uploadedImages = [...this.uploadedImages, {
                    id: Math.random().toString(36).substring(2),
                    url: reader.result,
                    file: file
                }];
                totalSize += file.size;
            };
            reader.readAsDataURL(file);
        });
    }

    removeImage(event) {
        const index = event.target.dataset.index;
        this.uploadedImages = this.uploadedImages.filter((_, i) => i !== parseInt(index));
    }

    async handleFormSubmit() {
        if (!this.formSubject || !this.formDescription) {
            this.showToast('Error', 'Please fill out all required fields.', 'error');
            return;
        }

        this.isLoading = true;
        try {
            const imageBase64Array = await Promise.all(
                this.uploadedImages.map(image => this.readFileAsBase64(image.file))
            );
            const result = await sendFeedbackEmail({
                subject: this.formSubject,
                description: this.formDescription,
                images: imageBase64Array
            });
            if (result === 'Success') {
                this.showToast('Success', 'Your feedback has been sent successfully.', 'success');
                this.resetForm();
            } else {
                this.showToast('Error', 'Failed to send feedback. Please try again.', 'error');
            }
        } catch (error) {
            console.error('Error sending feedback:', error.stack);
            this.showToast('Error', 'An error occurred while sending feedback. Please try again.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    resetForm() {
        this.formSubject = '';
        this.formDescription = '';
        this.uploadedImages = [];
    }

    async readFileAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve(reader.result.split(',')[1]);
            reader.onerror = error => reject(error);
            reader.readAsDataURL(file);
        });
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(evt);
    }
}