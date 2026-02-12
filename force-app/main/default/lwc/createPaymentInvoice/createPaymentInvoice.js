import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// import getPayerDetails from '@salesforce/apex/CreatePaymentInvoiceController.getPayerDetails';
// import sendInvoiceEmail from '@salesforce/apex/CreatePaymentInvoiceController.sendInvoiceEmail';
// import getVFPageContent from '@salesforce/apex/InvoiceVFController.getVFPageContent';
// import getVFPagePDF from '@salesforce/apex/InvoiceVFController.getVFPagePDF';
// import saveInvoiceAsFile from '@salesforce/apex/InvoiceVFController.saveInvoiceAsFile';
import { CurrentPageReference } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class CreatePaymentInvoice extends LightningElement {
    @api recordId; // Now refers to Payment_Plan__c record
    @track spinner = true;
    @track invoiceContent = '';
    @track selectedPayer = null;
    @track isButtonDisabled = true;
    @track invoiceId;
    @track errorMessage = '';

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.recordId = currentPageReference.state.recordId;
        }
    }

    connectedCallback() {
        console.log('Payment Plan Record ID:', this.recordId);
        this.fetchPayerDetails();
        this.fetchInvoiceContent();
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async fetchPayerDetails() {
        try {
            const payerDetails = await getPayerDetails({ paymentPlanId: this.recordId });
            if (payerDetails && payerDetails.label) {
                this.selectedPayer = {
                    label: payerDetails.label,
                    value: payerDetails.value,
                    email: payerDetails.email
                };
                this.isButtonDisabled = !payerDetails.email;
                this.errorMessage = '';
            } else {
                this.isButtonDisabled = false;
                this.errorMessage = 'No payer details available.';
            }
        } catch (error) {
            this.errorMessage = error.body?.message || 'Failed to fetch payer details';
            this.showToast('Error', this.errorMessage, 'error');
            this.isButtonDisabled = false;
        }
    }

    async fetchInvoiceContent() {
        try {
            this.invoiceContent = await getVFPageContent({ paymentPlanId: this.recordId });
            this.template.querySelector('.contract-preview').innerHTML = this.invoiceContent;
            this.spinner = false;
        } catch (error) {
            this.errorMessage = error.body?.message || 'Failed to fetch invoice content';
            this.showToast('Error', this.errorMessage, 'error');
            this.spinner = false;
        }
    }

    async handleDownload() {
        this.spinner = true;
        try {
            const base64Pdf = await getVFPagePDF({ paymentPlanId: this.recordId });

            console.log('Base64 PDF Length:', base64Pdf.length);
            console.log('Base64 PDF First 100 Chars:', base64Pdf.substring(0, Math.min(100, base64Pdf.length)));

            if (!base64Pdf || typeof base64Pdf !== 'string') {
                throw new Error('Invalid Base64 PDF data returned from server');
            }

            let binaryString;
            try {
                binaryString = atob(base64Pdf);
            } catch (e) {
                throw new Error('Failed to decode Base64 string: ' + e.message);
            }

            console.log('Binary String Length:', binaryString.length);

            const byteArray = new Uint8Array(binaryString.length);
            for (let i = 0; i < binaryString.length; i++) {
                byteArray[i] = binaryString.charCodeAt(i);
            }

            const pdfBlob = new Blob([byteArray], { type: 'application/pdf' });
            console.log('PDF Blob Size in LWC:', pdfBlob.size);

            if (!pdfBlob.size || pdfBlob.size === 0) {
                throw new Error('Generated PDF Blob is empty or invalid');
            }

            const url = window.URL.createObjectURL(pdfBlob);
            const link = document.createElement('a');
            link.href = url;
            link.download = `Statement.pdf`;
            link.click();
            window.URL.revokeObjectURL(url);

            console.log('Sending Base64 PDF to Apex:', base64Pdf.length, 'chars');
            this.invoiceId = await saveInvoiceAsFile({ paymentPlanId: this.recordId, base64Pdf: base64Pdf });
            this.showToast('Success', 'Invoice downloaded, saved, and record created successfully!', 'success');
            this.handleClose();
        } catch (error) {
            this.showToast('Error', error.message || 'Failed to download invoice', 'error');
            console.error('Download Error:', error);
        } finally {
            this.spinner = false;
        }
    }

    async handleSendEmail() {
        this.spinner = true;
        if (!this.selectedPayer || !this.selectedPayer.email) {
            this.showToast('Error', 'No email address available for the payer', 'error');
            this.spinner = false;
            return;
        }

        try {
            const base64Pdf = await getVFPagePDF({ paymentPlanId: this.recordId });

            if (!this.invoiceId) {
                console.log('Saving invoice as file before sending email');
                console.log('Base64 PDF Length:', base64Pdf.length);
                this.invoiceId = await saveInvoiceAsFile({ paymentPlanId: this.recordId, base64Pdf: base64Pdf });
            }

            const result = await sendInvoiceEmail({ paymentPlanId: this.recordId, pdfBlob: base64Pdf });

            if (result === 'Success') {
                this.showToast('Success', 'Invoice emailed successfully!', 'success');
                this.handleClose();
            } else {
                this.showToast('Error', result, 'error');
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to send email', 'error');
            console.error('Send Email Error:', error);
        } finally {
            this.spinner = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}