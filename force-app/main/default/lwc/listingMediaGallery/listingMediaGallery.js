import { LightningElement, track, api, wire } from 'lwc';
import fetchListingAndImages from "@salesforce/apex/ImageAndMediaController.fetchListingAndImages";
import { MessageContext, subscribe, unsubscribe } from 'lightning/messageService';
import Refresh_cmp from '@salesforce/messageChannel/refreshImagesChannel__c';
import { refreshApex } from '@salesforce/apex';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { errorDebugger } from 'c/globalProperties';

export default class ListingMediaGallery extends LightningElement {
    @api recordId;
    @track data = [];
    @track taglist = [];
    @track showSpinner = false;
    @track isdata = false;
    @track currentIndex = 0;
    @track subscription = null;
    @track isModalOpen = false;

    /**
    * Method Name: currentImageUrl
    * @description: Used to get the current image URL.
    * Created Date: 27/06/2024
    * Modified Date: 26/12/2024
    * Created By: Karan Singh
    * Modified By: Karan Singh
    */
    get currentImageUrl() {
        return this.data && this.data.length > 0 ? this.data[this.currentIndex]?.MVEX__BaseUrl__c : '';
    }

    /**
    * Method Name: currentImageName
    * @description: Used to get the current image name.
    * Created Date: 27/06/2024
    * Modified Date: 26/12/2024
    * Created By: Karan Singh
    * Modified By: Karan Singh
    */
    get currentImageName() {
        return this.data && this.data.length > 0 ? this.data[this.currentIndex]?.Name : '';
    }

    /**
    * Method Name: currentVideoUrl
    * @description: Used to get the current video URL.
    * Created Date: 27/06/2024
    * Modified Date: 26/12/2024
    * Created By: Karan Singh
    * Modified By: Karan Singh
    */
    get currentVideoUrl() {
        return this.data && this.data.length > 0 ? this.data[this.currentIndex]?.MVEX__ExternalLink__c : '';
    }

    /**
    * Method Name: currentImageTag
    * @description: Used to get the current image tags.
    * Created Date: 27/06/2024
    * Modified Date: 26/12/2024
    * Created By: Karan Singh
    * Modified By: Karan Singh
    */
    get currentImageTag() {
        var tags = this.data && this.data.length > 0 ? this.data[this.currentIndex]?.MVEX__Tags__c : '';
        if (tags !== '' && tags != undefined) {
            tags = tags.split(';').map(tag => tag.trim());
        } else {
            tags = [];
        }
        return tags;
    }

    @wire(MessageContext)
    messageContext;

    /**
    * Method Name: connectedCallback
    * @description: Used to load css and fetch data.
    * Created Date: 27/06/2024
    * Modified Date: 26/12/2024
    * Created By: Karan Singh
    * Modified By: Karan Singh
    */
    connectedCallback() {
        try {
            loadStyle(this, MulishFontCss);
            this.subscription = subscribe(this.messageContext, Refresh_cmp, (message) => {
                if (message.refresh === true) {
                    this.fetchingdata();
                    message.refresh = false;
                }
            });
            this.data = this.fetchingdata();
            refreshApex(this.data);
        } catch (error) {
            errorDebugger('ListingMediaGallery', 'connectedCallback', error, 'warn', 'Error in connectedCallback');
        }
    }

    /**
    * Method Name: disconnectedCallback
    * @description: Used to unsubscribe the message channel.
    * Created Date: 27/06/2024
    * Modified Date: 26/12/2024
    * Created By: Karan Singh
    * Modified By: Karan Singh
    */
    disconnectedCallback() {
        try {
            unsubscribe(this.subscription);
            this.subscription = null;
        } catch (error) {
            errorDebugger('ListingMediaGallery', 'disconnectedCallback', error, 'warn', 'Error in disconnectedCallback');
        }
    }

