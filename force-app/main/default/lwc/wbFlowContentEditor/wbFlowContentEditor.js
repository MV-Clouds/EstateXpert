import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import getS3ConfigSettings from '@salesforce/apex/AWSFilesController.getS3ConfigSettings';
import AWS_SDK from "@salesforce/resourceUrl/AWSSDK";

export default class WbFlowContentEditor extends LightningElement {

    @api parentFlowId = null; 
    @api isParentFlow = false;

    @track contentSections = [];
    @track imageOperationInProgress = {}; 

    screenTitle = 'Thank you';
    buttonLabel = 'Done';
    isScreenTitleExpanded = true;
    isButtonSectionExpanded = true;
    isDragging = false;
    readMoreMode = false;
    isAWSEnabled = false;
    confData;
    s3;
    isAwsSdkInitialized = false;
    
    internalMetadataMap = {};
    sectionIdCounter = 0;
    draggedSectionId = null;
    dragOverSectionId = null;
    tempSectionList = null;
    scrollInterval = null;
    scrollDirection = 0;
    scrollMagnitude = 0;
    boundDragOverHandler = null;
    editorContainerRect = null;
    scrollContainer = null;

    @api
    get metadataMap() {
        return this.internalMetadataMap;
    }

    set metadataMap(value) {
        this.internalMetadataMap = value || {};
    }


    get screenTitleIcon() {
        return this.isScreenTitleExpanded ? 'utility:chevronup' : 'utility:chevrondown';
    }

    get screenTitleContainerClass() {
        return this.isScreenTitleExpanded ? 'section-card expanded' : 'section-card';
    }

    get buttonSectionIcon() {
        return this.isButtonSectionExpanded ? 'utility:chevronup' : 'utility:chevrondown';
    }

    get buttonContainerClass() {
        return this.isButtonSectionExpanded ? 'section-card button-section expanded' : 'section-card button-section';
    }

    get screenTitleCharCount() {
        return this.screenTitle ? this.screenTitle.length : 0;
    }

    get buttonCharCount() {
        return this.buttonLabel ? this.buttonLabel.length : 0;
    }

    get showButtonSection() {
        return !this.readMoreMode;
    }

    get processedSections() {
        const listToUse = this.tempSectionList || this.contentSections;
        return listToUse.map(section => {
            // Build base class from section state (expanded/collapsed)
            const baseClass = section.isExpanded ? 'section-card expanded' : 'section-card collapsed';
            let containerClass = baseClass;
            
            // Add drag states
            if (section.id === this.draggedSectionId) {
                containerClass += ' dragging';
            }
            if (section.id === this.dragOverSectionId) {
                containerClass += ' drag-over';
            }
            
            // Calculate max options validation for dropdown/selection elements
            const optionsCount = section.options?.length || 0;
            const config = this.getMetadataConfig(section.itemName);
            const maxOptions = config?.constraints?.maxOptions || 10;
            const isMaxOptionsReached = optionsCount >= maxOptions;
            const addOptionButtonTitle = isMaxOptionsReached
                ? `You can add a maximum of ${maxOptions} options.`
                : 'Add option';
            
            // Check if this section has an image operation in progress
            const isLoading = this.imageOperationInProgress[section.id] || false;
            
            return {
                ...section,
                containerClass: containerClass,
                toggleIcon: section.isExpanded ? 'utility:chevronup' : 'utility:chevrondown',
                hasError: section.hasError || false,
                errorMessage: section.errorMessage || '',
                textareaClass: section.hasError ? 'native-textarea error' : 'native-textarea',
                charCounterClass: section.hasError ? 'char-counter-inside error' : 'char-counter-inside',
                isMaxOptionsReached: isMaxOptionsReached,
                addOptionButtonTitle: addOptionButtonTitle,
                isDraggable: true,
                isLoading: isLoading
            };
        });
    }

    /**
     * Method : loadScreenData
     * @description : API method to load screen data into the editor
     * @param {Object} screenData - The screen object from JSON
     */
    @api
    loadScreenData(screenData) {
        try {
            if (!screenData) {
                // Reset to defaults
                this.screenTitle = 'Thank you';
                this.buttonLabel = 'Done';
                this.contentSections = [];
                return;
            }
            
            // Set screen title
            this.screenTitle = screenData.title || 'Thank you';
            
            // Reset button label to default before processing
            this.buttonLabel = 'Done';
            
            // Parse layout children and populate contentSections
            this.contentSections = [];
            if (screenData.layout && screenData.layout.children) {
                const layoutChildren = screenData.layout.children;
                
                // Find Form element if it exists
                const formElement = layoutChildren.find(child => child.type === 'Form');
                const childrenToProcess = formElement ? formElement.children : layoutChildren;
                
                // Parse each child element
                childrenToProcess.forEach(child => {
                    // Check if this is a Footer element and extract button label
                    if (child.type === 'Footer' && child.label) {
                        this.buttonLabel = child.label;
                    }
                    
                    const section = this.parseSectionFromJson(child);
                    if (section) {
                        this.contentSections.push(section);
                    }
                });
            }
            
        } catch (error) {
            console.error('Error loading screen data:', error);
        }
    }


    @api
    addContentSection(contentData) {
        // Check max content limit
        if (this.contentSections.length >= 10) {
            return;
        }
        
        const { category, itemName, itemData } = contentData;
        
        // Check if adding an image and validate max image count per screen
        if (itemName === 'Image') {
            const currentImageCount = this.contentSections.filter(section => section.itemName === 'Image').length;
            if (currentImageCount >= 3) {
                // Show error message to user
                this.dispatchEvent(new CustomEvent('showerror', {
                    detail: {
                        title: 'Maximum Images Reached',
                        message: 'You can add a maximum of 3 images per screen.',
                        variant: 'error'
                    },
                    bubbles: true,
                    composed: true
                }));
                return;
            }
        }
        
        const newSection = this.createSection(category, itemName, itemData);
        if (newSection) {
            this.contentSections = [...this.contentSections, newSection];
            this.dispatchContentUpdate();
        }
    }

