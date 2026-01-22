import { LightningElement, api, track } from "lwc";
import { errorDebugger } from 'c/globalProperties'
export default class CustomCombobox extends LightningElement {

    // ***************************************************************************** //
    // *                             API Attributes           
    // * label              (attribute - label)
    // * multiselect        (attribute - multiselect)                          
    // * searchable         (attribute - searchable)                         
    // * required           (attribute - required)
    // * disabled           (attribute - disabled)                      
    // * showClearButton    (attribute - show-clear-button)                            
    // * showDescription    (attribute - show-description)                              
    // * showHelpText       (attribute - show-helptext)      
    // * showOptionIcon     (attribute - show-option-icon)
    // * iconName           (attribute - icon-name)                       
    // * value              (attribute - value)      
    // * dropdownPosition   (attribute - dropdown-position)      
    // * placeholder        (attribute - placeholder) 
    // * hideSearchIcon     (attribute - hide-search-icon)

    // * options            (attribute - options)               [ ...Required Attribute... ]  
    // * keys of options :
    // *     label : 'option label'               (Required), 
    // *     value : 'option unique value'        (Required), 
    // *     description : 'option description'   (optional),       Note :  show-description must be TRUE
    // *     helptext : 'option helptext'         (optional),       Note :  show-helptext must be TRUE
    // *     disabled : true/false                (optional),


    // * =========== dispatch events ============ 
    // *
    // * select (onselect)      -- Trigger when user select or remove selected option
    // * focus (onfocus)        -- Trigger when user focus in input for searchable combo
    // * search (onsearch)      -- Trigger when user search value in input for searchable combo
    // *

    // ******** API Functions / Method -- Used from parent component...
    // * unselectOption     (method)                             
    // * clearValue         (method)                        
    // * resetValue         (method)                         
    // * isInvalidInput     (method)
    // *
    // ***************************************************************************** //

    /**
     * label : defined the label for combobox, 
     * if label is null manse combo-box is label-hidden
     */
    _label;
    @api get label() { return this._label }
    set label(value) { this._label = value }

    /**
     * No Options Label : defined the label for combobox, 
     * if label is null manse combo-box is label-hidden
     */
    _noOptLabel;
    @api get noOptLabel() { return this._noOptLabel }
    set noOptLabel(value) { this._noOptLabel = value }

    /**
     * API to defined weather comboBox is multi-select or not.
     */
    isMultiSelect;
    @api get multiselect() { return this.isMultiSelect };
    set multiselect(value) { this.isMultiSelect = (value === 'true' || value === true) ? true : false };

    /**
     * API to defined weather comboBox is Searchable or not.
     */
    isSearchable;
    @api get searchable() { return this.isSearchable };
    set searchable(value) { this.isSearchable = (value === 'true' || value === true) ? true : false };

    /**
     * API to defined weather comboBox is Required or not.
     */
    isRequired;
    @api get required() { return this.isRequired };
    set required(value) { this.isRequired = (value === 'true' || value === true) ? true : false };

    /**
     * API to defined weather comboBox is Disabled or not.
     */
    _disabled;
    @api get disabled() { return this._disabled };
    set disabled(value) { this._disabled = (value === 'true' || value === true) ? true : false };

    /**
     * API to defined weather comboBox should display clear button or not.
     */
    _showClearButton = true;
    @api get showClearButton() { return this._showClearButton };
    set showClearButton(value) { this._showClearButton = (value === 'false' || value === false) ? false : true };

    /**
     * API to defined weather comboBox should display Description or not for drop-down options.
     */
    isDescription;
    @api get showDescription() { return this.isDescription };
    set showDescription(value) { this.isDescription = (value === 'true' || value === true) ? true : false };

    /**
     * API to defined weather comboBox should display Help text or not for drop-down options
     */
    _showHelpText;
    @api get showHelpText() { return this._showHelpText };
    set showHelpText(value) { this._showHelpText = (value === 'true' || value === true) ? true : false };

    /**
     * API to defined weather comboBox should display Icons or not for drop-down options
     */
    _showOptionIcon;
    @api get showOptionIcon() { return this._showOptionIcon }
    set showOptionIcon(value) { this._showOptionIcon = (value === 'true' || value === true) ? true : false }

