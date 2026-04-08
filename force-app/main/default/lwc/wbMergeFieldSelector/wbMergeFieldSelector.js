/*
 * Component Name: wbMergeFieldSelector
 * @description: Reusable merge field selector component with hierarchical field navigation
 * Date: 04/04/2026
 * Created By: Harsh Gandhi
 */
import { LightningElement, api, track } from 'lwc';
import getObjectFieldsWithRelationships from '@salesforce/apex/WBTemplateController.getObjectFieldsWithRelationships';

export default class WbMergeFieldSelector extends LightningElement {

    // PUBLIC API PROPERTIES
    
    _selectedObject = '';
    _previousSelectedObject = ''; // Track previous object to detect changes
    
    @api 
    get selectedObject() {
        return this._selectedObject;
    }
    set selectedObject(value) {
        const oldValue = this._selectedObject;
        this._selectedObject = value;
        
        // Reload fields when object changes (but only after initial load)
        if (value && value !== oldValue && this._hasInitialized) {
            this.handleObjectChangeInternal(value);
        }
    }
    
    @api selectedFieldPath = '';        // Current field path (e.g., "Account.Owner.Name")
    @api selectedFieldLabel = '';       // Display label (e.g., "Account > Owner > Name")
    @api maxHierarchyLevel = 5;         // Maximum relationship depth
    @api disabled = false;              // Disable the picker
    @api placeholder = 'Search fields...'; // Button placeholder

    // PRIVATE PROPERTIES
    
    isDropdownOpen = false;
    isLoading = false;
    searchTerm = '';
    currentExpandedPath = null;
    _hasInitialized = false; // Track if component has been initialized
    
    @track fieldOptionsWithRelationships = []; // Hierarchical field tree
    
    _boundHandleOutsideClick;

    get displayText() {
        return this.selectedFieldLabel || this.placeholder;
    }

    get buttonTitle() {
        return this.selectedFieldLabel || 'Select a field';
    }

    get showBreadcrumbs() {
        return this.breadcrumbs && this.breadcrumbs.length > 0;
    }

    get breadcrumbs() {
        if (!this.currentExpandedPath) {
            return [];
        }

        const pathParts = this.currentExpandedPath.split(' > ');
        const breadcrumbs = [];

        // Root breadcrumb
        breadcrumbs.push({
            id: 'breadcrumb-root',
            label: this.selectedObject || 'Fields',
            path: null,
            isClickable: true,
            isLast: false
        });

        // Build breadcrumbs for each level
        pathParts.forEach((part, index) => {
            const pathToThisLevel = pathParts.slice(0, index + 1).join(' > ');
            breadcrumbs.push({
                id: `breadcrumb-${index}`,
                label: part,
                path: pathToThisLevel,
                isClickable: index < pathParts.length - 1,
                isLast: index === pathParts.length - 1
            });
        });

        // Update isLast for the last breadcrumb
        if (breadcrumbs.length > 0) {
            breadcrumbs[breadcrumbs.length - 1].isLast = true;
        }

        return breadcrumbs;
    }

    get filteredFields() {
        const currentFields = this.getCurrentFields();
        
        if (!currentFields || currentFields.length === 0) {
            return [];
        }

        // Apply search filter
        let fields = currentFields;
        if (this.searchTerm) {
            const term = this.searchTerm.toLowerCase();
            fields = currentFields.filter(field => 
                field.label.toLowerCase().includes(term) ||
                field.apiName?.toLowerCase().includes(term)
            );
        }

        // Calculate hierarchy level
        const currentLevel = this.currentExpandedPath 
            ? this.currentExpandedPath.split(' > ').length 
            : 0;
        const isAtMaxLevel = currentLevel >= (this.maxHierarchyLevel - 1);

        // Map fields with metadata
        return fields.map(field => {
            const canExpand = field.isRelationship && 
                            !isAtMaxLevel && 
                            (!field.children || field.children.length === 0);
            
            const isSelected = this.selectedFieldPath === field.value;

            return {
                ...field,
                canExpand,
                showChevron: field.isRelationship && !isAtMaxLevel,
                cssClass: isSelected 
                    ? 'field-list-item field-list-item-selected' 
                    : 'field-list-item',
                iconName: field.isRelationship ? 'utility:hierarchy' : 'utility:text'
            };
        });
    }

    get hasFilteredFields() {
        return this.filteredFields && this.filteredFields.length > 0;
    }

