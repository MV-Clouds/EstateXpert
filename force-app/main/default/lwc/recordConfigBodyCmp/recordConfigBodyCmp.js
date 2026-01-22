import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getObjectFields from '@salesforce/apex/RecordManagersCmpController.getObjectFields';
import getListingFieldsParent from '@salesforce/apex/RecordManagersCmpController.getListingFieldsParent';
import saveMetadata from '@salesforce/apex/RecordManagersCmpController.saveMappings';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { loadStyle } from 'lightning/platformResourceLoader';
// Assuming errorDebugger is a shared utility, if not available, replace with console.error
import { errorDebugger } from 'c/globalProperties'; 

export default class RecordConfigBodyCmp extends LightningElement {

    @api featureName;
    @api customParam = '';
    @api isFromListingManager;

    // Tracker variables from child
    @track fieldOptions = [];
    @track setScroll = false;
    @track pageSize = 30; // Default Page Size
    @track checklistItems = [];
    @track searchText = '';
    @track filteredFieldOptions = [];
    @track parentFieldsOption = [];
    @track isLoading = false;
    @track isForFocus = false;
    @track setIndex = 0;
    @track dragStartIndex = null;
    scrollInterval = null;

    @track dateOptions = [
        { label: 'DD-MM-YYYY', value: 'ddmmyyyy' },
        { label: 'MM-DD-YYYY', value: 'mmddyyyy' },
        { label: 'YYYY-MM-DD', value: 'yyyymmdd' }
    ];
    @track dateTimeOptions = [
        { label: 'DD-MM-YYYY (24 hour)', value: 'ddmmyyy24' },
        { label: 'MM-DD-YYYY (24 hour)', value: 'mmddyyyy24' },
        { label: 'YYYY-MM-DD (24 hour)', value: 'yyyymmdd24' },
        { label: 'DD-MM-YYYY (12 hour)', value: 'ddmmyyy12' },
        { label: 'MM-DD-YYYY (12 hour)', value: 'mmddyyyy12' },
        { label: 'YYYY-MM-DD (12 hour)', value: 'yyyymmdd12' }
    ];

    // Computed Property: Decide if Card View should be shown
    get showCardView() {
        return this.featureName !== 'Inquiry Manager' && this.featureName !== 'Listing_Configuration';
    }

    // Computed Property: Dynamic Grid Class for Header
    get headerClass() {
        return this.showCardView ? 'popup__header-row-5' : 'popup__header-row-4';
    }

    // Computed Property: Dynamic Grid Class for Rows
    get rowClass() {
        return this.showCardView ? 'popup__data-row-5 popup__data-row' : 'popup__data-row-4 popup__data-row';
    }

    // Computed Property to get Object Name based on Feature
    get selectedTabObject() {
        switch (this.featureName) {
            case 'Marketing List':
                return 'Contact';
            case 'Listing Manager':
                return 'MVEX__Listing__c';
            case 'Listing_Configuration':
                return 'MVEX__Listing__c';
            case 'Inquiry Manager':
                return 'MVEX__Inquiry__c';
            default:
                return '';
        }
    }

    get showParentDropDown() {
        return this.parentFieldsOption.length > 0;
    }

    get isDataAvailable() {
        return this.checklistItems && this.checklistItems.length > 0;
    }

    connectedCallback() {
        loadStyle(this, MulishFontCss)
            .then(() => {
                console.log('External Css Loaded');
            })
            .catch(error => {
                console.log('Error loading external css', error);
            });
        
        if(this.selectedTabObject) {
            this.fetchMetadata();
        }
    }

    renderedCallback(){
        if(this.setScroll){
            const container = this.template.querySelector('.tableContainer');
            if(container) container.scrollTop = container.scrollHeight;
            this.setScroll = false;
        } else if (this.isForFocus) {
            const inputElement = this.template.querySelector(`input[data-index="${this.setIndex}"]`);
            if(inputElement) inputElement.focus();
            this.isForFocus = false;
        }
    }

    handleDialogueClose(){
        // Dispatch event to parent to close this component
        this.dispatchEvent(new CustomEvent('close'));
    }