    /**
     * API to defined icon to be display for options,
     * These icon are the salesforce standard icon,
     * You may get the name these icon from this site: https://www.lightningdesignsystem.com/icons/
     */
    _iconName = "standard:account";
    @api get iconName() { return this._iconName };
    set iconName(value) { this._iconName = value ? value : this._iconName };

    /**
     * API to defined weather comboBox should display Search Icon or not,
     * use to hide search icon... and show native down arrow...Only for Searchable Combobox
     */
    _hideSearchIcon;
    @api get hideSearchIcon() { return this._hideSearchIcon };
    set hideSearchIcon(value) { this._hideSearchIcon = (value === 'true' || value === true) ? true : false };

    /**
     * API that defined Drop-Down Options,
     */
    optionsToSet;
    @api get options() { return this.optionsToSet };
    set options(value) {
        try {
            this.optionsToSet = value;
            this.setDisplayOptions();
        } catch (error) {
            errorDebugger('CustomCombobox', 'get/set options', error, 'warn');
        }
    }
    /**
     * API that defined pre-selected drop-down options,
     */
    valueToSet;
    @api get value() { return this.valueToSet };
    set value(val) {
        try {
            this.valueToSet = val;
            if (val && this.options && this.options.length) {
                this.setDefaultValue();
            }
            else {
                this.clearValue();
            }
        } catch (error) {
            errorDebugger('CustomCombobox', 'get/set value', error, 'warn');
        }
    }

    /**
     * API that defined Position of drop-down,
     * It May be left, right or centred align
     */
    setDropDownPosition;
    @api get dropdownPosition() { return this.setDropDownPosition };
    set dropdownPosition(value) { this.setDropDownPosition = value };

    /**
     * API that defined drop-down should open upper-side,
     * Use this api when you want to open drop-down upper-side
     */
    _dropdownTop;
    @api get dropdownTop() { return this._dropdownTop };
    set dropdownTop(value) { this._dropdownTop = (value === 'true' || value === true) ? true : false }

    /**
     * API that defined custom placeholder for combo-box
     */
    _placeholder;
    @api get placeholder() { return this._placeholder };
    set placeholder(value) {
        this._placeholder = value;
        this.setPlaceHolder();
    }

    @track placeholderText = ''             // to set placeholder in markup as per multi select options

    @track displayOptions = [];              // to display option in dropdown
    @track selectedItems = [];              // to set store and send selected option to parent component
    @track selectedOptionLabel = null;      // to display selected option in markup (for single select)
    @track isDropDownOpen = false           // to check dropdown is open or not....

    // To show the label of selected option for single select non-searchable combo-box
    get _selectedOptionLabel() {
        return this.selectedOptionLabel;
    }

    allOptions = [];                        // All Option List Modified Keys....

    // to display no result found when search result not found...
    get isOptions() {
        return this.displayOptions.length ? true : false;
    }

    // To set info message when search result not found and when no option available.
    get emptyOptionLabel() {
        if (this.options && this.options.length) {
            return 'couldn\'t find any matches';
        }
        else {
            return this.noOptLabel ? this.noOptLabel : 'options are not available';
        }
    }


    connectedCallback() {
        try {
            this.setPlaceHolder();
            // window?.globalThis?.document?.body?.addEventListener('click', this.onBodyClick)
        } catch (error) {
            errorDebugger('CustomCombobox', 'connectedCallback', error, 'warn');
        }
    }

    onBodyClick = () => {
        if (this.isDropDownOpen) {
            this.closeDropDown();
        }
    }

    /**
     * Method to set display option on initialization and option change from parent component.
     */
    setDisplayOptions() {
        try {
            if (this.options) {
                this.allOptions = JSON.parse(JSON.stringify(this.options));

                var tempOptions = JSON.parse(JSON.stringify(this.options));
                tempOptions.forEach((ele, index) => {
                    ele['isSelected'] = false;                // by default set all option as unselected
                    ele['originalIndex'] = index;            // set original index of option for re-sorting
                });

                this.allOptions = tempOptions;
                this.displayOptions = tempOptions;

                if (this.value) {
                    // this.setDefaultSection();
                    this.setDefaultValue();
                }
                else {
                    this.clearValue();
                }
            }

        } catch (error) {
            errorDebugger('CustomCombobox', 'setDisplayOptions', error, 'warn');
        }
    }