    connectedCallback() {
        this._boundHandleOutsideClick = this.handleOutsideClick.bind(this);
        
        // Initialize with selected object if provided
        if (this._selectedObject) {
            this.loadRootFields().then(() => {
                // After loading root fields, load relationship children if needed
                this.loadRelationshipChildrenForSelectedPath();
                this._hasInitialized = true;
            });
        } else {
            this._hasInitialized = true;
        }
        
        // Parse currentExpandedPath from selectedFieldLabel if exists
        this.initializeExpandedPath();
    }

    /**
     * Handle object change internally - reload fields when selectedObject changes
     */
    async handleObjectChangeInternal(newObject) {
        // Clear existing field hierarchy and reset navigation state
        this.fieldOptionsWithRelationships = [];
        this.currentExpandedPath = null;
        this.searchTerm = '';
        
        // Load fields for the new object
        if (newObject) {
            await this.loadRootFields();
            // After loading new fields, load relationship children for selected path if any
            await this.loadRelationshipChildrenForSelectedPath();
        }
    }

    renderedCallback() {
        if (this.isDropdownOpen) {
            document.addEventListener('click', this._boundHandleOutsideClick);
        } else {
            document.removeEventListener('click', this._boundHandleOutsideClick);
        }
    }

    // PUBLIC METHODS
    
    /**
     * Refresh fields for current object
     */
    @api
    async refreshFields() {
        if (this.selectedObject) {
            await this.loadRootFields();
        }
    }


    @api
    closeDropdown() {
        this.isDropdownOpen = false;
        this.searchTerm = '';
    }
    
    initializeExpandedPath() {
        if (this.selectedFieldLabel && this.selectedFieldLabel.includes(' > ')) {
            const pathParts = this.selectedFieldLabel.split(' > ');
            if (pathParts.length > 1) {
                // Remove last part (field name) to get relationship path
                this.currentExpandedPath = pathParts.slice(0, -1).join(' > ');
            }
        }
    }

    /**
     * Load relationship children for the pre-selected field path
     * This ensures that when editing, the relationship fields are available
     */
    async loadRelationshipChildrenForSelectedPath() {
        if (!this.selectedFieldPath || !this.selectedFieldPath.includes('.')) {
            return;
        }

        try {
            // Extract all relationship paths from the selected field path
            // E.g., "CreatedById.Manager.Name" -> ["CreatedById", "CreatedById.Manager"]
            const pathParts = this.selectedFieldPath.split('.');
            const relationshipPaths = [];
            
            for (let i = 0; i < pathParts.length - 1; i++) {
                const path = pathParts.slice(0, i + 1).join('.');
                relationshipPaths.push(path);
            }

            if (relationshipPaths.length === 0) {
                return;
            }

            // Load children for all relationship paths
            const resultMap = await getObjectFieldsWithRelationships({
                objectNames: [this.selectedObject],
                relationshipPaths: relationshipPaths
            });

            // Update the tree with loaded children
            for (const [path, childFields] of Object.entries(resultMap)) {
                if (childFields && childFields.length > 0 && path !== this.selectedObject) {
                    this.updateFieldOptionsTree(path, childFields);
                }
            }
        } catch (error) {
            console.error('Error loading relationship children for selected path:', error);
        }
    }

    async loadRootFields() {
        if (!this.selectedObject) return;
        
        this.isLoading = true;
        try {
            const resultMap = await getObjectFieldsWithRelationships({ 
                objectNames: [this.selectedObject], 
                relationshipPaths: []
            });
            
            this.fieldOptionsWithRelationships = resultMap[this.selectedObject] || [];
        } catch (error) {
            console.error('Error loading fields:', error);
            this.dispatchEvent(new CustomEvent('error', {
                detail: { message: error.body?.message || error.message }
            }));
        } finally {
            this.isLoading = false;
        }
    }
    
    toggleDropdown(event) {
        event.stopPropagation();
        
        if (this.disabled) return;

        this.isDropdownOpen = !this.isDropdownOpen;
        
        if (this.isDropdownOpen) {
            if (this.fieldOptionsWithRelationships.length === 0) {
                this.loadRootFields().then(() => {
                    this.loadRelationshipChildrenForSelectedPath();
                });
            } else if (this.currentExpandedPath && this.getCurrentFields().length === 0) {
                // If we have an expanded path but no fields, load the relationship children
                this.loadRelationshipChildrenForSelectedPath();
            }
        }
    }

    handleOutsideClick(event) {
        const selector = this.template.querySelector('.merge-field-selector');
        if (selector && !selector.contains(event.target)) {
            this.closeDropdown();
        }
    }

