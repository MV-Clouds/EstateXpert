import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getCheckList from '@salesforce/apex/CheckListItemController.getCheckList';
import createCheckListItem from '@salesforce/apex/CheckListItemController.createCheckListItem';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { errorDebugger } from 'c/globalProperties';

export default class CheckListStatus extends LightningElement {
    @track checklistItems = []; // Initialize as an empty array
    @track originChecklistItems = [];
    @track showEditModal = false;
    @track objectName;
    @track recordId;
    @track isSpinner = true;
    @track screenWidth = 0;
    @track checklistEditable = false;

    @wire(CurrentPageReference)
    setCurrentPageReference(pageRef) {
        this.objectName = pageRef.attributes.objectApiName;
        this.recordId = pageRef.attributes.recordId;
    }

    /**
    * Method Name: isDataAvailable
    * @description: Used to check if data is available.
    * Date: 09/07/2024
    * Created By: Karan Singh
    */
    get isDataAvailable() {
        return this.checklistItems && this.checklistItems.length > 0;
    }

    /**
    * Method Name: totalCount
    * @description: Used to get total count.
    * Date: 09/07/2024
    * Created By: Karan Singh
    */
    get totalCount() {
        return this.checklistItems.length;
    }

    /**
    * Method Name: completedCount
    * @description: Used to get completed count.
    * Date: 09/07/2024
    * Created By: Karan Singh
    */
    get completedCount() {
        return this.checklistItems.filter(item => item.completed).length;
    }

    /**
    * Method Name: progressStyle
    * @description: Used to get progress style.
    * Date: 09/07/2024
    * Created By: Karan Singh
    */
    get progressStyle() {
        const percentage = (this.completedCount / this.totalCount) * 100;
        return `width: ${percentage}%;`;
    }

