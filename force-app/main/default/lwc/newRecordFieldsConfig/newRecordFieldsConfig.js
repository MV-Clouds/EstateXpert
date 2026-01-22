import { LightningElement, track, api } from 'lwc';
import getObjectFieldsWithMetaData from '@salesforce/apex/RecordManagersCmpController.getObjectFieldsWithMetaData';
import saveMappingsNewFields from '@salesforce/apex/RecordManagersCmpController.saveMappingsNewFields';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { loadStyle } from 'lightning/platformResourceLoader';
import { errorDebugger } from 'c/globalProperties';

export default class NewRecordFieldsConfig extends LightningElement {
    @api objectApiName;
    @track setScroll = false;
    @track fieldOptions = [];
    @track contactFieldsItems = [];
    @track filteredFieldOptions = [];
    @track isLoading = false;
    @track isForFocus = false;
    @track setIndex = 0;
    @track fieldOwnerName = 'Listing Fields'

    get isDataAvailable() {
        return this.contactFieldsItems && this.contactFieldsItems.length > 0;
    }

    /**
    * Method Name: connectedCallback
    * @description: Used to call getObjectFieldsAndName method.
    * Date: 09/07/2024
    * Created By: Karan Singh
    */
    connectedCallback() {
        loadStyle(this, MulishFontCss);
        this.fetchMetadata();
        this.fieldOwnerName = this.objectApiName == 'Contact' ? 'Contact Fields' : 'Listing Fields';
    }

    renderedCallback() {
        if (this.setScroll) {
            const container = this.template.querySelector('.tableContainer');
            container.scrollTop = container.scrollHeight;
            this.setScroll = false;
        } else if (this.isForFocus) {
            const inputElement = this.template.querySelector(`input[data-index="${this.setIndex}"]`);
            inputElement.focus();
            this.isForFocus = false;
        }
    }

    fetchMetadata() {
        this.isLoading = true;
        getObjectFieldsWithMetaData({ objectApiName: this.objectApiName })
            .then((result) => {
                this.fieldOptions = result.fieldDetailsList;
                if (result.metadataRecords.length > 0) {
                    const fieldsData = JSON.parse(result.metadataRecords[0]);

                    this.contactFieldsItems = fieldsData.map((item, index) => ({
                        id: index + 1,
                        isRequired: item.isRequired || false,
                        value: item.value,
                        searchValue : '',
                        label: item.label,
                        fieldType: item.fieldType
                    }));

                }

                this.isLoading = false;
                this.filteredFieldOptions = this.fieldOptions;
            })
            .catch((error) => {
                errorDebugger('NewRecordFieldsConfig', 'fetchMetadata', error, 'warn', 'Error in fetchMetadata');
            });
    }

    handleSearchChange(event) {
        try {
            const newValue = event.target.value;

            // Handle filtering or any other logic
            if (newValue) {
                this.filteredFieldOptions = this.filterFieldOptions(newValue);
            } else {
                this.filteredFieldOptions = [...this.fieldOptions]; // Reset to original options
            }
        } catch (e) {
            errorDebugger('NewRecordFieldsConfig', 'handleSearchChange', e, 'warn', 'Error in handleSearchChange');
        }
    }

    filterFieldOptions(searchText) {
        try {
            const searchValue = searchText.toLowerCase();
            return this.fieldOptions.filter(option =>
                option.label.toLowerCase().includes(searchValue)
            );
        } catch (e) {
            errorDebugger('NewRecordFieldsConfig', 'filterFieldOptions', e, 'warn', 'Error in filterFieldOptions');
        }
    }

    handleRequiredChange(event) {
        const index = parseInt(event.target.dataset.index, 10);
        const isRequired = event.target.checked;

        this.contactFieldsItems[index].isRequired = isRequired;
    }

    /**
    * Method Name: handleOrderChange
    * @description: Used to handle order change.
    * Date: 09/07/2024
    * Created By: Karan Singh
    */
    handleOrderChange(event) {
        try {
            const action = event.currentTarget.dataset.action;
            const index = parseInt(event.currentTarget.dataset.index, 10); // Get the index of the item to move
            if (action === 'up') {
                this.moveItemUp(index);
            } else if (action === 'down') {
                this.moveItemDown(index);
            }
        } catch (error) {
            errorDebugger('NewRecordFieldsConfig', 'handleOrderChange', error, 'warn', 'Error in handleOrderChange');
        }
    }

    /**
    * Method Name: moveItemUp
    * @description: Used to move item up.
    * Date: 09/07/2024
    * Created By: Karan Singh
    */
    moveItemUp(index) {
        if (index > 0) {
            const updatedItems = [...this.contactFieldsItems];
            [updatedItems[index - 1], updatedItems[index]] = [updatedItems[index], updatedItems[index - 1]]; // Swap items
            this.contactFieldsItems = updatedItems;
        }
    }

    /**
    * Method Name: moveItemDownP
    * @description: Used to move item down.
    * Date: 09/07/2024
    * Created By: Karan Singh
    */
    moveItemDown(index) {
        if (index < this.contactFieldsItems.length - 1) {
            const updatedItems = [...this.contactFieldsItems];
            [updatedItems[index], updatedItems[index + 1]] = [updatedItems[index + 1], updatedItems[index]]; // Swap items
            this.contactFieldsItems = updatedItems;
        }
    }

    /**
    * Method Name: handleDelete
    * @description: Used to handle delete.
    * Date: 09/07/2024
    * Created By: Karan Singh
    */
    handleDelete(event) {
        try {
            const index = parseInt(event.currentTarget.dataset.index, 10); // Ensure index is an integer
            const updatedItems = [...this.contactFieldsItems];
            updatedItems.splice(index, 1); // Remove the item at the specified index
            this.contactFieldsItems = updatedItems;
            // this.updateFieldOptionsIcons();
            this.filteredFieldOptions = this.fieldOptions;
        } catch (error) {
            errorDebugger('NewRecordFieldsConfig', 'handleDelete', error, 'warn', 'Error in handleDelete');
        }
    }

