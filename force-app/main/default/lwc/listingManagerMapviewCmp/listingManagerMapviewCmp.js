import { LightningElement, track, api } from 'lwc';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { loadStyle } from 'lightning/platformResourceLoader';
import { errorDebugger } from 'c/globalProperties';

export default class ListingManagerMapviewCmp extends LightningElement {
    @track listings = [];
    @track data = [];
    @track mapMarkers = [];
    @track mapMarkers1 = [];
    @track mapMarkers2 = [];

    /**
    * Method Name : get listingsdata
    * @description : get the filtered listing data from listing manager component reactively
    * date:4/06/2024
    * Created By: Vyom Soni
    */
    @api
    get listingsdata() {
        return this.listings;
    }

    /**
     * Method Name : set listingsdata
     * @description : set the filtered listing data from listing manager component reactively
     * @param: value- data from the parent component
     * date:4/06/2024
     * Created By: Vyom Soni
     */
    set listingsdata(value) {
        if (value && Array.isArray(value)) {
            this.listings = value;
            this.loadPropertyData(this.listings);
        } else {
            this.listings = [];
        }
    }

    /**
    * Method Name : connectedCallback
    * @description : load selected listing data in map-markers list.
    * date:5/06/2024
    * Created By: Vyom Soni
    */
    connectedCallback() {
        loadStyle(this, MulishFontCss);
        if (this.listings != null) {
            this.loadPropertyData(this.listings);
        }
    }

    /**
    * Method Name : loadPropertyData
    * @description : load the marker from the selected properties.
    * @param: data- properties data.
    * date:5/06/2024
    * Created By: Vyom Soni
    */
    loadPropertyData(data) {
        try {
            if (data) {
                this.data = data;
                this.mapMarkers = [];
                this.mapMarkers1 = [];
                this.mapMarkers2 = [];
                this.data.forEach(record => {
                    this.mapMarkers1.push({
                        id: record.Id
                    });
                    this.mapMarkers2.push({
                        location: {
                            id: record.Id,
                            rooms: record.MVEX__Number_of_Bedrooms__c,
                            City: record.MVEX__Listing_Address__City__s,
                            Country: record.MVEX__Listing_Address__CountryCode__s,
                            PostalCode: record.MVEX__Listing_Address__PostalCode__s,
                            State: record.MVEX__Listing_Address__StateCode__s,
                            Street: record.MVEX__Listing_Address__Street__s
                        },
                        title: record.Name,
                        description: `
                        <b>Address:-</b> 
                        ${record.MVEX__Listing_Address__Street__s ? record.MVEX__Listing_Address__Street__s + ',' : ''} 
                        ${record.MVEX__Listing_Address__City__s ? record.MVEX__Listing_Address__City__s + ',' : ''}
                        ${record.MVEX__Listing_Address__StateCode__s ? record.MVEX__Listing_Address__StateCode__s + ',' : ''}
                        ${record.MVEX__Listing_Address__CountryCode__s ? record.MVEX__Listing_Address__CountryCode__s + ',' : ''} 
                        <br><b>Sq_Ft:-</b> 
                        ${record.MVEX__Sq_Ft__c ? record.MVEX__Sq_Ft__c : ''}
                    `
                    });
                });
                this.mapMarkers = [...this.mapMarkers2];
            }
        } catch (error) {
            errorDebugger('ListingManagerMapviewCmp', 'loadPropertyData', error, 'warn', 'Error in loadPropertyData');
        }
    }
}