    handlePanelClick(event) {
        event.stopPropagation();
    }

    handleSearchClick(event) {
        event.stopPropagation();
    }

    handleSearchFocus(event) {
        event.stopPropagation();
    }

    handleSearchChange(event) {
        event.stopPropagation();
        this.searchTerm = event.target.value;
    }

    handleBreadcrumbClick(event) {
        event.stopPropagation();
        const targetPath = event.detail.path;
        
        // Navigate to the clicked breadcrumb level
        if (targetPath === 'null' || targetPath === null || targetPath === '') {
            this.currentExpandedPath = null;
        } else {
            this.currentExpandedPath = targetPath;
        }
        this.searchTerm = '';
    }
    
    handleFieldClick(event) {
        event.stopPropagation();
        
        const fieldValue = event.currentTarget.dataset.value;
        const fieldLabel = event.currentTarget.dataset.label;
        const fieldApiName = event.currentTarget.dataset.apiname;
        const isRelationship = event.currentTarget.dataset.relationship === 'true';
        const canExpand = event.currentTarget.dataset.canexpand === 'true';

        // Calculate current hierarchy level
        const currentPathParts = this.currentExpandedPath 
            ? this.currentExpandedPath.split(' > ') 
            : [];
        const currentHierarchyLevel = currentPathParts.length;
        const isAtMaxLevel = currentHierarchyLevel >= (this.maxHierarchyLevel - 1);

        // If it's a relationship and can expand, load children
        if (isRelationship && canExpand && !isAtMaxLevel) {
            this.expandRelationship(fieldValue, fieldLabel);
            return;
        }

        // If it's a final field selection (not expandable relationship)
        if (!isRelationship || isAtMaxLevel) {
            this.selectField(fieldValue, fieldLabel, fieldApiName, isRelationship);
        }
    }

    
    async expandRelationship(fieldValue, fieldLabel) {
        this.isLoading = true;
        
        try {
            const resultMap = await getObjectFieldsWithRelationships({ 
                objectNames: [this.selectedObject], 
                relationshipPaths: [fieldValue] 
            });
            
            const childFields = resultMap[fieldValue] || [];
            
            // Update the field options tree with loaded children
            this.updateFieldOptionsTree(fieldValue, childFields);
            
            // Navigate into the relationship
            const newPath = this.currentExpandedPath 
                ? `${this.currentExpandedPath} > ${fieldLabel}` 
                : fieldLabel;
            this.currentExpandedPath = newPath;
            this.searchTerm = '';
        } catch (error) {
            console.error('Error loading relationship fields:', error);
            this.dispatchEvent(new CustomEvent('error', {
                detail: { message: error.body?.message || error.message }
            }));
        } finally {
            this.isLoading = false;
        }
    }

    selectField(fieldValue, fieldLabel, fieldApiName, isRelationship) {
        // Build full display label
        let displayLabel = fieldLabel;
        if (this.currentExpandedPath) {
            displayLabel = `${this.currentExpandedPath} > ${fieldLabel}`;
        }

        // Dispatch field selected event
        this.dispatchEvent(new CustomEvent('fieldselected', {
            detail: {
                fieldPath: fieldValue,
                fieldLabel: displayLabel,
                fieldApiName: fieldApiName,
                isRelationship: isRelationship
            }
        }));

        // Close dropdown
        this.closeDropdown();
    }
    
    getCurrentFields() {
        if (!this.currentExpandedPath) {
            return this.fieldOptionsWithRelationships;
        }

        // Navigate through the tree to find current fields
        const pathParts = this.currentExpandedPath.split(' > ');
        let currentFields = this.fieldOptionsWithRelationships;

        for (const part of pathParts) {
            const relationshipField = currentFields.find(f => 
                f.isRelationship && f.label === part
            );
            
            if (relationshipField && relationshipField.children) {
                currentFields = relationshipField.children;
            } else {
                return [];
            }
        }

        return currentFields;
    }

    updateFieldOptionsTree(relationshipPath, childFields) {
        const updateChildren = (fields, path) => {
            return fields.map(field => {
                if (field.value === path) {
                    return { ...field, children: childFields };
                }
                if (field.children && field.children.length > 0) {
                    return { ...field, children: updateChildren(field.children, path) };
                }
                return field;
            });
        };

        this.fieldOptionsWithRelationships = updateChildren(
            this.fieldOptionsWithRelationships, 
            relationshipPath
        );
    }

    disconnectedCallback() {
        document.removeEventListener('click', this._boundHandleOutsideClick);
    }

}