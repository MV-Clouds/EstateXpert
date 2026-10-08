import { LightningElement, track } from 'lwc';
import getListingData from '@salesforce/apex/SinglePropertyViewCmpController.getListingData';
import getShowingData from '@salesforce/apex/SinglePropertyViewCmpController.getShowingData';
import updateShowingStatus from '@salesforce/apex/SinglePropertyViewCmpController.updateShowingStatus';
import updateShowingDate from '@salesforce/apex/SinglePropertyViewCmpController.updateShowingDate';
import emptyState from '@salesforce/resourceUrl/emptyState';

const SWIPE_THRESHOLD = 40;
const DEFAULT_CURRENCY = 'AED';

export default class SinglePropertyView extends LightningElement {
    // URL params
    listingrecordid;
    urlType;
    objectId = '';

    // Listing data
    propertyData = [];
    propertyImages = [];
    formattedAddress = '';
    priceLabel = '';
    priceAmount = '';
    priceSuffix = '';
    isRentListing = false;

    // Page state
    spinnerdatatable = false;
    showError = false;
    isListingInactive = false;
    errorTitle = 'Listing Unavailable';
    errorMessage = '';
    emptyStateUrl = emptyState;
    isInitialRender = true;
    showOfferForm = false;
    showSiteVisit = false;
    showBooking = false;
    showOffer = false;

    // Carousel
    currentSlide = 0;
    touchStartX = 0;

    // Image preview
    Show_ImagePreview = false;
    PreviewImageTitle;
    PreviewImageId;
    PreviewImageSrc;
    PreviewIsVideo = false;
    Is_ImageHavePreview = false;
    PreviewImgSpinner = false;
    NotFirstImg = false;
    NotLastImg = false;
    buttonClickName;

    // Map
    mapMarkers = [];
    @track mapCenter = {};
    mapZoom = 15;
    hasValidLocation = false;
    mapClass = 'map';
    isFullScreen = false;
    mapSearchQuery = '';

    // Site visit
    showingStatus = '';
    showingDate = '';
    showingTimestamp = null;
    showingDuration = '';
    cancellationReasonSaved = '';
    rawShowingDate = '';
    rescheduleDate = '';
    rawRescheduleDate = '';
    showConfirmPopup = false;
    showCancelPopup = false;
    showReschedulePopup = false;
    newScheduleDate = '';
    cancellationReason = '';

    // Toast
    showToast = false;
    toastMessage = '';
    toastType = '';

    /* ------------------------------------------------------------------
       Getters: page / property
    ------------------------------------------------------------------ */
    get showEmptyState() {
        return this.showError || this.isListingInactive;
    }

    get hasProperty() {
        return this.propertyData.length > 0;
    }

    get property() {
        return this.propertyData[0] || {};
    }

    get currency() {
        return this.property.CurrencyIsoCode || DEFAULT_CURRENCY;
    }

    get toastClass() {
        return `toast toast-${this.toastType}`;
    }

    /* ------------------------------------------------------------------
       Getters: agent (listing owner) details
    ------------------------------------------------------------------ */
    get hasAgent() {
        const p = this.property;
        return !!(p.MVEX__Listing_Agent_Full_Name__c || p.MVEX__Listing_Agent_Firstname__c || p.MVEX__Listing_Agent_Lastname__c);
    }

    get agentName() {
        const p = this.property;
        return p.MVEX__Listing_Agent_Full_Name__c ||
            [p.MVEX__Listing_Agent_Firstname__c, p.MVEX__Listing_Agent_Lastname__c].filter(Boolean).join(' ');
    }

    get agentInitials() {
        return this.agentName
            .split(/\s+/)
            .filter(Boolean)
            .slice(0, 2)
            .map(part => part.charAt(0).toUpperCase())
            .join('');
    }

    // The Listing object has no agent photo field. If you add one later,
    // return its URL here and both avatars will switch from initials to the photo.
    get agentPhotoUrl() {
        return this.property.Agent_Photo_URL__c || '';
    }

