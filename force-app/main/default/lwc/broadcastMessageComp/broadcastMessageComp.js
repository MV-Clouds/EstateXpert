import { LightningElement, api, track } from 'lwc';
import getObjectConfigs from '@salesforce/apex/BroadcastMessageController.getObjectConfigs';
import getListViewsForObject from '@salesforce/apex/BroadcastMessageController.getListViewsForObject';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import processBroadcastMessageWithObject from '@salesforce/apex/BroadcastMessageController.processBroadcastMessageWithObject';
import getBroadcastGroupDetails from '@salesforce/apex/BroadcastMessageController.getBroadcastGroupDetails';
import getSessionId from '@salesforce/apex/BroadcastMessageController.getSessionId';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { NavigationMixin } from 'lightning/navigation';

export default class BroadcastMessageComp extends NavigationMixin(LightningElement) {
    @api broadcastGroupId;
    @api communicationType;
    @track objectOptions = [];
    @track listViewOptions = [];
    @track selectedObject = '';
    @track selectedListView = '';
    @track data = [];
    @track filteredData = [];
    @track paginatedData = [];
    @track currentPage = 1;
    @track pageSize = 10;
    @track visiblePages = 5;
    @track isLoading = false;
    @track configMap = {};
    @track searchTerm = '';
    @track selectedRecords = new Set();
    @track isCreateBroadcastModalOpen = false;
    @track messageText = '';
    @track broadcastGroupName = '';
    @track isIntialRender = true;
    @track groupMembers = [];
    @track maxLimit = 30000;
    @track fetchedResults = [];
    @track sessionId;
    @track broadcastHeading = 'New Group';
    @track createBtnLabel = 'Save Group';
    @track showPhoneColumn = false;
    @track showEmailColumn = false;

    get dynamicFieldNames() {
        if (!this.selectedObject || !this.configMap[this.selectedObject]) {
            return [];
        }
        const fields = this.configMap[this.selectedObject];
        const fieldNames = [`${this.selectedObject}.${fields.nameField}`];
        if (this.communicationType === 'Email') {
            fieldNames.push(`${this.selectedObject}.${fields.emailField}`);
        } else if (this.communicationType === 'Phone' || this.communicationType === 'WhatsApp') {
            fieldNames.push(`${this.selectedObject}.${fields.phoneField}`);
        } else if (this.communicationType === 'Both') {
            fieldNames.push(`${this.selectedObject}.${fields.phoneField}`);
            if (fields.emailField) {
                fieldNames.push(`${this.selectedObject}.${fields.emailField}`);
            }
        }
        return fieldNames;
    }

    get isAllSelected() {
        return this.paginatedData.length > 0 && 
               this.paginatedData.every(record => this.selectedRecords.has(record.Id));
    }

    get isIndeterminate() {
        return this.paginatedData.some(record => this.selectedRecords.has(record.Id)) && 
               !this.isAllSelected;
    }

    get showNoRecordsMessage() {
        return this.paginatedData.length === 0;
    }

    get isSearchDisabled() {
        return !this.selectedObject || !this.selectedListView;
    }

    get isListViewDropdownDisabled() {
        return !this.selectedObject;
    }

    get isBtnDisabled() {
        return !this.paginatedData.length;
    }

    get totalItems() {
        return this.filteredData.length;
    }

    get totalPages() {
        return Math.ceil(this.totalItems / this.pageSize);
    }

    get pageNumbers() {
        try {
            const totalPages = this.totalPages;
            const currentPage = this.currentPage;
            const visiblePages = this.visiblePages;

            let pages = [];
            if (totalPages <= visiblePages) {
                for (let i = 1; i <= totalPages; i++) {
                    pages.push({
                        number: i,
                        isEllipsis: false,
                        className: `pagination-button ${i === currentPage ? 'active' : ''}`
                    });
                }
            } else {
                pages.push({
                    number: 1,
                    isEllipsis: false,
                    className: `pagination-button ${currentPage === 1 ? 'active' : ''}`
                });

                if (currentPage > 3) {
                    pages.push({ isEllipsis: true });
                }

                let start = Math.max(2, currentPage - 1);
                let end = Math.min(currentPage + 1, totalPages - 1);

                for (let i = start; i <= end; i++) {
                    pages.push({
                        number: i,
                        isEllipsis: false,
                        className: `pagination-button ${i === currentPage ? 'active' : ''}`
                    });
                }

                if (currentPage < totalPages - 2) {
                    pages.push({ isEllipsis: true });
                }

                pages.push({
                    number: totalPages,
                    isEllipsis: false,
                    className: `pagination-button ${currentPage === totalPages ? 'active' : ''}`
                });
            }
            return pages;
        } catch (error) {
            this.showToast('Error', 'Error in pageNumbers->' + error, 'error');
            return null;
        }
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === Math.ceil(this.totalItems / this.pageSize);
    }

