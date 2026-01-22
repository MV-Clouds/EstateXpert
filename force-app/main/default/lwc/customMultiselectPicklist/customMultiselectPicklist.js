import { LightningElement,api,track } from 'lwc';

export default class CustomMultiselectPicklist extends LightningElement {
    @api options = []; 
    @api selectedValues = [];
    @api isDropdownOpen = false;
    @track searchTerm = '';

    get selectedCountText() {
        try {
            const count = this.selectedValues.length;
    
            if (count == 1) {
                const selectedOption = this.options.find(option => option.value === this.selectedValues[0]);
                return selectedOption ? selectedOption.label : 'Select options';
            } else if (count > 1) {
                return `${count} options selected`;
            } 
            return 'Select options';
        } catch (error) {
            console.error('Error in selectedCountText : ', error);
            return 'Select options';
        }
    }

    get filteredOptions() {
        return this.options.filter(option => {
            return option.label.toLowerCase().includes(this.searchTerm.toLowerCase());
        });
    }

    connectedCallback() {
        document.addEventListener('click', this.toggleDropdown);
    }

    disconnectedCallback() {
        document.removeEventListener('click', this.toggleDropdown);
    }    

    handleSearchInput(event) {
        this.searchTerm = event.target.value;
    }

    toggleDropdown() {          
        this.isDropdownOpen = !this.isDropdownOpen;
    }

    handleOptionChange(event) {
        try {
            event.preventDefault();
            const value = event.target.name;
            let tempSelectedValues = [...this.selectedValues]; 
    
            if (event.target.checked) {
                if (!tempSelectedValues.includes(value)) {
                    tempSelectedValues.push(value);
                }
            } else {
                tempSelectedValues = tempSelectedValues.filter(item => item !== value);
            }
        
            this.selectedValues = tempSelectedValues;
            
            this.options = this.options.map(option => ({
                ...option,
                selected: this.selectedValues.includes(option.value),
            }));
            
            const selectionChangeEvent = new CustomEvent('selectionchange', {
                detail: { selectedValues: [...this.selectedValues] },
            });
            this.dispatchEvent(selectionChangeEvent);
        } catch (error) {
            console.error('Error in handleOptionChnage : ', error);
        }
    }
    
    handleBlur(event) {
        const relatedTarget = event.relatedTarget;
        const dropdown = this.template.querySelector('.dropdown');
        if (!dropdown || (relatedTarget && dropdown.contains(relatedTarget))) {
            return;
        }
        this.isDropdownOpen = false;
    }
}