    get agentEmail() {
        return this.property.MVEX__Listing_Agent_Email__c || '';
    }

    get agentPhone() {
        return this.property.MVEX__Listing_Agent_Mobile_Phone__c || '';
    }

    get agentMeta() {
        return this.agentPhone ? `Assigned Agent · ${this.agentPhone}` : 'Assigned Agent';
    }

    get agentTelHref() {
        if (!this.agentPhone) return null;
        const cleaned = String(this.agentPhone).replace(/[^\d+]/g, '');
        return cleaned ? `tel:${cleaned}` : null;
    }

    get agentMailHref() {
        return this.agentEmail ? `mailto:${this.agentEmail}` : null;
    }

    /* ------------------------------------------------------------------
       Getters: highlights, details and address (all driven by Apex fields)
    ------------------------------------------------------------------ */
    get highlights() {
        const p = this.property;
        const items = [];

        const beds = p.MVEX__Bedrooms__c;
        if (!this.isBlank(beds)) {
            items.push({
                key: 'beds', isBed: true,
                text: Number(beds) === 0 ? 'Studio' : `${beds} ${Number(beds) === 1 ? 'Bed' : 'Beds'}`
            });
        }
        const baths = p.MVEX__Bathrooms__c;
        if (!this.isBlank(baths) && Number(baths) > 0) {
            items.push({ key: 'baths', isBath: true, text: `${baths} ${Number(baths) === 1 ? 'Bath' : 'Baths'}` });
        }
        const parking = p.MVEX__Parking_Spaces__c;
        if (!this.isBlank(parking) && Number(parking) > 0) {
            items.push({ key: 'parking', isParking: true, text: `${parking} Parking` });
        }
        const area = !this.isBlank(p.MVEX__Sq_Ft__c) ? p.MVEX__Sq_Ft__c : p.MVEX__Lot_Size__c;
        if (!this.isBlank(area) && Number(area) > 0) {
            items.push({ key: 'area', isArea: true, text: this.formatArea(area) });
        }
        return items;
    }

    get hasHighlights() {
        return this.highlights.length > 0;
    }

    get detailRows() {
        const p = this.property;
        const rows = [];
        const add = (label, value) => {
            rows.push({ label, value: this.isBlank(value) ? '-' : value });
        };
        const addBoolean = (label, value) => {
            add(label, this.isBlank(value) ? '' : value ? 'Yes' : 'No');
        };

        add('Property Type', p.MVEX__Property_Type__c);
        add('Status', p.MVEX__Status__c);
        add('Year Built', p.MVEX__Year_Built__c);
        add('Furnished Status', p.MVEX__Furnished__c);
        add('Completion Status', p.MVEX__Completion_Status__c);
        add('Floor', p.MVEX__Floor__c);
        add('RERA Permit Number', p.MVEX__RERA_Permit_Number__c);
        add('Property Category', p.MVEX__Property_Category__c);
        add('Property Status', p.MVEX__Property_Status__c);
        add('Property Sub Type', p.MVEX__Property_Sub_Type__c);

        const listingType = p.MVEX__Listing_Type__c;
        add('Listing Type', listingType ? `For ${listingType}` : '');
        add('Carpet Area', this.isBlank(p.MVEX__Lot_Size__c) ? '' : this.formatArea(p.MVEX__Lot_Size__c));
        add('Built-up Area', this.isBlank(p.MVEX__Sq_Ft__c) ? '' : this.formatArea(p.MVEX__Sq_Ft__c));
        add('Facing', p.MVEX__Facing__c);
        add('Possession Status', p.MVEX__Possession_Status__c);
        add('Completion Date', this.formatDateValue(p.MVEX__Completion_Date__c));
        addBoolean('Off Plan', p.MVEX__Off_Plan__c);
        addBoolean('New Construction', p.MVEX__IS_New_Construction__c);
        add('Units', p.MVEX__Units__c);
        add('Parking Available', this.formatFlexible(p.MVEX__Parking_Available__c));
        add('Private Amenities', p.MVEX__Private_Amenities__c);
        add('Commercial Amenities', p.MVEX__Commercial_Amenities__c);
        addBoolean('Shared Accommodation', p.MVEX__Share_Accommodation__c);
        add('Service Charge', this.formatMoney(p.MVEX__Service_Charge__c));
        add('HOA Fees', this.formatMoney(p.MVEX__HOA_Fees__c));
        add('Application Fee', this.formatMoney(p.MVEX__Application_Fee__c));
        add('Taxes', this.formatPlainNumber(p.MVEX__Taxes__c));
        addBoolean('Price Negotiable', p.MVEX__Negotiable__c);

        add('Availability Date', this.formatDateValue(p.MVEX__Availability_Date__c));
        add('Available From', this.formatDateValue(p.MVEX__Available_From__c));
        add('Available To', this.formatDateValue(p.MVEX__Available_to__c));
        add('Number of Cheques', p.MVEX__Number_of_Cheques__c);

        add('Listing Reference', p.MVEX__Broker_s_Listing_ID__c || p.MVEX__Listing_Auto_ID__c);
        add('Listed On', this.formatDateValue(p.MVEX__Listed_Date__c || p.MVEX__On_Market_Date__c));
        add('Off Market Date', this.formatDateValue(p.MVEX__Off_Market_Date__c));
        add('Sale Date', this.formatDateValue(p.MVEX__Sale_Date__c));
        add('Sale Price', this.formatMoney(p.MVEX__Sale_Price__c));

        return rows;
    }

