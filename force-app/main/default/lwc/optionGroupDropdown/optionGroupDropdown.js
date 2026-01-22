import { LightningElement, api, track } from 'lwc';

export default class OptionGroupDropdown extends LightningElement {
    @api headerLabel;
    @api options = [];
    @track selectedLabel = 'Last 30 Days';
    @api selectedValue;
    @track isOpen = false;

    get ungroupedOptions() {
        return this.options
            .filter(opt => !opt.groupName)
            .map(opt => ({
                ...opt,
                selected: opt.value === this.selectedValue
            }));
    }

    get groupedOptions() {
        return this.options
            .filter(opt => opt.groupName)
            .map(group => ({
                ...group,
                childs: group.childs.map(child => ({
                    ...child,
                    selected: child.value === this.selectedValue
                }))
            }));
    }

    connectedCallback() {
        document.addEventListener('click', this.closeDropdown.bind(this));
    }

    disconnectedCallback() {
        document.removeEventListener('click', this.closeDropdown.bind(this));
    }

    outsideClick(event) {
        event.stopPropagation();
    }

    closeDropdown(event) {
        if (!this.template.contains(event.target)) {
            this.isOpen = false;
        }
    }

    toggleDropdown() {
        this.isOpen = !this.isOpen;
    }

    handleSelect(event) {
        const value = event.currentTarget.dataset.value;
        const selected = this.options
            .flatMap(opt => opt.childs ? opt.childs : [opt])
            .find(opt => opt.value === value);
        this.selectedLabel = selected?.label || '';
        this.selectedValue = value;
        this.isOpen = false;
        this.dispatchEvent(
            new CustomEvent('optionselection', { detail: { value } })
        );
    }
}