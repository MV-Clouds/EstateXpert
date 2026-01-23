import { LightningElement, api, track } from 'lwc';
import getListingDetails from '@salesforce/apex/ListingMapController.getListingDetails';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class RecordPageMapView extends LightningElement {
    @api recordId;
    @track mapMarkers = [];
    @track isLoading  = false;
    
    connectedCallback() {
        this.loadListingDetails();
    }

    loadListingDetails() {
        if (!this.recordId) return;
        this.isLoading = true;
        getListingDetails({ recordId: this.recordId })
            .then(data => {
                if (data) {
                    this.mapMarkers = [
                        {
                            location: {
                                Street: data.MVEX__Listing_Address__Street__s,
                                City: data.MVEX__Listing_Address__City__s,
                                State: data.MVEX__Listing_Address__StateCode__s,
                                PostalCode: data.MVEX__Listing_Address__PostalCode__s,
                                Country: data.MVEX__Listing_Address__CountryCode__s
                            },
                            title: data.Name,
                            description: `
                                <b>Listing Type:-</b>
                                ${data.MVEX__Listing_Type__c ? data.MVEX__Listing_Type__c : ''}
                                <br><b>Property Type:-</b> 
                                ${data.MVEX__Property_Type__c ? data.MVEX__Property_Type__c : ''}
                                <br><b>Property Category:-</b>
                                ${data.MVEX__Property_Category__c ? data.MVEX__Property_Category__c : ''}
                                <br><b>Address:-</b></br>
                                ${data.MVEX__Listing_Address__Street__s ? data.MVEX__Listing_Address__Street__s + ',' : ''} 
                                ${data.MVEX__Listing_Address__City__s ? data.MVEX__Listing_Address__City__s + ',' : ''}
                                ${data.MVEX__Listing_Address__StateCode__s ? data.MVEX__Listing_Address__StateCode__s + ',' : ''}
                                ${data.MVEX__Listing_Address__CountryCode__s ? data.MVEX__Listing_Address__CountryCode__s + ',' : ''} 
                            `
                        }
                    ];
                }
            })
            .catch(error => {
                this.showToast('Error loading map', error?.body?.message || error.stack, 'error');
            }). finally(() => {
                this.isLoading = false;
            }
        );
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}