    /**
     * Method to set default selected option if user defied...
     */
    setDefaultValue() {
        try {
            const valueToSet = typeof this.value === 'object' ? this.value : [this.value];

            if (this.multiselect) {
                valueToSet.forEach(ele => {
                    var matchedOption = this.displayOptions.find(option => option.value === ele);

                    if (matchedOption && !matchedOption.disabled) {
                        (!matchedOption.isSelected) && this.selectedItems.push(matchedOption);
                    }
                    else {
                        this.selectedItems = this.selectedItems.filter((item) => {
                            return item !== ele;
                        });
                    }
                });

                this.setPlaceHolder();
            }
            else {

                // for single select took first one as default option...
                var matchedOption = this.displayOptions.find(option => option.value === valueToSet[0]);
                if (matchedOption && !matchedOption.disabled) {
                    this.selectedItems = [matchedOption];
                    this.selectedOptionLabel = matchedOption.label;
                }
                else {
                    this.selectedItems = [];
                    this.selectedOptionLabel = null;
                }
            }
            this.setSelection();

        } catch (error) {
            errorDebugger('CustomCombobox', 'setDefaultValue', error, 'warn');
        }
    }

    /**
     * Method to handle oping of dropdown,
     */
    handleShowDropDown() {
        try {
            this.isDropDownOpen = true;

            const comboBoxDiv = this.template.querySelector(`[data-id="slds-combobox"]`);
            if (comboBoxDiv) {
                comboBoxDiv.classList.add('slds-is-open');
            }

            const backDrop = this.template.querySelector('.backDrop');
            backDrop && (backDrop.style = 'display : block');

            this.sortDisplayItems();

        } catch (error) {
            errorDebugger('CustomCombobox', 'handleShowDropDown', error, 'warn');
        }
    }

    /**
     * Method to handle search of option for searchable combo-box,
     * Method send search value to parent component using CustomEvent,
     * @param {*} event 
     */
    handleSearch(event) {
        try {
            var searchValue = (event.target.value).toLowerCase();
            this.setOptionAfterSearch(searchValue);
        } catch (error) {
            errorDebugger('CustomCombobox', 'handleSearch', error, 'warn');
        }
    }

    handleSpecialKeyPress(event) {
        try {
            if (event.code === 'Tab' || event.code === 'Escape') {
                this.closeDropDown();
            }
        } catch (error) {
            errorDebugger('CustomCombobox', 'handleSpecialKeyPress', error, 'warn');
        }
    }

    /**
     * Method to set option based search value.
     * @param {*} searchValue 
     */
    setOptionAfterSearch(searchValue) {
        try {
            if (searchValue === null || searchValue.trim() === '' || searchValue === undefined) {
                this.displayOptions = this.allOptions;
            }
            else {
                this.displayOptions = this.allOptions.filter((ele) => {
                    return ele.label.toLowerCase().includes(searchValue)
                });

                (!this.displayOptions.length)
            };

            if (typeof window !== 'undefined') {
                this.searchable && this.dispatchEvent(new CustomEvent('search', { detail: event.target.value }));
            }
            // sort After each Search
            this.sortDisplayItems();
        } catch (error) {
            errorDebugger('CustomCombobox', 'setOptionAfterSearch', error, 'warn');
        }
    }