    /**
    * Method Name: addNewRow
    * @description: Used to add new row.
    * Date: 09/07/2024
    * Created By: Karan Singh
    */
    addNewRow() {
        try {
            const newItem = {
                Id: '',
                value: '',
                label: '',
                fieldType: '',
                isRequired: false
            };
            this.contactFieldsItems = [...this.contactFieldsItems, newItem];
            this.setScroll = true;
        } catch (error) {
            errorDebugger('NewRecordFieldsConfig', 'addNewRow', error, 'warn', 'Error in addNewRow');
        }
    }

    savecontactFieldsRecords() {
        try {
            for (let i = 0; i < this.contactFieldsItems.length; i++) {
                const item = this.contactFieldsItems[i];
                if (!item.value) {
                    this.toast('Error', `Please select field`, 'error');
                    return;
                }
            }

            const fieldNames = new Set();
            for (let i = 0; i < this.contactFieldsItems.length; i++) {
                const item = this.contactFieldsItems[i];
                if (fieldNames.has(item.value)) {
                    this.toast('Error', `Duplicate field name found: ${item.value}`, 'error');
                    return;
                }
                fieldNames.add(item.value);
            }

            // Create an array of objects representing the contactFields items
            const itemsToSave = this.contactFieldsItems.map(item => ({
                label: item.label,
                value: item.value,
                isRequired: item.isRequired,
                fieldType: item.fieldType
            }));

            // Convert the array into a JSON string
            const selectFieldsData = JSON.stringify(itemsToSave);
            const objectApiName = this.objectApiName;

            // Call the Apex method to save this JSON string to the metadata
            saveMappingsNewFields({ selectFieldsData, objectApiName })
                .then(() => {
                    this.toast('Success', 'Fields updated successfully', 'success');
                })
                .catch(error => {
                    errorDebugger('NewRecordFieldsConfig', 'savecontactFieldsRecords', error, 'warn', 'Error in savecontactFieldsRecords');
                    this.toast('Error', 'Error while updating Fields', 'error');
                });

        } catch (error) {
            errorDebugger('NewRecordFieldsConfig', 'savecontactFieldsRecords', error, 'warn', 'Error in savecontactFieldsRecords');
        }
    }


    /**
    * Method Name: toast
    * @description: Used to show toast.
    * @param {string} title - The title of the toast.
    * @param {string} message - The message of the toast.
    * @param {string} variant - The variant of the toast.
    * Date: 09/07/2024
    * Created By: Karan Singh
    */
    toast(title, message, variant) {
        const toastEvent = new ShowToastEvent({
            title,
            message,
            variant
        })
        this.dispatchEvent(toastEvent)
    }

    // Picklist field methods

    /**
    * Method Name: handleFocus1
    * @description: Handle the Focus event in picklist fiedls.
    * Date: 25/06/2024
    * Created By: Karan Singh
    */
    handleFocus1(event) {
        try {
            const index = event.currentTarget.dataset.index;
            this.setIndex = index;
            this.contactFieldsItems = this.contactFieldsItems.map((item, i) => {
                if (i === parseInt(index, 10)) {
                    return { ...item, isFocused: true };
                }
                return item;
            });
            this.isForFocus = true;
        } catch (error) {
            errorDebugger('NewRecordFieldsConfig', 'handleFocus1', error, 'warn', 'Error in handleFocus1');
        }
    }

    /**
   * Method Name: handleBlur1
   * @description: Handle the blur event in picklist fiedls.
   * Date: 25/06/2024
   * Created By: Karan Singh
   */
    handleBlur1(event) {
        try {
            const index = event.currentTarget.dataset.index;
            this.contactFieldsItems = this.contactFieldsItems.map((item, i) => {
                if (i === parseInt(index, 10)) {
                    return { ...item, isFocused: false };
                }
                return item;
            });
            this.filteredFieldOptions = [...this.fieldOptions];
        } catch (error) {
            errorDebugger('NewRecordFieldsConfig', 'handleBlur1', error, 'warn', 'Error in handleBlur1');
        }
    }

    /**
   * Method Name: handlePreventDefault
   * @description: prevent default events when the options div clicked.
   * Date: 23/07/2024
   * Created By: Karan Singh
   */
    handlePreventDefault(event) {
        event.preventDefault();
    }

    selectOption1(event) {
        try {
            const index = event.currentTarget.dataset.index;
            this.selectOption1Logic(event);
            setTimeout(() => {
                this.handleBlur(index);
            },0);
        } catch (e) {
            errorDebugger('NewRecordFieldsConfig', 'selectOption1', e, 'warn', 'Error in selectOption1');
        }
    }

    selectOption1Logic(event){
        const selectedOptionValue = event.currentTarget.dataset.id;
        const label = event.currentTarget.dataset.label;
        const index = event.currentTarget.dataset.index;
        const type = event.currentTarget.dataset.type;

        this.contactFieldsItems[index].value = selectedOptionValue;
        this.contactFieldsItems[index].label =label;
        this.contactFieldsItems[index].fieldType = type;
    }

    handleBlur(index) {
        try {
            this.contactFieldsItems = this.contactFieldsItems.map((item, i) => {
                if (i === parseInt(index, 10)) {
                    return { ...item, isFocused: false };
                }
                return item;
            });
            this.filteredFieldOptions = [...this.fieldOptions];
        } catch (error) {
            errorDebugger('NewRecordFieldsConfig', 'handleBlur', error, 'warn', 'Error in handleBlur');
        }
    }

}