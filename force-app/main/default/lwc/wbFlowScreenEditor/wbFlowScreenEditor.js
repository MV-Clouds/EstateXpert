import { LightningElement, api, track } from 'lwc';
import getFlowElementTypes from '@salesforce/apex/WhatsAppFlowControllerV2.getFlowElementTypes';

export default class WbFlowScreenEditor extends LightningElement {
    @api parentFlowId = null;
    @api isParentFlow = false;

    @track metadataMap = {};
    
    flowElementTypes = null;
    showDropdown = false;
    activeCategory = null;
    contentCount = 0;
    readMoreMode = false;
    json = null;
    screenId = null;
    parsedJson = null;
    previousScreenId = null;
    pendingScreenLoad = null;
    contentEditorRef = null;
    boundDocumentClickHandler = null;
    isMetadataReady = false;

    @api
    get jsonData() {
        return this.json;
    }

    set jsonData(value) {
        if (this.json !== value) {
            this.json = value;
            this.parseJsonData(value);
        }
    }

    @api
    get currentScreenId() {
        return this.screenId;
    }

    set currentScreenId(value) {
        if (this.screenId !== value) {
            this.screenId = value;
            this.updateCurrentScreen();
        }
    }

    get categories() {
        if (!this.flowElementTypes) return [];

        // Filter categories based on read more mode
        const allowedCategories = this.readMoreMode ? ['Text', 'Media'] : Object.keys(this.flowElementTypes);

        return allowedCategories
            .filter(key => this.flowElementTypes[key])
            .map(key => {
                const items = this.flowElementTypes[key];
                const categoryIcon =
                    items && items.length > 0 ? items[0].typeIcon : 'utility:settings';

                return {
                    name: key,
                    label: this.formatCategoryLabel(key),
                    icon: categoryIcon,
                    items,
                    submenuClass: 'submenu'
                };
            });
    }

    get addContentButtonTitle() {
        return this.isMaxContentReached ? 'You can add a maximum of 8.' : 'Add content';
    }

    get isMaxContentReached() {
        return this.contentCount >= 8;
    }

    connectedCallback() {
        this.fetchFlowElementTypes();
        this.boundDocumentClickHandler = this.handleDocumentClick.bind(this);
        document.addEventListener('click', this.boundDocumentClickHandler);
    }

    renderedCallback() {
        if (this.pendingScreenLoad !== undefined) {
            this.loadScreenIntoEditor();
        }
    }

    fetchFlowElementTypes() {
        getFlowElementTypes()
            .then(result => {                
                this.flowElementTypes = result;
                
                const tempMetadataMap = {};
                
                Object.entries(result || {}).forEach(([categoryKey, categoryItems]) => {
                    if (Array.isArray(categoryItems)) {
                        categoryItems.forEach((item) => {
                            if (item.options && item.developerName) {
                                tempMetadataMap[item.developerName] = item.options;
                            }
                        });
                    }
                });
                
                this.metadataMap = tempMetadataMap;
                this.isMetadataReady = true;
                
                if (this.parsedJson && this.screenId) {
                    this.updateCurrentScreen();
                }
            })
            .catch(error => {
                console.error('Error fetching flow element types:', error);
            });
    }

    formatCategoryLabel(key) {
        return key.replace(/([A-Z])/g, ' $1').trim();
    }

    parseJsonData(jsonString) {
        try {
            if (!jsonString) {
                this.parsedJson = null;
                this.pendingScreenLoad = null;
                return;
            }

            this.parsedJson = JSON.parse(jsonString);
            this.updateCurrentScreen();
        } catch (err) {
            console.error('Error parsing JSON in flowScreenEditor:', err);
            this.parsedJson = null;
            this.pendingScreenLoad = null;
        }
    }

    updateCurrentScreen() {
        try {
            if (!this.parsedJson || !this.screenId) {
                if (this.previousScreenId !== null) {
                    this.previousScreenId = null;
                    this.pendingScreenLoad = null;
                    this.contentCount = 0;
                    this.loadScreenIntoEditor();
                }
                return;
            }

            if (!this.isMetadataReady) {
                return;
            }

            if (this.previousScreenId !== this.screenId) {
                this.previousScreenId = this.screenId;
                const screens = this.parsedJson.screens || [];
                const foundScreen = screens.find(s => s.id === this.screenId);
                
                this.pendingScreenLoad = foundScreen;
                this.loadScreenIntoEditor();
            }
        } catch (error) {
            console.error('Error updating current screen:', error);
            this.pendingScreenLoad = null;
            this.loadScreenIntoEditor();
        }
    }

    loadScreenIntoEditor() {
        try {
            if (!this.contentEditorRef) {
                this.contentEditorRef = this.template.querySelector('c-wb-flow-content-editor');
            }

            if (this.contentEditorRef && this.pendingScreenLoad !== undefined) {
                this.contentEditorRef.metadataMap = this.metadataMap;
                this.contentEditorRef.loadScreenData(this.pendingScreenLoad);
                this.contentEditorRef.setReadMoreMode(this.readMoreMode);
                this.pendingScreenLoad = undefined;
                this.contentCount = this.contentEditorRef.getContentCount();
            }
        } catch (error) {
            console.error('Error loading screen into editor:', error);
        }
    }

