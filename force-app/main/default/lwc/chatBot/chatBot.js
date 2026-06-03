import { LightningElement } from 'lwc';
import sendFeedbackEmail from '@salesforce/apex/GeminiChatService.sendFeedbackEmail';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';

export default class ChatBot extends LightningElement {
    isLoading = false;
    formSubject = '';
    formDescription = '';
    uploadedImages = [];
    MAX_SUBJECT_LENGTH = 255;
    MAX_DESCRIPTION_LENGTH = 32000;

    get subjectCharCount() {
        return this.formSubject.length;
    }

    get subjectCounterClass() {
        const ratio = this.subjectCharCount / this.MAX_SUBJECT_LENGTH;
        if (ratio >= 1) return 'char-counter char-counter--error';
        if (ratio >= 0.9) return 'char-counter char-counter--warning';
        return 'char-counter';
    }

    get descriptionCharCount() {
        return this.formDescription.length;
    }

    get descriptionCounterClass() {
        const ratio = this.descriptionCharCount / this.MAX_DESCRIPTION_LENGTH;
        if (ratio >= 1) return 'char-counter char-counter--error';
        if (ratio >= 0.9) return 'char-counter char-counter--warning';
        return 'char-counter';
    }

    connectedCallback() {
        loadStyle(this, MulishFontCss);
    }

    handleFormInputChange(event) {
        const field = event.target.dataset.field;
        if (field === 'formSubject') {
            const val = event.target.value;
            if (val.length > this.MAX_SUBJECT_LENGTH) {
                event.target.value = val.substring(0, this.MAX_SUBJECT_LENGTH);
                this.formSubject = event.target.value;
                return;
            }
        }
        if (field === 'formDescription') {
            // Enforce character limit client-side; trim silently if pasted over the limit
            const val = event.target.value;
            if (val.length > this.MAX_DESCRIPTION_LENGTH) {
                event.target.value = val.substring(0, this.MAX_DESCRIPTION_LENGTH);
                this.formDescription = event.target.value;
                return;
            }
        }
        this[field] = event.target.value;
    }

    handleImageChange(event) {
        const files = Array.from(event.target.files);
        const maxTotalSize = 4 * 1024 * 1024; // 4MB in bytes
        const validFormats = ['image/jpeg', 'image/jpg', 'image/png'];
        const validExtensions = ['jpg', 'jpeg', 'png'];
        let totalSize = this.uploadedImages.reduce((sum, img) => sum + img.file.size, 0);

        files.forEach(file => {
            const fileExtension = file.name.split('.').pop().toLowerCase();
            if (!validFormats.includes(file.type) || !validExtensions.includes(fileExtension)) {
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
        if (this.formSubject.length > this.MAX_SUBJECT_LENGTH) {
            this.showToast('Error', `Subject must not exceed ${this.MAX_SUBJECT_LENGTH} characters.`, 'error');
            return;
        }
        if (this.formDescription.length > this.MAX_DESCRIPTION_LENGTH) {
            this.showToast('Error', `Description must not exceed ${this.MAX_DESCRIPTION_LENGTH.toLocaleString()} characters.`, 'error');
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
        const textarea = this.template.querySelector('textarea');
        if (textarea) {
            textarea.value = '';
        }
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