    connectedCallback() {
        loadStyle(this, MulishFontCss);
        this.setColumnVisibility();
        this.loadConfigs();
        this.fetchGroupDetails();
    }

    setColumnVisibility() {
        if (this.communicationType === 'Email') {
            this.showEmailColumn = true;
            this.showPhoneColumn = false;
        } else if (this.communicationType === 'Phone' || this.communicationType === 'WhatsApp') {
            this.showPhoneColumn = true;
            this.showEmailColumn = false;
        } else if (this.communicationType === 'Both') {
            this.showPhoneColumn = true;
            this.showEmailColumn = this.configMap[this.selectedObject]?.emailField ? true : false;
        }
    }

    loadConfigs() {
        this.isLoading = true;
        getObjectConfigs()
            .then(result => {
                // Filter objects based on communicationType
                this.objectOptions = result.objectOptions.filter(option => {
                    const config = result.configMap[option.value];
                    if (!config) return false;
                    if (this.communicationType === 'Phone' || this.communicationType === 'WhatsApp') {
                        return config.phoneField && config.phoneField.trim() !== '';
                    } else if (this.communicationType === 'Email' || this.communicationType === 'Both') {
                        return config.emailField && config.emailField.trim() !== '';
                    }
                    return false;
                });
                this.configMap = result.configMap;
                // Update column visibility after loading configs
                this.setColumnVisibility();
            })
            .catch(() => {
                this.showToast('Error', 'Error loading configs', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    fetchGroupDetails() {
        // Only fetch group details if editing an existing group
        if (!this.broadcastGroupId) {
            getSessionId()
                .then(result => {
                    this.sessionId = result;
                })
                .catch(error => {
                    this.showToast('Error', 'Error fetching session ID - ' + (error.body.message || error.message), 'error');
                });
            return;
        }

        this.isLoading = true;
        getBroadcastGroupDetails({ groupId: this.broadcastGroupId })
            .then((result) => {
                this.broadcastHeading = 'Edit Group';
                this.createBtnLabel = 'Save Group';
                let groupData = result.group || {};
                this.selectedObject = groupData.MVEX__Object_Name__c || 'Contact';
                this.setColumnVisibility();
                this.loadListViews();
                this.selectedListView = groupData.MVEX__List_View__c || '';
                this.broadcastGroupName = groupData.Name;
                this.messageText = groupData.MVEX__Description__c;
                this.groupMembers = result.members || [];

                getSessionId()
                    .then(res => {
                        this.sessionId = res;
                        this.fetchAllListViewRecords(this.selectedListView, this.sessionId, this.maxLimit);
                    })
                    .catch(error => {
                        this.showToast('Error', 'Error fetching session ID - ' + (error.body.message || error.message), 'error');
                    });
            })
            .catch(() => {
                this.showToast('Error', 'Error fetching group details', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    updateShownData() {
        try {
            const startIndex = (this.currentPage - 1) * this.pageSize;
            const endIndex = Math.min(startIndex + this.pageSize, this.totalItems);
            this.paginatedData = this.filteredData.slice(startIndex, endIndex).map(record => ({
                ...record,
                isSelected: this.selectedRecords.has(record.Id)
            }));
            console.log('paginatedData', JSON.stringify(this.paginatedData));
            
        } catch (error) {
            this.showToast('Error', 'Error updating shown data', 'error');
        }
    }

    handlePrevious() {
        try {
            if (this.currentPage > 1) {
                this.currentPage--;
                this.updateShownData();
            }
        } catch (error) {
            this.showToast('Error', 'Error handling previous button click', 'error');
        }
    }

    handleNext() {
        try {
            if (this.currentPage < this.totalPages) {
                this.currentPage++;
                this.updateShownData();
            }
        } catch (error) {
            this.showToast('Error', 'Error handling next button click', 'error');
        }
    }

    handlePageChange(event) {
        try {
            const selectedPage = parseInt(event.target.getAttribute('data-id'), 10);
            if (selectedPage !== this.currentPage) {
                this.currentPage = selectedPage;
                this.updateShownData();
            }
        } catch (error) {
            this.showToast('Error', 'Error handling page change', 'error');
        }
    }

    handleBack() {
        this.cleardata();
        this.navigateToAllGroup();
    }

    cleardata() {
        this.selectedObject = '';
        this.selectedListView = '';
        this.data = [];
        this.filteredData = [];
        this.paginatedData = [];
        this.currentPage = 1;
        this.selectedRecords.clear();
        this.broadcastGroupName = '';
        this.messageText = '';
        this.isCreateBroadcastModalOpen = false;
        this.groupMembers = [];
        this.isIntialRender = true;
    }

    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
        const term = this.searchTerm.trim();
        this.filteredData = this.data.filter(item => {
            const name = item.name?.toLowerCase() || '';
            const phone = item.phone?.toLowerCase() || '';
            const email = item.email?.toLowerCase() || '';
            return !term || name.includes(term) || phone.includes(term) || email.includes(term);
        });
        this.currentPage = 1;
        this.updateShownData();
    }

    handleInputChange(event) {
        const { name, value } = event.target;
        switch(name) {
            case 'name':
                this.broadcastGroupName = value;
                break;
            case 'message':
                this.messageText = value;
                break;
            default:
                this.showToast('Error', `Unhandled input change for name: ${name}`, 'error');
                break;
        }
    }

    handleObjectChange(event) {
        this.selectedObject = event.detail.value;
        this.selectedListView = '';
        this.data = [];
        this.filteredData = [];
        this.paginatedData = [];
        this.currentPage = 1;
        this.selectedRecords.clear();
        this.setColumnVisibility();
        this.loadListViews();
    }

    loadListViews() {
        this.isLoading = true;
        getListViewsForObject({ objectApiName: this.selectedObject })
            .then(result => {
                this.listViewOptions = result.map(lv => ({
                    label: lv.Name,
                    value: lv.Id
                }));
            })
            .catch(() => {
                this.showToast('Error', 'Error loading list views', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleListViewChange(event) {
        this.selectedListView = event.detail.value;
        this.fetchAllListViewRecords(this.selectedListView, this.sessionId, this.maxLimit);
    }

    async fetchListViewSOQL(listViewId, sessionId) {
        const myHeaders = {
            "Authorization": "Bearer " + sessionId,
            "Content-Type": "application/json"
        };

        const requestOptions = {
            method: "GET",
            headers: myHeaders,
            redirect: "follow"
        };

        let domainURL = location.origin.replace('lightning.force.com', 'my.salesforce.com');
        let queryURL = '/services/data/v58.0/sobjects/' + this.selectedObject + '/listviews/' + this.selectedListView + '/describe';

        const response = await fetch(domainURL + queryURL, requestOptions);
        const result = await response.json();

        if (response.status === 200) {
            const fields = this.configMap[this.selectedObject];
            let fieldsString = `Id, ${fields.nameField}, ${fields.phoneField}`;
            if ((this.communicationType === 'Email' || this.communicationType === 'Both') && fields.emailField) {
                fieldsString += `, ${fields.emailField}`;
            }

            let originalQuery = result.query;
            let modifiedQuery = originalQuery.replace(/SELECT(.*?)FROM/i, `SELECT ${fieldsString} FROM`);
            return modifiedQuery;
        }

        throw new Error("No query found for the specified ListView ID.");
    }

    fetchAllListViewRecords(listViewId, sessionId, maxLimit) {
        this.fetchListViewSOQL(listViewId, sessionId)
            .then(query => {
                if (!query) {
                    return;
                }
                const soqlQueryUrl = `/services/data/v59.0/query?q=${encodeURIComponent(query)}`;
                this.fetchRecords(soqlQueryUrl, sessionId, maxLimit);
            });
    }

    fetchRecords(queryUrl, sessionId, maxLimit) {
        const domainURL = location.origin.replace('lightning.force.com', 'my.salesforce.com');

        const headers = {
            "Authorization": "Bearer " + sessionId,
            "Content-Type": "application/json"
        };

        const requestOptions = {
            method: "GET",
            headers: headers,
            redirect: "follow"
        };

        return fetch(domainURL + queryUrl, requestOptions)
            .then(response => response.json())
            .then(result => {
                if (!this.selectedObject || !this.selectedListView) {
                    return;
                }

                if (result) {
                    const fields = this.configMap[this.selectedObject];
                    this.data = result.records.map((record, index) => {
                        let recordData = {
                            index: index + 1,
                            Id: record.Id,
                            name: record[fields.nameField] ? record[fields.nameField] : '',
                            phone: record[fields.phoneField] ? record[fields.phoneField] : '',
                            isSelected: false
                        };
                        if ((this.communicationType === 'Email' || this.communicationType === 'Both') && fields.emailField) {
                            recordData.email = record[fields.emailField] ? record[fields.emailField] : '';
                        }
                        return recordData;
                    });

                    this.filteredData = [...this.data];
                    this.currentPage = 1;

                    if (this.isIntialRender && this.broadcastGroupId && this.groupMembers.length > 0) {
                        this.isIntialRender = false;
                        const memberIds = new Set(this.groupMembers.map(member => member.MVEX__Member_Record_Id__c));
                        this.data.forEach(record => {
                            if (memberIds.has(record.Id)) {
                                record.isSelected = true;
                                this.selectedRecords.add(record.Id);
                            }
                        });
                        this.filteredData = [...this.data];
                    } else {
                        this.selectedRecords.clear();
                    }
                    this.updateShownData();

                    if (result.records && Array.isArray(result.records)) {
                        this.fetchedResults = maxLimit ? result.records.slice(0, maxLimit) : result.records;
                        return true;
                    } else {
                        this.showToast('warning', 'No Records', 'No records were found.');
                        return false;
                    }
                }
            })
            .catch(() => {
                this.showToast('error', 'Error', 'Failed to retrieve records');
                return false;
            });
    }

    handleRecordSelection(event) {
        const recordId = event.target.dataset.recordid;
        const record = this.paginatedData.find(row => row.Id === recordId);
        if (record) {
            record.isSelected = event.target.checked;
            if (record.isSelected) {
                this.selectedRecords.add(recordId);
            } else {
                this.selectedRecords.delete(recordId);
            }
            this.selectedRecords = new Set(this.selectedRecords);
        }
    }

    handleSelectAll(event) {
        const isChecked = event.target.checked;
        this.paginatedData.forEach(record => {
            record.isSelected = isChecked;
            if (isChecked) {
                this.selectedRecords.add(record.Id);
            } else {
                this.selectedRecords.delete(record.Id);
            }
        });
        this.selectedRecords = new Set(this.selectedRecords);
    }

    handleModalOpen() {
        if (this.selectedRecords.size === 0) {
            this.showToast('Error', 'Please select at least one record', 'error');
            return;
        }

        if (this.communicationType === 'Email') {
            if (Array.from(this.selectedRecords).some(recordId => {
                const record = this.data.find(r => r.Id === recordId);
                return !record || !record.email || record.email.trim() === '';
            })) {
                this.showToast('Error', 'One or more selected records have invalid or missing email addresses', 'error');
                return;
            }
        } else if (this.communicationType === 'Phone' || this.communicationType === 'WhatsApp') {
            if (Array.from(this.selectedRecords).some(recordId => {
                const record = this.data.find(r => r.Id === recordId);
                return !record || !record.phone || record.phone.trim() === '';
            })) {
                this.showToast('Error', 'One or more selected records have invalid or missing phone numbers', 'error');
                return;
            }
        } else if (this.communicationType === 'Both') {
            if (Array.from(this.selectedRecords).some(recordId => {
                const record = this.data.find(r => r.Id === recordId);
                return !record || !record.phone || record.phone.trim() === '' || 
                       (!record.email || record.email.trim() === '');
            })) {
                this.showToast('Error', 'One or more selected records have invalid or missing phone numbers or email addresses', 'error');
                return;
            }
        }

        this.isCreateBroadcastModalOpen = true;
    }

    closePopUp() {
        this.isCreateBroadcastModalOpen = false;
        this.broadcastGroupName = '';
        this.messageText = '';
    }

    handleSave() {
        if (this.messageText.trim() === '' || this.broadcastGroupName.trim() === '') {
            this.showToast('Error', 'Please fill in all required fields', 'error');
            return;
        }

        const recipients = Array.from(this.selectedRecords).map(recordId => {
            const record = this.data.find(r => r.Id === recordId);
            if (!record) return null;
            if (this.communicationType === 'WhatsApp' || this.communicationType === 'Phone') {
                return { Id: record.Id, phone: record.phone };
            } else if (this.communicationType === 'Email') {
                return { Id: record.Id, email: record.email };
            } else if (this.communicationType === 'Both') {
                return { Id: record.Id, phone: record.phone, email: record.email };
            }
            return null;
        }).filter(r => r !== null);

        const isUpdate = this.broadcastGroupId != null;
        const fields = this.configMap[this.selectedObject];
        const messageData = {
            objectApiName: this.selectedObject,
            listViewName: this.selectedListView,
            recipients: recipients,
            description: this.messageText,
            name: this.broadcastGroupName,
            isUpdate: isUpdate,
            broadcastGroupId: this.broadcastGroupId,
            phoneField: fields.phoneField,
            emailField: fields.emailField || '',
            communicationType: this.communicationType
        };

        this.isLoading = true;
        processBroadcastMessageWithObject({ requestJson: JSON.stringify(messageData) })
            .then(() => {
                this.showToast('Success', 'Group is saved successfully', 'success');
                this.closePopUp();
                this.selectedRecords.clear();
                this.updateShownData();
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || 'Failed to save group', 'error');
            })
            .finally(() => {
                this.isLoading = false;
                this.navigateToAllGroup();
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }

    navigateToAllGroup() {
        let componentDef = {
            componentDef: "c:wbAllBroadcastGroupPage"
        };
        let encodedComponentDef = btoa(JSON.stringify(componentDef));
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/one/one.app#' + encodedComponentDef
            }
        });
    }
}