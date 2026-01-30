import { LightningElement, track } from 'lwc';
import getListingData from '@salesforce/apex/SinglePropertyViewCmpController.getListingData';
import getShowingData from '@salesforce/apex/SinglePropertyViewCmpController.getShowingData';
import updateShowingStatus from '@salesforce/apex/SinglePropertyViewCmpController.updateShowingStatus';
import updateShowingDate from '@salesforce/apex/SinglePropertyViewCmpController.updateShowingDate';
import plvimg from '@salesforce/resourceUrl/plvimgs';

export default class SinglePropertyView extends LightningElement {
    imagesOnDescription = [];
    listingrecordid;
    urlType;
    firstImageUrl;
    spinnerdatatable = false;
    propertyData = [];
    propertyImages = [];
    totalCountOfImg;
    Show_ImagePreview = false;
    PreviewImageTitle;
    Is_ImageHavePreview = false;
    PreviewImageSrc;
    PreviewImgSpinner = false;
    NotFirstImg = false;
    NotLastImg = false;
    totalImagesInGallery;
    mapMarkers = [];
    @track mapCenter = {};
    hasValidLocation = false;
    showError = false;
    errorMessage = '';
    formattedAddress = '';
    formattedPrice = '';
    isRentListing = false;
    currentSlide = 0;
    mapClass = 'map';
    autoSlideInterval;
    isInitialRender = true;
    isFullScreen = false;
    showOfferForm = false;
    showSiteVisit = false;
    showBooking = false;
    showOffer = false;
    objectId = '';
    showingStatus = '';
    showingDate = '';
    rawShowingDate = '';
    rescheduleDate = '';
    rawRescheduleDate = '';
    showConfirmPopup = false;
    showCancelPopup = false;
    showReschedulePopup = false;
    newScheduleDate = '';
    cancellationReason = '';
    showToast = false;
    toastMessage = '';
    toastType = '';

    plvimg1 = plvimg + '/plvimgs/Bedroom.png';
    plvimg2 = plvimg + '/plvimgs/Bathroom.png';
    plvimg4 = plvimg + '/plvimgs/CarParking.png';

    // State-based getters
    get isProposed() {
        return this.showingStatus === 'Proposed' || this.showingStatus === 'Waiting For Confirmation' || !this.showingStatus;
    }

    get isConfirmed() {
        return this.showingStatus === 'Scheduled';
    }

    get isRescheduled() {
        return this.showingStatus === 'Rescheduled';
    }

    get isCancelled() {
        return this.showingStatus === 'Cancelled';
    }

    get isDateInPast() {
        if (!this.showingDate) return false;
        const scheduledDate = new Date(this.showingDate);
        const today = new Date();
        return scheduledDate < today;
    }

    // Button visibility logic
    get showConfirmButton() {
        return this.isProposed && !this.isDateInPast;
    }

    get showRescheduleButton() {
        return (this.isProposed || this.isConfirmed) && !this.isDateInPast;
    }

    get showCancelButton() {
        return (this.isProposed || this.isConfirmed) && !this.isDateInPast;
    }

    get showReactivateButton() {
        return this.isCancelled;
    }

    get showChangeLinksAfterConfirm() {
        return this.isConfirmed && !this.isDateInPast;
    }

    get showDatePassedMessage() {
        return this.isDateInPast && !this.isCancelled;
    }

    get showStatusMessageBox() {
        // Show message when no buttons are visible
        const hasAnyButton = this.showConfirmButton || this.showRescheduleButton || 
                            this.showCancelButton || this.showReactivateButton;
        return !hasAnyButton;
    }

    get statusMessage() {
        if (this.isDateInPast && !this.isCancelled) {
            return 'This appointment time has passed';
        } else if (this.isConfirmed) {
            return `Appointment Confirmed! We will see you on ${this.showingDate}.`;
        } else if (this.isRescheduled) {
            return 'We have sent your reschedule request to the agent. They will update the time shortly.';
        } else if (this.isCancelled) {
            return 'Visit Cancelled';
        } else if (this.showingStatus === 'Waiting For Confirmation') {
            return 'Appointment Proposed';
        } else if (this.showingStatus === 'Proposed') {
            return 'Site Visit Request Reactivated';
        } else {
            return 'Appointment Proposed';
        }
    }

    get rescheduleMessage() {
        if (this.isRescheduled && this.rescheduleDate) {
            return `Requested new time: ${this.rescheduleDate}`;
        }
        return '';
    }

