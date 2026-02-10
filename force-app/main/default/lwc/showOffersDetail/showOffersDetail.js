import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getOfferTimeline from '@salesforce/apex/ShowOffersDetailController.getOfferTimeline';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { loadStyle } from 'lightning/platformResourceLoader';

export default class ShowOffersDetail extends NavigationMixin(LightningElement) {
    @api recordId; // The current offer record ID
    
    offers = [];
    errorMessage = '';
    isLoading = true;
    isRefreshing = false;
    wiredOfferResult;

    connectedCallback() {
        loadStyle(this, MulishFontCss)
    }

    @wire(getOfferTimeline, { recordId: '$recordId' })
    wiredOfferTimeline(result) {
        this.wiredOfferResult = result;
        const { error, data } = result;
        this.isLoading = true;
        this.errorMessage = '';
        
        if (data) {
            if (data.isSuccess) {
                this.processOffers(data.offers);
            } else {
                this.errorMessage = data.errorMessage;
                this.offers = [];
            }
            this.isLoading = false;
        } else if (error) {
            this.errorMessage = 'Error loading offer timeline: ' + (error.body?.message || error.message);
            this.offers = [];
            this.isLoading = false;
        }
    }

    processOffers(offerData) {
        if (!offerData || offerData.length === 0) {
            this.offers = [];
            return;
        }

        this.offers = offerData.map((offer, index) => {
            const isLastItem = (index === offerData.length - 1);
            
            // Determine status class for color coding
            let statusClass = 'status-badge';
            if (offer.status) {
                const status = offer.status.toLowerCase();
                if (status === 'accepted') {
                    statusClass += ' status-accepted';
                } else if (status === 'declined') {
                    statusClass += ' status-declined';
                } else if (status === 'countered') {
                    statusClass += ' status-countered';
                } else if (status === 'submitted') {
                    statusClass += ' status-submitted';
                } else if (status === 'withdrawn') {
                    statusClass += ' status-withdrawn';
                } else if (status === 'expired') {
                    statusClass += ' status-expired';
                } else if (status === 'draft') {
                    statusClass += ' status-draft';
                }
            }
            
            // Determine node class
            let nodeClass = 'timeline-node';
            if (offer.isFirstOffer) {
                nodeClass += ' first-offer-node';
            } else {
                nodeClass += ' counter-offer-node';
            }
            
            return {
                ...offer,
                isLastItem: isLastItem,
                nodeClass: nodeClass,
                statusClass: statusClass,
                isCurrentRecord: offer.offerId === this.recordId,
                formattedOfferDate: offer.offerDate ? this.formatDate(offer.offerDate) : 'N/A',
                formattedOfferAmount: offer.offerAmount ? this.formatCurrency(offer.offerAmount) : 'N/A',
                formattedExpirationDate: offer.expirationDate ? this.formatDate(offer.expirationDate) : null
            };
        });
    }

    formatDate(dateString) {
        if (!dateString) return '';
        const date = new Date(dateString);
        return date.toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        });
    }

    formatCurrency(amount) {
        if (amount == null) return '';
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(amount);
    }

    handleViewDetails(event) {
        const offerId = event.currentTarget.dataset.offerId;
        if (offerId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: offerId,
                    objectApiName: 'MVEX__Offer__c',
                    actionName: 'view'
                }
            });
        }
    }

    get hasOffers() {
        return !this.isLoading && !this.errorMessage && this.offers && this.offers.length > 0;
    }

    get totalOffers() {
        return this.offers ? this.offers.length : 0;
    }

    get pluralSuffix() {
        return this.totalOffers === 1 ? '' : 's';
    }

    async handleRefresh() {
        this.isRefreshing = true;
        try {
            await refreshApex(this.wiredOfferResult);
        } catch (error) {
            this.errorMessage = 'Error refreshing data: ' + (error?.body?.message || error?.message);
        } finally {
            this.isRefreshing = false;
        }
    }
}