    @api
    getContentData() {
        return {
            screenTitle: this.screenTitle,
            buttonLabel: this.buttonLabel,
            sections: this.contentSections
        };
    }

    @api
    getContentCount() {
        return this.contentSections.length;
    }

    @api
    setReadMoreMode(isReadMoreMode) {
        this.readMoreMode = isReadMoreMode;
    }

    @api
    updateSectionReadMoreFlag(sectionName, hasReadMore) {
        // Update the specific section's hasReadMoreScreen flag
        this.contentSections = this.contentSections.map(section => {
            if (section.name === sectionName) {
                return {
                    ...section,
                    hasReadMoreScreen: hasReadMore
                };
            }
            return section;
        });
    }

    /**
     * Method : connectedCallback
     * @description : Component initialization
     */
    connectedCallback() {
        loadStyle(this, MulishFontCss)
            .then(() => {
                console.log('External Css Loaded');
            })
            .catch(error => {
                console.log('Error occuring during loading external css', error);
            });
        this.getS3ConfigData();
    }

    renderedCallback(){
        if (!this.isAwsSdkInitialized) {
            Promise.all([loadScript(this, AWS_SDK)])
                .then(() => {
                    this.isAwsSdkInitialized = true;
                })
                .catch((error) => {
                    console.error("error -> ", error);
                });

        }
    }

    /**
     * Method : toggleReadMoreButtons
     * @description : Simple method to toggle read more button visibility
     * @param {string} sectionId - Internal section ID
     * @param {boolean} show - Whether to show Edit/Delete buttons (true) or Add link button (false)
     */
    toggleReadMoreButtons(sectionId, show) {
        
        this.contentSections = this.contentSections.map(section => {
            if (section.id === sectionId) {
                return {
                    ...section,
                    hasReadMoreScreen: show
                };
            }
            return section;
        });

        
    }

    /**
     * Drag and Drop Handlers
     */
    handleDragStart(event) {
        const sectionId = event.currentTarget.dataset.sectionId;
        const section = this.contentSections.find(s => s.id === sectionId);
        
        // Don't allow dragging if somehow triggered incorrectly
        if (!section) {
            event.preventDefault();
            return;
        }
        
        this.draggedSectionId = sectionId;
        this.isDragging = true;
        this.tempSectionList = [...this.contentSections];
        event.dataTransfer.effectAllowed = 'move';
        event.dataTransfer.setData('text/plain', sectionId);
        
        // Cache the editor container rect for scroll calculations
        const editorContainer = this.template.querySelector('.editor-container');
        if (editorContainer) {
            this.editorContainerRect = editorContainer.getBoundingClientRect();
        }
        
        // Add document-level drag listener for auto-scroll
        this.boundDragOverHandler = this.handleDocumentDragOver.bind(this);
        document.addEventListener('dragover', this.boundDragOverHandler);
        
        // Add CSS class to draggable sections container
        setTimeout(() => {
            const container = this.template.querySelector('.draggable-sections-container');
            if (container) container.classList.add('is-dragging');
        }, 0);
    }

    /**
     * Document-level drag over handler for smooth auto-scroll
     * This ensures auto-scroll works even when not directly over a section
     */
    handleDocumentDragOver(event) {
        if (!this.isDragging) return;
        
        const container = this.template.querySelector('.editor-container');
        if (!container) return;
        
        // Update cached rect periodically (in case of layout changes)
        const rect = container.getBoundingClientRect();
        const mouseY = event.clientY;
        const mouseX = event.clientX;
        
        // Check if mouse is within the horizontal bounds of the container
        if (mouseX < rect.left - 50 || mouseX > rect.right + 50) {
            this.stopAutoScroll();
            return;
        }
        
        const threshold = 50; // Distance from edge to start scrolling
        const maxSpeed = 10; // Maximum speed
        const minSpeed = 2; // Minimum speed
        
        // Calculate distance from top and bottom of the container
        const distanceFromTop = mouseY - rect.top;
        const distanceFromBottom = rect.bottom - mouseY;
        
        // Check if container is actually scrollable
        const isScrollable = container.scrollHeight > container.clientHeight;
        if (!isScrollable) {
            this.stopAutoScroll();
            return;
        }
        
        // Determine scroll direction and speed based on proximity to edges
        if (distanceFromTop < threshold) {
            // Near top edge - scroll up (negative speed)
            // Only scroll up if we aren't already at the top
            if (container.scrollTop > 0) {
                // Safety: Stop scrolling if mouse is WAY above container (prevent runaway scroll)
                if (distanceFromTop < -100) {
                    this.stopAutoScroll();
                    return;
                }

                const proximity = threshold - Math.max(0, distanceFromTop);
                const normalizedProximity = Math.min(proximity / threshold, 1);
                
                // Changed to Linear easing (removed square) for more predictable speed
                // This prevents the "sudden jump" to max speed when crossing the edge
                const speed = minSpeed + (normalizedProximity * (maxSpeed - minSpeed));
                this.startAutoScroll(container, -speed);
            } else {
                this.stopAutoScroll();
            }
        } else if (distanceFromBottom < threshold) {
            // Near bottom edge - scroll down (positive speed)
            // Only scroll down if we aren't already at the bottom
            const maxScroll = container.scrollHeight - container.clientHeight;
            if (container.scrollTop < maxScroll) {
                // Safety: Stop scrolling if mouse is WAY below container
                if (distanceFromBottom < -100) {
                    this.stopAutoScroll();
                    return;
                }

                const proximity = threshold - Math.max(0, distanceFromBottom);
                const normalizedProximity = Math.min(proximity / threshold, 1);
                
                // Changed to Linear easing
                const speed = minSpeed + (normalizedProximity * (maxSpeed - minSpeed));
                this.startAutoScroll(container, speed);
            } else {
                this.stopAutoScroll();
            }
        } else {
            // Not near edges - stop scrolling
            this.stopAutoScroll();
        }
    }