    handlePageSizeChange(event) {
        let value = parseInt(event.target.value, 10);
        if (isNaN(value) || value < 1) {
            value = 30; // Default fallback
        }
        this.pageSize = value;
    }

    /* ================= DATA FETCHING ================= */

    fetchMetadata() {
        this.isLoading = true;
        getObjectFields({ objectApiName: this.selectedTabObject , featureName: this.featureName})
            .then((result) => {
                if(!result) {
                     this.isLoading = false;
                     return;
                }
                this.fieldOptions = result.fieldDetailsList;
                // Exclude OwnerId and map lookup flags
                this.fieldOptions = this.fieldOptions.map(option => ({
                    ...option,
                    showRightRef: this.isLookupField(option.fieldType)
                })).filter(option => option.value !== 'OwnerId');

                if (result.metadataRecords && result.metadataRecords.length > 0) {
                    // Check if JSON exists
                    if(result.metadataRecords[0]) {
                        const fieldsData = JSON.parse(result.metadataRecords[0]);
                        this.checklistItems = fieldsData.map((item, index) => ({
                            id: index + 1,
                            fieldName: item.fieldName,
                            cardView: item.cardView || false,
                            value: item.value,
                            label: item.label,
                            fieldType: item.fieldType,
                            format: item.format,
                            isDisable: item.format === '' || item.format == null,
                            picklist: item.fieldType === 'DATE' ? this.dateOptions :
                                item.fieldType === 'DATETIME' ? this.dateTimeOptions : null
                        }));
                    }
                    if(result.metadataRecords[1]) {
                        this.pageSize = parseInt(result.metadataRecords[1], 10);
                    } else {
                        this.pageSize = 30; // Default if not found
                    }
                }
                this.isLoading = false;
                this.filteredFieldOptions = this.fieldOptions;
            })
            .catch((error) => {
                this.isLoading = false;
                console.error('Error fetching data', error);
                this.toast('Error', 'Error fetching configuration', 'error');
            });
    }

    isLookupField(fieldType) {
        return fieldType === 'REFERENCE' || fieldType === 'Lookup';
    }

    fetchObjectFieldsWithoutReference(objectApiName) {
        getListingFieldsParent({ objectApiName })
            .then(fields => {
                if (fields) {
                    let filteredFields = fields.filter(field => field.fieldType !== 'REFERENCE');
                    this.parentFieldsOption = filteredFields.map(field => {
                        return {
                            label: field.label,
                            value: field.value,
                            fieldType: field.fieldType,
                            referenceObjectName: field.referenceFields || [],
                            objectApiName: field.referenceObjectName || ''
                        };
                    });
                }
            })
            .catch(error => {
                console.error('Error fetching parent fields', error);
            });
    }

    /* ================= UI INTERACTION (SEARCH, PICKLIST) ================= */

    handleFocus1(event) {
        try {
            const index = event.currentTarget.dataset.index;
            this.setIndex = index;
            this.checklistItems = this.checklistItems.map((item, i) => {
                if (i === parseInt(index, 10)) {
                    return { ...item, isFocused: true };
                }
                return item;
            });
            this.isForFocus = true;
        } catch (error) {
            console.error(error);
        }
    }

    handleBlur1(event) {
        try {
            const index = event.currentTarget.dataset.index;
            this.checklistItems = this.checklistItems.map((item, i) => {
                if (i === parseInt(index, 10)) {
                    return { ...item, isFocused: false };
                }
                return item;
            });
            this.parentFieldsOption = [];
            this.filteredFieldOptions = [...this.fieldOptions];
        } catch (error) {
            console.error(error);
        }
    }

    handlePreventDefault(event){
        event.preventDefault();
    }

    handleSearchChange(event) {
        try {
            const index = event.target.dataset.index;
            const newValue = event.target.value;
            this.checklistItems = this.checklistItems.map((item, i) => {
                if (i === parseInt(index, 10)) {
                    return { ...item, value: newValue };
                }
                return item;
            });
            if (newValue) {
                this.filteredFieldOptions = this.filterFieldOptions(newValue);
            } else {
                this.filteredFieldOptions = [...this.fieldOptions];
            }
        } catch (e) {
            console.error(e);
        }
    }