    connectedCallback() {
        const urlParams = new URLSearchParams(window.location.search);
        this.listingrecordid = urlParams.get('listingrecordid');
        this.urlType = urlParams.get('urlType');
        this.objectId = urlParams.get('objectId');
        if (!this.listingrecordid) {
            this.showError = true;
            this.errorMessage = 'No property ID provided in the URL.';
            return;
        }

        if (this.urlType === 'sitevisit') {
            this.showSiteVisit = true;
            this.getShowingStatus();
        } else if (this.urlType === 'offer') {
            this.showOffer = true;
        } else if (this.urlType === 'booking') {
            this.showBooking = true;
        }
        this.getListingDetail();
    }

    getShowingStatus() {
        getShowingData({ showingId: this.objectId })
            .then(result => {
                if (result != null) {
                    this.showingStatus = result.MVEX__Status__c;
                    if (result.MVEX__Scheduled_Date__c) {
                        const dateObj = new Date(result.MVEX__Scheduled_Date__c);
                        this.showingDate = dateObj.toLocaleString('en-US', {
                            year: 'numeric',
                            month: 'short',
                            day: 'numeric',
                            hour: '2-digit',
                            minute: '2-digit'
                        });
                        // Store raw datetime in ISO format for lightning-input
                        this.rawShowingDate = dateObj.toISOString().slice(0, 16);
                    } else {
                        this.showingDate = '';
                        this.rawShowingDate = '';
                    }
                    
                    // Fetch reschedule date if exists
                    if (result.MVEX__Reschedule_Date__c) {
                        const rescheduleDateObj = new Date(result.MVEX__Reschedule_Date__c);
                        this.rescheduleDate = rescheduleDateObj.toLocaleString('en-US', {
                            year: 'numeric',
                            month: 'short',
                            day: 'numeric',
                            hour: '2-digit',
                            minute: '2-digit'
                        });
                        this.rawRescheduleDate = rescheduleDateObj.toISOString().slice(0, 16);
                    } else {
                        this.rescheduleDate = '';
                        this.rawRescheduleDate = '';
                    }
                }
            })
            .catch(error => {
                console.error('Error fetching showing status:', error);
                this.showCustomToast('Failed to fetch showing status', 'error');
            });
    }

    disconnectedCallback() {
        clearInterval(this.autoSlideInterval);
    }

    renderedCallback() {
        if (!this.showError && !this.showOfferForm) {
            this.handleTabEvents();
            this.updateCarousel();

            if (this.isInitialRender) {
                const body = document.querySelector("body");
                const style = document.createElement('style');
                style.innerText = `
                    .map lightning-map{
                        width: -webkit-fill-available;
                        height: -webkit-fill-available;
                    }

                    .map-fullscreen {
                        position: fixed !important;
                        top: 0;
                        left: 0;
                        width: 100%;
                        height: 100% !important;
                        z-index: 1000;
                        background: #fff;
                    }
                    .map-fullscreen lightning-map {
                        height: 100%;
                    }
                    .map .slds-map:before {
                        display: none !important;
                    }
                `;
                body.appendChild(style);
                this.isInitialRender = false;

                // Start auto-sliding
                this.startAutoSlide();
            }
        }
    }