    @api
    setReadMoreMode(isReadMoreMode) {
        this.readMoreMode = isReadMoreMode;
        if (this.contentEditorRef) {
            this.contentEditorRef.setReadMoreMode(isReadMoreMode);
        }
    }

    handleAddContent(event) {
        event.stopPropagation();
        
        if (this.isMaxContentReached) {
            return;
        }
        
        this.showDropdown = !this.showDropdown;
        if (!this.showDropdown) {
            this.closeDropdown();
        }
    }

    handleCategoryClick(event) {
        event.stopPropagation();
        const clickedCategory = event.currentTarget.dataset.category;
        
        // Toggle: if same category clicked, close it; otherwise open the new one
        if (this.activeCategory === clickedCategory) {
            this.activeCategory = null;
        } else {
            this.activeCategory = clickedCategory;
        }
    }

    closeDropdown() {
        this.showDropdown = false;
        this.activeCategory = null;
    }

    handleDocumentClick(event) {
        if (!this.showDropdown) return;

        const path = event.composedPath();
        const dropdownContainer = this.template.querySelector('.dropdown-container');

        if (dropdownContainer && !path.includes(dropdownContainer)) {
            this.closeDropdown();
        }
    }

    handleCategoryHover(event) {
        this.activeCategory = event.currentTarget.dataset.category;
    }

    getTotalImageCount() {
        try {
            if (!this.parsedJson?.screens) return 0;
            
            let totalImages = 0;
            this.parsedJson.screens.forEach(screen => {
                if (screen.layout?.children) {
                    screen.layout.children.forEach(child => {
                        if (child.type === 'Image') {
                            totalImages++;
                        }
                    });
                }
            });
            return totalImages;
        } catch (error) {
            console.error('Error counting total images:', error);
            return 0;
        }
    }

    handleItemSelect(event) {
        try {
            event.stopPropagation();

            const category = event.currentTarget.dataset.category;
            const itemName = event.currentTarget.dataset.item;

            // Check global image limit before adding
            if (itemName === 'Image') {
                const totalImages = this.getTotalImageCount();
                if (totalImages >= 12) {
                    this.dispatchEvent(new CustomEvent('showerror', {
                        detail: {
                            title: 'Maximum Images Reached',
                            message: 'You can add a maximum of 12 images across all screens in the flow.',
                            variant: 'error'
                        },
                        bubbles: true,
                        composed: true
                    }));
                    this.closeDropdown();
                    return;
                }
            }

            const itemData = this.flowElementTypes[category]?.find(
                item => item.developerName === itemName
            );

            if (!itemData) {
                console.warn('Item data not found for:', { category, itemName });
                return;
            }

            if (!this.contentEditorRef) {
                this.contentEditorRef = this.template.querySelector('c-wb-flow-content-editor');
            }

            if (this.contentEditorRef) {
                this.contentEditorRef.metadataMap = this.metadataMap;
                this.contentEditorRef.addContentSection({
                    category,
                    itemName: itemName,
                    itemData: itemData
                });
            } else {
                console.warn('Content editor not found');
            }

            this.closeDropdown();
        } catch (err) {
            console.error('Error stack:', err.stack);
        }
    }

    handleContentUpdate(event) {
        try {
            // Stop the original event from bubbling further - we'll dispatch a new one with screenId
            event.stopPropagation();
            
            const contentData = event.detail;
            
            if (!this.contentEditorRef) {
                this.contentEditorRef = this.template.querySelector('c-wb-flow-content-editor');
            }
            if (this.contentEditorRef) {
                this.contentCount = this.contentEditorRef.getContentCount();
            }
            
            if (!this.screenId) {
                console.warn('No screenId available in wbFlowScreenEditor - skipping content update dispatch');
                return;
            }
            
            this.dispatchEvent(new CustomEvent('contentupdate', {
                detail: {
                    screenId: this.screenId,
                    metadataMap: this.metadataMap,
                    ...contentData
                },
                bubbles: true,
                composed: true
            }));
        } catch (error) {
            console.error('Error handling content update in flowScreenEditor:', error);
        }
    }

    handleEditReadMore(event) {
        const { sectionId, shouldNavigate, internalSectionId } = event.detail;
        
        // Dispatch to parent to create/edit read more screen
        this.dispatchEvent(new CustomEvent('editreadmore', {
            detail: {
                sectionId,
                shouldNavigate,
                internalSectionId
            },
            bubbles: true,
            composed: true
        }));
    }

    handleDeleteReadMore(event) {
        this.dispatchEvent(new CustomEvent('deletereadmore', {
            detail: event.detail,
            bubbles: true,
            composed: true
        }));
    }

    disconnectedCallback() {
        if (this.boundDocumentClickHandler) {
            document.removeEventListener('click', this.boundDocumentClickHandler);
            this.boundDocumentClickHandler = null;
        }
        this.contentEditorRef = null;
        this.parsedJson = null;
    }
}