    /**
    * Method Name: connectedCallback
    * @description: Used to call checklistValues method.
    * Created Date: 09/07/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    connectedCallback() {
        try {
            loadStyle(this, MulishFontCss);
            this.screenWidth = window?.globalThis?.innerWidth;
            window?.globalThis?.addEventListener("resize", this.handleResize);
            this.checklistValues();
        } catch (error) {
            errorDebugger('CheckListStatus', 'connectedCallback', error, 'warn', 'Error while loading css and fetching data');
        }
    }

    /**
    * Method Name: checklistValues
    * @description: Used to get checklist values.
    * Created Date: 09/07/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    checklistValues() {
        try {
            this.isSpinner = true;
            getCheckList({ objectName: this.objectName, recordId: this.recordId })
                .then(result => {
                    this.checklistItems = JSON.parse(JSON.stringify(result?.checklistData));
                    this.originChecklistItems = JSON.parse(JSON.stringify(result?.checklistData));
                    this.checklistEditable = result.isEditable;
                    this.updateChecklistItems();
                })
                .catch(error => {
                    this.isSpinner = false;
                    errorDebugger('CheckListStatus', 'getCheckList:checklistValues', error, 'warn', 'Error while fetching checklist values');
                });
        } catch (error) {
            errorDebugger('CheckListStatus', 'checklistValues', error, 'warn', 'Error while fetching checklist values');
            this.isSpinner = false;
        }
    }

    /**
    * Method Name: handleCheckboxChange
    * @description: Used to handle checkbox change.
    * Created Date: 09/07/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    handleCheckboxChange(event) {
        try {
            const itemId = event.currentTarget.dataset.id;
            const checkboxValue = event.currentTarget.checked;
            const fieldName = event.currentTarget.dataset.fieldname;
            this.checklistItems = this.checklistItems.map(item => {
                if (item.id === itemId) {
                    item.completed = checkboxValue;
                }
                return item;
            });
            if (fieldName == null || fieldName == '' || fieldName == undefined) {
                this.createOrUpdateChecklistItem(itemId, checkboxValue);
            }
            this.updateChecklistItems();
        } catch (error) {
            errorDebugger('CheckListStatus', 'handleCheckboxChange', error, 'warn', 'Error while handling checkbox change');
        }
    }

    /**
    * Method Name: handleDropdownClick
    * @description: Used to handle dropdown click.
    * Created Date: 09/07/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    handleDropdownClick(event) {
        try {
            const itemId = event.target.dataset.id;
            this.checklistItems = this.checklistItems.map(item => {
                if (item.id === itemId) {
                    item.showDropdown = !item.showDropdown;
                }
                return item;
            });
            this.updateChecklistItems();
        } catch (error) {
            errorDebugger('CheckListStatus', 'handleDropdownClick', error, 'warn', 'Error while handling dropdown click');
        }
    }

    /**
    * Method Name: updateChecklistItems
    * @description: Used to update checklist items.
    * Created Date: 09/07/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    updateChecklistItems() {
        try {
            this.checklistItems = this.checklistItems.map(item => {
                item.statusClass = item.completed ? 'status1 completed' : 'status2 pending';
                item.statusText = item.completed ? 'Completed' : 'Pending';
                item.dropdownIcon = item.showDropdown ? '▲' : '▼';
                return item;
            });
            this.isSpinner = false;
        } catch (error) {
            errorDebugger('CheckListStatus', 'updateChecklistItems', error, 'warn', 'Error while updating checklist items');
            this.isSpinner = false;
        }
    }

    /**
    * Method Name: handleHideEditPopup
    * @description: Used to handle hide edit popup.
    * Created Date: 09/07/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    handleHideEditPopup(event) {
        try {
            this.showEditModal = event.details;
            this.addMainDiv();
        } catch (error) {
            errorDebugger('CheckListStatus', 'handleHideEditPopup', error, 'warn', 'Error while hiding edit popup');
        }
    }

    /**
    * Method Name: handleShowEditModal
    * @description: Used to handle show edit modal.
    * Created Date: 09/07/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    handleShowEditModal() {
        try {
            this.showEditModal = true;
            this.hideMainDiv();
        } catch (error) {
            errorDebugger('CheckListStatus', 'handleShowEditModal', error, 'warn', 'Error while showing edit modal');
        }
    }

    /**
    * Method Name: createOrUpdateChecklistItem
    * @description: Used to create or update checklist item.
    * Created Date: 09/07/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    createOrUpdateChecklistItem(itemId, checkboxValue) {
        try {
            createCheckListItem({ recordId: this.recordId, checklistId: itemId, completed: checkboxValue })
                .then(result => {
                    if (result == 'success') {
                        this.toast('Success', 'Checklist Item Updated successfully', 'success');
                    } else {
                        this.toast('Error', result, 'error');
                    }
                })
                .catch(error => {
                    errorDebugger('CheckListStatus', 'createOrUpdateChecklistItem', error, 'warn', 'Error while creating or updating checklist item');
                });
        } catch (error) {
            errorDebugger('CheckListStatus', 'createOrUpdateChecklistItem', error, 'warn', 'Error while creating or updating checklist item');
        }
    }

    /**
    * Method Name: handleHideEditPopupAndRefresh
    * @description: Used to handle hide edit popup and refresh.
    * Created Date: 09/07/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    handleHideEditPopupAndRefresh(event) {
        try {
            this.showEditModal = event.details;
            this.addMainDiv();
            const inputElement = this.template.querySelector('.search_Input');
            if (inputElement) {
                inputElement.value = '';
            }
            this.checklistItems = [];
            this.checklistValues();
        } catch (error) {
            errorDebugger('CheckListStatus', 'handleHideEditPopupAndRefresh', error, 'warn', 'Error while hiding edit popup and refreshing');
        }
    }

    /**
    * Method Name: toast
    * @description: Used to show toast.
    * @param {string} title - The title of the toast.
    * @param {string} message - The message of the toast.
    * @param {string} variant - The variant of the toast.
    * Created Date: 09/07/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    toast(title, message, variant) {
        try {
            if (!import.meta.env.SSR) {
                const toastEvent = new ShowToastEvent({
                    title,
                    message,
                    variant
                })
                this.dispatchEvent(toastEvent);
            }
        } catch (error) {
            errorDebugger('CheckListStatus', 'toast', error, 'warn', 'Error while showing toast');
        }
    }

    /**
    * Method Name: refreshTable
    * @description: Used to refresh table.
    * Created Date: 15/07/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    refreshTable() {
        try {
            const inputElement = this.template.querySelector('.search_Input');
            if (inputElement) {
                inputElement.value = '';
            }
            this.checklistItems = [];
            this.checklistValues();
        } catch (error) {
            errorDebugger('CheckListStatus', 'refreshTable', error, 'warn', 'Error while refreshing table');
        }
    }

    /**
    * Method Name: hideMainDiv
    * @description: Used to hide main div.
    * Created Date: 15/07/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    hideMainDiv() {
        try {
            if (this.screenWidth <= 1050 && this.isDataAvailable) {
                this.template.querySelector('.data_container').classList.add("removeMain");
                this.template.querySelector('.container').classList.add("adddiv");
            }
        } catch (error) {
            errorDebugger('CheckListStatus', 'hideMainDiv', error, 'warn', 'Error while hiding main div');
        }
    }

    /**
    * Method Name: addMainDiv
    * @description: Used to add main div.
    * Created Date: 15/07/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    addMainDiv() {
        try {
            if (this.screenWidth <= 1050 && this.isDataAvailable) {
                this.template.querySelector('.data_container').classList.remove("removeMain");
                this.template.querySelector('.container').classList.remove("adddiv");
            }
        } catch (error) {
            errorDebugger('CheckListStatus', 'addMainDiv', error, 'warn', 'Error while adding main div');
        }
    }

    /**
    * Method Name: handleResize
    * @description: Used to handle resize.
    * Created Date: 15/07/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    handleResize = () => {
        this.screenWidth = window?.globalThis?.innerWidth;
    }

    /**
    * Method Name: disconnectedCallback
    * @description: Used to disconnect callback.
    * Created Date: 15/07/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    disconnectedCallback() {
        try {
            window?.globalThis?.removeEventListener('resize', this.handleResize);
        } catch (error) {
            errorDebugger('CheckListStatus', 'disconnectedCallback', error, 'warn', 'Error while disconnecting callback');
        }
    }

    /**
    * Method Name: handleSearch
    * @description: Used to handle search.
    * Created Date: 15/07/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    handleSearch(event) {
        try {
            const searchTerm = event.target.value.toLowerCase();

            this.checklistItems = this.originChecklistItems.filter(template =>
                template.name && template.name.toLowerCase().includes(searchTerm)
            );

            this.updateChecklistItems();
        } catch (error) {
            errorDebugger('CheckListStatus', 'handleSearch', error, 'warn', 'Error while handling search');
        }
    }
}