    filterFieldOptions(searchText) {
        const searchValue = searchText.toLowerCase();
        return this.fieldOptions.filter(option =>
            option.label.toLowerCase().includes(searchValue)
        );
    }

    selectOption1(event) {
        try {
            const index = event.currentTarget.dataset.index;
            const selectedOptionValue = event.currentTarget.dataset.id;
            const label = event.currentTarget.dataset.label;
            const type = event.currentTarget.dataset.type;

            this.updateChecklistItem(index, selectedOptionValue, selectedOptionValue, label, type);
            
            requestAnimationFrame(() => {
                this.handleBlur(index);
            });
        } catch (e) {
            console.error(e);
        }
    }

    selectOptionParent(event){
        try{
            const index = event.currentTarget.dataset.index;
            const selectedOptionValue = event.currentTarget.dataset.id;
            const label = event.currentTarget.dataset.label;
            const type = event.currentTarget.dataset.type;

            const fullValue = this.checklistItems[index].relationshipName + '.' + selectedOptionValue;
            
            this.updateChecklistItem(index, fullValue, fullValue, label, type);

            requestAnimationFrame(() => {
                this.handleBlur(index);
            });
        } catch (e) {
            console.error(e);
        }
    }

    updateChecklistItem(index, fieldName, value, label, type) {
        let item = this.checklistItems[index];
        item.fieldName = fieldName;
        item.value = value;
        item.label = label;
        item.fieldType = type;

        if (type === 'DATE') {
            item.isDisable = false;
            item.picklist = this.dateOptions;
            item.format = this.dateOptions[0].value;
        } else if (type === 'DATETIME') {
            item.isDisable = false;
            item.picklist = this.dateTimeOptions;
            item.format = this.dateTimeOptions[0].value;
        } else {
            item.isDisable = true;
            item.format = null;
        }
        this.filteredFieldOptions = [...this.fieldOptions];
    }

    handleBlur(index) {
        this.checklistItems = this.checklistItems.map((item, i) => {
            if (i === parseInt(index, 10)) {
                return { ...item, isFocused: false };
            }
            return item;
        });
        this.parentFieldsOption = [];
        this.filteredFieldOptions = [...this.fieldOptions];
    }

    clickOnRef(event){
        const selectedValue = event.currentTarget.dataset.id;
        const index = event.currentTarget.dataset.index;
        const relationShip = event.currentTarget.dataset.label;
        this.checklistItems[index].relationshipName = relationShip;
        
        const selectedField = this.fieldOptions.find(option => option.value === selectedValue);
        if (selectedField != null) {
            this.fetchObjectFieldsWithoutReference(selectedField.referenceObjectName);
        }
    }

    handleFormatChange(event){
        const value = event.detail.value;
        const index = event.currentTarget.dataset.id;
        this.checklistItems[index].format = value;
    }

    /* ================= ROW MANAGEMENT & CARD VIEW ================= */

    addNewRow() {
        const newItem = {
            id: this.checklistItems.length + 1,
            fieldName: '',
            cardView: false,
            value: '',
            searchTerm: '',
            label: '',
            isDisable: true
        };
        this.checklistItems = [...this.checklistItems, newItem];
        this.setScroll = true;
    }

    handleDelete(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        const updatedItems = [...this.checklistItems];
        updatedItems.splice(index, 1);
        this.checklistItems = updatedItems;
    }

    handleCardViewChange(event) {
        const index = parseInt(event.target.dataset.index, 10);
        const cardView = event.target.checked;
        const selectedCardViewCount = this.checklistItems.filter(item => item.cardView).length;
        if (cardView && selectedCardViewCount >= 5) {
            event.target.checked = false;
            this.toast('Error', 'You can only select up to 5 items for card view', 'error');
        } else {
            this.checklistItems[index].cardView = cardView;
        }
    }

    /* ================= DRAG AND DROP ================= */

    handleDragStart(event) {
        this.dragStartIndex = Number(event.currentTarget.dataset.index);
        event.currentTarget.classList.add('dragged');
        event.dataTransfer.effectAllowed = 'move';
        event.dataTransfer.dropEffect = 'move';
    }