    /**
     * Container-level drag over handler for auto-scroll
     * This handles drags directly on the editor container and draggable sections container
     */
    handleContainerDragOver(event) {
        event.preventDefault();
    }

    handleDragOver(event) {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'move';
        return false;
    }

    handleDragEnter(event) {
        event.preventDefault();
        const sectionId = event.currentTarget.dataset.sectionId;
        
        // Only update if it's a different section and not the dragged one
        if (sectionId && sectionId !== this.draggedSectionId && sectionId !== this.dragOverSectionId) {
            this.dragOverSectionId = sectionId;
            
            // Reorder tempSectionList
            if (this.tempSectionList) {
                const draggedIndex = this.tempSectionList.findIndex(s => s.id === this.draggedSectionId);
                const targetIndex = this.tempSectionList.findIndex(s => s.id === sectionId);
                
                if (draggedIndex !== -1 && targetIndex !== -1) {
                    const reordered = [...this.tempSectionList];
                    const [draggedItem] = reordered.splice(draggedIndex, 1);
                    reordered.splice(targetIndex, 0, draggedItem);
                    this.tempSectionList = reordered;
                }
            }
        }
    }

    handleDrop(event) {
        event.stopPropagation();
        event.preventDefault();
        
        // Stop auto-scrolling
        this.stopAutoScroll();
        
        // Remove document-level drag listener
        if (this.boundDragOverHandler) {
            document.removeEventListener('dragover', this.boundDragOverHandler);
            this.boundDragOverHandler = null;
        }
        
        // Apply the final reordering if tempSectionList exists
        if (this.tempSectionList) {
            // Update contentSections with the reordered list and update order property
            this.contentSections = this.tempSectionList.map((section, index) => ({
                ...section,
                order: index
            }));
            
            // Dispatch update event to parent
            this.dispatchContentUpdate();
        }
        
        // Clean up
        this.draggedSectionId = null;
        this.dragOverSectionId = null;
        this.isDragging = false;
        this.tempSectionList = null;
        this.editorContainerRect = null;
        
        // Remove CSS class from draggable sections container
        const container = this.template.querySelector('.draggable-sections-container');
        if (container) container.classList.remove('is-dragging');
        
        return false;
    }

    handleDragLeave(event) {
        // Only clear if we're leaving the actual element (not just moving between children)
        const relatedTarget = event.relatedTarget;
        const currentTarget = event.currentTarget;
        
        // Check if we're leaving the section-card element completely
        if (!currentTarget.contains(relatedTarget)) {
            if (this.dragOverSectionId === event.currentTarget.dataset.sectionId) {
                this.dragOverSectionId = null;
            }
        }
    }

    handleDragEnd() {
        // Stop auto-scrolling
        this.stopAutoScroll();
        
        // Remove document-level drag listener
        if (this.boundDragOverHandler) {
            document.removeEventListener('dragover', this.boundDragOverHandler);
            this.boundDragOverHandler = null;
        }
        
        this.draggedSectionId = null;
        this.dragOverSectionId = null;
        this.isDragging = false;
        this.tempSectionList = null;
        this.editorContainerRect = null;
        
        // Remove CSS class from draggable sections container
        const container = this.template.querySelector('.draggable-sections-container');
        if (container) container.classList.remove('is-dragging');
    }

    /**
     * Auto-scroll Helper Methods
     */
    startAutoScroll(container, speed) {
        // Store the container reference
        this.scrollContainer = container;
        
        // Store the scroll direction and speed separately
        // speed > 0 means scroll down, speed < 0 means scroll up
        this.scrollDirection = speed < 0 ? -1 : 1;
        this.scrollMagnitude = Math.abs(speed);
        
        // If already scrolling, just update direction/speed (the loop will pick it up)
        if (this.scrollInterval) {
            return;
        }
        
        // Use requestAnimationFrame for smoother scrolling
        const scrollStep = () => {
            const cont = this.scrollContainer;
            
            // Stop if no longer dragging or container is gone
            if (!this.isDragging || !cont) {
                this.stopAutoScroll();
                return;
            }
            
            // Get current scroll values
            const direction = this.scrollDirection;
            const magnitude = this.scrollMagnitude;
            
            // If magnitude is 0, keep loop running but don't scroll
            if (magnitude === 0) {
                this.scrollInterval = requestAnimationFrame(scrollStep);
                return;
            }
            
            // Get current and max scroll positions
            const currentScrollTop = cont.scrollTop;
            const maxScrollTop = cont.scrollHeight - cont.clientHeight;

             // Check boundaries to stop unnecessary processing immediately
             if ((direction === -1 && currentScrollTop <= 0) || 
                 (direction === 1 && currentScrollTop >= maxScrollTop)) {
                 this.stopAutoScroll();
                 return;
             }
            
            // Calculate delta (how much to scroll this frame)
            const delta = direction * magnitude;
            
            // Calculate new scroll position
            let newScrollTop = currentScrollTop + delta;
            
            // Clamp to valid range
            newScrollTop = Math.max(0, Math.min(maxScrollTop, newScrollTop));
            
            // Only apply if there's a change
            if (newScrollTop !== currentScrollTop) {
                cont.scrollTop = newScrollTop;
                // Continue the animation loop
                this.scrollInterval = requestAnimationFrame(scrollStep);
            } else {
                // Hit the wall
                this.stopAutoScroll();
            }
        };
        
        this.scrollInterval = requestAnimationFrame(scrollStep);
    }