    get addressRows() {
        const p = this.property;
        const rows = [];
        const add = (label, value) => {
            if (!this.isBlank(value)) rows.push({ label, value });
        };
        add('House / Office No', p.MVEX__House_Office_No__c);
        add('Street', p.MVEX__Listing_Address__Street__s || p.MVEX__Street__c);
        add('Community', p.MVEX__Community__c);
        add('Sub Community', p.MVEX__Subcommunity__c);
        add('City', p.MVEX__Listing_Address__City__s || p.MVEX__City__c);
        add('State', p.MVEX__Listing_Address__StateCode__s || p.MVEX__State__c);
        add('Postal Code', p.MVEX__Listing_Address__PostalCode__s || p.MVEX__Zip_Postal_Code__c);
        add('Country', p.MVEX__Country__c || p.MVEX__Listing_Address__CountryCode__s);
        return rows;
    }

    get hasAddressRows() {
        return this.addressRows.length > 0;
    }

    /* ------------------------------------------------------------------
       Getters: gallery
    ------------------------------------------------------------------ */
    get hasImages() {
        return this.propertyImages.length > 0;
    }

    get hasMultipleImages() {
        return this.propertyImages.length > 1;
    }

    get slides() {
        return this.propertyImages.map((img, index) => ({
            ...img,
            index,
            thumbClass: index === this.currentSlide ? 'thumb thumb_active' : 'thumb',
            ariaCurrent: index === this.currentSlide ? 'true' : 'false',
            label: `Show ${img.isVideo ? 'video' : 'photo'} ${index + 1}`
        }));
    }

    get carouselStyle() {
        return `transform: translateX(-${this.currentSlide * 100}%);`;
    }

    get slideCounter() {
        return `${this.currentSlide + 1} / ${this.propertyImages.length}`;
    }