    handleDragLeave(event) {
        const row = event.currentTarget;
        row.classList.remove('drop-over');
        if (this.scrollInterval) {
            clearInterval(this.scrollInterval);
            this.scrollInterval = null;
        }
    }

    handleDragOver(event) {
        event.preventDefault();
        const row = event.currentTarget;
        row.classList.add('drop-over');
    
        const container = this.template.querySelector('.tableContainer');
        if (!container) return;
    
        const bounding = container.getBoundingClientRect();
        const mouseY = event.clientY;
        const scrollMargin = 70; 
        const scrollSpeed = 20;
        const maxScroll = container.scrollHeight - container.clientHeight;
        const currentScroll = container.scrollTop;
    
        if (this.scrollInterval) {
            clearInterval(this.scrollInterval);
            this.scrollInterval = null;
        }
    
        if (mouseY < bounding.top + scrollMargin && currentScroll > 0) {
            this.scrollInterval = setInterval(() => {
                container.scrollTop = Math.max(0, container.scrollTop - scrollSpeed);
            }, 16);
        } else if (mouseY > bounding.bottom - scrollMargin && currentScroll < maxScroll) {
            this.scrollInterval = setInterval(() => {
                container.scrollTop = Math.min(maxScroll, container.scrollTop + scrollSpeed);
            }, 16);
        }
    }

    handleDrop(event) {
        event.preventDefault();
        const dragStartIndex = this.dragStartIndex;
        const dropIndex = Number(event.currentTarget.dataset.index);

        if (dragStartIndex === dropIndex) return;

        const items = [...this.checklistItems];
        const [draggedItem] = items.splice(dragStartIndex, 1);
        items.splice(dropIndex, 0, draggedItem);

        this.checklistItems = items;
        event.currentTarget.classList.remove('drop-over');
    }

    handleDragEnd(event) {
        this.template.querySelectorAll('.popup__data-row').forEach(row => {
            row.classList.remove('dragged', 'drop-over');
        });
        if (this.scrollInterval) {
            clearInterval(this.scrollInterval);
            this.scrollInterval = null;
        }
    }

    /* ================= SAVE LOGIC ================= */

    saveChecklistRecords() {
        try {
            // Validate
            for (let i = 0; i < this.checklistItems.length; i++) {
                if (!this.checklistItems[i].fieldName) {
                    this.toast('Error', `Please select field for row ${i+1}`, 'error');
                    return;
                }
            }
            
            // Duplicate Check
            const fieldNames = new Set();
            let errorFields = [];
            this.checklistItems.forEach(item => {
                if (fieldNames.has(item.fieldName)) {
                    errorFields.push(item.label);
                } else {
                    fieldNames.add(item.fieldName);
                }
            });
            
            if (errorFields.length > 0) {
                this.toast('Error', `Duplicate field name found: ${errorFields.join(', ')}`, 'error');
                return;
            }

            // Prepare Data
            const itemsToSave = this.checklistItems.map(item => ({
                fieldName: item.fieldName,
                fieldApiname: item.value,
                cardView: item.cardView,
                value: item.fieldName,
                label: item.label,
                fieldType: item.fieldType,
                format: item.format
            }));
            
            const checklistData = JSON.stringify(itemsToSave);
            
            this.isLoading = true;

            // Ensure pageSize is valid before saving
            const pageSizeToSave = this.pageSize || 30;

            saveMetadata({ 
                checklistData: checklistData, 
                totalPages: pageSizeToSave, 
                objectApiName: this.selectedTabObject, 
                featureName: this.featureName 
            })
            .then(() => {
                this.toast('Success', 'Configuration updated successfully', 'success');
                this.isLoading = false;
                this.handleDialogueClose(); // Close modal on success
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Save error', error);
                this.toast('Error', 'Error while updating settings', 'error');
            });

        } catch (error) {
            this.isLoading = false;
            console.error(error);
        }
    }

    toast(title, message, variant) {
        const toastEvent = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(toastEvent);
    }
}