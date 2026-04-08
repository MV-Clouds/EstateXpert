import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class WbFlowScreenNavigation extends LightningElement {
    
    screenList = [];
    isDragging = false;
    parsedJson = null;
    screenCounter = 0;
    isConfirming = false;
    draggedScreenId = null;
    dragOverScreenId = null;
    tempScreenList = null;
    lastDropPositionKey = null;
    selectedId = null;
    json = null;

    @api
    get selectedScreenId() {
        return this.selectedId;
    }

    set selectedScreenId(value) {
        this.selectedId = value;
    }

    @api
    get jsonData() {
        return this.json;
    }

    set jsonData(value) {
        this.json = value;
        this.parseJsonData(value);
    }

    get processedScreens() {
        const listToUse = this.tempScreenList || this.screenList;
        const processedList = [];
        
        listToUse.forEach(screen => {
            const isReadMoreScreen = screen.id && screen.id.startsWith('READ_MORE_');
            if (isReadMoreScreen) {
                return;
            }
            
            let css = 'screen-item';
            let wrapperCss = 'screen-wrapper';

            if (screen.id === this.selectedScreenId) css += ' selected';
            if (screen.isEditing) {
                css += ' editing';
                wrapperCss += ' editing';
            }
            if (screen.id === this.draggedScreenId) wrapperCss += ' dragging';
            if (screen.id === this.dragOverScreenId) wrapperCss += ' drag-over';
            
            const readMoreScreens = this.getReadMoreScreensForParent(screen.id, listToUse);
            
            const processedReadMoreScreens = readMoreScreens.map(rmScreen => {
                let childCss = 'screen-item read-more-child';
                if (rmScreen.id === this.selectedScreenId) childCss += ' selected';
                
                return {
                    ...rmScreen,
                    cssClass: childCss,
                    isParent: false,
                    isReadMoreScreen: true,
                    isDraggable: false,
                    showDeleteButton: false
                };
            });
            
            processedList.push({
                ...screen,
                cssClass: css,
                wrapperCssClass: wrapperCss,
                isParent: true,
                isDraggable: !screen.isEditing,
                showDeleteButton: true,
                readMoreScreens: processedReadMoreScreens.length > 0 ? processedReadMoreScreens : null
            });
        });
        
        return processedList;
    }


    get isMaxScreensReached() {
        const parentScreensCount = this.screenList.filter(s => !s.id || !s.id.startsWith('READ_MORE_')).length;
        return parentScreensCount >= 8;
    }

    get addScreenButtonTitle() {
        return this.isMaxScreensReached ? 'You can add a maximum of 8.' : 'Add New Screen';
    }


    connectedCallback() {
        document.addEventListener('click', this.handleDocumentClick);
    }

    getReadMoreScreensForParent(parentScreenId, listToSearch = null) {
        const searchList = listToSearch || this.screenList;
        const readMoreScreens = [];
        const parentIndex = searchList.findIndex(s => s.id === parentScreenId);
        
        if (parentIndex === -1) return readMoreScreens;
        
        for (let i = parentIndex + 1; i < searchList.length; i++) {
            const screen = searchList[i];
            if (screen.id && screen.id.startsWith('READ_MORE_')) {
                if (screen.parentScreenId === parentScreenId || !screen.parentScreenId) {
                    readMoreScreens.push(screen);
                } else {
                    break;
                }
            } else {
                break;
            }
        }
        
        return readMoreScreens;
    }

    parseJsonData(jsonString) {
        try {
            if (!jsonString) {
                this.screenList = [];
                return;
            }

            this.parsedJson = JSON.parse(jsonString);
            const incomingScreens = this.parsedJson.screens || [];

            if (incomingScreens.length > 0 && !this.selectedScreenId) {
                this.selectedScreenId = incomingScreens[0].id;
            }

            this.screenCounter = Math.max(
                ...incomingScreens.map(s => {
                    const match = s.id.match(/_(\d+)$/);
                    return match ? parseInt(match[1], 10) : 0;
                }),
                0
            );

            this.screenList = incomingScreens.map((s, index) => {
                const counterMatch = s.id.match(/_(\d+)$/);
                return {
                    ...s,
                    isEditing: false,
                    order: s.order !== undefined ? s.order : index,
                    counter: counterMatch ? parseInt(counterMatch[1], 10) : 0
                };
            });

        } catch (err) {
            console.error('Error parsing JSON:', err);
            this.screenList = [];
        }
    }

    handleScreenSelect(event){
        try {
            
            const screenId = event.currentTarget.dataset.screenId;
            
            // Find screen in main list (all screens are now in main array)
            let screen = this.screenList.find(s => s.id === screenId);

            if (screen?.isEditing) {
                event.stopPropagation();
                return;
            }

            this.selectedScreenId = screenId;            

            this.dispatchEvent(
                new CustomEvent('screenselect', {
                    detail: { screenId },
                    bubbles: true,
                    composed: true
                })
            );
        } catch (error) {
            console.error('Error dispatching screenselect event:', error.stack);
        }
    }

    handleAddScreen(event) {
        event.stopPropagation();

        const parentScreensCount = this.screenList.filter(s => !s.id || !s.id.startsWith('READ_MORE_')).length;
        if (parentScreensCount >= 8) {
            return this.showToast('Error', 'Maximum 8 screens allowed', 'error');
        }

        if (this.screenList.some(s => s.isEditing)) return;

        this.screenCounter++;

        const maxOrder = this.screenList.length > 0 
            ? Math.max(...this.screenList.map(s => s.order || 0)) 
            : -1;

        const newScreen = {
            id: `SCREEN_${this.screenCounter}`,
            title: '',
            isEditing: true,
            order: maxOrder + 1,
            counter: this.screenCounter
        };

        this.screenList = [...this.screenList, newScreen];

        setTimeout(() => {
            const input = this.template.querySelector(
                `input[data-screen-id="SCREEN_${this.screenCounter}"]`
            );
            input?.focus();
        }, 50);
    }

    handleDocumentClick = (event) => {
        const editing = this.screenList.find(s => s.isEditing);
        if (!editing) return;

        const clickedInside =
            event.target.closest('.screen-item.editing') ||
            event.target.closest('.add-screen-icon-btn');

        if (!clickedInside) {
            this.cancelEditingScreen(editing.id);
        }
    };

    cancelEditingScreen(screenId) {
        const screen = this.screenList.find(s => s.id === screenId);

        if (screen && screen.isEditing) {
            this.screenList = this.screenList.filter(s => s.id !== screenId);

            if (this.selectedScreenId === screenId && this.screenList.length > 0) {
                this.selectedScreenId = this.screenList[0].id;
            }
        }
    }

    handleDeleteScreen (event){
        event.stopPropagation();
        const screenId = event.currentTarget.dataset.screenId;

        const screen = this.screenList.find(s => s.id === screenId);

        if (screen.isEditing) {
            return this.cancelEditingScreen(screenId);
        }

        const confirmedScreens = this.screenList.filter(s => !s.isEditing);

        if (confirmedScreens.length <= 1) {
            return this.showToast('Error', 'At least one screen must exist', 'error');
        }

        const index = this.screenList.findIndex(s => s.id === screenId);
        this.screenList = this.screenList
            .filter(s => s.id !== screenId)
            .map((s, idx) => ({ ...s, order: idx }));

        if (this.selectedId === screenId && this.screenList.length > 0) {
            this.selectedId = this.screenList[Math.min(index, this.screenList.length - 1)].id;
        }

        this.dispatchEvent(
            new CustomEvent('deletescreen', {
                detail: { screenId },
                bubbles: true,
                composed: true
            })
        );

        if (this.selectedScreenId) {
            this.dispatchEvent(
                new CustomEvent('screenselect', {
                    detail: { screenId: this.selectedScreenId },
                    bubbles: true,
                    composed: true
                })
            );
        }
    }

    handleConfirmScreen(event) {
        event.stopPropagation();
        if (this.isConfirming) return;

        this.isConfirming = true;
        const screenId = event.currentTarget.dataset.screenId;
        this.confirmScreen(screenId);
    }

    confirmScreen(screenId) {
        const input = this.template.querySelector(`input[data-screen-id="${screenId}"]`);
        const newTitle = input?.value?.trim();

        if (!newTitle) {
            this.showToast('Error', 'Screen name cannot be empty', 'error');
            this.isConfirming = false;
            input?.focus();
            return;
        }

        const screen = this.screenList.find(s => s.id === screenId);
        
        let sanitizedTitle = newTitle.replace(/[^a-zA-Z_\s]/g, '');
        sanitizedTitle = sanitizedTitle.replace(/\s+/g, '_');
        sanitizedTitle = sanitizedTitle.replace(/_+/g, '_');
        sanitizedTitle = sanitizedTitle.replace(/^_+|_+$/g, '');
        
        if (!sanitizedTitle) {
            sanitizedTitle = 'SCREEN';
        }
        
        const counter = screen?.counter || 1;
        const alphabeticHash = this.hashToAlphabetic(counter);
        
        const newId = `${sanitizedTitle}_${alphabeticHash}`.toUpperCase();

        this.screenList = this.screenList.map(s =>
            s.id === screenId
                ? { ...s, id: newId, title: newTitle, isEditing: false }
                : s
        );

        this.selectedId = newId;

        const defaultSection = {
            type: 'TextInput',
            label: 'Label',
            isRequired: true,
            inputType: 'text',
            placeholder: '',
            helpText: '',
            minLength: null,
            maxLength: null
        };
        this.dispatchEvent(
            new CustomEvent('addscreen', {
                detail: { 
                    screenId: newId, 
                    title: newTitle,
                    order: screen?.order || 0,
                    defaultSection: defaultSection
                },
                bubbles: true,
                composed: true
            })
        );
        
        this.isConfirming = false;
    }

    handleKeyDown(event) {
        const screenId = event.currentTarget.dataset.screenId;

        if (event.key === 'Enter') {
            event.stopPropagation();
            if (!this.isConfirming) {
                this.isConfirming = true;
                this.confirmScreen(screenId);
            }
        }

        if (event.key === 'Escape') {
            event.stopPropagation();
            this.cancelEditingScreen(screenId);
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }

    handleDragStart(event) {
        const screenId = event.currentTarget.dataset.screenId;
        const screen = this.screenList.find(s => s.id === screenId);
        
        if (screen?.isEditing || screen?.isReadMoreScreen) {
            event.preventDefault();
            return;
        }
        
        const processedScreen = this.processedScreens.find(s => s.id === screenId);
        if (processedScreen && !processedScreen.isDraggable) {
            event.preventDefault();
            return;
        }
        
        this.draggedScreenId = screenId;
        this.isDragging = true;
        this.tempScreenList = [...this.screenList];
        event.dataTransfer.effectAllowed = 'move';
        event.dataTransfer.setData('text/plain', screenId);
        
        setTimeout(() => {
            const container = this.template.querySelector('.screens-list');
            if (container) container.classList.add('is-dragging');
        }, 0);
    }

    handleDragOver(event) {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'move';
        
        const screenId = event.currentTarget.dataset.screenId;
        if (!screenId || screenId === this.draggedScreenId) {
            return false;
        }
        
        const targetScreen = this.screenList.find(s => s.id === screenId);
        if (targetScreen?.id?.startsWith('READ_MORE_')) {
            return false;
        }
        
        const rect = event.currentTarget.getBoundingClientRect();
        const mouseY = event.clientY;
        const elementMiddle = rect.top + (rect.height / 2);
        const isInLowerHalf = mouseY > elementMiddle;
        const positionKey = `${screenId}_${isInLowerHalf ? 'after' : 'before'}`;
        
        if (positionKey !== this.lastDropPositionKey && this.draggedScreenId && this.tempScreenList) {
            this.lastDropPositionKey = positionKey;
            this.dragOverScreenId = screenId;
            
            const originalList = [...this.screenList];
            const draggedIndex = originalList.findIndex(s => s.id === this.draggedScreenId);
            const targetIndex = originalList.findIndex(s => s.id === screenId);
            
            if (draggedIndex !== -1 && targetIndex !== -1) {
                const newList = [...originalList];
                
                const readMoreScreens = [];
                for (let i = draggedIndex + 1; i < newList.length; i++) {
                    if (newList[i].id?.startsWith('READ_MORE_')) {
                        readMoreScreens.push(newList[i]);
                    } else {
                        break;
                    }
                }
                
                const itemsToMove = [newList[draggedIndex], ...readMoreScreens];
                newList.splice(draggedIndex, itemsToMove.length);
                
                let adjustedTargetIndex = newList.findIndex(s => s.id === screenId);
                
                if (isInLowerHalf) {
                    let insertIndex = adjustedTargetIndex + 1;
                    while (insertIndex < newList.length && newList[insertIndex].id?.startsWith('READ_MORE_')) {
                        insertIndex++;
                    }
                    adjustedTargetIndex = insertIndex;
                }
                
                newList.splice(adjustedTargetIndex, 0, ...itemsToMove);
                
                this.tempScreenList = newList.map((screen, idx) => ({
                    ...screen,
                    order: idx
                }));
            }
        }
        
        return false;
    }

    handleDragEnter(event) {
        event.preventDefault();
        const screenId = event.currentTarget.dataset.screenId;
        
        const targetScreen = this.screenList.find(s => s.id === screenId);
        if (targetScreen?.id?.startsWith('READ_MORE_')) {
            return;
        }
        
        if (screenId && screenId !== this.draggedScreenId) {
            this.dragOverScreenId = screenId;
        }
    }

    
    handleDrop(event) {
        event.stopPropagation();
        event.preventDefault();
        
        if (this.tempScreenList) {
            this.screenList = this.tempScreenList.map((screen, index) => ({
                ...screen,
                order: index
            }));

            this.dispatchEvent(
                new CustomEvent('reorderscreen', {
                    detail: { 
                        screens: this.screenList.map(s => ({ id: s.id, order: s.order })) 
                    },
                    bubbles: true,
                    composed: true
                })
            );
        }
        
        this.draggedScreenId = null;
        this.dragOverScreenId = null;
        this.isDragging = false;
        this.tempScreenList = null;
        this.lastDropPositionKey = null;
        
        const container = this.template.querySelector('.screens-list');
        if (container) container.classList.remove('is-dragging');
        
        return false;
    }

    handleDragLeave(event) {
        const relatedTarget = event.relatedTarget;
        const currentTarget = event.currentTarget;
        
        if (!currentTarget.contains(relatedTarget)) {
            const screenId = event.currentTarget.dataset.screenId;
            if (screenId === this.dragOverScreenId) {
                this.dragOverScreenId = null;
            }
        }
    }

    handleDragEnd() {
        this.draggedScreenId = null;
        this.dragOverScreenId = null;
        this.isDragging = false;
        this.tempScreenList = null;
        this.lastDropPositionKey = null;
        
        const container = this.template.querySelector('.screens-list');
        if (container) container.classList.remove('is-dragging');
    }

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
        document.removeEventListener('click', this.handleDocumentClick);
    }

    
}