import { LightningElement, track, api } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import getAllJSONData from '@salesforce/apex/WhatsAppFlowControllerV2.getAllJSONData';
import saveWhatsAppFlow from '@salesforce/apex/WhatsAppFlowControllerV2.saveWhatsAppFlow';
import publishWhatsAppFlow from '@salesforce/apex/WhatsAppFlowControllerV2.publishWhatsAppFlow';
import getFlowById from '@salesforce/apex/WhatsAppFlowControllerV2.getFlowByIdWithScreens';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const MAX_FLOW_NAME_LENGTH = 150;

export default class WbCreateFlowManagement extends LightningElement {
    
    @api isEditMode = false;
    @api isCloneFlow = false;
    @api selectedFlowId = null;
    @api cloneFlowName = '';
    
    // @track only needed for arrays/objects that are mutated
    @track selectedCategories = [];
    @track templateTypeOptions = [];
    @track jsonDataMap = {};
    
    selectedCategory = '';
    templateType = 'Default';
    flowName = '';
    isLoading = false;
    jsonString = '';
    showFlowBuilder = false;
    selectedScreenId = null;
    hasUnsavedChanges = false;
    flowRecordId = null;
    metaFlowId = null;
    isFlowSaved = false;
    parentFlowId = null;
    isParentFlow = false;
    initialJsonString = '';

    get typeOptions() {
        return [
            { label: 'Sign up', value: 'SIGN_UP' },
            { label: 'Sign in', value: 'SIGN_IN' },
            { label: 'Appointment booking', value: 'APPOINTMENT_BOOKING' },
            { label: 'Lead generation', value: 'LEAD_GENERATION' },
            { label: 'Shopping', value: 'SHOPPING' },
            { label: 'Contact us', value: 'CONTACT_US' },
            { label: 'Customer support', value: 'CUSTOMER_SUPPORT' },
            { label: 'Survey', value: 'SURVEY' },
            { label: 'Other', value: 'OTHER' }
        ];
    }

    get hasSelectedCategories() {
        return Array.isArray(this.selectedCategories) && this.selectedCategories.length > 0;
    }

    get isCreateDisabled() {
        return (this.flowName.trim() == '') || (this.selectedCategories.length == 0 || (this.selectedCategories.length == 1 && this.selectedCategories[0] == ''));
    }
    
    get headerNameLengthError(){
        return this.flowName.length > MAX_FLOW_NAME_LENGTH;
    }
    
    get maxFlowNameLength(){
        return MAX_FLOW_NAME_LENGTH;
    }

    get isSaveDisabled() {
        return !this.hasUnsavedChanges || this.isLoading;
    }

    get isPublishDisabled() {
        return !this.isFlowSaved || this.hasUnsavedChanges || this.isLoading;
    }

    get saveButtonClass() {
        return `save-button ${this.isSaveDisabled ? 'disabled' : ''}`;
    }

    get publishButtonClass() {
        return `publish-button ${this.isPublishDisabled ? 'disabled' : ''}`;
    }

    /**
     * Method : connectedCallback
     * @description : Initializes component and loads all JSON data.
     */
    connectedCallback(){
        loadStyle(this, MulishFontCss)
            .then(() => {
                console.log('External Css Loaded');
            })
            .catch(error => {
                console.log('Error occuring during loading external css', error);
            });
        // Load existing flow data if in edit mode
        
        if (this.isEditMode && this.selectedFlowId) {
            this.loadExistingFlowData();
        } else if (this.isCloneFlow && this.cloneFlowName) {
            this.flowName = this.cloneFlowName;
        } else{
            this.loadAllJSONData();
        }
        
    }

