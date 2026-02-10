import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import getRecordDetails from '@salesforce/apex/CreateOfferFromListingController.getRecordDetails';
import updateOfferRecord from '@salesforce/apex/CreateOfferFromListingController.updateOfferRecord';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';

export default class CreateOfferFromListing extends NavigationMixin(LightningElement) {
    @track recordId; // Record ID from quick action
    @track sourceObjectType; // 'Listing' or 'Offer'
    @track todayDate;
    @track isLoading = true;
    @track offerFields = [];
    @track firstOfferId; // Store first offer ID for counter offers

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.recordId = currentPageReference.state.recordId;
        }
    }

    /**
     * Getter for modal title based on source object type
     */
    get modalTitle() {
        return this.sourceObjectType === 'Offer' ? 'Create Counter Offer' : 'Create Offer';
    }

    /**
     * Method Name: connectedCallback
     * @description: Initializes the component and fetches record details
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    connectedCallback() {
        try {
            loadStyle(this, MulishFontCss);
            this.todayDate = new Date().toISOString();
            this.fetchRecordDetails();
        } catch (error) {
            this.showToast('Error', 'Error initializing component: ' + error.message, 'error');
            this.isLoading = false;
        }
    }

    /**
     * Method Name: fetchRecordDetails
     * @description: Fetches record details and detects object type automatically
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    fetchRecordDetails() {
        getRecordDetails({ recordId: this.recordId })
            .then(result => {
                if (result && result.isSuccess) {
                    // Set the object type from the response
                    this.sourceObjectType = result.objectType;
                    
                    // Initialize fields based on object type
                    this.initializeFields();
                    
                    // Update field values from the response
                    if (result.firstOfferId) {
                        this.firstOfferId = result.firstOfferId;
                    }
                    
                    this.updateFieldValues({
                        listingId: result.listingId,
                        listingType: result.listingType,
                        listingPrice: result.listingPrice,
                        sellerContact: result.sellerContact,
                        buyerContact: result.buyerContact,
                        offerMadeBy: result.offerMadeBy,
                        offerAmount: result.offerAmount,
                        status: result.status,
                        expirationDate: result.offerExpirationDate,
                        targetCloseDate: result.targetCloseDate,
                        description: result.description,
                        counterOfferFor: result.counterOfferFor
                    });
                } else if (result && !result.isSuccess) {
                    this.showToast('Error', result.errorMessage || 'Error fetching record details', 'error');
                }
                this.isLoading = false;
            })
            .catch(error => {
                this.showToast('Error', 'Error fetching record details: ' + (error?.body?.message || error?.message), 'error');
                this.isLoading = false;
            });
    }

    /**
     * Method Name: initializeFields
     * @description: Initializes the field configuration for the offer form
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    initializeFields() {
        const baseFields = [
            { id: 1, fieldName: 'MVEX__Offer_Date__c', label: 'Offer Date', required: true, disabled: true, value: this.todayDate },
            { id: 2, fieldName: 'MVEX__Listing__c', label: 'Listing', required: false, disabled: false, value: '', hidden: true },
            { id: 3, fieldName: 'MVEX__Listing_Type__c', label: 'Listing Type', required: false, disabled: true, value: '' },
            { id: 4, fieldName: 'MVEX__Listing_Price__c', label: 'Listing Price', required: false, disabled: true, value: '' },
            { id: 5, fieldName: 'MVEX__Seller_Contact__c', label: 'Seller Contact', required: false, disabled: true, value: '' },
            { id: 6, fieldName: 'MVEX__Buyer_Contact__c', label: 'Buyer Contact', required: true, disabled: false, value: '' },
            { id: 7, fieldName: 'MVEX__Offer_made_by__c', label: 'Offer Made By', required: false, disabled: false, value: '' },
            { id: 8, fieldName: 'MVEX__Offer_Amount__c', label: 'Offer Amount', required: true, disabled: false, value: '' },
            { id: 9, fieldName: 'MVEX__Status__c', label: 'Status', required: true, disabled: false, value: '' },
            { id: 10, fieldName: 'MVEX__Offer_Expiration_Date__c', label: 'Offer Expiration Date', required: false, disabled: false, value: '' },
            { id: 11, fieldName: 'MVEX__Target_Close_Date__c', label: 'Target Close Date', required: false, disabled: false, value: '' },
            { id: 12, fieldName: 'MVEX__Description__c', label: 'Description', required: false, disabled: false, value: '' }
        ];

        // Add Counter Offer field if source is Offer
        if (this.sourceObjectType === 'Offer') {
            baseFields.splice(2, 0, { 
                id: 13, 
                fieldName: 'MVEX__Counter_Offer_for__c', 
                label: 'Counter Offer For', 
                required: false, 
                disabled: true, 
                value: this.recordId, 
                hidden: false 
            });
        }

        this.offerFields = baseFields;
    }

    /**
     * Method Name: updateFieldValues
     * @description: Updates field values based on fetched data
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    updateFieldValues(data) {
        this.offerFields = this.offerFields.map(field => {
            switch(field.fieldName) {
                case 'MVEX__Listing__c':
                    return { ...field, value: data.listingId };
                case 'MVEX__Listing_Type__c':
                    return { ...field, value: data.listingType };
                case 'MVEX__Listing_Price__c':
                    return { ...field, value: data.listingPrice };
                case 'MVEX__Seller_Contact__c':
                    return { ...field, value: data.sellerContact };
                case 'MVEX__Counter_Offer_for__c':
                    return data.counterOfferFor ? { ...field, value: data.counterOfferFor } : field;
                case 'MVEX__Buyer_Contact__c':
                    return data.buyerContact ? { ...field, value: data.buyerContact } : field;
                case 'MVEX__Offer_made_by__c':
                    return data.offerMadeBy ? { ...field, value: data.offerMadeBy } : field;
                case 'MVEX__Offer_Amount__c':
                    return data.offerAmount ? { ...field, value: data.offerAmount } : field;
                case 'MVEX__Status__c':
                    return data.status ? { ...field, value: data.status } : field;
                case 'MVEX__Offer_Expiration_Date__c':
                    return data.expirationDate ? { ...field, value: data.expirationDate } : field;
                case 'MVEX__Target_Close_Date__c':
                    return data.targetCloseDate ? { ...field, value: data.targetCloseDate } : field;
                case 'MVEX__Description__c':
                    return data.description ? { ...field, value: data.description } : field;
                default:
                    return field;
            }
        });
    }

    /**
     

    /**
     * Method Name: handleSaveClick
     * @description: Handles save button click and submits the form
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    handleSaveClick() {
        const form = this.template.querySelector('lightning-record-edit-form');
        
        if (form) {
            // Collect all field values from the form
            const fields = {};
            const inputFields = this.template.querySelectorAll('lightning-input-field');
            inputFields.forEach(field => {
                const fieldName = field.fieldName;
                const fieldValue = field.value;
                if (fieldName && fieldValue !== undefined && fieldValue !== null && fieldValue !== '') {
                    fields[fieldName] = fieldValue;
                }
            });

            if (this.firstOfferId) {
                fields.MVEX__First_Offer_Id__c = this.firstOfferId;
            }
            
            form.submit(fields);
        }
    }

    /**
     * Method Name: handleSuccess
     * @description: Handles successful offer creation and navigates to the new offer record
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    handleSuccess(event) {
        const offerId = event.detail.id;
        
        // Update old offer status to 'Countered' if this is a counter offer
        if (this.sourceObjectType === 'Offer') {
            updateOfferRecord({ sourceObjectType: 'Offer', offerId: this.recordId })
                .then(result => {
                    if (!result) {
                        console.error('Failed to update offer status to Countered');
                    }
                })
                .catch(error => {
                    console.error('Error updating offer status:', error);
                });
        } else if (this.sourceObjectType === 'Listing') {
            updateOfferRecord({ sourceObjectType: 'Listing', offerId: offerId })
                .then(result => {
                    if (!result) {
                        console.error('Failed to update First Offer ID');
                    }
                })
                .catch(error => {
                    console.error('Error updating First Offer ID:', error);
                });
        }
        
        this.showToast('Success', 'Offer created successfully!', 'success');
        
        // Close the quick action modal
        this.dispatchEvent(new CloseActionScreenEvent());
        
        // Navigate to the newly created offer record
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: offerId,
                objectApiName: 'MVEX__Offer__c',
                actionName: 'view'
            }
        });
    }

    /**
     * Method Name: handleError
     * @description: Handles errors during offer creation
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    handleError(event) {
        let errorMessage = 'Unknown error';
        if (event.detail && event.detail.detail) {
            errorMessage = event.detail.detail;
        } else if (event.detail && event.detail.message) {
            errorMessage = event.detail.message;
        }
        this.showToast('Error', 'Error creating offer: ' + errorMessage, 'error');
    }

    /**
     * Method Name: handleDialogueClose
     * @description: Closes the modal dialog
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    handleDialogueClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    /**
     * Method Name: showToast
     * @description: Shows toast notification
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}