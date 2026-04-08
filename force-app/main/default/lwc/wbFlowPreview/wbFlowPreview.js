import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class WbFlowPreview extends NavigationMixin(LightningElement) {
    @api flowname;
    @api iserror;
    showPreview = false;
    @track screens = [];
    @track detailsOptions = [];
    detailsValue;
    previewClass = 'preview';
    isNight = false;
    theme = 'light';

    @track inputValues = {};
    @track inputFocus = {};
    @track inputErrors = {}; // Track validation errors for required fields
    @api selectedtheme = 'light';
    internalCurrentScreenId;
    @track parsedJson = null; 
    previousScreenId = null;
    @track navigationHistory = []; // Track navigation history for main flow

    screenTitle = ''; 
    @track screenChildren = []; 
    hasFooter = false; 
    footerLabel = ''; 
    footerAction = '';
    showBackButton = false;
    isReorderOperation = false; // Track if JSON change is due to reordering 

    @api
    set jsonstringdata(value) {
        if (!this.iserror) {
            // Check if value has actually changed
            const hasChanged = this.internalJsonStringData !== value;
            this.internalJsonStringData = value;            
            try {
                if(value){
                    const parsed = JSON.parse(value);
                    const oldScreenCount = this.screens ? this.screens.length : 0;
                    
                    // Always update screens from fresh parsed data
                    this.screens = parsed.screens || [];
                    const newScreenCount = this.screens.length;
                    // Build options for dropdown - all screens are in main array now
                    // Build fresh array to ensure reactivity
                    const newOptions = [];
                    this.screens.forEach(screen => {
                        const isReadMore = screen.id && screen.id.startsWith('READ_MORE_');
                        newOptions.push({
                            label: isReadMore ? `${screen.title || screen.id} (Read More)` : (screen.title || screen.id),
                            value: screen.id
                        });
                    });
                    this.detailsOptions = newOptions;
                    
                    // Reset to first screen when screens are added/removed/reordered (keep preview open)
                    if (hasChanged && (this.isReorderOperation || newScreenCount !== oldScreenCount)) {
                        // Reset to first screen (don't close preview)
                        this.detailsValue = this.detailsOptions.length ? this.detailsOptions[0].value : null;
                        this.internalCurrentScreenId = this.detailsValue;
                        // Clear navigation state
                        this.navigationHistory = [];
                        this.previousScreenId = null;
                        this.inputValues = {};
                        this.inputFocus = {};
                        this.inputErrors = {};
                        this.isReorderOperation = false; // Reset flag after use
                    } else {
                        // For content changes, keep current screen if it exists
                        const currentScreenExists = this.internalCurrentScreenId && 
                            this.detailsOptions.some(opt => opt.value === this.internalCurrentScreenId);
                        
                        if (!currentScreenExists) {
                            // Fall back to first screen only if current screen no longer exists
                            this.detailsValue = this.detailsOptions.length ? this.detailsOptions[0].value : null;
                            this.internalCurrentScreenId = this.detailsValue;
                        } else {
                            // Keep current screen
                            this.detailsValue = this.internalCurrentScreenId;
                        }
                    }
                    
                    // Always update parsedJson with fresh data
                    this.parsedJson = parsed;
                    
                    // Always regenerate preview when data is received to ensure it reflects current order
                    this.generatePreview();
                }
            } catch (e) {
                console.error('Error parsing JSON data in wbcp_flowPreview in wbcp_flowPreview:', e);
                this.detailsOptions = [];
                this.detailsValue = null;
                this.parsedJson = null; 
                this.screenChildren = []; 
            }
        }
    }

    get jsonstringdata() {
        return this.internalJsonStringData;
    }

    get previewContainerClass() {
        return `preview-container ${this.theme}-theme`;
    }

    get modeClass() {
        return this.isNight ? 'toggle night' : 'toggle day';
    }

    @api
    get currentscreenid() {
        return this.internalCurrentScreenId;
    }

    set currentscreenid(value) {
        // Preview is now independent of selected screen
        // It always works based on screen order, not selection
        // This setter is kept for backward compatibility but does not change preview state
    }

    get isOptionSelected() {
        return !this.inputValues[this.child?.name];
    }

    get disableDetailsCombobox() {
        return !this.showPreview;
    }

    getInputClass(name) { 
        const hasValue = this.inputFocus[name] || (this.inputValues[name] && this.inputValues[name] !== '');
        const hasError = this.inputErrors[name];
        return `whatsapp-flow-previewer-input ${hasValue ? 'active' : ''} ${hasError ? 'error-border' : ''}`; 
    }

    /**
    * Method : connectedCallback
    * @description : Lifecycle hook to add event listeners for window resize.
    */
    connectedCallback() {
        window.addEventListener('resize', this.adjustContentHeight.bind(this)); 
        this.selectedtheme = this.theme;
    }

    /**
    * Method : renderedCallback
    * @description : Lifecycle hook to set theme attribute and adjust content height after each render.
    */
    renderedCallback() {
        const mainContainer = this.template.querySelector('.whatsapp-flow-previewer-main-container'); 
        if (mainContainer) {
            mainContainer.setAttribute('data-theme', this.selectedtheme); 
        }
        this.adjustContentHeight(); 
    }

    /**
    * Method : runPreview
    * @description : Public method to run the preview generation and adjust content height.
    */
    @api
    runPreview() {
        this.generatePreview();
        this.adjustContentHeight(); 
    }

    /**
    * Method : markAsReorderOperation
    * @description : Marks the next JSON update as a reorder operation to reset to first screen.
    */
    @api
    markAsReorderOperation() {
        this.isReorderOperation = true;
    }

    /**
    * Method : handlePreviewFlow
    * @description : Handles the preview flow button click to show the preview with animation.
    */
    handlePreviewFlow() {
        this.showPreview = true;
        this.navigationHistory = []; // Reset navigation history when opening preview
        this.previousScreenId = null;
        // Clear all input data when opening preview fresh
        this.inputValues = {};
        this.inputFocus = {};
        this.inputErrors = {}; // Clear errors
        requestAnimationFrame(() => {
            this.previewClass = 'preview slide-up';
            this.generatePreview();
        });
    }

    /**
    * Method : handleDetailsChange
    * @description : Handles the change event of the details combobox to update the current screen and regenerate the preview.
    */
    handleDetailsChange(event) {
        this.detailsValue = event.detail.value;
        this.internalCurrentScreenId = this.detailsValue;
        this.generatePreview();
    }

    /**
    * Method : handleRefreshAll
    * @description : Handles the refresh all button click to reset all input fields and regenerate the preview.
    */
    handleRefreshAll() {
        this.inputFocus = {};
        this.inputValues = {};
        this.inputErrors = {}; // Clear errors
        this.navigationHistory = [];
        this.previousScreenId = null;
        // Reset to first screen
        if (this.parsedJson && this.parsedJson.screens && this.parsedJson.screens.length > 0) {
            this.internalCurrentScreenId = this.parsedJson.screens[0].id;
            this.detailsValue = this.internalCurrentScreenId;
        }
        this.generatePreview();
        this.adjustContentHeight(); 
    }

    /**
    * Method : handleCloseClick
    * @description : Handles the close button click to hide the preview with animation.
    */
    handleCloseClick() {
        this.previewClass = 'preview slide-down';
        setTimeout(() => {
            this.showPreview = false;
            // Clear all input data when closing preview
            this.inputValues = {};
            this.inputFocus = {};
            this.inputErrors = {}; // Clear errors
            this.navigationHistory = [];
            this.previousScreenId = null;
            // Reset to first screen
            if (this.parsedJson && this.parsedJson.screens && this.parsedJson.screens.length > 0) {
                this.internalCurrentScreenId = this.parsedJson.screens[0].id;
                this.detailsValue = this.internalCurrentScreenId;
            }
        }, 300);
    }

    /**
    * Method : toggleMode
    * @description : Toggles between light and dark mode and updates the theme accordingly.
    */
    toggleMode() {
        this.isNight = !this.isNight;
        this.theme = this.isNight ? 'dark' : 'light';
        this.selectedtheme = this.theme;
    }

    /**
    * Method : adjustContentHeight
    * @description : Adjusts the content height based on the presence of the footer to ensure proper layout.
    */
    adjustContentHeight() { 
        try {
            const content = this.template.querySelector('.whatsapp-flow-previewer-content'); 
            if (content) {
                const contentHeight = this.hasFooter ? '66%' : '86%'; 
                this.template.host.style.setProperty('--content-height', contentHeight);
            }
        } catch (error) {
            console.error('Error in adjustContentHeight : ', error);
        }
    }

    /**
    * Method : generatePreview
    * @description : Generates the preview content based on the parsed JSON data.
    */
    generatePreview() { 
        try {
            if (this.parsedJson) {
                if (!this.internalCurrentScreenId) {
                    this.internalCurrentScreenId = this.parsedJson.screens[0]?.id || null; 
                }

                // All screens are now in main array (including read more screens)
                let screen = this.parsedJson.screens.find(screen => screen.id === this.internalCurrentScreenId);
                
                if (screen) {
                    this.screenTitle = screen.title; 
                    const newScreenChildren = []; // Build new array instead of mutating
                    this.hasFooter = false; 
                    this.footerLabel = ''; 
                    this.footerAction = ''; 
    
                    const form = screen.layout.children.find(child => child.type === 'Form') || screen.layout;
                    
                    // Initialize default values for fields that don't have values yet
                    form.children.forEach(child => {
                        if (child.name && this.inputValues[child.name] === undefined) {
                            if (child.type === 'CheckboxGroup' && child['init-value']) {
                                // Initialize CheckboxGroup with init-value array
                                this.inputValues[child.name] = Array.isArray(child['init-value']) 
                                    ? [...child['init-value']] 
                                    : [child['init-value']];
                            } else if (child.type === 'OptIn' && child['init-value'] !== undefined) {
                                // Initialize OptIn with boolean init-value
                                this.inputValues[child.name] = child['init-value'] === true || child['init-value'] === 'true';
                            } else if (child['init-value'] !== undefined && child['init-value'] !== null) {
                                // Initialize other fields with their init-value
                                this.inputValues[child.name] = child['init-value'];
                            }
                        }
                    }); 
    
                    form.children.forEach(child => { 
                        // For OptIn, default required to true if not explicitly set to false
                        const isRequired = child.type === 'OptIn' 
                            ? (child.required !== false) 
                            : (child.required || false);
                        
                        const commonProps = { 
                            name: child.name, 
                            label: child.label, 
                            text: child.text, 
                            dataSource: child['data-source'], 
                            inputClass: this.getInputClass(child.name),
                            hasReadMore: child['on-click-action']?.name === 'navigate' && child['on-click-action']?.next?.name,
                            readMoreScreenId: child['on-click-action']?.next?.name || null,
                            value: this.inputValues[child.name] || '',
                            required: isRequired,
                            helperText: child['helper-text'] || '',
                            placeholder: child.placeholder || ''
                        };

                        if (child.type === 'TextHeading') { 
                            newScreenChildren.push({ ...commonProps, isTextHeading: true }); 
                        } else if (child.type === 'TextSubheading') { 
                            newScreenChildren.push({ ...commonProps, isTextSubheading: true }); 
                        } else if (child.type === 'TextBody') { 
                            newScreenChildren.push({ ...commonProps, isTextBody: true }); 
                        } else if (child.type === 'TextCaption') { 
                            newScreenChildren.push({ ...commonProps, isTextCaption: true }); 
                        } else if (child.type === 'TextInput') { 
                            newScreenChildren.push({ ...commonProps, isTextInput: true, inputType: child['input-type'], errorMessage: this.inputErrors[child.name] || '' }); 
                        } else if (child.type === 'TextArea') { 
                            newScreenChildren.push({ ...commonProps, isTextArea: true, errorMessage: this.inputErrors[child.name] || '' }); 
                        } else if (child.type === 'RadioButtonsGroup') { 
                            const dataSourceWithOptions = (child['data-source'] || []).map(option => ({ 
                                ...option,
                                checked: this.inputValues[child.name] === option.id 
                            }));
                            newScreenChildren.push({ ...commonProps, isRadioButtonsGroup: true, dataSource: dataSourceWithOptions, errorMessage: this.inputErrors[child.name] || '' }); 
                        } else if (child.type === 'CheckboxGroup') { 
                            const currentValue = this.inputValues[child.name];
                            const checkedValues = Array.isArray(currentValue) ? currentValue : [];
                            const dataSourceWithOptions = (child['data-source'] || []).map(option => ({ 
                                ...option,
                                checked: checkedValues.includes(option.id) 
                            }));
                            newScreenChildren.push({ ...commonProps, isCheckboxGroup: true, dataSource: dataSourceWithOptions, errorMessage: this.inputErrors[child.name] || '' }); 
                        } else if (child.type === 'OptIn') { 
                            const isChecked = this.inputValues[child.name] === true || this.inputValues[child.name] === 'true';
                            newScreenChildren.push({ 
                                ...commonProps,
                                isOptIn: true,
                                checked: isChecked,
                                errorMessage: this.inputErrors[child.name] || ''
                            });
                        } else if (child.type === 'Dropdown') { 
                            const dataSourceWithOptions = (child['data-source'] || []).map(option => ({ 
                                ...option,
                                selected: this.inputValues[child.name] === option.id 
                            }));
                            newScreenChildren.push({ ...commonProps, isDropdown: true, dataSource: dataSourceWithOptions, errorMessage: this.inputErrors[child.name] || '' }); 
                        } else if (child.type === 'DatePicker') { 
                            newScreenChildren.push({ ...commonProps, isDatePicker: true, errorMessage: this.inputErrors[child.name] || '' }); 
                        } else if (child.type === 'Image') { 
                            if (child.src) {
                                const imageHeight = child.height || 200;
                                newScreenChildren.push({ 
                                    ...commonProps, 
                                    isImage: true, 
                                    src: child.src, 
                                    alt: child['alt-text'],
                                    height: imageHeight,
                                    imageStyle: `height: ${imageHeight}px;`
                                }); 
                            }
                        } else if (child.type === 'Footer') { 
                            this.hasFooter = true; 
                            this.footerLabel = child.label; 
                            this.footerAction = JSON.stringify(child['on-click-action']); 
                        }
                    });
                    
                    // Assign the new array to trigger reactivity
                    this.screenChildren = newScreenChildren;
                    
                    // Show back button
                    this.showBackButton = this.previousScreenId !== null || this.navigationHistory.length > 0;
                    this.adjustContentHeight();
                    
                     
                }
            }
        } catch (error) {
            console.error('Error in generatePreview : ' , error);
        }
    }

    /**
    * Method : handleInputChange
    * @description : Handles input changes for various input types and updates the inputValues state accordingly.
    */
    handleInputChange(event) { 
        try {
            const { name, value, type, checked } = event.target;
            
            // Clear error for this field when user starts typing/interacting
            if (this.inputErrors[name]) {
                const newErrors = { ...this.inputErrors };
                delete newErrors[name];
                this.inputErrors = newErrors;
                
                // Update the error message in screenChildren without full regeneration
                this.screenChildren = this.screenChildren.map(child => {
                    if (child.name === name) {
                        return { ...child, errorMessage: '', inputClass: this.getInputClass(name) };
                    }
                    return child;
                });
            }
            
            // Update inputValues based on field type
            if (type === 'checkbox') {
                // Check if this is a CheckboxGroup (has value attribute) or OptIn (no value or single checkbox)
                if (value && value !== 'on') {
                    // This is a CheckboxGroup - handle as array
                    const currentValues = Array.isArray(this.inputValues[name]) ? [...this.inputValues[name]] : []; 
                    if (checked) { 
                        if (!currentValues.includes(value)) { 
                            currentValues.push(value); 
                        }
                    } else { 
                        const index = currentValues.indexOf(value); 
                        if (index > -1) { 
                            currentValues.splice(index, 1); 
                        }
                    }
                    this.inputValues = { ...this.inputValues, [name]: currentValues };
                    
                    // Update checkbox state in screenChildren without full regeneration
                    this.screenChildren = this.screenChildren.map(child => {
                        if (child.name === name && child.isCheckboxGroup) {
                            const updatedDataSource = (child.dataSource || []).map(option => ({
                                ...option,
                                checked: currentValues.includes(option.id)
                            }));
                            return { ...child, dataSource: updatedDataSource, errorMessage: '' };
                        }
                        return child;
                    });
                } else {
                    // This is an OptIn - handle as boolean
                    this.inputValues = { ...this.inputValues, [name]: checked };
                    
                    // Update OptIn checkbox state in screenChildren without full regeneration
                    this.screenChildren = this.screenChildren.map(child => {
                        if (child.name === name && child.isOptIn) {
                            return { ...child, checked: checked, errorMessage: '' };
                        }
                        return child;
                    });
                }
            } else if (type === 'radio') { 
                this.inputValues = { ...this.inputValues, [name]: value };
                
                // Update radio state in screenChildren without full regeneration
                this.screenChildren = this.screenChildren.map(child => {
                    if (child.name === name && child.isRadioButtonsGroup) {
                        const updatedDataSource = (child.dataSource || []).map(option => ({
                            ...option,
                            checked: value === option.id
                        }));
                        return { ...child, dataSource: updatedDataSource, errorMessage: '' };
                    }
                    return child;
                });
            } else if (type === 'select-one') {
                this.inputValues = { ...this.inputValues, [name]: value };
                
                // Update dropdown state in screenChildren without full regeneration
                this.screenChildren = this.screenChildren.map(child => {
                    if (child.name === name && child.isDropdown) {
                        const updatedDataSource = (child.dataSource || []).map(option => ({
                            ...option,
                            selected: value === option.id
                        }));
                        return { ...child, dataSource: updatedDataSource, value: value, errorMessage: '', inputClass: this.getInputClass(name) };
                    }
                    return child;
                });
                
                if (value) { 
                    event.target.classList.add('active'); 
                } else { 
                    event.target.classList.remove('active'); 
                }
            } else if (type === 'date') {
                this.inputValues = { ...this.inputValues, [name]: value };
                
                // Update value in screenChildren without full regeneration
                this.screenChildren = this.screenChildren.map(child => {
                    if (child.name === name && child.isDatePicker) {
                        return { ...child, value: value, errorMessage: '', inputClass: this.getInputClass(name) };
                    }
                    return child;
                });
                
                if (value) { 
                    event.target.classList.add('active'); 
                } else { 
                    event.target.classList.remove('active'); 
                }
            }
            else { 
                this.inputValues = { ...this.inputValues, [name]: value };
                
                // Update value in screenChildren for text inputs/textareas without full regeneration
                this.screenChildren = this.screenChildren.map(child => {
                    if (child.name === name && (child.isTextInput || child.isTextArea)) {
                        return { ...child, value: value, errorMessage: '', inputClass: this.getInputClass(name) };
                    }
                    return child;
                });
            }
        } catch (error) {
            console.error('Error in handleInputChange : ', error);
        }
    }

    /**
    * Method : handleInputFocus
    * @description : Handles input focus event to update focus state and apply active class.
    */
    handleInputFocus(event) { 
        const { name } = event.target; 
        this.inputFocus = { ...this.inputFocus, [name]: true }; 
        event.target.classList.add('active'); 
        
        // Update inputClass in screenChildren to reflect focus state
        this.screenChildren = this.screenChildren.map(child => {
            if (child.name === name && (child.isTextInput || child.isTextArea || child.isDropdown || child.isDatePicker)) {
                return { ...child, inputClass: this.getInputClass(name) };
            }
            return child;
        });
    }

    /**
    * Method : handleInputBlur
    * @description : Handles input blur event to update focus state and apply active class.
    */
    handleInputBlur(event) { 
        const { name, value } = event.target; 
        this.inputFocus = { ...this.inputFocus, [name]: false }; 
        const trimmedValue = value ? value.trim() : '';
        if (!trimmedValue) { 
            event.target.classList.remove('active'); 
        }
        
        // Update inputClass in screenChildren to reflect blur state
        this.screenChildren = this.screenChildren.map(child => {
            if (child.name === name && (child.isTextInput || child.isTextArea || child.isDropdown || child.isDatePicker)) {
                return { ...child, inputClass: this.getInputClass(name) };
            }
            return child;
        });
    }

    /**
    * Method : handleDropdownChange
    * @description : Handles dropdown change event to update input values and apply active class.
    */
    handleDropdownChange(event) { 
        this.handleInputChange(event); 
        const selectElement = event.target; 
        if (selectElement.value) { 
            selectElement.classList.add('active'); 
        } else { 
            selectElement.classList.remove('active'); 
        }
    }

    /**
    * Method : handleReadMoreClick
    * @description : Handles navigation to read more screen.
    */
    handleReadMoreClick(event) {
        event.preventDefault();
        const screenId = event.target.dataset.screenId;
        if (screenId) {
            this.previousScreenId = this.internalCurrentScreenId;
            this.internalCurrentScreenId = screenId;
            this.detailsValue = screenId;
            this.generatePreview();
        }
    }

    /**
    * Method : handleBackClick
    * @description : Handles back navigation from read more screen.
    */
    handleBackClick(event) {
        event.preventDefault();
        
        // Check if we're in read more mode first
        if (this.previousScreenId) {
            this.internalCurrentScreenId = this.previousScreenId;
            this.detailsValue = this.previousScreenId;
            this.previousScreenId = null;
            this.generatePreview();
        } 
        // Otherwise, go back in main flow navigation history
        else if (this.navigationHistory.length > 0) {
            const prevScreen = this.navigationHistory.pop();
            this.internalCurrentScreenId = prevScreen;
            this.detailsValue = prevScreen;
            this.generatePreview();
        }
    }

    /**
    * Method : handleContinueClick
    * @description : Handles navigation to the next screen.
    */
    handleContinueClick(event) { 
        event.preventDefault();
        event.stopPropagation();
        
        // Validate required fields before navigation
        if (!this.validateRequiredFields()) {
            return; // Stop navigation if validation fails
        }
        
        const actionString = event.target.dataset.action; 
        try { 
            const action = JSON.parse(actionString); 
            
            if (action.name === 'navigate' && action.next) { 
                // Extract screen name from next object or use directly if string
                const nextScreen = typeof action.next === 'object' ? action.next.name : action.next;
                
                if (nextScreen) {
                    // Add current screen to navigation history for main flow
                    if (this.internalCurrentScreenId && !this.navigationHistory.includes(this.internalCurrentScreenId)) {
                        this.navigationHistory.push(this.internalCurrentScreenId);
                    }
                    
                    this.previousScreenId = null; // Reset read more tracking
                    this.internalCurrentScreenId = nextScreen;
                    this.detailsValue = nextScreen;
                    this.generatePreview();
                }
            }
        } catch (e) { 
            console.error('Invalid action JSON:', e); 
        }
    }

    /**
    * Method : validateRequiredFields
    * @description : Validates all required fields on current screen
    * @returns {boolean} - True if all required fields are filled, false otherwise
    */
    validateRequiredFields() {
        try {
            const errors = {};
            let isValid = true;

            // Get current screen (all screens are in main array now)
            let screen = this.parsedJson.screens.find(s => s.id === this.internalCurrentScreenId);

            if (!screen) return true;

            const form = screen.layout.children.find(child => child.type === 'Form') || screen.layout;
            
            // Check each field for required validation
            form.children.forEach(child => {
                // For OptIn, default required to true if not explicitly set to false
                const isRequired = child.type === 'OptIn' 
                    ? (child.required !== false) 
                    : child.required;
                    
                if (isRequired) {
                    const value = this.inputValues[child.name];
                    
                    // Check if field is empty based on type
                    if (child.type === 'CheckboxGroup') {
                        if (!value || !Array.isArray(value) || value.length === 0) {
                            errors[child.name] = 'Please select at least one option';
                            isValid = false;
                        }
                    } else if (child.type === 'OptIn') {
                        if (value !== true && value !== 'true') {
                            errors[child.name] = 'You must agree to continue';
                            isValid = false;
                        }
                    } else if (child.type === 'TextInput') {
                        // Check if empty
                        if (!value || value.toString().trim() === '') {
                            errors[child.name] = 'This field is required';
                            isValid = false;
                        } else {
                            // Additional validation based on input type
                            const inputType = child['input-type'] || 'text';
                            
                            if (inputType === 'email') {
                                const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
                                if (!emailRegex.test(value)) {
                                    errors[child.name] = 'Please enter a valid email address';
                                    isValid = false;
                                }
                            } else if (inputType === 'number') {
                                if (isNaN(value) || value === '') {
                                    errors[child.name] = 'Please enter a valid number';
                                    isValid = false;
                                }
                            } else if (inputType === 'tel') {
                                const phoneRegex = /^[0-9+\-\s()]+$/;
                                if (!phoneRegex.test(value) || value.replace(/[^0-9]/g, '').length < 10) {
                                    errors[child.name] = 'Please enter a valid phone number';
                                    isValid = false;
                                }
                            } else if (inputType === 'url') {
                                try {
                                    new URL(value);
                                } catch {
                                    errors[child.name] = 'Please enter a valid URL';
                                    isValid = false;
                                }
                            }
                        }
                    } else if (child.type === 'TextArea') {
                        if (!value || value.toString().trim() === '') {
                            errors[child.name] = 'This field is required';
                            isValid = false;
                        }
                    } else if (child.type === 'RadioButtonsGroup' || child.type === 'Dropdown') {
                        if (!value || value.toString().trim() === '') {
                            errors[child.name] = 'Please select an option';
                            isValid = false;
                        }
                    } else if (child.type === 'DatePicker') {
                        if (!value || value.toString().trim() === '') {
                            errors[child.name] = 'Please select a date';
                            isValid = false;
                        }
                    } else {
                        // For other types
                        if (!value || value.toString().trim() === '') {
                            errors[child.name] = 'This field is required';
                            isValid = false;
                        }
                    }
                }
            });

            this.inputErrors = errors;
            
            // Update error messages in screenChildren without full DOM regeneration
            if (!isValid) {
                this.screenChildren = this.screenChildren.map(child => {
                    if (child.name && errors[child.name]) {
                        return { 
                            ...child, 
                            errorMessage: errors[child.name],
                            inputClass: this.getInputClass(child.name)
                        };
                    }
                    return child;
                });
            }

            return isValid;
        } catch (error) {
            console.error('Error in validateRequiredFields:', error);
            return true; // Allow navigation on error
        }
    }

    /**
    * Method : disconnectedCallback
    * @description : Lifecycle hook to remove event listeners when component is removed from DOM.
    */
    disconnectedCallback() {
        window.removeEventListener('resize', this.adjustContentHeight.bind(this)); 
    }
}