    generateUUID() {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
            const r = Math.random() * 16 | 0, v = c === 'x' ? r : (r & 0x3 | 0x8);
            return v.toString(16);
        });
    }

    handleTabEvents() {
        this.template.querySelectorAll(".tab-menu a").forEach(element => {
            element.addEventListener("click", evt => {
                evt.preventDefault();
                const target = evt.currentTarget.dataset.tabId;

                this.template.querySelectorAll(".tab-menu a").forEach(tabel => {
                    tabel.classList.remove("active-tab");
                });
                element.classList.add("active-tab");

                this.template.querySelectorAll(".tab-css").forEach(tabdata => {
                    tabdata.classList.remove("active-tab-content");
                    tabdata.style.opacity = '0';
                });

                const targetTab = this.template.querySelector(`[data-id="${target}"]`);
                targetTab.classList.add("active-tab-content");
                setTimeout(() => {
                    targetTab.style.opacity = '1';
                }, 50);
            });
        });
    }

    getListingDetail() {
        this.spinnerdatatable = true;
        getListingData({ recordId: this.listingrecordid })
            .then(result => {
                if (!result.listingData || result.listingData.length === 0) {
                    this.showError = true;
                    this.errorMessage = 'No property data found for the provided ID.';
                    this.spinnerdatatable = false;
                    return;
                }

                this.propertyData = result.listingData;
                this.propertyImages = result.listingImages.map(img => ({
                    ...img,
                    isLoading: true
                }));
                this.totalImagesInGallery = this.propertyImages.length;

                this.formattedAddress = this.formatAddress(this.propertyData[0]);
                this.formattedPrice = this.formatPrice(this.propertyData[0]);
                this.isRentListing = this.propertyData[0].MVEX__Listing_Type__c === 'Rent';

                const location = this.getLocationFromRecord(this.propertyData[0]);
                if (location) {
                    this.mapMarkers = [location.marker];
                    this.mapCenter = location.center;
                    this.hasValidLocation = true;
                } else {
                    this.hasValidLocation = false;
                }

                if (this.propertyImages.length > 6) {
                    this.firstImageUrl = this.propertyImages[0].MVEX__BaseUrl__c;
                    this.imagesOnDescription = this.propertyImages.slice(0, 6).map(img => ({
                        ...img,
                        isLoading: true
                    }));
                    this.totalCountOfImg = this.propertyImages.length - 5;
                    setTimeout(() => {
                        const element = this.template.querySelectorAll('.black1')[5];
                        if (element) element.classList.add('black_enabled');
                    }, 1000);
                } else if (this.propertyImages.length >= 1) {
                    this.firstImageUrl = this.propertyImages[0].MVEX__BaseUrl__c;
                    this.imagesOnDescription = this.propertyImages.map(img => ({
                        ...img,
                        isLoading: true
                    }));
                }

                this.spinnerdatatable = false;
            })
            .catch(error => {
                this.spinnerdatatable = false;
                this.showError = true;
                this.errorMessage = 'Failed to load property data. Please try again later.';
                console.error('Error loading listing data:', error);
            });
    }

    formatAddress(record) {
        const addressParts = [
            record.MVEX__Listing_Address__Street__s,
            record.MVEX__Listing_Address__City__s,
            record.MVEX__Listing_Address__StateCode__s,
            record.MVEX__Listing_Address__PostalCode__s
        ].filter(part => part != null && part !== '');
        return addressParts.length > 0 ? addressParts.join(', ') : 'Address not available';
    }

    formatPrice(record) {
        if (record.MVEX__Listing_Type__c === 'Sale') {
            return record.MVEX__Sale_Price__c ? `AED ${record.MVEX__Sale_Price__c.toLocaleString()}` : 'Price not available';
        } else if (record.MVEX__Listing_Type__c === 'Rent') {
            return record.MVEX__Rental_Price__c && record.MVEX__Rent_Frequency__c
                ? `AED ${record.MVEX__Rental_Price__c.toLocaleString()} / ${record.MVEX__Rent_Frequency__c}`
                : 'Rent not available';
        }
        return 'Price not available';
    }

    getLocationFromRecord(record) {
        const addressFields = [
            record.MVEX__Listing_Address__Street__s,
            record.MVEX__Listing_Address__City__s,
            record.MVEX__Listing_Address__StateCode__s,
            record.MVEX__Listing_Address__PostalCode__s
        ].filter(field => field != null && field !== '');

        if (addressFields.length > 0) {
            return {
                marker: {
                    location: {
                        Street: record.MVEX__Listing_Address__Street__s || '',
                        City: record.MVEX__Listing_Address__City__s || '',
                        StateCode: record.MVEX__Listing_Address__StateCode__s || '',
                        PostalCode: record.MVEX__Listing_Address__PostalCode__s || ''
                    },
                    title: record.Name,
                    description: `${record.Name}\n${this.formatAddress(record)}`
                },
                center: {
                    location: {
                        Street: record.MVEX__Listing_Address__Street__s || '',
                        City: record.MVEX__Listing_Address__City__s || '',
                        StateCode: record.MVEX__Listing_Address__StateCode__s || '',
                        PostalCode: record.MVEX__Listing_Address__PostalCode__s || ''
                    }
                }
            };
        }
        return null;
    }

    startAutoSlide() {
        clearInterval(this.autoSlideInterval);
        this.autoSlideInterval = setInterval(() => {
            this.nextSlide();
        }, 3000);
    }

    prevSlide() {
        this.currentSlide = this.currentSlide > 0 ? this.currentSlide - 1 : this.imagesOnDescription.length - 1;
        this.updateCarousel();
        this.startAutoSlide();
    }

    nextSlide() {
        this.currentSlide = this.currentSlide < this.imagesOnDescription.length - 1 ? this.currentSlide + 1 : 0;
        this.updateCarousel();
        this.startAutoSlide();
    }

    updateCarousel() {
        const carouselInner = this.template.querySelector('.carousel-inner');
        if (carouselInner && this.imagesOnDescription.length > 0) {
            carouselInner.style.transform = `translateX(-${this.currentSlide * 100}%)`;
        }
    }

    handleImageLoaded(event) {
        const imageId = event.target.dataset.id;
        this.imagesOnDescription = this.imagesOnDescription.map(img =>
            img.Id === imageId ? { ...img, isLoading: false } : img
        );
        this.propertyImages = this.propertyImages.map(img =>
            img.Id === imageId ? { ...img, isLoading: false } : img
        );
        if (this.PreviewImageId === imageId) {
            this.PreviewImgSpinner = false;
        }
    }

    handleImageError(event) {
        const imageId = event.target.dataset.id;
        this.imagesOnDescription = this.imagesOnDescription.map(img =>
            img.Id === imageId ? { ...img, isLoading: false } : img
        );
        this.propertyImages = this.propertyImages.map(img =>
            img.Id === imageId ? { ...img, isLoading: false } : img
        );
        if (this.PreviewImageId === imageId) {
            this.PreviewImgSpinner = false;
            this.Is_ImageHavePreview = false;
        }
    }

    handleBoxClick() {
        this.template.querySelectorAll(".tab-menu a").forEach(tab => {
            tab.classList.remove("active-tab");
        });
        this.template.querySelectorAll(".tab-css").forEach(tabContent => {
            tabContent.classList.remove("active-tab-content");
            tabContent.style.opacity = '0';
        });

        const galleryTab = this.template.querySelector('[data-id="tab2"]');
        galleryTab.classList.add("active-tab-content");
        this.template.querySelector('[data-tab-id="tab2"]').classList.add("active-tab");
        setTimeout(() => {
            galleryTab.style.opacity = '1';
            const lastImage = galleryTab.querySelector('.thumbnails:last-child');
            if (lastImage) {
                lastImage.scrollIntoView({
                    behavior: 'smooth',
                    block: 'end'
                });
            }
        }, 50);
    }

    stopEventPropagation(event) {
        event.stopPropagation();
    }

    closeImagePreview() {
        this.Is_ImageHavePreview = false;
        this.Show_ImagePreview = false;
    }

    handleImageNotLoaded() {
        this.Is_ImageHavePreview = false;
        this.PreviewImgSpinner = false;
    }

    changeImg(event) {
        this.Is_ImageHavePreview = false;
        this.Show_ImagePreview = false;
        this.buttonClickName = event.currentTarget.dataset.name;
        this.changeImageHelper(this.PreviewImageId, true);
    }

    changeImageHelper(imageId, nextPreviusBtnClick) {
        const imagePreviewList = this.propertyImages;
        for (let i in imagePreviewList) {
            if (imagePreviewList[i].Id === imageId) {
                if (nextPreviusBtnClick) {
                    if (this.buttonClickName === 'Previous_Image') {
                        const prevIndex = parseInt(i) - 1;
                        if (prevIndex >= 0) {
                            this.openCustomPreviewHelper(
                                imagePreviewList[prevIndex].MVEX__BaseUrl__c,
                                imagePreviewList[prevIndex].Name,
                                imagePreviewList[prevIndex].Id
                            );
                            this.changeImageHelper(imagePreviewList[prevIndex].Id, false);
                        }
                    } else if (this.buttonClickName === 'Next_Image') {
                        const nextIndex = parseInt(i) + 1;
                        if (nextIndex < imagePreviewList.length) {
                            this.openCustomPreviewHelper(
                                imagePreviewList[nextIndex].MVEX__BaseUrl__c,
                                imagePreviewList[nextIndex].Name,
                                imagePreviewList[nextIndex].Id
                            );
                            this.changeImageHelper(imagePreviewList[nextIndex].Id, false);
                        }
                    }
                } else {
                    this.NotFirstImg = parseInt(i) > 0;
                    this.NotLastImg = parseInt(i) < imagePreviewList.length - 1;
                }
            }
        }
    }

    get previousButtonClass() {
        return this.NotFirstImg ? 'Previous_img_btn' : 'Previous_img_btn disabled';
    }

    get nextButtonClass() {
        return this.NotLastImg ? 'Next_img_btn' : 'Next_img_btn disabled';
    }

    openCustomPreviewHelper(imageSrc, imageTitle, previewImageId) {
        this.PreviewImageSrc = imageSrc;
        this.PreviewImageTitle = imageTitle;
        this.PreviewImageId = previewImageId;
        this.PreviewImgSpinner = true;
        this.Is_ImageHavePreview = true;
        this.Show_ImagePreview = true;
    }

    previewAllImages(event) {
        const imageId = event.currentTarget.dataset.id;
        const imageName = event.currentTarget.dataset.name;
        const imageURL = event.currentTarget.dataset.url;
        this.clickedImage = imageURL;
        this.changeImageHelper(imageId, false);
        this.openCustomPreviewHelper(imageURL, imageName, imageId);
    }

    makeOffer() {
        this.showOfferForm = true;
    }

    handleOfferFormCancel() {
        this.showOfferForm = false;
    }

    handleOfferFormSubmit() {
        this.showOfferForm = false;
    }

    openGoogleMap() {
        const record = this.propertyData[0];
        const address = this.formatAddress(record);
        if (address !== 'Address not available') {
            const googleMapsUrl = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(address)}`;
            window.open(googleMapsUrl, '_blank');
        } else {
            console.error('Cannot open Google Maps: Location data not available.');
        }
    }

    toggleFullMapView() {
        this.mapClass = this.mapClass === 'map' ? 'map map-fullscreen' : 'map';
        this.isFullScreen = !this.isFullScreen;
        this.mapMarkers = [...this.mapMarkers];
    }

    confirmSiteVisit() {
        this.showConfirmPopup = true;
    }

    cancelSiteVisit() {
        this.showCancelPopup = true;
    }

    rescheduleSiteVisit() {
        this.newScheduleDate = this.rawShowingDate;
        this.showReschedulePopup = true;
    }

    closePopup() {
        this.showConfirmPopup = false;
        this.showCancelPopup = false;
        this.showReschedulePopup = false;
    }

    handleDateChange(event) {
        this.newScheduleDate = event.target.value;
    }

    handleReasonChange(event) {
        this.cancellationReason = event.target.value;
    }

    handleConfirm() {
        updateShowingStatus({ showingId: this.objectId, status: 'Scheduled', reason: null })
            .then(() => {
                this.showingStatus = 'Scheduled';
                this.showConfirmPopup = false;
                this.showCustomToast('Site visit scheduled successfully', 'success');
                this.getShowingStatus();
            })
            .catch(error => {
                console.error('Error confirming site visit:', error);
                this.showCustomToast('Failed to confirm site visit', 'error');
            });
    }

    handleCancel() {
        if (!this.cancellationReason) {
            this.showCustomToast('Please provide a reason for cancellation', 'error');
            return;
        }

        updateShowingStatus({ showingId: this.objectId, status: 'Cancelled', reason: this.cancellationReason })
            .then(() => {
                this.showingStatus = 'Cancelled';
                this.showCancelPopup = false;
                this.showCustomToast('Site visit cancelled successfully', 'success');
                this.getShowingStatus();
            })
            .catch(error => {
                console.error('Error cancelling site visit:', error);
                this.showCustomToast('Failed to cancel site visit', 'error');
            });
    }

    handleReschedule() {
        if (!this.newScheduleDate) {
            this.showCustomToast('Please select a date and time', 'error');
            return;
        }

        // Validate that the selected date is not in the past
        const selectedDate = new Date(this.newScheduleDate);
        const today = new Date();
        if (selectedDate < today) {
            this.showCustomToast('Cannot reschedule to a past date', 'error');
            return;
        }

        updateShowingDate({ showingId: this.objectId, status: 'Rescheduled', newDate: this.newScheduleDate })
            .then(() => {
                this.showReschedulePopup = false;
                this.showCustomToast('Reschedule request sent to agent', 'success');
                this.getShowingStatus();
            })
            .catch(error => {
                console.error('Error rescheduling site visit:', error);
                this.showCustomToast('Failed to reschedule site visit', 'error');
            });
    }

    reactivateSiteVisit() {
        updateShowingStatus({ showingId: this.objectId, status: 'Proposed', reason: null })
            .then(() => {
                this.showingStatus = 'Proposed';
                this.showCustomToast('Site visit request reactivated', 'success');
                this.getShowingStatus();
            })
            .catch(error => {
                console.error('Error reactivating site visit:', error);
                this.showCustomToast('Failed to reactivate site visit', 'error');
            });
    }

    showCustomToast(message, type) {
        this.toastMessage = message;
        this.toastType = type;
        this.showToast = true;
        setTimeout(() => {
            this.showToast = false;
        }, 5000);
    }

    handleToastClose() {
        this.showToast = false;
    }
}