    /**
    * Method Name: fetchingdata
    * @description: Used to fetch the data from apex.
    * Created Date: 27/06/2024
    * Modified Date: 26/12/2024
    * Created By: Karan Singh
    * Modified By: Karan Singh
    */
    fetchingdata() {
        try {
            this.showSpinner = true;
            fetchListingAndImages({ recordId: this.recordId })
                .then(result => {
                    this.data = result.listingImages;
                    this.isdata = result.listingImages?.length > 0;
                    this.showSpinner = false;
                })
                .catch(error => {
                    errorDebugger('ListingMediaGallery', 'fetchingdata', error, 'warn', 'Error in fetchingdata');
                });
        } catch (error) {
            errorDebugger('ListingMediaGallery', 'fetchingdata', error, 'warn', 'Error in fetchingdata');
            this.showSpinner = false;
        }
    }

    /**
    * Method Name: showPreviousImage
    * @description: Used to show the previous image in the gallery.
    * Created Date: 27/06/2024
    * Modified Date: 26/12/2024
    * Created By: Karan Singh
    * Modified By: Karan Singh
    */
    showPreviousImage() {
        try {
            this.showSpinner = true;
            if (this.currentIndex > 0) {
                this.currentIndex--;
            }
            else {
                this.currentIndex = this.data.length - 1;
            }
        } catch (error) {
            errorDebugger('ListingMediaGallery', 'showPreviousImage', error, 'warn', 'Error in showPreviousImage');
        } finally {
            this.showSpinner = false;
        }
    }

    /**
    * Method Name: showNextImage
    * @description: Used to show the next image in the gallery.
    * Created Date: 27/06/2024
    * Modified Date: 26/12/2024
    * Created By: Karan Singh
    * Modified By: Karan Singh
    */
    showNextImage() {
        try {
            this.showSpinner = true;
            if (this.currentIndex < this.data.length - 1) {
                this.currentIndex++;
            }
            else {
                this.currentIndex = 0;
            }
        } catch (error) {
            errorDebugger('ListingMediaGallery', 'showNextImage', error, 'warn', 'Error in showNextImage');
        } finally {
            this.showSpinner = false;
        }
    }

    /**
    * Method Name: reloadComponent
    * @description: Used to reload the component and fetch the data again from apex.
    * Created Date: 27/06/2024
    * Modified Date: 26/12/2024
    * Created By: Karan Singh
    * Modified By: Karan Singh
    */
    reloadComponent() {
        try {
            this.showSpinner = true;
            this.fetchingdata();
            this.currentIndex = 0;
        } catch (error) {
            errorDebugger('ListingMediaGallery', 'reloadComponent', error, 'warn', 'Error in reloadComponent');
            this.showSpinner = false;
        }
    }

    /**
    * Method Name: openImagePreview
    * @description: Used to open the image preview in new tab.
    * Created Date: 27/06/2024
    * Modified Date: 26/12/2024
    * Created By: Karan Singh
    * Modified By: Karan Singh
    */
    openImagePreview() {
        try {
            if (!this.currentImageUrl) {
                return;
            }
            const url = this.currentVideoUrl || this.currentImageUrl;
            window?.globalThis?.open(url, '_blank');
            this.showSpinner = false;
        } catch (error) {
            errorDebugger('ListingMediaGallery', 'openImagePreview', error, 'warn', 'Error in openImagePreview');
            this.showSpinner = false;
        }
    }

    /**
    * Method Name: closeModal
    * @description: Used to close the modal popup for image preview.
    * Created Date: 27/06/2024
    * Modified Date: 26/12/2024
    * Created By: Karan Singh
    * Modified By: Karan Singh
    */
    closeModal() {
        this.isModalOpen = false;
    }

    /**
    * Method Name: openImageModel
    * @description: Used to open the modal popup for image preview.
    * Created Date: 27/06/2024
    * Modified Date: 26/12/2024
    * Created By: Karan Singh
    * Modified By: Karan Singh
    */
    openImageModel() {
        this.modalImageUrl = this.currentImageUrl;
        this.isModalOpen = true;
    }
}