    /* ------------------------------------------------------------------
       Getters: site visit state (same rules as before)
    ------------------------------------------------------------------ */
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
        if (!this.showingTimestamp) return false;
        return this.showingTimestamp < Date.now();
    }

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

    get showFreeCancellationNote() {
        return this.showCancelButton && !this.isConfirmed;
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
        }
        return 'Appointment Proposed';
    }

    get rescheduleMessage() {
        if (this.isRescheduled && this.rescheduleDate) {
            return `Requested new time: ${this.rescheduleDate}`;
        }
        return '';
    }

    get cancellationNote() {
        return this.isCancelled && this.cancellationReasonSaved ? `Reason: ${this.cancellationReasonSaved}` : '';
    }

    get showingDurationLabel() {
        return this.showingDuration ? `${this.showingDuration} min visit` : '';
    }

    get statusPillLabel() {
        if (this.isDateInPast && !this.isCancelled) return 'Time passed';
        if (this.isConfirmed) return 'Confirmed';
        if (this.isRescheduled) return 'Reschedule requested';
        if (this.isCancelled) return 'Cancelled';
        return 'Awaiting confirmation';
    }

    get statusPillClass() {
        let variant = 'warning';
        if (this.isDateInPast && !this.isCancelled) variant = 'neutral';
        else if (this.isConfirmed) variant = 'success';
        else if (this.isRescheduled) variant = 'info';
        else if (this.isCancelled) variant = 'error';
        return `status-pill status-pill_${variant}`;
    }

    /* ------------------------------------------------------------------
       Lifecycle
    ------------------------------------------------------------------ */
    connectedCallback() {
        const urlParams = new URLSearchParams(window.location.search);
        this.listingrecordid = urlParams.get('listingrecordid');
        this.urlType = urlParams.get('urlType');
        this.objectId = urlParams.get('objectId');

        if (!this.listingrecordid) {
            this.showError = true;
            this.errorTitle = 'Listing Not Found';
            this.errorMessage = 'No property ID was provided in the link. Please verify the URL or contact your agent.';
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

    renderedCallback() {
        if (this.isInitialRender && !this.showError) {
            // lightning-map internals can only be styled from the document level
            const style = document.createElement('style');
            style.innerText = `
                .map lightning-map {
                    display: block;
                    width: -webkit-fill-available;
                    height: -webkit-fill-available;
                }
                .map-fullscreen {
                    position: fixed !important;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100% !important;
                    z-index: 9000;
                    background: #fff;
                }
                .map-fullscreen lightning-map {
                    height: 100%;
                }
                .map .slds-map:before {
                    display: none !important;
                }
            `;
            document.body.appendChild(style);
            this.isInitialRender = false;
        }
    }

    /* ------------------------------------------------------------------
       Data loading
    ------------------------------------------------------------------ */
    getListingDetail() {
        this.spinnerdatatable = true;
        getListingData({ recordId: this.listingrecordid })
            .then(result => {
                if (!result.listingData || result.listingData.length === 0) {
                    this.showError = true;
                    this.errorTitle = 'Listing Unavailable';
                    this.errorMessage = 'This property listing is currently unavailable or no longer active. It may have been sold, rented, or removed from the market.';
                    this.spinnerdatatable = false;
                    return;
                }

                if (result.listingData[0].MVEX__Status__c !== 'Active') {
                    this.isListingInactive = true;
                    this.errorTitle = 'Listing Unavailable';
                    this.errorMessage = 'This property listing is no longer active. It may have been sold, rented, or temporarily taken off the market.';
                    this.spinnerdatatable = false;
                    return;
                }

                const record = result.listingData[0];
                this.propertyData = result.listingData;
                this.propertyImages = (result.listingImages || [])
                    .map(img => {
                        const fileType = (img.MVEX__MimeType__c || '').trim().toLowerCase();
                        const isVideo = fileType.startsWith('video/');
                        const isImage = fileType.startsWith('image/');
                        if (fileType && !isVideo && !isImage) return null;

                        return {
                            ...img,
                            isVideo,
                            mediaUrl: isVideo
                                ? img.MVEX__ExternalLink__c || img.MVEX__BaseUrl__c
                                : img.MVEX__BaseUrl__c || img.MVEX__ExternalLink__c,
                            isLoading: true
                        };
                    })
                    .filter(Boolean);

                this.formattedAddress = this.formatAddress(record);
                this.isRentListing = record.MVEX__Listing_Type__c === 'Rent';
                this.setPrice(record);
                this.setupMap(record);

                this.spinnerdatatable = false;
            })
            .catch(error => {
                this.spinnerdatatable = false;
                this.showError = true;
                this.errorTitle = 'Listing Unavailable';
                this.errorMessage = 'We encountered a temporary issue while loading this property. Please refresh the page or contact your agent.';
                console.error('Error loading listing data:', error);
            });
    }

    getShowingStatus() {
        getShowingData({ showingId: this.objectId })
            .then(result => {
                if (result != null) {
                    this.showingStatus = result.MVEX__Status__c;
                    this.showingDuration = result.MVEX__Showing_Duration__c || '';
                    this.cancellationReasonSaved = result.MVEX__Cancellation_Reason__c || '';

                    if (result.MVEX__Scheduled_Date__c) {
                        const dateObj = new Date(result.MVEX__Scheduled_Date__c);
                        this.showingDate = this.formatDateTime(dateObj);
                        this.showingTimestamp = dateObj.getTime();
                        // Store raw datetime in ISO format for lightning-input
                        this.rawShowingDate = dateObj.toISOString().slice(0, 16);
                    } else {
                        this.showingDate = '';
                        this.showingTimestamp = null;
                        this.rawShowingDate = '';
                    }

                    // Fetch reschedule date if exists
                    if (result.MVEX__Reschedule_Date__c) {
                        const rescheduleDateObj = new Date(result.MVEX__Reschedule_Date__c);
                        this.rescheduleDate = this.formatDateTime(rescheduleDateObj);
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

    /* ------------------------------------------------------------------
       Formatting helpers
    ------------------------------------------------------------------ */
    isBlank(value) {
        return value === null || value === undefined || value === '';
    }

    formatArea(value) {
        const n = Number(value);
        return Number.isFinite(n) ? `${n.toLocaleString()} sqft` : String(value);
    }

    formatMoney(value) {
        if (this.isBlank(value)) return '';
        const n = Number(value);
        return Number.isFinite(n) ? `${this.currency} ${n.toLocaleString()}` : String(value);
    }

    formatPlainNumber(value) {
        if (this.isBlank(value)) return '';
        const n = Number(value);
        return Number.isFinite(n) ? n.toLocaleString() : String(value);
    }

    formatFlexible(value) {
        if (typeof value === 'boolean') return value ? 'Yes' : 'No';
        return this.isBlank(value) ? '' : value;
    }

    formatDateValue(value) {
        if (this.isBlank(value)) return '';
        const text = String(value);
        const match = text.match(/^(\d{4})-(\d{2})-(\d{2})$/);
        // Plain dates are parsed as local dates to avoid a one-day timezone shift
        const date = match
            ? new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]))
            : new Date(value);
        if (Number.isNaN(date.getTime())) return text;
        return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    }

    formatDateTime(dateObj) {
        const datePart = dateObj.toLocaleDateString('en-US', {
            weekday: 'short',
            month: 'short',
            day: 'numeric',
            year: 'numeric'
        });
        const timePart = dateObj.toLocaleTimeString('en-US', {
            hour: 'numeric',
            minute: '2-digit'
        });
        return `${datePart} at ${timePart}`;
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

    setPrice(record) {
        const type = record.MVEX__Listing_Type__c;
        const currency = record.CurrencyIsoCode || DEFAULT_CURRENCY;
        this.priceSuffix = '';

        if (type === 'Sale') {
            this.priceLabel = 'Sale price';
            this.priceAmount = record.MVEX__Listing_Price__c
                ? `${currency} ${record.MVEX__Listing_Price__c.toLocaleString()}`
                : 'Price not available';
        } else if (type === 'Rent') {
            const frequency = record.MVEX__Rent_Frequency__c;
            this.priceLabel = frequency ? `${frequency} rent` : 'Rent';
            if (record.MVEX__Rental_Price__c && frequency) {
                this.priceAmount = `${currency} ${record.MVEX__Rental_Price__c.toLocaleString()}`;
                this.priceSuffix = `/ ${frequency}`;
            } else {
                this.priceAmount = 'Rent not available';
            }
        } else {
            this.priceLabel = 'Price';
            this.priceAmount = 'Price not available';
        }
    }

    /* ------------------------------------------------------------------
       Map
       Location priority: custom Latitude/Longitude fields, then the
       compound address coordinates, then geocoding the address text.
    ------------------------------------------------------------------ */
    parseCoordinate(value, limit) {
        if (this.isBlank(value)) return null;
        const n = parseFloat(value);
        return Number.isFinite(n) && Math.abs(n) <= limit ? n : null;
    }

    getCoordinates(record) {
        const pairs = [
            [record.MVEX__Latitude__c, record.MVEX__Longitude__c],
            [record.MVEX__Listing_Address__Latitude__s, record.MVEX__Listing_Address__Longitude__s]
        ];
        for (const [rawLat, rawLng] of pairs) {
            const lat = this.parseCoordinate(rawLat, 90);
            const lng = this.parseCoordinate(rawLng, 180);
            if (lat !== null && lng !== null && !(lat === 0 && lng === 0)) {
                return { Latitude: lat, Longitude: lng };
            }
        }
        return null;
    }

    setupMap(record) {
        const coords = this.getCoordinates(record);
        const addressFields = [
            record.MVEX__Listing_Address__Street__s || record.MVEX__Street__c,
            record.MVEX__Listing_Address__City__s || record.MVEX__City__c,
            record.MVEX__Listing_Address__StateCode__s || record.MVEX__State__c,
            record.MVEX__Listing_Address__PostalCode__s || record.MVEX__Zip_Postal_Code__c,
            record.MVEX__Listing_Address__CountryCode__s
        ].filter(field => field != null && field !== '');

        if (!coords && addressFields.length === 0) {
            this.hasValidLocation = false;
            return;
        }

        let location;
        if (coords) {
            location = coords;
            this.mapZoom = 15;
            this.mapSearchQuery = `${coords.Latitude},${coords.Longitude}`;
        } else {
            location = {
                Street: record.MVEX__Listing_Address__Street__s || record.MVEX__Street__c || '',
                City: record.MVEX__Listing_Address__City__s || record.MVEX__City__c || '',
                State: record.MVEX__Listing_Address__StateCode__s || record.MVEX__State__c || '',
                PostalCode: record.MVEX__Listing_Address__PostalCode__s || record.MVEX__Zip_Postal_Code__c || '',
                Country: record.MVEX__Listing_Address__CountryCode__s || ''
            };
            this.mapZoom = 12;
            this.mapSearchQuery = addressFields.join(', ');
        }

        this.mapMarkers = [{
            location,
            title: record.Name,
            description: `${record.Name}\n${this.formatAddress(record)}`
        }];
        this.mapCenter = location;
        this.hasValidLocation = true;
    }

    openGoogleMap() {
        if (this.mapSearchQuery) {
            const googleMapsUrl = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(this.mapSearchQuery)}`;
            window.open(googleMapsUrl, '_blank');
        } else {
            console.error('Cannot open Google Maps: Location data not available.');
        }
    }

    toggleFullMapView() {
        this.mapClass = this.mapClass === 'map' ? 'map map-fullscreen' : 'map';
        this.isFullScreen = !this.isFullScreen;
        // Re-assign to make lightning-map redraw at its new size
        this.mapMarkers = [...this.mapMarkers];
        this.mapCenter = { ...this.mapCenter };
    }

    /* ------------------------------------------------------------------
       Carousel
    ------------------------------------------------------------------ */
    prevSlide() {
        const total = this.propertyImages.length;
        this.currentSlide = this.currentSlide > 0 ? this.currentSlide - 1 : total - 1;
    }

    nextSlide() {
        const total = this.propertyImages.length;
        this.currentSlide = this.currentSlide < total - 1 ? this.currentSlide + 1 : 0;
    }

    selectSlide(event) {
        this.currentSlide = parseInt(event.currentTarget.dataset.index, 10);
    }

    handleTouchStart(event) {
        this.touchStartX = event.changedTouches[0].clientX;
    }

    handleTouchEnd(event) {
        if (!this.hasMultipleImages) return;
        const delta = event.changedTouches[0].clientX - this.touchStartX;
        if (Math.abs(delta) < SWIPE_THRESHOLD) return;
        if (delta < 0) {
            this.nextSlide();
        } else {
            this.prevSlide();
        }
    }

    handleImageLoaded(event) {
        const imageId = event.target.dataset.id;
        this.propertyImages = this.propertyImages.map(img =>
            img.Id === imageId ? { ...img, isLoading: false } : img
        );
        if (this.PreviewImageId === imageId) {
            this.PreviewImgSpinner = false;
        }
    }

    handleImageError(event) {
        const imageId = event.target.dataset.id;
        this.propertyImages = this.propertyImages.map(img =>
            img.Id === imageId ? { ...img, isLoading: false } : img
        );
        if (this.PreviewImageId === imageId) {
            this.PreviewImgSpinner = false;
            this.Is_ImageHavePreview = false;
        }
    }

    /* ------------------------------------------------------------------
       Image preview
    ------------------------------------------------------------------ */
    openPreview(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        const image = this.propertyImages[index];
        if (!image) return;
        this.changeImageHelper(image.Id, false);
        this.openCustomPreviewHelper(image.mediaUrl, image.Name, image.Id, image.isVideo);
    }

    openCustomPreviewHelper(imageSrc, imageTitle, previewImageId, isVideo = false) {
        this.PreviewImageSrc = imageSrc;
        this.PreviewImageTitle = imageTitle;
        this.PreviewImageId = previewImageId;
        this.PreviewIsVideo = isVideo;
        this.PreviewImgSpinner = true;
        this.Is_ImageHavePreview = true;
        this.Show_ImagePreview = true;
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
        const list = this.propertyImages;
        const i = list.findIndex(img => img.Id === imageId);
        if (i < 0) return;

        if (nextPreviusBtnClick) {
            const target = this.buttonClickName === 'Previous_Image' ? i - 1 : i + 1;
            if (target >= 0 && target < list.length) {
                this.openCustomPreviewHelper(
                    list[target].mediaUrl,
                    list[target].Name,
                    list[target].Id,
                    list[target].isVideo
                );
                this.changeImageHelper(list[target].Id, false);
                this.currentSlide = target;
            }
        } else {
            this.NotFirstImg = i > 0;
            this.NotLastImg = i < list.length - 1;
        }
    }

    get previousButtonClass() {
        return this.NotFirstImg ? 'Previous_img_btn' : 'Previous_img_btn disabled';
    }

    get nextButtonClass() {
        return this.NotLastImg ? 'Next_img_btn' : 'Next_img_btn disabled';
    }

    stopEventPropagation(event) {
        event.stopPropagation();
    }

    /* ------------------------------------------------------------------
       Offer / booking
    ------------------------------------------------------------------ */
    makeOffer() {
        this.showOfferForm = true;
    }

    // The original template referenced makeBooking but the JS never defined it.
    // It follows the same path as makeOffer until a booking form exists.
    makeBooking() {
        this.showOfferForm = true;
    }

    handleOfferFormCancel() {
        this.showOfferForm = false;
    }

    handleOfferFormSubmit() {
        this.showOfferForm = false;
    }

    /* ------------------------------------------------------------------
       Site visit actions (original flow and messages)
    ------------------------------------------------------------------ */
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