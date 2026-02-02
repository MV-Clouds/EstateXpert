import { LightningElement, track , wire, api} from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
// import getOfferData from '@salesforce/apex/OfferManagerController.getOfferData';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import redirectImg from '@salesforce/resourceUrl/redirect';
// import getOfferHistory from '@salesforce/apex/OfferManagerController.getOfferHistory';
import { errorDebugger } from 'c/globalProperties';
import { CurrentPageReference } from 'lightning/navigation';

export default class OfferManager extends NavigationMixin(LightningElement) {
    @api recordId;
    @track offers = [];
    @track error;
    @track isLoading = true;
    redirectIcon = redirectImg;
    @track processedHistory = [];
    @track showModal = false;
    @track offerName = '';


    get isOfferDataAvailable() {
        return this.offers && this.offers.length > 0;
    }

    get hasRecords() {
        return this.processedHistory.length > 0;
    }

    connectedCallback() {
        loadStyle(this, MulishFontCss);
        this.loadData();
    }


    @wire(CurrentPageReference)
    setCurrentPageReference(pageRef) {
        this.recordId = pageRef.attributes.recordId;
    }


    // async loadData() {

    //     try {
    //         this.isLoading = true;
    //         console.log('Listing ID:', this.recordId);
            
    //         const data = await getOfferData({ listingId: this.recordId });
    //         console.log('Offer Data:', data);

    //         this.offers = data.offers.map(offer => ({
    //             ...offer,
    //             FormattedOfferDate: offer.MVEX__Offer_Date__c ? new Date(offer.MVEX__Offer_Date__c).toLocaleString('en-US', {
    //                 year: 'numeric',
    //                 month: 'short',
    //                 day: 'numeric',
    //                 hour: '2-digit',
    //                 minute: '2-digit'
    //             }) : '',
    //             FormattedExpirationDate: offer.MVEX__Offer_Expiration_Date__c ? new Date(offer.MVEX__Offer_Expiration_Date__c).toLocaleString('en-US', {
    //                 year: 'numeric',
    //                 month: 'short',
    //                 day: 'numeric',
    //                 hour: '2-digit',
    //                 minute: '2-digit'
    //             }) : '',
    //             contactName: offer.MVEX__Buyer_Contact__c ? offer.MVEX__Buyer_Contact__r.Name : 'N/A'
    //         }));
    //         this.error = undefined;
    //         setTimeout(() => {
    //             this.isLoading = false;
    //         }, 2000);
    //     } catch (error) {
    //         this.error = error;
    //         this.showToast('Error', 'Failed to load data', 'error');
    //         this.offers = [];
    //         console.error('Error loading offer data:', error);
    //         console.error('Error loading offer data:', error.stack);
    //     } finally {
    //         this.isLoading = false;
    //     }
    // }

    redirectToRecord(event) {
        try {
            const recordId = event.target.dataset.id;

            // Generate the URL using NavigationMixin
            this[NavigationMixin.GenerateUrl]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: 'Contact', // or dynamic object name
                    actionName: 'view'
                }
            }).then(url => {
                window.open(url, '_blank'); // Open in new tab
            });
        } catch (error) {
            errorDebugger('ListingManager', 'redirectToRecord', error, 'warn', 'Error in redirectToRecord');
        }
    }

    // handleOfferHistory(event) {
    //     console.log('handleOfferHistory called');
    //     const recordId = event.currentTarget.dataset.id;
    //     this.offerName = event.currentTarget.dataset.name;

    //     getOfferHistory({ offerId: recordId })
    //         .then(result => {
    //             console.log('Offer History:', result);
    //             if (result && result.length > 0) {
    //                 this.processedHistory = this.processHistoryData(result);
    //                 this.showModal = true;
    //                 console.log('processedHistory:', this.processedHistory);
    //                 // You can handle the result further, e.g., display in a modal or table
    //             } else {
    //                 this.showToast('Info', 'No offer history found', 'info');
    //             }
    //         })
    //         .catch(error => {
    //             console.error('Error fetching offer history:', error);
    //             this.showToast('Error', 'Failed to load offer history', 'error');
    //         });

    // }

    closeModal() {
        this.showModal = false;
    }

    processHistoryData(rawData) {
        if (!rawData) return [];

        return rawData.map(item => {
            return {
                key: item.id,
                fieldName: item.fieldApiName || '--',
                dataType: item.dataType || '--',
                oldValue: this.formatValue(item.oldValue) || '--',
                newValue: this.formatValue(item.newValue) || '--',
                changeDate: this.formatValue(item.createdDate) || '--',
                changedBy: item.createdBy || '--',
                label: item.fieldLabel || '--',
            };
        });
    }

    formatValue(value) {
        console.log('formatValue called with value:', value);

        if (value === null || value === undefined) return '--';
        if (typeof value === 'boolean') return value ? 'Yes' : 'No';

        const stringValue = String(value).trim();

        // Regex: YYYY-MM-DD or YYYY-MM-DD HH:MM:SS
        const dateRegex1 = /^\d{4}-\d{2}-\d{2}(?: \d{2}:\d{2}:\d{2})?$/;
        // Regex: ISO 8601 format (e.g., 2025-06-13T12:49:50.000Z)
        const isoRegex = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z$/;

        if (dateRegex1.test(stringValue)) {
            const isoCompatible = stringValue.replace(' ', 'T');
            const dateObj = new Date(isoCompatible);
            if (!isNaN(dateObj.getTime())) {
                return dateObj.toLocaleDateString('en-US', {
                    year: 'numeric',
                    month: 'short',
                    day: '2-digit'
                });
            }
        }

        if (isoRegex.test(stringValue)) {
            const dateObj = new Date(stringValue);
            if (!isNaN(dateObj.getTime())) {
                return dateObj.toLocaleDateString('en-US', {
                    year: 'numeric',
                    month: 'short',
                    day: '2-digit',
                    hour: '2-digit',
                    minute: '2-digit',
                    hour12: true
                });
            }
        }

        return stringValue;
    }

    redirectToOfferInbox(event) {
        console.log('redirectToOfferInbox called');

        const recordId = event.currentTarget.dataset.id;
        const offerId = event.currentTarget.dataset.offer;
        const offerRecord = this.offers.find(offer => offer.Id === offerId);
        console.log('offerRecord:', offerRecord);

        try {
            let cmpDef = {
                componentDef: "MVEX:OfferChatInbox",
                attributes: {
                    recordId: recordId,
                    listingId: this.recordId,
                    offerRecord: offerRecord || {}
                }
            };

            let encodedDef = btoa(JSON.stringify(cmpDef));
            this[NavigationMixin.Navigate]({
                type: "standard__webPage",
                attributes: {
                    url: "/one/one.app#" + encodedDef
                }
            });
        } catch (error) {
            console.log('Error in navigationTotab -> ', error.stack);
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}