    /**
     *  Method to handle option selection form Ui and send selected option to parent component using dispatch event.
     * Method handle option selection for both type (single select and multi-select).
     * @param {*} event 
     */
    handleOptionClick(event) {
        try {
            // Use Original Index as unique Value and comparison...
            var originalIndex = event.currentTarget.dataset.oriindex;
            const currentOption = this.displayOptions.find(option => option.originalIndex === Number(originalIndex));
            if (currentOption && !currentOption.disabled) {

                if (this.multiselect) {

                    // Assign or remove clicked option from selected list...
                    if (!currentOption.isSelected) {
                        this.selectedItems.push(currentOption);
                    }
                    else {
                        this.selectedItems = this.selectedItems.filter((selectedOption) => {
                            return selectedOption.originalIndex !== Number(originalIndex);
                        });
                    }
                    this.setSelection();
                    this.setPlaceHolder();

                    // this logic create a list of selected options with original values...(remove additonal keys...)
                    var selectedOptionList = [];
                    this.selectedItems.forEach((selectedOption) => {
                        selectedOptionList.push(this.options[selectedOption.originalIndex].value);
                    });

                    // Send data to parent component...
                    this.dispatchEvent(new CustomEvent('select', {
                        detail: selectedOptionList
                    }));

                }
                else {

                    this.clearSearch();
                    this.selectedOptionLabel = event.currentTarget.dataset.label;

                    this.selectedItems = [currentOption];
                    this.setSelection();

                    // if combobox is not multi-select it will return array with only one element...
                    this.dispatchEvent(new CustomEvent('select', {
                        detail:
                            [currentOption.value]
                    }));

                    this.closeDropDown();
                }

                this.setErrorBorder();
            }

        } catch (error) {
            errorDebugger('CustomCombobox', 'handleOptionClick', error, 'warn');
        }
    }

    /**
     * Method handle selection clearing,
     * Generally this method clear all selected option...
     */
    clearSelection() {
        try {
            this.selectedOptionLabel = null;
            this.selectedItems = [];

            this.displayOptions.forEach(option => { option.isSelected = false; });
            this.allOptions.forEach(option => { option.isSelected = false; });

            // Send Null Data to parent Component...
            if (!import.meta.env.SSR) {
                this.dispatchEvent(new CustomEvent('select', {
                    detail:
                        []
                }));
            }

            if (this.searchable) {
                const searchInput = this.template.querySelector('[data-id="search-input"]');
                searchInput && searchInput.focus();
            }

            this.clearSearch();
            this.setErrorBorder();
            this.setPlaceHolder();
        } catch (error) {
            errorDebugger('CustomCombobox', 'clearSelection', error, 'warn');
        }
    }

    /**
     * Method Handle closing of drop-down
     */
    closeDropDown() {
        try {
            this.isDropDownOpen = false;

            // remove slds-is-open class from combobox div to hide dropdown...
            const comboBoxDiv = this.template.querySelector(`[data-id="slds-combobox"]`);
            if (comboBoxDiv && comboBoxDiv.classList.contains('slds-is-open')) {
                comboBoxDiv.classList.remove('slds-is-open');
            }

            // remove back-shadow from main div
            const backDrop = this.template.querySelector('.backDrop');
            backDrop && (backDrop.style = 'display : none');

            this.setErrorBorder();
            this.sortDisplayItems();
            // this.clearSearch();

        } catch (error) {
            errorDebugger('CustomCombobox', 'closeDropDown', error, 'warn');
        }
    }

    /**
     * Method to add and remove option from selected option list based on user selection
     */
    setSelection() {
        try {
            this.displayOptions.forEach(options => { options.isSelected = this.selectedItems?.some(ele => ele.originalIndex === options.originalIndex) });
            this.allOptions.forEach(options => { options.isSelected = this.selectedItems?.some(ele => ele.originalIndex === options.originalIndex) });
        } catch (error) {
            errorDebugger('CustomCombobox', 'setSelection', error, 'warn');
        }
    }

    // Generic Method -> to Set place older as user select or unselect options... (Generally used for multi-Select combobox)
    /**
     * Method that set place holder based on user selection,
     * This method cover both combo-box type (searchable and non-searchable)
     */
    setPlaceHolder() {
        this.selectedItems = this.selectedItems.filter((item, index, self) =>
            index === self.findIndex((t) => (
                t.value === item.value
            ))
        );
        if (this.selectedItems.length <= 0) {
            this.placeholderText = this.placeholder ? this.placeholder : (this.multiselect ? 'Select an Options...' : 'Select an Option...');
        }
        else {
            var length = this.selectedItems.length;
            this.placeholderText = this.selectedItems.length + (length === 1 ? ' option' : ' options') + ' selected';
        }
    }