    stopAutoScroll() {
        if (this.scrollInterval) {
            cancelAnimationFrame(this.scrollInterval);
            this.scrollInterval = null;
        }
        this.scrollDirection = 0;
        this.scrollMagnitude = 0;
        this.scrollContainer = null;
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
     * Helper Method : getMetadataConfig
     * @description : Get parsed metadata config for a given item name
     */
    getMetadataConfig(itemName) {
        const metadata = this.internalMetadataMap?.[itemName];
        return metadata ? this.parseMetadata(metadata) : null;
    }

    /**
     * Helper Method : getTypeOptionsForSection
     * @description : Get type switch options from metadata for text elements
     */
    getTypeOptionsForSection(itemName) {
        const config = this.getMetadataConfig(itemName);
        if (!config || !config.uiFields?.showTypeSwitch) {
            return [];
        }

        // Build options from allowedTypeSwitches
        const allowedTypes = config.uiFields.allowedTypeSwitches || [];
        return allowedTypes.map(typeName => {
            const typeConfig = this.getMetadataConfig(typeName);
            return {
                label: typeConfig?.category === 'Text' ? typeName.replace(/([A-Z])/g, ' $1').trim() : typeName,
                value: typeName
            };
        });
    }

    /**
     * Helper Method : getInputTypeOptions
     * @description : Get input type options from metadata for TextInput
     */
    getInputTypeOptions(itemName) {
        const config = this.getMetadataConfig(itemName);
        if (!config || !config.uiFields?.showInputType) {
            return [];
        }

        // Get inputTypeOptions from metadata
        const inputTypes = config.inputTypeOptions || [];
        return inputTypes.map(type => {
            // Ensure type is a string and handle both string and object formats
            const typeValue = typeof type === 'string' ? type : (type?.value || type?.name || String(type));
            const typeLabel = typeof type === 'object' && type?.label ? type.label : 
                             (typeValue.charAt(0).toUpperCase() + typeValue.slice(1));
            return {
                label: typeLabel,
                value: typeValue
            };
        });
    }

    /**
     * Method : parseSectionFromJson
     * @description : Converts JSON element to internal section format (metadata-driven)
     */
    parseSectionFromJson(jsonElement) {
        try {
            if (!jsonElement || !jsonElement.type) {
                console.warn('Invalid JSON element:', jsonElement);
                return null;
            }

            if (jsonElement.type === 'Footer') {
                return null;
            }

            // Get metadata configuration using the jsonType from the JSON
            const config = this.getMetadataConfigByJsonType(jsonElement.type);
            if (!config || !config.itemName) {
                console.warn('No metadata config found for jsonType:', jsonElement.type);
                return null;
            }

            // Derive value field from jsonType
            const valueField = this.getValueFieldFromMetadata(config);
            const value = jsonElement[valueField] || '';

            // Determine the required value - OptIn defaults to true if not explicitly set to false
            let requiredValue = jsonElement.required;
            if (jsonElement.type === 'OptIn' && requiredValue === undefined) {
                requiredValue = true; // OptIn defaults to required
            }

            // Build section using shared function with values from JSON
            const section = this.buildSectionObject({
                itemName: config.itemName,
                config: config,
                overrides: {
                    name: jsonElement.name,
                    value: value,
                    required: requiredValue,
                    inputType: jsonElement['input-type'],
                    helperText: jsonElement['helper-text'],
                    previewText: value || config.defaults?.text || 'Enter content',
                    // Detect read more from on-click-action for OptIn
                    hasReadMoreScreen: jsonElement.type === 'OptIn' && jsonElement['on-click-action']?.name === 'navigate' && !!jsonElement['on-click-action']?.next?.name,
                    readMoreScreenData: jsonElement.type === 'OptIn' && jsonElement['on-click-action']?.next?.name ? {
                        id: jsonElement['on-click-action']?.next?.name,
                        title: 'Read more'
                    } : null
                }
            });

            // Parse options for selection elements
            if (section.isSelection && jsonElement['data-source']) {
                section.options = jsonElement['data-source'].map((opt, idx) => ({
                    id: this.generateSanitizedId(`OPT_${idx + 1}_${section.id}_${Date.now()}`),
                    label: opt.title || `Option ${idx + 1}`
                }));
            }

            // Parse image properties
            if (section.isImage) {
                section.imageSrc = jsonElement.src || '';
                section.imageUrl = jsonElement.src || null;  // Set imageUrl from src for display
                section.awsKey = jsonElement.src || null;  // Store awsKey for deletion tracking
                section.altText = jsonElement['alt-text'] || '';
                section.scaleType = jsonElement['scale-type'] || config.defaults?.scaleType || 'cover';
                section.height = jsonElement.height || 200;  // Extract height from JSON
            }

            return section;
        } catch (error) {
            console.error('Error parsing section from JSON:', error);
            return null;
        }
    }

    /**
     * Helper Method : getValueFieldFromMetadata
     * @description : Derive the JSON value field from metadata category
     */
    getValueFieldFromMetadata(config) {
        // Use category from metadata to determine value field
        switch (config.category) {
            case 'Text':
                return 'text';
            case 'Input':
            case 'Selection':
                return 'label';
            case 'Image':
                return 'src';
            default:
                return 'text';
        }
    }

    /**
     * Helper Method : isInputElementFromMetadata
     * @description : Determine if element should show required checkbox from metadata
     */
    isInputElementFromMetadata(config) {
        // Directly use showRequired flag from metadata
        return config.uiFields?.showRequired === true;
    }

    /**
     * Helper Method : getMetadataConfigByJsonType
     * @description : Get metadata config by searching for matching jsonType
     */
    getMetadataConfigByJsonType(jsonType) {
        // Find the metadata entry that has this jsonType
        for (const itemName in this.internalMetadataMap) {
            const config = this.getMetadataConfig(itemName);
            if (config && config.jsonType === jsonType) {
                return { ...config, itemName };
            }
        }
        return null;
    }

    generateSectionId() {
        return this.generateSanitizedId('SECTION', ++this.sectionIdCounter + Date.now());
    }

    createSection(category, itemName, itemData) {
        // Get metadata configuration
        const config = this.getMetadataConfig(itemName);
        if (!config) {
            console.warn('No metadata config found for:', itemName);
            return null;
        }

        // Build section with defaults from metadata
        return this.buildSectionObject({
            itemName,
            config,
            overrides: {
                category,
                developerName: itemData?.developerName || itemName,
                typeLabel: itemData?.label || itemName.replace(/([A-Z])/g, ' $1').trim()
            }
        });
    }

    /**
     * Helper Method : buildSectionObject
     * @description : Shared function to build section object from metadata config
     */
    buildSectionObject({ itemName, config, overrides = {} }) {
        const sectionId = this.generateSectionId();
        const { jsonType, defaults, uiFields, constraints } = config;

        // Derive isInputElement from existing metadata properties
        const isInputElement = this.isInputElementFromMetadata(config);
        

        // Build base section with metadata-driven properties
        const section = {
            id: sectionId,
            name: overrides.name || sectionId,
            category: overrides.category || config.category || 'Text',
            itemName,
            developerName: overrides.developerName || itemName,
            isExpanded: true,
            toggleIcon: 'utility:chevronup',
            containerClass: 'section-card expanded',
            typeLabel: overrides.typeLabel || itemName.replace(/([A-Z])/g, ' $1').trim(),
            
            // Metadata-driven properties
            jsonType: jsonType,
            uiFields: uiFields || {},
            constraints: constraints || {},
            
            // UI control flags
            showTypeSwitch: uiFields?.showTypeSwitch || false,
            showLabel: uiFields?.showLabel || false,
            showHelperText: uiFields?.showHelperText || false,
            showRequired: isInputElement,
            showInputType: uiFields?.showInputType || false,
            showOptions: uiFields?.showOptions || false,
            showImageProps: uiFields?.showImageProps || false,
            showReadMoreLink: uiFields?.showReadMoreLink || false,
            
            // Type-specific flags for rendering - dynamically derived from metadata
            isTextElement: config.category === 'Text',
            isTextInput: jsonType === 'TextInput',
            isTextArea: jsonType === 'TextArea',
            isSelection: config.category === 'Selection',
            isDatePicker: jsonType === 'DatePicker',
            isOptIn: jsonType === 'OptIn',
            isImage: jsonType === 'Image',
            
            // Default values from metadata or overrides
            // For OptIn, default to true if required is not explicitly set
            value: overrides.value !== undefined ? overrides.value : (defaults?.text || defaults?.label || ''),
            required: overrides.required !== undefined ? overrides.required : (jsonType === 'OptIn' ? true : (defaults?.required || false)),
            inputType: overrides.inputType || defaults?.inputType || 'text',
            helperText: overrides.helperText || '',
            
            // Read more link properties
            hasReadMoreScreen: overrides.hasReadMoreScreen || false,
            readMoreScreenData: overrides.readMoreScreenData || null,
            
            // Type options for switching (if applicable)
            typeOptions: this.getTypeOptionsForSection(itemName),
            
            // Input type options (for TextInput)
            inputTypeOptions: this.getInputTypeOptions(itemName),
            
            // Constraints
            maxLength: constraints?.textMaxLength || constraints?.labelMaxLength || 4096,
            optionMaxLength: 30,
            helperTextMaxLength: constraints?.helperTextMaxLength || 80,
            
            // Preview text from overrides or metadata defaults
            previewText: overrides.previewText || defaults?.text || 'Enter content'
        };

        // Add options for selection elements
        if (section.isSelection) {
            section.options = overrides.options || [
                { id: this.generateSanitizedId(`OPT_1_${section.id}_${Date.now()}`), label: 'Option 1' },
                { id: this.generateSanitizedId(`OPT_2_${section.id}_${Date.now()}`), label: 'Option 2' }
            ];
        }

        // Add image properties for Image element
        if (section.isImage) {
            section.imageSrc = overrides.imageSrc || defaults?.src || '';
            section.imageUrl = overrides.imageUrl || null;  // AWS public URL
            section.awsKey = overrides.awsKey || null;  // AWS S3 key for deletion
            section.isUploading = false;  // Upload state
            section.uploadError = null;  // Upload error message
            section.altText = overrides.altText || '';
            section.scaleType = overrides.scaleType || defaults?.scaleType || 'cover';
            section.height = overrides.height || 200;  // Default height
            section.imageScaleTypes = config.imageScaleTypes || ['cover', 'contain'];
            section.fileInputId = `file-input-${sectionId}`;  // Unique ID for file input
            
            // Get max file size from metadata constraints
            section.maxFileSize = constraints?.maxFileSize ? `${constraints.maxFileSize}kb` : '300kb';
            
            // Get allowed file types from metadata and format for display
            const allowedTypes = constraints?.allowedFileTypes || ['image/jpeg', 'image/png'];
            section.acceptableFileTypes = allowedTypes
                .map(type => type.replace('image/', '').toUpperCase())
                .join(', ');
        }

        return section;
    }

    toggleSection(event) {
        const sectionId = event.currentTarget.dataset.section;

        if (sectionId === 'screenTitle') {
            this.isScreenTitleExpanded = !this.isScreenTitleExpanded;
        } else if (sectionId === 'button') {
            this.isButtonSectionExpanded = !this.isButtonSectionExpanded;
        } else {
            this.contentSections = this.contentSections.map(section => {
                if (section.id === sectionId) {
                    const isExpanded = !section.isExpanded;
                    return {
                        ...section,
                        isExpanded,
                        toggleIcon: isExpanded ? 'utility:chevronup' : 'utility:chevrondown',
                        containerClass: isExpanded ? 'section-card expanded' : 'section-card collapsed'
                    };
                }
                return section;
            });
        }
    }

    handleScreenTitleChange(event) {
        this.screenTitle = event.target.value;
        this.dispatchContentUpdate();
    }

    handleButtonLabelChange(event) {
        this.buttonLabel = event.target.value;
        this.dispatchContentUpdate();
    }

    handleContentChange(event) {
        const sectionId = event.target.dataset.id;
        const field = event.target.dataset.field || 'value';
        const newValue = event.target.value;

        this.contentSections = this.contentSections.map(section => {
            if (section.id === sectionId) {
                const maxLength = section.maxLength || 4096;
                const hasError = newValue.length > maxLength;
                const errorMessage = hasError ? `This field cannot be longer than ${maxLength} characters` : '';
                
                const updatedSection = {
                    ...section,
                    [field]: newValue,
                    hasError: hasError,
                    errorMessage: errorMessage
                };
                
                // Update preview text if value field changed
                if (field === 'value') {
                    updatedSection.previewText = newValue || section.previewText;
                }
                
                return updatedSection;
            }
            return section;
        });
        
        // Force re-render by creating new array reference
        this.contentSections = [...this.contentSections];
        this.dispatchContentUpdate();
    }

    /**
     * Method : handleFieldChange
     * @description : Handles changes to dropdown/checkbox fields
     */
    handleEditReadMore(event) {
        event.stopPropagation();
        const sectionId = event.currentTarget.dataset.sectionId;
        
        const section = this.contentSections.find(s => s.id === sectionId);
        
        const hasExistingReadMore = section?.hasReadMoreScreen === true;        
        
        if (!hasExistingReadMore) {
            this.toggleReadMoreButtons(sectionId, true);
        }
        
        this.dispatchEvent(new CustomEvent('editreadmore', {
            detail: { 
                sectionId: section?.name || sectionId,  // Use name for JSON matching
                internalSectionId: sectionId,  // Keep internal ID for UI updates
                shouldNavigate: hasExistingReadMore  // Only navigate if already exists (Edit content)
            }
        }));
    }

    handleDeleteReadMoreLink(event) {
        event.stopPropagation();
        const sectionId = event.currentTarget.dataset.sectionId;
        
        // Find the section to get its name
        const section = this.contentSections.find(s => s.id === sectionId);
        
        // Update UI immediately
        this.toggleReadMoreButtons(sectionId, false);
        
        // Dispatch event to parent to remove read more screen from JSON
        this.dispatchEvent(new CustomEvent('deletereadmore', {
            detail: { 
                sectionId: section?.name || sectionId
            }
        }));
        
        this.dispatchContentUpdate();
    }

    handleFieldChange(event) {
        const sectionId = event.target.dataset.sectionId;
        const field = event.target.dataset.field;
        const newValue = event.detail.value !== undefined ? event.detail.value : event.target.checked;

        this.contentSections = this.contentSections.map(section => {
            if (section.id === sectionId) {
                return {
                    ...section,
                    [field]: newValue
                };
            }
            return section;
        });
        
        // Force re-render
        this.contentSections = [...this.contentSections];
        this.dispatchContentUpdate();
    }

    handleHeightChange(event) {
        const sectionId = event.target.dataset.sectionId;
        let value = parseInt(event.target.value, 10);
        
        // Ensure value is a valid positive number
        if (isNaN(value) || value < 1) {
            value = 200; // Reset to default if invalid
        }

        this.contentSections = this.contentSections.map(section => {
            if (section.id === sectionId) {
                return { ...section, height: value };
            }
            return section;
        });

        // Force re-render
        this.contentSections = [...this.contentSections];
        this.dispatchContentUpdate();
    }

    handleTypeChange(event) {
        const sectionId = event.target.dataset.sectionId;
        const newItemName = event.detail.value;

        this.contentSections = this.contentSections.map(section => {
            if (section.id === sectionId) {
                // Get new metadata config for the switched type
                const newConfig = this.getMetadataConfig(newItemName);
                if (!newConfig) {
                    console.warn('No metadata config found for new type:', newItemName);
                    return section;
                }

                const { jsonType, defaults, uiFields, constraints } = newConfig;

                // Derive if the new type is an input element from metadata
                const isInputElement = this.isInputElementFromMetadata(newConfig);

                // Calculate new max length and check for errors
                const newMaxLength = constraints?.textMaxLength || constraints?.labelMaxLength || 4096;
                const currentValue = section.value || '';
                const hasError = currentValue.length > newMaxLength;
                const errorMessage = hasError ? `This field cannot be longer than ${newMaxLength} characters` : '';

                // Build updated section with new type's properties
                const updatedSection = {
                    ...section,
                    itemName: newItemName,
                    jsonType: jsonType,
                    typeLabel: newItemName.replace(/([A-Z])/g, ' $1').trim(),
                    uiFields: uiFields || {},
                    constraints: constraints || {},
                    
                    // Update UI control flags
                    showTypeSwitch: uiFields?.showTypeSwitch || false,
                    showLabel: uiFields?.showLabel || false,
                    showHelperText: uiFields?.showHelperText || false,
                    showRequired: isInputElement,  // Show required checkbox for all input elements
                    showInputType: uiFields?.showInputType || false,
                    showOptions: uiFields?.showOptions || false,
                    showImageProps: uiFields?.showImageProps || false,
                    
                    // Update type-specific flags - dynamically derived from metadata
                    isTextElement: newConfig.category === 'Text',
                    isTextInput: jsonType === 'TextInput',
                    isTextArea: jsonType === 'TextArea',
                    isSelection: newConfig.category === 'Selection',
                    isDatePicker: jsonType === 'DatePicker',
                    isOptIn: jsonType === 'OptIn',
                    isImage: jsonType === 'Image',
                    
                    // Update constraints and validation state
                    maxLength: newMaxLength,
                    hasError: hasError,
                    errorMessage: errorMessage,
                    
                    // Update type options (for next switch)
                    typeOptions: this.getTypeOptionsForSection(newItemName),
                    
                    // Keep existing value
                    previewText: section.value || defaults?.text || 'Enter content'
                };
                
                return updatedSection;
            }
            return section;
        });
        
        // Force re-render
        this.contentSections = [...this.contentSections];
        this.dispatchContentUpdate();
    }

    handleOptionChange(event) {
        const sectionId = event.target.dataset.sectionId;
        const optionId = event.target.dataset.optionId;
        const newLabel = event.target.value;

        this.contentSections = this.contentSections.map(section => {
            if (section.id === sectionId && section.options) {
                return {
                    ...section,
                    options: section.options.map(opt => 
                        opt.id === optionId ? { ...opt, label: newLabel } : opt
                    )
                };
            }
            return section;
        });
        this.dispatchContentUpdate();
    }

    addOption(event) {
        const sectionId = event.target.dataset.sectionId;

        this.contentSections = this.contentSections.map(section => {
            if (section.id === sectionId && section.options) {
                const config = this.getMetadataConfig(section.itemName);
                const maxOptions = config?.constraints?.maxOptions || 10;

                // Limit to maximum options defined in metadata
                if (section.options.length >= maxOptions) {
                    return section;
                }
                const newOptionId = this.generateSanitizedId(`OPT_${section.options.length + 1}_${section.id}_${Date.now()}`);
                return {
                    ...section,
                    options: [...section.options, { id: newOptionId, label: 'Option' }]
                };
            }
            return section;
        });
        this.dispatchContentUpdate();
    }

    deleteOption(event) {
        const sectionId = event.currentTarget.dataset.sectionId;
        const optionId = event.currentTarget.dataset.optionId;

        this.contentSections = this.contentSections.map(section => {
            if (section.id === sectionId && section.options) {
                // Only allow deletion if there are more than 2 options
                if (section.options.length > 2) {
                    return {
                        ...section,
                        options: section.options.filter(opt => opt.id !== optionId)
                    };
                }
            }
            return section;
        });
        this.dispatchContentUpdate();
    }

    deleteSection(event) {
        const sectionId = event.currentTarget.dataset.sectionId;
        
        // Find the section to check if it has an image
        const section = this.contentSections.find(s => s.id === sectionId);
        
        // If section has an image, delete it from S3 first
        if (section && section.imageUrl && section.awsKey) {
            this.deleteImageFromAWS(section.awsKey, sectionId);
        }
        
        // Remove the section from contentSections
        this.contentSections = this.contentSections.filter(section => section.id !== sectionId);
        this.dispatchContentUpdate();
    }

    dispatchContentUpdate() {
        this.dispatchEvent(new CustomEvent('contentupdate', {
            detail: {
                screenTitle: this.screenTitle,
                buttonLabel: this.buttonLabel,
                sections: this.contentSections
            },
            bubbles: true,
            composed: true
        }));
    }

    /**
     * Method : getS3ConfigData
     * @description : Fetches AWS S3 configuration from Salesforce
     */
    getS3ConfigData() {
        try {
            getS3ConfigSettings()
                .then(result => {
                    if (result != null) {
                        this.confData = result;
                        this.isAWSEnabled = true;
                    }
                })
                .catch(error => {
                    console.error('Error in Apex call getS3ConfigSettings: ', error);
                });
        } catch (error) {
            console.error('Error in getS3ConfigData method: ', error);
        }
    }

    /**
     * Method : initializeAwsSdk
     * @description : Initializes the AWS SDK with configuration data from Salesforce
     */
    initializeAwsSdk(confData) {
        try {
            let AWS = window.AWS;
            if (!AWS) {
                console.error('AWS SDK not loaded');
                return;
            }

            AWS.config.update({
                accessKeyId: confData.MVEX__AWS_Access_Key__c,
                secretAccessKey: confData.MVEX__AWS_Secret_Access_Key__c
            });

            AWS.config.region = confData.MVEX__S3_Region_Name__c;

            this.s3 = new AWS.S3({
                apiVersion: '2006-03-01',
                params: {
                    Bucket: confData.MVEX__S3_Bucket_Name__c
                }
            });
        } catch (error) {
            console.error('Error initializeAwsSdk: ', error);
        }
    }

    /**
     * Method : handleImageUpload
     * @description : Handles image file selection and uploads to AWS
     */
    handleImageUpload(event) {
        const sectionId = event.target.dataset.sectionId;
        const file = event.target.files[0];

        if (!file) return;

        // Validate file type
        const validImageTypes = ['image/jpeg', 'image/png'];
        if (!validImageTypes.includes(file.type)) {
            this.showErrorMessage(sectionId, 'Please upload only JPEG or PNG images');
            event.target.value = '';
            return;
        }

        // Validate file size (300KB max)
        const maxSize = 300 * 1024;
        if (file.size > maxSize) {
            this.showErrorMessage(sectionId, 'Image size must be less than 300KB');
            event.target.value = '';
            return;
        }

        // Upload to AWS
        this.uploadImageToAWS(file, sectionId);
    }

    /**
     * Method : uploadImageToAWS
     * @description : Uploads image file to AWS S3 and stores public URL
     */
    uploadImageToAWS(file, sectionId) {
        this.initializeAwsSdk(this.confData);
        if (!this.isAWSEnabled || !this.s3) {
            console.error('AWS is not configured or initialized');
            this.showErrorMessage(sectionId, 'AWS configuration is not available');
            return;
        }

        const fileName = this.renameFileName(file.name);
        const params = {
            Key: fileName,
            Body: file,
            ContentType: file.type,
            ACL: 'public-read'
        };

        // Update section to show loading state
        const section = this.contentSections.find(s => s.id === sectionId);
        if (section) {
            section.isUploading = true;
            section.uploadError = null;
            this.contentSections = [...this.contentSections];
        }

        this.s3.upload(params, (err, data) => {
            const targetSection = this.contentSections.find(s => s.id === sectionId);
            if (targetSection) {
                targetSection.isUploading = false;
            }

            if (err) {
                console.error('Error uploading to S3:', err);
                this.showErrorMessage(sectionId, 'Failed to upload image. Please try again.');
                this.contentSections = [...this.contentSections];
                return;
            }

            // Store the public URL and AWS key in section data (src property for JSON export)
            if (targetSection) {
                targetSection.src = data.Location; // Store in src for JSON compatibility
                targetSection.imageUrl = data.Location; // Keep imageUrl for backward compatibility
                targetSection.awsKey = fileName;
                targetSection.uploadError = null;
                this.contentSections = [...this.contentSections];
                this.dispatchContentUpdate();
            }
        });
    }

    /**
     * @description Creates a unique filename by appending a timestamp to the base name.
     */
    renameFileName(filename) {
        try {
            if (!filename) return '';

            const dotIndex = filename.lastIndexOf('.');
            const name = dotIndex !== -1 ? filename.slice(0, dotIndex) : filename;
            const ext = dotIndex !== -1 ? filename.slice(dotIndex) : '';

            // Compact timestamp: YYYYMMDDHHMMSS
            const timestamp = new Date().toISOString()
                .replace(/[-:T.Z]/g, '')
                .slice(0, 14);

            // Normalize + encode
            const safeName = encodeURIComponent(
                `${name}_${timestamp}${ext}`.replace(/\s+/g, '_')
            );

            return safeName;
        } catch (error) {
            console.error('error in renameFileName -> ', error);
            return '';
        }
    }


    /**
     * Method : handleImageDelete
     * @description : Deletes image from AWS (only if no parent flow) and clears from section
     */
    handleImageDelete(event) {
        const sectionId = event.currentTarget.dataset.sectionId;
        const section = this.contentSections.find(s => s.id === sectionId);

        if (!section || !section.awsKey) {
            
            this.contentSections = this.contentSections.map(s => {
                if (s.id === sectionId) {
                    return { ...s, value: '', awsKey: '', src: '', imageUrl: null, imageSrc: '', hasImage: false };
                }
                return s;
            });
            this.dispatchContentUpdate();
            return;
        }

        // Check if this flow has a parent flow OR if this flow is a parent to other flows
        if (this.parentFlowId || this.isParentFlow) {
            // Flow has parent or is a parent - don't delete from AWS, just clear from section
            const reason = this.parentFlowId ? 'flow has a parent' : 'flow is a parent to other flows';
            this.contentSections = this.contentSections.map(s => {
                if (s.id === sectionId) {
                    return { ...s, value: '', awsKey: '', src: '', imageUrl: null, imageSrc: '', hasImage: false };
                }
                return s;
            });
            this.dispatchContentUpdate();
            return; // Exit the method - don't proceed to AWS deletion
        }
        
        // Set loading state
        this.imageOperationInProgress = {
            ...this.imageOperationInProgress,
            [sectionId]: true
        };

        // Delete from AWS
        this.deleteImageFromAWS(section.awsKey, sectionId);
    }

    /**
     * Method : deleteImageFromAWS
     * @description : Deletes image from AWS S3 bucket
     */
    deleteImageFromAWS(awsKey, sectionId) {
        if (!this.isAWSEnabled || !this.s3) {
            console.error('AWS is not configured or initialized');
            this.imageOperationInProgress = {
                ...this.imageOperationInProgress,
                [sectionId]: false
            };
            return;
        }

        const params = {
            Key: awsKey
        };

        this.s3.deleteObject(params, (err) => {
            // Clear loading state
            this.imageOperationInProgress = {
                ...this.imageOperationInProgress,
                [sectionId]: false
            };
            
            if (err) {
                console.error('Error deleting from S3:', err);
                return;
            }

            // Clear image data from section and trigger reactivity
            this.contentSections = this.contentSections.map(section => {
                if (section.id === sectionId) {
                    return {
                        ...section,
                        src: null,
                        imageUrl: null,
                        awsKey: null,
                        uploadError: null
                    };
                }
                return section;
            });
            
            // Reset file input
            const fileInput = this.template.querySelector(`input[data-section-id="${sectionId}"]`);
            if (fileInput) {
                fileInput.value = '';
            }
            
            this.dispatchContentUpdate();
        });
    }

    /**
     * Method : showErrorMessage
     * @description : Shows error message for a specific section
     */
    showErrorMessage(sectionId, message) {
        const section = this.contentSections.find(s => s.id === sectionId);
        if (section) {
            section.uploadError = message;
            this.contentSections = [...this.contentSections];
        }
    }

    /**
     * Helper Method : generateSanitizedId
     * @description : Generates unique IDs with only alphabetics and underscores using hash
     * @param {string} baseName - Base name for the ID
     * @param {string|number} uniquifier - Additional value to ensure uniqueness
     * @returns {string} - Sanitized ID containing only alphabetics and underscores
     */
    generateSanitizedId(baseName, uniquifier = '') {
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
     * Helper Method : hashToAlphabetic
     * @description : Converts a numeric hash to alphabetic characters only
     * @param {number} num - Numeric hash value
     * @returns {string} - Alphabetic representation
     */
    hashToAlphabetic(num) {
        const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        let result = '';
        let n = num;
        
        do {
            result = letters[n % 26] + result;
            n = Math.floor(n / 26);
        } while (n > 0);
        
        while (result.length < 6) {
            result = letters[Math.floor(Math.random() * 26)] + result;
        }
        
        return result;
    }

    disconnectedCallback() {
        // Clean up auto-scroll
        this.stopAutoScroll();
        
        // Remove document-level drag listener if component is destroyed during drag
        if (this.boundDragOverHandler) {
            document.removeEventListener('dragover', this.boundDragOverHandler);
            this.boundDragOverHandler = null;
        }
    }

}