    /**
    * Method : loadAllJSONData
    * @description  : Loads all JSON data from Apex once during initialization.
    */
    loadAllJSONData() {
        this.isLoading = true;

        getAllJSONData()
        .then(data => {
            if (data) {
                // Process JSON to convert inline read more screens
                const processedData = {};
                Object.keys(data).forEach(key => {
                    processedData[key] = this.processReadMoreScreens(data[key]);
                });
                this.jsonDataMap = processedData;
                this.buildTemplateTypeOptions();
                this.setJSONForTemplateType();
            } else {
                console.error('No JSON data received');
            }
        })
        .catch(error => {
            console.error('Error loading all JSON data:', error);
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    /**
    * Method : loadExistingFlowData
    * @description  : Loads existing flow data when in edit mode.
    */
    async loadExistingFlowData() {
        this.isLoading = true;
        try {
            
            const resultString = await getFlowById({ flowId: this.selectedFlowId });
            const result = JSON.parse(resultString);
            
            if (result && result.success) {
                const flowData = result.data;
                
                // Set flow details
                this.flowName = flowData.MVEX__Flow_Name__c || '';
                this.flowRecordId = flowData.Id;
                this.metaFlowId = flowData.MVEX__Flow_Id__c;
                this.parentFlowId = flowData.MVEX__Parent_Flow__c || null;
                this.isParentFlow = result.isParentFlow || false;
                this.templateType = flowData.MVEX__Template_Type__c || 'Default';
                
                // Set categories
                if (flowData.MVEX__Category__c) {
                    this.selectedCategories = flowData.MVEX__Category__c.split(';');
                }
                
                // Set flow JSON
                if (flowData.MVEX__Flow_JSON__c) {
                    // Process read more screens to ensure proper ID prefixes and ordering
                    this.jsonString = this.processReadMoreScreens(flowData.MVEX__Flow_JSON__c);
                    this.initialJsonString = this.jsonString;
                    this.isFlowSaved = true;
                    
                    // Automatically show the flow builder
                    this.showFlowBuilder = true;
                    
                    // Parse JSON to select first screen
                    try {
                        const parsedJson = JSON.parse(this.jsonString);
                        if (parsedJson.screens && parsedJson.screens.length > 0) {
                            const firstMainScreen = parsedJson.screens.find(s => !s.id || !s.id.startsWith('READ_MORE_'));
                            this.selectedScreenId = firstMainScreen ? firstMainScreen.id : parsedJson.screens[0].id;
                        }
                    } catch (parseError) {
                        console.error('Error parsing flow JSON:', parseError);
                    }
                }
                
            } else {
                this.showToast('Error', result.message || 'Failed to load flow data', 'error');
            }
        } catch (error) {
            console.error('Error loading existing flow:', error);
            this.showToast('Error', 'Failed to load flow data: ' + (error.body?.message || error.message), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Method : handleInputChange
     * @description : Updates flow name from input field.
     */
    handleInputChange(event){
        try {
            this.flowName = event.target.value;  
        } catch (error) {
            console.error('Error in handleInputChange : ' , error);
        }
    }

    /**
    * Method : handleCategories
    * @description  : Handles category selection
    */
    handleCategories(event) {
        try {
            const selectedValue = event.detail.value;
            const selectedLabel = this.typeOptions.find(opt => opt.value === selectedValue)?.label;

            if (selectedLabel && !this.selectedCategories.includes(selectedValue)) {
                this.selectedCategories = [...this.selectedCategories, selectedValue];
            }
        } catch (error) {
            console.error('Error in handleCategories : ' , error);
        }
    }

    /**
    * Method : handleRemoveCategory
    * @description  : Removes selected category
    */
    handleRemoveCategory(event) {
        const nameToRemove = event.detail.name;
        this.selectedCategories = this.selectedCategories.filter(item => item !== nameToRemove);
        this.selectedCategory = '';
    }

    /**
     * Method : handleDiscard
     * @description : Navigates back to previous page.
     */
    handleDiscard() {
        // Dispatch event to parent component to navigate back
        this.dispatchEvent(new CustomEvent('previous', {
            bubbles: true,
            composed: true
        }));
    }

    /**
     * Method : handleTypeChange
     * @description : Updates template type selection and sets corresponding JSON.
     */
    handleTypeChange(event) {
        this.templateType = event.target.value;
        this.setJSONForTemplateType();
    }
  
    /**
     * Method : handleCreate
     * @description : Creates flow in Meta first, then shows the flow builder screen.
     */
    async handleCreate(){
        // Process read more screens before creating (migration and cleanup)
        this.jsonString = this.processReadMoreScreens(this.jsonString);
        
        this.isLoading = true;
        
        try {
            // Create flow in Meta first
            const result = await saveWhatsAppFlow({
                flowName: this.flowName,
                categories: this.selectedCategories,
                flowJson: this.jsonString,
                templateType: this.templateType,
                flowRecordId: null,
                metaFlowId: null
            });
            
            const response = JSON.parse(result);
            
            if (response.success) {
                // Store the created flow IDs
                this.flowRecordId = response.flowRecordId;
                this.metaFlowId = response.metaFlowId;
                this.initialJsonString = this.jsonString;
                this.isFlowSaved = true;
                
                // Show the flow builder
                this.showFlowBuilder = true;
                
                // Initialize selectedScreenId with first screen (skip READ_MORE_ screens)
                try {
                    if (this.jsonString) {
                        const parsed = JSON.parse(this.jsonString);
                        if (parsed.screens && parsed.screens.length > 0) {
                            // Find first non-read-more screen
                            const firstMainScreen = parsed.screens.find(s => !s.id.startsWith('READ_MORE_'));
                            this.selectedScreenId = firstMainScreen ? firstMainScreen.id : parsed.screens[0].id;
                        }
                    }
                } catch (error) {
                    console.error('Error initializing selectedScreenId:', error);
                }
                
                this.showToast('Success', 'Flow created successfully in Meta', 'success');
            } else {
                // Handle Meta API error
                this.handleMetaError(response);
            }
        } catch (error) {
            console.error('Error creating flow:', error);
            this.handleMetaError({ message: error.body?.message || 'Failed to create flow in Meta' });
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Method : handleBackToForm
     * @description : Returns to all flows page.
     */
    handleBackToForm(){
        // Always go back to all flows page
        this.dispatchEvent(new CustomEvent('previous', {
            bubbles: true,
            composed: true
        }));
    }

    /**
     * Method : processReadMoreScreens
     * @description : Migrates old nested readMoreScreens to flat structure and cleans invalid properties
     * Also ensures read more screens have proper ID prefix (READ_MORE_) and proper ordering
     */
    processReadMoreScreens(jsonString) {
        try {
            if (!jsonString) return jsonString;
            
            const jsonData = JSON.parse(jsonString);
            if (!jsonData.screens || jsonData.screens.length === 0) return jsonString;

            // Remove any readMoreScreens array at root level (not allowed in WhatsApp Flow)
            delete jsonData.readMoreScreens;

            // First pass: Build parent-child relationships (parent screen ID -> read more screen IDs)
            const parentToReadMore = new Map(); // parent screen id -> [read more screen ids]
            jsonData.screens.forEach(screen => {
                if (screen.layout && screen.layout.children) {
                    screen.layout.children.forEach(layoutChild => {
                        if (layoutChild.type === 'Form' && layoutChild.children) {
                            layoutChild.children.forEach(formChild => {
                                if (formChild.type === 'OptIn' && formChild['on-click-action']?.name === 'navigate') {
                                    const targetScreenId = formChild['on-click-action']?.next?.name;
                                    if (targetScreenId && targetScreenId !== '__back__') {
                                        if (!parentToReadMore.has(screen.id)) {
                                            parentToReadMore.set(screen.id, []);
                                        }
                                        parentToReadMore.get(screen.id).push(targetScreenId);
                                    }
                                }
                            });
                        }
                    });
                }
            });

            // Get all read more screen IDs
            const readMoreScreenIds = new Set();
            parentToReadMore.forEach(children => {
                children.forEach(childId => readMoreScreenIds.add(childId));
            });

            // Second pass: Rename read more screens to have READ_MORE_ prefix if needed
            const screenIdMapping = new Map(); // old ID -> new ID
            jsonData.screens.forEach(screen => {
                if (readMoreScreenIds.has(screen.id) && !screen.id.startsWith('READ_MORE_')) {
                    const newId = `READ_MORE_${this.sanitizeScreenId(screen.id)}`;
                    screenIdMapping.set(screen.id, newId);
                    screen.id = newId;
                }
            });

            // Third pass: Update all on-click-action references to use new IDs
            jsonData.screens.forEach(screen => {
                if (screen.layout && screen.layout.children) {
                    screen.layout.children.forEach(layoutChild => {
                        if (layoutChild.type === 'Form' && layoutChild.children) {
                            layoutChild.children.forEach(formChild => {
                                if (formChild.type === 'OptIn' && formChild['on-click-action']?.next?.name) {
                                    const oldId = formChild['on-click-action'].next.name;
                                    if (screenIdMapping.has(oldId)) {
                                        formChild['on-click-action'].next.name = screenIdMapping.get(oldId);
                                    }
                                }
                            });
                        }
                    });
                }
            });

            // Update parentToReadMore map with new IDs
            const updatedParentToReadMore = new Map();
            parentToReadMore.forEach((children, parentId) => {
                const newParentId = screenIdMapping.get(parentId) || parentId;
                const newChildren = children.map(childId => screenIdMapping.get(childId) || childId);
                updatedParentToReadMore.set(newParentId, newChildren);
            });

            // Fourth pass: Process legacy nested readMoreScreens
            jsonData.screens.forEach(screen => {
                if (screen.readMoreScreens && Array.isArray(screen.readMoreScreens) && screen.readMoreScreens.length > 0) {
                    screen.readMoreScreens.forEach(readMoreScreen => {
                        // Ensure read more screen has proper ID prefix
                        if (!readMoreScreen.id.startsWith('READ_MORE_')) {
                            readMoreScreen.id = `READ_MORE_${this.sanitizeScreenId(readMoreScreen.id)}`;
                        }
                        
                        // Add to parent's read more list
                        if (!updatedParentToReadMore.has(screen.id)) {
                            updatedParentToReadMore.set(screen.id, []);
                        }
                        updatedParentToReadMore.get(screen.id).push(readMoreScreen.id);
                        
                        // Add to screens array if not already present
                        if (!jsonData.screens.find(s => s.id === readMoreScreen.id)) {
                            jsonData.screens.push(readMoreScreen);
                        }
                    });
                    
                    // Update parent screen's OptIn sections to use on-click-action
                    if (screen.layout && screen.layout.children) {
                        screen.layout.children.forEach(layoutChild => {
                            if (layoutChild.type === 'Form' && layoutChild.children) {
                                layoutChild.children.forEach(formChild => {
                                    if (formChild.type === 'OptIn' && formChild.hasReadMoreScreen && formChild.readMoreScreenData) {
                                        const readMoreScreenId = formChild.readMoreScreenData.id;
                                        const properReadMoreId = readMoreScreenId.startsWith('READ_MORE_') 
                                            ? readMoreScreenId 
                                            : `READ_MORE_${this.sanitizeScreenId(readMoreScreenId)}`;
                                        
                                        formChild['on-click-action'] = {
                                            name: 'navigate',
                                            payload: {},
                                            next: {
                                                name: properReadMoreId,
                                                type: 'screen'
                                            }
                                        };
                                    }
                                });
                            }
                        });
                    }
                    
                    // Remove the nested readMoreScreens array
                    delete screen.readMoreScreens;
                }
            });

            // Fifth pass: Reorder screens so read-more screens appear after their parent
            const orderedScreens = [];
            const processedScreenIds = new Set();
            const readMoreScreensSet = new Set();
            
            // Collect all read more screen IDs
            updatedParentToReadMore.forEach(children => {
                children.forEach(childId => readMoreScreensSet.add(childId));
            });
            
            jsonData.screens.forEach(screen => {
                // Skip if already processed or if it's a read-more screen (will be added after parent)
                if (processedScreenIds.has(screen.id) || readMoreScreensSet.has(screen.id)) {
                    return;
                }
                
                // Add main screen
                orderedScreens.push(screen);
                processedScreenIds.add(screen.id);
                
                // Add its read-more screens immediately after
                const readMoreIds = updatedParentToReadMore.get(screen.id) || [];
                readMoreIds.forEach(readMoreId => {
                    const readMoreScreen = jsonData.screens.find(s => s.id === readMoreId);
                    if (readMoreScreen && !processedScreenIds.has(readMoreId)) {
                        orderedScreens.push(readMoreScreen);
                        processedScreenIds.add(readMoreId);
                    }
                });
            });

            // Update with reordered screens
            jsonData.screens = orderedScreens;

            // Clean all screens - remove internal tracking properties
            jsonData.screens = jsonData.screens.map(screen => {
                const cleanScreen = { ...screen };
                
                // Keep only valid WhatsApp Flow screen properties
                const validScreenProps = ['id', 'title', 'data', 'terminal', 'success', 'layout'];
                Object.keys(cleanScreen).forEach(key => {
                    if (!validScreenProps.includes(key)) {
                        delete cleanScreen[key];
                    }
                });

                // Clean layout children recursively
                if (cleanScreen.layout && cleanScreen.layout.children) {
                    cleanScreen.layout.children = this.cleanLayoutChildren(cleanScreen.layout.children);
                }
                
                return cleanScreen;
            });

            return JSON.stringify(jsonData, null, 2);
        } catch (error) {
            console.error('Error processing read more screens:', error);
            return jsonString;
        }
    }

    /**
     * Method : cleanLayoutChildren
     * @description : Recursively clean layout children to remove invalid properties
     */
    cleanLayoutChildren(children) {
        if (!Array.isArray(children)) return children;
        
        return children.map(child => {
            const cleanChild = { ...child };
            
            // Remove internal tracking properties (not allowed in WhatsApp Flow)
            delete cleanChild.hasReadMoreScreen;
            delete cleanChild.readMoreScreenData;
            delete cleanChild.isReadMoreScreen;
            delete cleanChild.parentSectionId;
            delete cleanChild.readMoreScreens;
            
            // Recursively clean nested children
            if (cleanChild.children && Array.isArray(cleanChild.children)) {
                cleanChild.children = this.cleanLayoutChildren(cleanChild.children);
            }
            
            return cleanChild;
        });
    }


    /**
    * Method : buildTemplateTypeOptions
    * @description  : Builds template type options dynamically from metadata keys.
    */
    buildTemplateTypeOptions(){
        try {
            if(this.jsonDataMap){
                this.templateTypeOptions = Object.keys(this.jsonDataMap).map(key => ({
                    label: key,
                    value: key,
                    checked: this.templateType === key
                }));
            }
        } catch (error) {
            console.error('Error building template type options:', error);
        }
    }

    /**
    * Method : setJSONForTemplateType
    * @description  : Sets the JSON string based on current template type from cached data.
    */
    setJSONForTemplateType(){
        try {
            if(this.jsonDataMap && this.jsonDataMap[this.templateType]){
                this.jsonString = this.jsonDataMap[this.templateType];
            } else {
                console.error('No JSON data found for template type:', this.templateType);
            }
        } catch (error) {
            console.error('Error setting JSON for template type:', error);
        }
    }

    /**
     * Method : updateJSON
     * @description : Reusable method to update JSON structure with screens data.
     * @param {Array} screens - Array of screen objects to be included in JSON
     */
    updateJSON(screens) {
        try {
            let parsedJson;
            
            // Parse existing JSON or create new structure
            if (this.jsonString) {
                parsedJson = JSON.parse(this.jsonString);
            } else {
                parsedJson = {};
            }


            // Filter out isEditing, order, and success fields from screens
            const cleanedScreens = (screens || []).map(screen => {
                const { isEditing, order, success, ...cleanScreen } = screen;
                return cleanScreen;
            });

            // Update screens array with cleaned data
            parsedJson.screens = cleanedScreens;

            // Convert back to string
            this.jsonString = JSON.stringify(parsedJson, null, 2);
            
            // Track changes for save button
            this.checkForChanges();
        } catch (error) {
            console.error('🔴 Error updating JSON:', error);
        }
    }

    /**
     * Method : checkForChanges
     * @description : Checks if JSON has changed from initial state
     */
    checkForChanges() {
        if (this.initialJsonString) {
            this.hasUnsavedChanges = this.jsonString !== this.initialJsonString;
        }
    }

    /**
     * Method : handleSaveFlow
     * @description : Updates the flow in Meta and Salesforce
     */
    async handleSaveFlow() {
        if (this.isSaveDisabled) return;
                
        this.isLoading = true;
        
        try {
            // Update existing flow
            const result = await saveWhatsAppFlow({
                flowName: this.flowName,
                categories: this.selectedCategories,
                flowJson: this.jsonString,
                templateType: this.templateType,
                flowRecordId: this.flowRecordId,
                metaFlowId: this.metaFlowId
            });

            const response = JSON.parse(result);
            
            if (response.success) {
                this.flowRecordId = response.flowRecordId;
                this.metaFlowId = response.metaFlowId;
                this.initialJsonString = this.jsonString;
                this.hasUnsavedChanges = false;
                this.isFlowSaved = true;
                
                this.showToast('Success', 'Flow updated successfully', 'success');
            } else {
                this.handleMetaError(response);
            }
        } catch (error) {
            console.error('Error saving flow:', error);
            this.handleMetaError({ message: error.body?.message || 'Failed to save flow' });
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Method : handlePublishFlow
     * @description : Publishes the flow to Meta
     */
    async handlePublishFlow() {
        if (this.isPublishDisabled) return;
        
        this.isLoading = true;
        
        try {
            const result = await publishWhatsAppFlow({
                metaFlowId: this.metaFlowId,
                flowRecordId: this.flowRecordId
            });
            
            const response = JSON.parse(result);
            
            if (response.success) {
                this.showToast('Success', 'Flow published successfully', 'success');
            } else {
                this.handleMetaError(response);
            }
        } catch (error) {
            console.error('Error publishing flow:', error);
            this.handleMetaError({ message: error.body?.message || 'Failed to publish flow' });
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Method : handleScreenAdded
     * @description : Handles the addscreen event from child component
     */
    handleScreenAdded(event) {
        try {
            const { screenId, title, order, defaultSection } = event.detail;
            
            let parsedJson = this.jsonString ? JSON.parse(this.jsonString) : {};
            let screens = parsedJson.screens || [];

            // Build layout children array with default section if provided
            const layoutChildren = [];
            
            if (defaultSection) {
                // Build Form element with default section
                const formChildren = [];
                
                // Generate sanitized name for default section
                const defaultSectionName = this.sanitizeScreenId(defaultSection.label);

                // Convert defaultSection to WhatsApp Flow JSON format
                const element = {
                    type: defaultSection.type,
                    name: defaultSectionName,
                    label: defaultSection.label,
                    required: defaultSection.isRequired || false,
                    'input-type': defaultSection.inputType || 'text'
                };
                
                // Add optional fields if they exist
                if (defaultSection.placeholder) element.placeholder = defaultSection.placeholder;
                if (defaultSection.helpText) element['helper-text'] = defaultSection.helpText;
                if (defaultSection.minLength) element['min-length'] = defaultSection.minLength;
                if (defaultSection.maxLength) element['max-length'] = defaultSection.maxLength;
                
                formChildren.push(element);
                
                // Add Form to layout children
                layoutChildren.push({
                    type: 'Form',
                    name: 'flow_form',
                    children: formChildren
                });
            }
            
            // Add Footer element to new screens (even if no default section)
            if (layoutChildren.length === 0) {
                // If no default section, create a Form with just Footer
                layoutChildren.push({
                    type: 'Form',
                    name: 'flow_form',
                    children: [
                        {
                            type: 'Footer',
                            label: 'Continue',
                            'on-click-action': {
                                name: 'complete',
                                payload: {}
                            }
                        }
                    ]
                });
            } else {
                // If there's a Form with default section, add Footer to it
                const form = layoutChildren.find(child => child.type === 'Form');
                if (form && !form.children.find(child => child.type === 'Footer')) {
                    form.children.push({
                        type: 'Footer',
                        label: 'Continue',
                        'on-click-action': {
                            name: 'complete',
                            payload: {}
                        }
                    });
                }
            }

            const newScreen = {
                id: this.sanitizeScreenId(screenId),
                title: title,
                terminal: false,
                data: {},
                layout: {
                    type: "SingleColumnLayout",
                    children: layoutChildren
                },
                order: order || 0
            };

            // Insert screen at the correct position based on order
            screens.splice(order || 0, 0, newScreen);
            
            // Update terminal property: only last screen should be terminal
            this.updateTerminalProperty(screens);
            
            // Update navigation chain - ensure each screen points to the next one
            this.updateNavigationChain(screens);
            
            // Set as selected screen
            this.selectedScreenId = screenId;
            
            // Exit read more mode when adding a new screen
            setTimeout(() => {
                const screenEditor = this.template.querySelector('c-wb-flow-screen-editor');
                if (screenEditor) {
                    screenEditor.setReadMoreMode(false);
                }
            }, 50);
            
            this.updateJSON(screens);
        } catch (error) {
            console.error('🔴 Error handling screen added:', error);
        }
    }

    /**
     * Method : handleScreenDeleted
     * @description : Handles the deletescreen event from child component
     * Also deletes associated read more screens when deleting a parent screen
     */
    handleScreenDeleted(event) {
        try {
            const { screenId } = event.detail;
            
            let parsedJson = this.jsonString ? JSON.parse(this.jsonString) : {};
            let screens = parsedJson.screens || [];

            // If deleting a parent screen, also collect IDs of its read more screens to delete
            const screenToDelete = screens.find(s => s.id === screenId);
            const screensToDelete = [screenId];
            
            // Only collect read more screens if we're deleting a parent (non-read-more) screen
            if (screenToDelete && (!screenToDelete.id || !screenToDelete.id.startsWith('READ_MORE_'))) {
                // Find sections in this screen that might have read more screens
                if (screenToDelete.layout && screenToDelete.layout.children) {
                    screenToDelete.layout.children.forEach(layoutChild => {
                        if (layoutChild.type === 'Form' && layoutChild.children) {
                            layoutChild.children.forEach(formChild => {
                                // Check if this section has a read more screen
                                if (formChild.type === 'OptIn' && formChild['on-click-action']) {
                                    const readMoreScreenId = formChild['on-click-action'].next?.name ||
                                                            formChild['on-click-action'].payload?.screen;
                                    if (readMoreScreenId && readMoreScreenId.startsWith('READ_MORE_')) {
                                        screensToDelete.push(readMoreScreenId);
                                    }
                                }
                            });
                        }
                    });
                }
            }

            // Remove screen and its read more screens from array
            screens = screens.filter(screen => !screensToDelete.includes(screen.id));
            
            // Update terminal property: only last screen should be terminal
            this.updateTerminalProperty(screens);
            
            this.updateJSON(screens);

        } catch (error) {
            console.error('Error handling screen deleted:', error);
        }
    }

    /**
     * Method : handleScreenSelected
     * @description : Handles the screenselect event from child component
     */
    handleScreenSelected(event) {
        try {
            const { screenId } = event.detail;
            this.selectedScreenId = screenId;
            
            // Update screen navigation component
            const screenNavigation = this.template.querySelector('c-wb-flow-screen-navigation');
            if (screenNavigation) {
                screenNavigation.selectedScreenId = screenId;
            }
            
            // Check if selected screen is a read more screen
            const parsedJson = this.jsonString ? JSON.parse(this.jsonString) : {};
            const screens = parsedJson.screens || [];
            
            // Determine if this is a read more screen (by checking screen ID pattern)            
            const isReadMoreScreen = screenId.startsWith('READ_MORE_');
            
            // Set read more mode on screen editor
            setTimeout(() => {
                const screenEditor = this.template.querySelector('c-wb-flow-screen-editor');
                if (screenEditor) {
                    screenEditor.setReadMoreMode(isReadMoreScreen);
                }
            }, 0);
            
        } catch (error) {
            console.error('Error handling screen selected:', error.stack);
        }
    }

    /**
     * Method : handleEditReadMore
     * @description : Handles the editreadmore event to create/edit a read more screen
     * Creates read more screens in main screens array (not nested) as per WhatsApp Flow spec
     */
    handleEditReadMore(event) {
        try {
            const { sectionId, shouldNavigate } = event.detail;
            
            let parsedJson = this.jsonString ? JSON.parse(this.jsonString) : {};
            let screens = parsedJson.screens || [];
            
            // Find the parent screen by searching for the section
            let parentScreen = null;
            let parentScreenIndex = -1;
            let optInSection = null;
            for (let i = 0; i < screens.length; i++) {
                const screen = screens[i];
                if (screen.layout && screen.layout.children) {
                    for (const child of screen.layout.children) {
                        if (child.type === 'Form' && child.children) {
                            const foundSection = child.children.find(s => s.name === sectionId);
                            if (foundSection) {
                                parentScreen = screen;
                                parentScreenIndex = i;
                                optInSection = foundSection;
                                break;
                            }
                        }
                    }
                }
                if (parentScreen) break;
            }
            
            if (!parentScreen) {
                console.error('Parent screen not found for section:', sectionId);
                return;
            }
            
            // Generate read more screen ID
            const readMoreScreenId = this.sanitizeScreenId(`READ_MORE_${sectionId}`);
            
            // Check if read more screen already exists:
            let readMoreScreen = screens.find(s => s.id === readMoreScreenId);
            
            // If not found by ID, check if the section has on-click-action pointing to another screen
            if (!readMoreScreen && optInSection && optInSection['on-click-action']) {
                const existingScreenRef = optInSection['on-click-action'].next?.name || 
                                         optInSection['on-click-action'].payload?.screen;
                if (existingScreenRef) {
                    readMoreScreen = screens.find(s => s.id === existingScreenRef);
                    // If we found it, rename it to proper ID for consistency
                    if (readMoreScreen && readMoreScreen.id !== readMoreScreenId) {
                        const oldId = readMoreScreen.id;
                        readMoreScreen.id = readMoreScreenId;
                        
                        // Update any references to the old ID in navigation
                        screens.forEach(scr => {
                            if (scr.layout && scr.layout.children) {
                                scr.layout.children.forEach(layoutChild => {
                                    if (layoutChild.type === 'Form' && layoutChild.children) {
                                        layoutChild.children.forEach(formChild => {
                                            if (formChild['on-click-action'] && 
                                                (formChild['on-click-action'].next?.name === oldId || 
                                                 formChild['on-click-action'].payload?.screen === oldId)) {
                                                if (formChild['on-click-action'].next) {
                                                    formChild['on-click-action'].next.name = readMoreScreenId;
                                                }
                                                if (formChild['on-click-action'].payload) {
                                                    formChild['on-click-action'].payload.screen = readMoreScreenId;
                                                }
                                            }
                                        });
                                    }
                                });
                            }
                        });
                    }
                }
            }
            
            if (!readMoreScreen) {
                // Get first available text type from metadata (dynamic)
                const screenEditor = this.template.querySelector('c-wb-flow-screen-editor');
                let defaultTextType = 'TextHeading';  // Fallback
                
                if (screenEditor && screenEditor.flowElementTypes && screenEditor.flowElementTypes.Text) {
                    const textTypes = screenEditor.flowElementTypes.Text;
                    if (textTypes && textTypes.length > 0) {
                        const firstTextType = textTypes[0];
                        if (firstTextType.jsonType) {
                            defaultTextType = firstTextType.jsonType;
                        }
                    }
                }
                
                // Create default text element for read more screen
                const defaultTextElement = {
                    type: defaultTextType,
                    text: 'Read more content'
                };
                
                // Create new read more screen in main array
                readMoreScreen = {
                    id: readMoreScreenId,
                    title: 'Read more',
                    data: {},
                    layout: {
                        type: "SingleColumnLayout",
                        children: [
                            {
                                type: 'Form',
                                name: 'read_more_form',
                                children: [defaultTextElement]
                            }
                        ]
                    }
                };
                
                // Insert read more screen right after parent screen
                screens.splice(parentScreenIndex + 1, 0, readMoreScreen);
            }
            
            // Update the OptIn section to have on-click-action
            if (parentScreen.layout && parentScreen.layout.children) {
                for (const child of parentScreen.layout.children) {
                    if (child.type === 'Form' && child.children) {
                        const section = child.children.find(s => s.name === sectionId);
                        if (section) {
                            // Add on-click-action for navigation to read more screen
                            section['on-click-action'] = {
                                name: 'navigate',
                                payload: {},
                                next: {
                                    name: readMoreScreenId,
                                    type: 'screen'
                                }
                            };
                            break;
                        }
                    }
                }
            }
            
            // Update JSON
            this.updateJSON(screens);
            
            // Only navigate to read more screen if shouldNavigate is true (Edit content click)
            if (shouldNavigate) {
                // Navigate to the read more screen
                this.selectedScreenId = readMoreScreen.id;
                
                // Update screen navigation component to highlight the read more screen
                setTimeout(() => {
                    const screenNavigation = this.template.querySelector('c-wb-flow-screen-navigation');
                    if (screenNavigation) {
                        screenNavigation.selectedScreenId = readMoreScreen.id;
                    }
                    
                    // Set read more mode on screen editor
                    const screenEditor = this.template.querySelector('c-wb-flow-screen-editor');
                    if (screenEditor) {
                        screenEditor.setReadMoreMode(true);
                    }
                }, 50);
            }
            
        } catch (error) {
            console.error('Error handling edit read more:', error.stack);
        }
    }

    /**
     * Method : handleDeleteReadMore
     * @description : Handles the deletereadmore event to remove a read more screen
     * Removes from main screens array and removes on-click-action from OptIn
     */
    handleDeleteReadMore(event) {
        try {
            const { sectionId } = event.detail;
            
            let parsedJson = this.jsonString ? JSON.parse(this.jsonString) : {};
            let screens = parsedJson.screens || [];
            
            // Find the parent screen by searching for the section
            let parentScreen = null;
            for (const screen of screens) {
                if (screen.layout && screen.layout.children) {
                    for (const child of screen.layout.children) {
                        if (child.type === 'Form' && child.children) {
                            if (child.children.some(s => s.name === sectionId)) {
                                parentScreen = screen;
                                break;
                            }
                        }
                    }
                }
                if (parentScreen) break;
            }
            
            if (!parentScreen) {
                console.error('Parent screen not found for section:', sectionId);
                return;
            }
            
            // Generate read more screen ID
            const readMoreScreenId = this.sanitizeScreenId(`READ_MORE_${sectionId}`);
            
            // Remove read more screen from main screens array
            screens = screens.filter(s => s.id !== readMoreScreenId);
            
            // Remove on-click-action from the OptIn section
            if (parentScreen.layout && parentScreen.layout.children) {
                for (const child of parentScreen.layout.children) {
                    if (child.type === 'Form' && child.children) {
                        const section = child.children.find(s => s.name === sectionId);
                        if (section && section['on-click-action']) {
                            delete section['on-click-action'];
                            break;
                        }
                    }
                }
            }
            
            // Update JSON
            this.updateJSON(screens);
            
        } catch (error) {
            console.error('Error handling delete read more:', error);
        }
    }

    /**
     * Method : handleScreenReordered
     * @description : Handles the reorderscreen event from child component
     */
    handleScreenReordered(event) {
        try {
            const { screens } = event.detail;
            
            // Parse current JSON
            let parsedJson = this.jsonString ? JSON.parse(this.jsonString) : {};
            let currentScreens = parsedJson.screens || [];

            // Create a map for quick lookup
            const screenMap = new Map(currentScreens.map(s => [s.id, s]));

            // Reorder screens based on the new order
            const reorderedScreens = screens.map(({ id, order }) => {
                const screen = screenMap.get(id);
                if (screen) {
                    return { ...screen, order };
                }
                return null;
            }).filter(s => s !== null);

            // Update navigation chain before updating terminal property
            this.updateNavigationChain(reorderedScreens);
            
            // Update terminal property after reordering
            this.updateTerminalProperty(reorderedScreens);
            
            // Update JSON with new order
            this.updateJSON(reorderedScreens);
            
            // Mark preview component that this is a reorder operation
            const previewComponent = this.template.querySelector('c-wb-flow-preview');
            if (previewComponent) {
                previewComponent.markAsReorderOperation();
            }
        } catch (error) {
            console.error('🔴 Error handling screen reordered:', error);
        }
    }

    /**
     * Method : updateTerminalProperty
     * @description : Updates terminal property - only last screen should be terminal: true
     */
    updateTerminalProperty(screens) {
        try {
            if (screens && screens.length > 0) {
                screens.forEach((screen, index) => {
                    // Only the last screen should be terminal
                    screen.terminal = (index === screens.length - 1);
                });
            }
        } catch (error) {
            console.error('Error updating terminal property:', error);
        }
    }

    /**
     * Method : updateNavigationChain
     * @description : Updates navigation chain for all screens to ensure proper flow
     */
    updateNavigationChain(screens) {
        try {
            // Filter out read more screens from main navigation
            // Read more screens have IDs starting with 'READ_MORE_'
            const regularScreens = screens.filter(s => {
                return !s.id || !s.id.startsWith('READ_MORE_');
            });

            regularScreens.forEach((screen, index) => {
                // Find the Form in the screen's layout
                const form = screen.layout?.children?.find(child => child.type === 'Form');
                if (form) {
                    // Find the Footer in the Form's children
                    const footer = form.children?.find(child => child.type === 'Footer');
                    if (footer && footer['on-click-action']) {
                        const isLastScreen = index === regularScreens.length - 1;
                        
                        if (isLastScreen) {
                            // Last screen should complete (keep payload, just remove next)
                            footer['on-click-action'].name = 'complete';
                            delete footer['on-click-action'].next;
                        } else {
                            // Other screens should navigate to next regular screen only
                            const nextScreen = regularScreens[index + 1];
                            if (nextScreen && nextScreen.id) {
                                footer['on-click-action'].name = 'navigate';
                                footer['on-click-action'].next = {
                                    name: nextScreen.id,
                                    type: 'screen'
                                };
                            }
                        }
                    }
                }
            });
        } catch (error) {
            console.error('Error updating navigation chain:', error);
        }
    }

    handleInputBlur(){
        this.flowName = this.flowName.trim();
    }

    /**
     * Method : handleShowError
     * @description : Handles the showerror event from child components
     */
    handleShowError(event) {
        const { title, message, variant } = event.detail;
        this.showToast(title, message, variant);
    }

    /**
     * Helper Method : sanitizeScreenId
     * @description : Ensures screen ID only contains alphabets and underscores
     */
    sanitizeScreenId(screenId) {
        if (!screenId) return screenId;
        
        // Replace all non-alphanumeric characters (except underscores) with underscores
        let sanitized = screenId.replace(/[^a-zA-Z0-9_]/g, '_');
        
        // Ensure it doesn't start with a number
        if (/^[0-9]/.test(sanitized)) {
            sanitized = 'screen_' + sanitized;
        }
        
        return sanitized;
    }

    /**
     * Helper Method : parseMetadata
     * @description : Parse metadata Options__c JSON string
     */
    parseMetadata(optionsString) {
        try {
            return optionsString ? JSON.parse(optionsString) : null;
        } catch (error) {
            console.error('Error parsing metadata:', error);
            return null;
        }
    }

    /**
     * Helper Method : buildWhatsAppJsonElement
     * @description : Build WhatsApp Flow JSON element from section data and metadata config
     */
    buildWhatsAppJsonElement(section, metadataConfig) {
        if (!section || !metadataConfig) return null;

        const { jsonType, defaults } = metadataConfig;
        const element = {
            type: jsonType
        };

        // Add 'name' only for input elements that require it
        const inputElements = ['TextInput', 'TextArea', 'RadioButtonsGroup', 'CheckboxGroup', 'Dropdown', 'DatePicker', 'OptIn'];
        if (inputElements.includes(jsonType)) {
            element.name = section.name || section.id || this.generateUniqueId('SECTION_');
        }

        // Handle different element types
        switch (jsonType) {
            case 'TextHeading':
            case 'TextSubheading':
            case 'TextBody':
            case 'TextCaption':
                element.text = section.value || defaults?.text || '';
                break;

            case 'TextInput':
                element.label = section.value || defaults?.label || '';
                element.required = section.required !== undefined ? section.required : (defaults?.required || false);
                element['input-type'] = section.inputType || defaults?.inputType || 'text';
                if (section.helperText) element['helper-text'] = section.helperText;
                break;

            case 'TextArea':
                element.label = section.value || defaults?.label || '';
                element.required = section.required !== undefined ? section.required : (defaults?.required || false);
                if (section.helperText) element['helper-text'] = section.helperText;
                break;

            case 'RadioButtonsGroup':
            case 'CheckboxGroup':
                element.label = section.value || defaults?.label || '';
                element.required = section.required !== undefined ? section.required : (defaults?.required || false);
                element['data-source'] = (section.options || []).map(opt => ({
                    id: opt.id,
                    title: opt.label
                }));
                break;

            case 'Dropdown':
                element.label = section.value || defaults?.label || '';
                element.required = section.required !== undefined ? section.required : (defaults?.required || false);
                element['data-source'] = (section.options || []).map(opt => ({
                    id: opt.id,
                    title: opt.label
                }));
                break;

            case 'DatePicker':
                element.label = section.value || defaults?.label || '';
                element.required = section.required !== undefined ? section.required : (defaults?.required || false);
                if (section.helperText) element['helper-text'] = section.helperText;
                break;

            case 'OptIn':
                element.label = section.value || defaults?.label || '';
                element.required = section.required !== undefined ? section.required : (defaults?.required || true);
                break;

            case 'Image':
                // Use imageUrl (AWS public URL) if available, otherwise fall back to imageSrc
                element.src = section.imageUrl || section.imageSrc || defaults?.src || '';
                // Store awsKey for proper deletion support in edit mode
                if (section.awsKey) element.awsKey = section.awsKey;
                if (section.altText) element['alt-text'] = section.altText;
                if (section.scaleType) element['scale-type'] = section.scaleType;
                element.height = section.height || 200;  // Add height to JSON output
                break;

            default:
                console.warn('Unknown jsonType:', jsonType);
        }

        return element;
    }

    /**
     * Method : handleContentUpdate
     * @description : Handles the contentupdate event from flowScreenEditor component (via flowContentEditor)
     */
    handleContentUpdate(event) {
        try {
            // Store current selected screen to preserve it after JSON update
            const currentSelectedScreen = this.selectedScreenId;
            const { screenId, screenTitle, buttonLabel, sections, metadataMap } = event.detail;
            
            if (!screenId) {
                console.warn('⚠️ No screenId provided in content update');
                return;
            }

            // Parse current JSON
            let parsedJson = this.jsonString ? JSON.parse(this.jsonString) : {};
            let screens = parsedJson.screens || [];

            // Find the screen in main screens array (read more screens are now in main array)
            let screenIndex = screens.findIndex(s => s.id === screenId);
            let targetScreen = null;
            
            if (screenIndex !== -1) {
                targetScreen = screens[screenIndex];
            }
            
            if (!targetScreen) {
                console.warn('⚠️ Screen not found:', screenId);
                return;
            }

            // Determine if this is a read more screen (by checking screen ID pattern)
            const isReadMoreScreen = screenId.startsWith('READ_MORE_');

            // Update screen title
            if (screenTitle !== undefined) {
                targetScreen.title = screenTitle;
            }

            // Build WhatsApp Flow JSON structure from sections
            if (sections) {
                // Build Form children from sections using metadata
                const formChildren = [];
                const inputFields = []; // Track input fields for payload generation
                
                sections.forEach((section, index) => {
                    
                    // Get metadata config for this section
                    const metadata = metadataMap?.[section.itemName];
                    const config = metadata ? this.parseMetadata(metadata) : null;
                    
                    if (config) {
                        const element = this.buildWhatsAppJsonElement(section, config);
                        if (element) {
                            formChildren.push(element);
                            
                            // Track input fields for payload and data schema
                            if (this.isInputField(config.jsonType)) {
                                inputFields.push({
                                    name: element.name,
                                    type: this.getFieldDataType(config.jsonType, section.inputType),
                                    screenIndex: screenIndex
                                });
                            }
                            
                        }
                    }
                });

                const isTerminal = isReadMoreScreen ? false : (screenIndex === screens.length - 1);
                const nextScreenId = (!isTerminal && !isReadMoreScreen) ? screens[screenIndex + 1]?.id : null;

                // Build Footer payload - only for regular screens, not read more screens
                const footerPayload = isReadMoreScreen ? {} : this.buildFooterPayload(screenIndex, inputFields, screens);

                // Add Footer element as last child of Form
                // Read more screens should NOT have a footer - user uses back button in header
                if (buttonLabel && !isReadMoreScreen) {
                    const footerAction = {
                        type: 'Footer',
                        label: buttonLabel,
                        'on-click-action': {
                            name: isTerminal ? 'complete' : 'navigate',
                            payload: footerPayload
                        }
                    };

                    // Add next screen reference for navigation
                    if (!isTerminal && nextScreenId) {
                        footerAction['on-click-action'].next = {
                            name: nextScreenId,
                            type: 'screen'
                        };
                    }

                    formChildren.push(footerAction);
                }

                // Build complete layout structure with Form containing all elements + Footer
                const layoutChildren = [];
                
                // Add Form element with all sections + Footer
                if (formChildren.length > 0) {
                    layoutChildren.push({
                        type: 'Form',
                        name: isReadMoreScreen ? 'read_more_form' : 'flow_path',
                        children: formChildren
                    });
                }

                // Update screen layout
                if (!targetScreen.layout) {
                    targetScreen.layout = {
                        type: 'SingleColumnLayout',
                        children: []
                    };
                }

                targetScreen.layout.children = layoutChildren;

                // Build data schema - only for regular screens
                if (!isReadMoreScreen) {
                    targetScreen.data = this.buildDataSchema(screenIndex, screens);
                    
                    // Rebuild data schemas and Footer payloads for all subsequent screens
                    // They reference this screen's fields, so indices may have changed
                    for (let i = screenIndex + 1; i < screens.length; i++) {
                        const subsequentScreen = screens[i];
                        // Skip read more screens
                        if (subsequentScreen && subsequentScreen.id && !subsequentScreen.id.startsWith('READ_MORE_')) {
                            // Rebuild data schema
                            subsequentScreen.data = this.buildDataSchema(i, screens);
                            
                            // Rebuild Footer payload
                            this.rebuildScreenFooter(subsequentScreen, i, screens);
                        }
                    }
                } else {
                    // Read more screens don't need data schema
                    targetScreen.data = {};
                }
                
            }

            // Update JSON string
            this.updateJSON(screens);
            
            // Preserve the selected screen after JSON update (if it still exists)
            // This prevents the preview from jumping to the first screen during edits
            if (currentSelectedScreen) {
                // All screens are now in main array, so just check there
                const screenStillExists = screens.some(s => s.id === currentSelectedScreen);
                
                if (screenStillExists) {
                    this.selectedScreenId = currentSelectedScreen;
                }
            }
                        
        } catch (error) {
            console.error('🔴 Error handling content update:', error);
        }
    }

    /**
     * Helper Method : isInputField
     * @description : Check if a field type requires user input
     */
    isInputField(jsonType) {
        const inputTypes = ['TextInput', 'TextArea', 'RadioButtonsGroup', 'CheckboxGroup', 'Dropdown', 'DatePicker', 'OptIn'];
        return inputTypes.includes(jsonType);
    }

    generateUniqueId(baseName, uniquifier = '') {
        // Sanitize base name: remove numbers and non-alphabetic chars except underscores
        let sanitized = baseName.replace(/[^a-zA-Z_]/g, '_');
        
        // Remove consecutive underscores and trim
        sanitized = sanitized.replace(/_+/g, '_').replace(/^_+|_+$/g, '');
        
        // Generate hash from uniquifier
        const hashInput = uniquifier ? String(uniquifier) : String(Date.now() + Math.random());
        let hash = 0;
        for (let i = 0; i < hashInput.length; i++) {
            const char = hashInput.charCodeAt(i);
            hash = ((hash << 5) - hash) + char;
            hash = hash & hash;
        }
        
        // Convert hash to alphabetic-only suffix
        const alphabeticHash = this.hashToAlphabetic(Math.abs(hash));
        
        return `${sanitized}_${alphabeticHash}`.toUpperCase();
    }


    /**
     * Helper Method : getFieldDataType
     * @description : Get the data type for a field based on jsonType and inputType
     */
    getFieldDataType(jsonType, inputType = null) {
        switch (jsonType) {
            case 'CheckboxGroup':
                return 'array';
            case 'OptIn':
                return 'boolean';
            case 'TextInput':
            case 'TextArea':
                // Check if input type is number
                if (inputType === 'number') {
                    return 'number';
                }
                return 'string';
            default:
                return 'string';
        }
    }

    /**
     * Helper Method : buildFooterPayload
     * @description : Build the payload object for Footer on-click-action.
     * The payload must include:
     * 1. Current screen's form fields (using ${form.fieldName})
     * 2. All data from previous screens (using ${data.keyName}) - to forward to next screen/completion
     */
    buildFooterPayload(currentScreenIndex, currentInputFields, allScreens) {
        const payload = {};
        
        // Add current screen's form fields
        currentInputFields.forEach((field, idx) => {
            const key = `screen_${currentScreenIndex}_${field.name}_${idx}`;
            payload[key] = `\${form.${field.name}}`;
        });

        // Collect and forward all previous screens' input fields
        // We scan each previous screen's form directly instead of relying on data schema
        for (let i = 0; i < currentScreenIndex; i++) {
            const prevScreen = allScreens[i];
            // Skip read more screens - they don't participate in the data flow
            if (prevScreen?.id?.startsWith('READ_MORE_')) continue;
            
            if (!prevScreen?.layout?.children) continue;
            
            const formElement = prevScreen.layout.children.find(child => child.type === 'Form');
            if (!formElement?.children) continue;
            
            // Extract input fields from previous screen's form
            let inputFieldIndex = 0;
            formElement.children.forEach((element) => {
                if (element.type === 'Footer') return;
                
                if (this.isInputField(element.type)) {
                    const key = `screen_${i}_${element.name}_${inputFieldIndex}`;
                    payload[key] = `\${data.${key}}`;
                    inputFieldIndex++;
                }
            });
        }

        return payload;
    }

    /**
     * Helper Method : buildDataSchema
     * @description : Build the data schema for a screen based on previous screens.
     * The data model defines what data a screen RECEIVES from previous screens.
     * It should NOT include the current screen's own input fields.
     */
    buildDataSchema(currentScreenIndex, allScreens) {
        const dataSchema = {};

        // Collect input fields ONLY from previous screens (not current screen)
        // Screen 0 (first screen) should have empty data since it receives nothing
        for (let i = 0; i < currentScreenIndex; i++) {
            const screen = allScreens[i];
            if (!screen?.layout?.children) continue;

            // Extract form children
            const formElement = screen.layout.children.find(child => child.type === 'Form');
            if (!formElement?.children) continue;

            // Process each form child to extract input fields
            // Use a separate counter for input fields only (to match buildFooterPayload indexing)
            let inputFieldIndex = 0;
            formElement.children.forEach((element) => {
                if (element.type === 'Footer') return; // Skip footer

                const jsonType = element.type;
                if (this.isInputField(jsonType)) {
                    const fieldName = element.name;
                    const key = `screen_${i}_${fieldName}_${inputFieldIndex}`;
                    const dataType = this.getFieldDataType(jsonType);

                    dataSchema[key] = {
                        type: dataType,
                        __example__: dataType === 'array' ? [] : (dataType === 'boolean' ? false : 'Example')
                    };

                    // Add items for array type
                    if (dataType === 'array') {
                        dataSchema[key].items = { type: 'string' };
                    }
                    
                    inputFieldIndex++; // Increment only for input fields
                }
            });

        }

        return dataSchema;
    }

    /**
     * Helper Method : rebuildScreenFooter
     * @description : Rebuilds Footer payload for a screen based on its input fields and previous screens
     */
    rebuildScreenFooter(screen, screenIndex, allScreens) {
        try {
            if (!screen?.layout?.children) return;

            // Find Form element
            const formElement = screen.layout.children.find(child => child.type === 'Form');
            if (!formElement?.children) return;

            // Extract input fields from this screen
            const inputFields = [];
            let inputFieldIndex = 0;
            
            formElement.children.forEach((element) => {
                if (element.type === 'Footer') return;
                
                const jsonType = element.type;
                if (this.isInputField(jsonType)) {
                    inputFields.push({
                        name: element.name,
                        type: this.getFieldDataType(jsonType),
                        screenIndex: screenIndex
                    });
                    inputFieldIndex++;
                }
            });

            // Find Footer element
            const footerElement = formElement.children.find(child => child.type === 'Footer');
            if (!footerElement || !footerElement['on-click-action']) return;

            // Rebuild Footer payload
            const newPayload = this.buildFooterPayload(screenIndex, inputFields, allScreens);
            
            // Update Footer's on-click-action payload
            footerElement['on-click-action'].payload = newPayload;
            
        } catch (error) {
            console.error('Error rebuilding screen footer:', error);
        }
    }

    /**
     * Method : showToast
     * @description : Shows toast notification
     */
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }

    /**
     * Method : handleMetaError
     * @description : Handles Meta API errors and displays them properly
     */
    handleMetaError(response) {
        let errorMessage = 'Failed to process flow';
        let errorDetails = '';
        
        try {
            // Check if response.message is a JSON string containing error details
            if (response.message && response.message.includes('error')) {
                const errorData = JSON.parse(response.message);
                
                if (errorData.error && errorData.error.error_user_msg) {
                    errorMessage = errorData.error.error_user_msg;
                } else if (errorData.error && errorData.error.message) {
                    errorMessage = errorData.error.message;
                }
                
                // Extract additional details
                if (errorData.error && errorData.error.error_subcode) {
                    errorDetails = `Error Code: ${errorData.error.error_subcode}`;
                }
            } else if (response.message) {
                errorMessage = response.message;
            }
        } catch (e) {
            // If parsing fails, use the message as is
            errorMessage = response.message || errorMessage;
        }
        
        // Show toast with error
        this.showToast('Error', errorMessage, 'error');
        
        console.error('Meta API Error:', response);
    }

}