    /**
     * Method to Set Error border when user not select and option for required combo-box ,
     */
    setErrorBorder() {
        try {
            if (this.required) {
                if ((this.multiselect && this.selectedItems.length === 0) || (!this.multiselect && this.selectedOptionLabel === null)) {
                    this.template.querySelector('.inputAreaCSS_1')?.classList.add('invalid-input');
                }
                else {
                    this.template.querySelector('.inputAreaCSS_1')?.classList.remove('invalid-input');
                }
            }
        } catch (error) {
            errorDebugger('CustomCombobox', 'setErrorBorder', error, 'warn');
        }
    }

    /**
     * Method to handle ordering of option after user select and un-select any option,
     * this method bring all selected option on top, and set back on original position when user un-select.
     */
    sortDisplayItems() {
        try {
            var displayOptions = JSON.parse(JSON.stringify(this.displayOptions));
            // Sort the display options based on selected or unselect...
            displayOptions.sort((a, b) => {
                if (a.isSelected > b.isSelected) {
                    return -1;
                }
                if (a.isSelected < b.isSelected) {
                    return 1;
                }
                if (a.isSelected === b.isSelected) {
                    if (a.originalIndex < b.originalIndex) {
                        return -1;
                    }
                    if (a.label > b.label) {
                        return 1;
                    }
                }
                return 1;
            });

            this.displayOptions = displayOptions;

        } catch (error) {
            errorDebugger('CustomCombobox', 'sortDisplayItems', error, 'warn');
        }
    }

    /**
     * Method that prevent any click on disable option
     * @param {*} event 
     */
    handleDisableClick(event) {
        event.stopPropagation();
        event.preventDefault();
    }

    // === ==== ==== ===  [ API Methods to Access from Parent Components ] === === == === ==== ===

    /**
     * API method to un-select option from parent component,
     * It removes selected option form selectedItems List and set error border and place holder according to it.
     * @param {*} unselectedOption 
     */
    @api
    unselectOption(unselectedOption) {
        try {
            this.selectedItems = this.selectedItems.filter((option) => {
                option.isSelected = false;
                return option.value !== unselectedOption;
            });

            this.setSelection();
            this.setErrorBorder();
            this.setPlaceHolder();
        } catch (error) {
            errorDebugger('CustomCombobox', 'unselectOption', error, 'warn');
        }
    }

    /**
     * API Method to clear all selected option from parent component,
     */
    @api
    clearValue() {
        try {
            if (this.multiselect) {
                if (this.selectedItems.length > 0) {
                    this.selectedItems = this.selectedItems.filter((option) => {
                        option.isSelected = false;
                        return null;
                    });

                    this.setSelection();
                    this.setErrorBorder();
                    this.setPlaceHolder();
                }
            }
            else {
                if (this.selectedOptionLabel !== null) {
                    this.clearSelection();
                }
            }
        } catch (error) {
            errorDebugger('CustomCombobox', 'clearValue', error, 'warn');
        }
    }

    /**
     * API Method to reset all option to default selected,
     * This method does not clear all selection but is set option to default on that user have defined,
     * if there is no default value are defined, it clear all options...
     * 
     */
    @api
    resetValue() {
        this.clearValue();
        if (this.value) {
            // this.setDefaultSection();
            this.setDefaultValue();
        }
    }

    /**
     * API Method to clear search from combo-box,
     */
    @api
    clearSearch() {
        try {
            // console.log('clearing value');
            if (this.searchable) {
                const searchInput = this.template.querySelector('[data-id="search-input"]');
                searchInput && (searchInput.value = '');
                this.setOptionAfterSearch(null);
            }

        } catch (error) {
            errorDebugger('CustomCombobox', 'clearSearch', error, 'warn');
        }
    }

    /**
     * Method to show error border on combo-box from parent component
     * parameter take true/false values that defined, should error border to be show or not,
     * @param {*} isInvalid 
     */
    @api
    isInvalidInput(isInvalid) {
        try {
            // if isInvalid is "TRUE" --> Show Error Border...
            if (isInvalid) {
                this.template.querySelector('.inputAreaCSS_1')?.classList.add('invalid-input');
            }
            // else Remove Error Border...
            else {
                this.template.querySelector('.inputAreaCSS_1')?.classList.remove('invalid-input');
            }
        } catch (error) {
            errorDebugger('CustomCombobox', 'isInvalidInput', error, 'warn');
        }
    }

}