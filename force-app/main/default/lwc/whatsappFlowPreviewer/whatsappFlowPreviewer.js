import { LightningElement, api, track } from 'lwc';

export default class WhatsappFlowPreviewer extends LightningElement {
    @api jsondata;
    inputValues = {}; // Stores { name: value }
    inputFocus = {}; // Stores { name: boolean }
    @api selectedtheme = 'light';
    showMenu = false;
    _currentscreenid;
    parsedJson = null;
    @track contentHeight = '86%';

    @api
    get currentscreenid() {
        return this._currentscreenid;
    }
    set currentscreenid(value) {
        if (value !== this._currentscreenid) {
            this._currentscreenid = value;
        }
    }

    connectedCallback() {
        window.addEventListener('click', this.handleOutsideClick.bind(this));
        window.addEventListener('resize', this.adjustContentHeight.bind(this));
    }

    disconnectedCallback() {
        window.removeEventListener('click', this.handleOutsideClick.bind(this));
        window.removeEventListener('resize', this.adjustContentHeight.bind(this));
    }

    handleOutsideClick(event) {
        const menuSection = this.template.querySelector('.menu-section');
        const menuBtn = this.template.querySelector('.menu');

        if (this.showMenu && !menuSection?.contains(event.target) && !menuBtn?.contains(event.target)) {
            this.showMenu = false;
            this.generatePreview();
        }
    }

    renderedCallback() {
        this.generatePreview();
        this.adjustContentHeight();
    }

    @api
    runPreview() {
        this.generatePreview();
        this.adjustContentHeight();
    }

    adjustContentHeight() {
        const content = this.template.querySelector('.content');

        if (content) {
            content.style.height = `${this.contentHeight}`;
        }
    }

    generatePreview() {
        if (this.jsondata) {
            try {
                this.parsedJson = JSON.parse(this.jsondata);
                if (!this._currentscreenid) {
                    this._currentscreenid = this.parsedJson.screens[0]?.id || null;
                }
            } catch (error) {
                return;
            }
            let html = '';
            const screen = this.parsedJson.screens.find(screen => screen.id === this._currentscreenid);
            if (screen) {
                html += `<section class="container">
                    <style>
                        .main-container{
                            background: ${this.selectedtheme === 'dark' ? 'black' : 'white'};
                            position: relative;
                        }
                        .container {
                            background: ${this.selectedtheme === 'dark' ? '#2d2c2c' : 'white'};
                            border-radius: 10px;
                            display: flex;
                            flex-direction: column;
                            justify-content: space-between;
                            font-family: system-ui, sans-serif;
                            overflow: scroll;
                            width: 310px;
                            color: ${this.selectedtheme === 'dark' ? '#ddd' : '#333'};
                        }
                        .header-preview {
                            display: flex;
                            justify-content: space-between;
                            align-items: center;
                            position: sticky;
                            top: 0;
                            height: 15%;
                            left: 0;
                            background: inherit;
                            padding: 5% 1%;
                        }
                        ::-webkit-scrollbar {
                            display: none;
                        }                        
                        .icon-button {
                            background: none;
                            border: none;
                            font-size: 1.5rem;
                            cursor: pointer;
                            color: ${this.selectedtheme === 'dark' ? '#bbb' : '#000'};
                        }
                        .menu {
                            transform: rotate(180deg);
                        }
                        .header-welcome h2 {
                            text-align: center;
                            font-size: 1.2rem;
                            color: ${this.selectedtheme === 'dark' ? '#ddd' : '#333'};
                        }
                        .content {
                            padding: 5%;
                            text-align: left;
                            height: ${this.contentHeight};
                            overflow-y: scroll;
                            position: fixed;
                            top: 14%;
                            background-color: ${this.selectedtheme === 'dark' ? '#2d2c2c' : 'white'};
                            width: 100%;
                            border-top: 1px solid ${this.selectedtheme === 'dark' ? '#444' : '#eee'};
                        }
                        .heading {
                            font-size: 1.3rem;
                            font-weight: bold;
                            margin-bottom: 0.5rem;
                            color: ${this.selectedtheme === 'dark' ? '#ddd' : '#333'};
                        }
                        .subheading {
                            font-size: 1.2rem;
                            font-weight: 500;
                            margin-bottom: 1rem;
                            color: ${this.selectedtheme === 'dark' ? '#ccc' : '#333'};
                        }
                        .body-text {
                            font-size: 0.9rem;
                            color: ${this.selectedtheme === 'dark' ? '#ccc' : '#333'};
                            margin-bottom: 1rem;
                        }
                        .footer2 {
                            padding: 5%;
                            text-align: center;
                            font-size: 0.8rem;
                            width: 100%;
                            color: ${this.selectedtheme === 'dark' ? '#999' : '#5c5c5c'};
                            border-top: 1px solid ${this.selectedtheme === 'dark' ? '#444' : '#eee'};
                            position: fixed;
                            top: 80%;
                            bottom: 0;
                            left: 0;
                            background-color: ${this.selectedtheme === 'dark' ? '#2d2c2c' : 'white'};
                        }
                        .continue {
                            width: 100%;
                            padding: 0.75rem;
                            background-color: ${this.selectedtheme === 'dark' ? '#388e3c' : '#4CAF50'};
                            border: none;
                            border-radius: 1.5rem;
                            font-size: 1rem;
                            font-weight: bold;
                            color: white;
                            cursor: pointer;
                        }
                        .floating-label {
                            position: relative;
                            margin-top: 10px;
                        }
                        .floating-label select + label {
                            top: 1.1rem;
                        }
                       .input {
                            width: 100%;
                            padding: 1.2rem 0.5rem 0.5rem 0.5rem;
                            border: 2px solid ${this.selectedtheme === 'dark' ? '#555' : '#ccc'};
                            border-radius: 0.5rem;
                            font-size: 1rem;
                            outline: none;
                            transition: border-color 0.3s;
                            background: ${this.selectedtheme === 'dark' ? '#2c2c2c' : 'white'};
                            color: ${this.selectedtheme === 'dark' ? '#ddd' : '#333'};
                            margin-bottom: 0.5rem;
                        }
                        .input.active {
                            border-color: ${this.selectedtheme === 'dark' ? '#66bb6a' : '#28a745'};
                        }
                        .floating-label label {
                            position: absolute;
                            left: 0.6rem;
                            top: 1.1rem;
                            color: ${this.selectedtheme === 'dark' ? '#999' : '#777'};
                            background: ${this.selectedtheme === 'dark' ? '#2c2c2c' : 'white'};
                            padding: 0 0.2rem;
                            transition: 0.2s ease all;
                            pointer-events: none;
                        }
                        .input.active + label,
                        .input:focus + label {
                            top: -0.6rem;
                            font-size: 0.75rem;
                            color: ${this.selectedtheme === 'dark' ? '#66bb6a' : '#28a745'};
                        }
                        .floating-label select.input.active + label,
                        .floating-label select.input:focus + label {
                            top: -0.6rem;
                            font-size: 0.75rem;
                            color: ${this.selectedtheme === 'dark' ? '#66bb6a' : '#28a745'};
                        }
                        .checkbox-group {
                            margin: 1rem 0;
                            display: flex;
                            align-items: center;
                            gap: 0.5rem;
                        }
                        .checkbox-container {
                            margin: 1rem 0;
                            display: flex;
                            flex-direction: column;
                            gap: 15px;
                        }
                        .checkbox-label {
                            font-size: 0.8rem;
                            color: ${this.selectedtheme === 'dark' ? '#ddd' : '#333'};
                            display: flex;
                            align-items: center;
                            gap: 0.5rem;
                            cursor: pointer;
                        }
                        .radio-container {
                            margin: 1rem 0;
                            display: flex;
                            flex-direction: column;
                            gap: 15px;
                        }
                        input[type="checkbox"] {
                            accent-color: ${this.selectedtheme === 'dark' ? '#4a90e2' : '#1a73e8'};
                        }
                        input[type="number"]::-webkit-outer-spin-button,
                        input[type="number"]::-webkit-inner-spin-button {
                        -webkit-appearance: none;
                        margin: 0;
                        }
                        /* Hide spinners in Firefox */
                        input[type="number"] {
                        -moz-appearance: textfield;
                        }
                        .read-more {
                            color: ${this.selectedtheme === 'dark' ? '#81c784' : 'green'};
                            text-decoration: underline;
                            font-size: 0.9rem;
                        }
                        .label {
                            font-weight: 500;
                            font-size: 1rem;
                            color: ${this.selectedtheme === 'dark' ? '#ddd' : '#333'};
                        }
                        .radio-row {
                            margin-bottom: 0.5rem;
                            display: flex;
                            align-items: center;
                            justify-content: space-between;
                        }
                        .radio-label {
                            font-size: 0.8rem;
                            color: ${this.selectedtheme === 'dark' ? '#ddd' : '#333'};
                            display: flex;
                            align-items: center;
                            gap: 0.5rem;
                            width: 100%;
                            cursor: pointer;
                            position: relative;
                            justify-content: space-between;
                        }
                        input[type="radio"] {
                            accent-color: ${this.selectedtheme === 'dark' ? '#4a90e2' : '#1a73e8'};
                        }
                        .menu-section {
                            display: ${this.showMenu ? 'block' : 'none'};
                            position: absolute;
                            top: 2.5rem;
                            right: 1.6rem;
                            background: ${this.selectedtheme === 'dark' ? '#3a3a3a' : '#fff'};
                            border: 1px solid ${this.selectedtheme === 'dark' ? '#555' : '#ccc'};
                            border-radius: 5px;
                            box-shadow: 0 2px 5px rgba(0,0,0,0.2);
                            z-index: 10;
                            width: 150px;
                        }
                        .menu-section ul {
                            list-style: none;
                            margin: 0;
                            padding: 0.5rem 0;
                        }
                        .menu-section li {
                            padding: 0.5rem 1rem;
                            font-size: 0.9rem;
                            color: ${this.selectedtheme === 'dark' ? '#ddd' : '#333'};
                            cursor: pointer;
                        }
                        .menu-section li:hover {
                            background: ${this.selectedtheme === 'dark' ? '#4a4a4a' : '#f0f0f0'};
                        }
                    </style>`;

                // Header
                html += `
                    <div class="header-preview">
                        <button class="icon-button" onclick={handleCloseClick} aria-label="Close">
                            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                                <path d="M18 6L6 18" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                                <path d="M6 6L18 18" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                            </svg>
                        </button>
                        <div class="header-welcome">
                            <h2>${screen.title}</h2>
                        </div>
                        <button class="icon-button menu" onclick={handleMenuClick}>⋮</button>
                        
                    </div>
                `;
                if (this.showMenu) {
                    html += `
                        <div class="menu-section">
                            <ul>
                                <li data-option="help">Help</li>
                            </ul>
                        </div>
                    `;
                }

                html += `<div class="content">
                            <div class="content-inner">`;

                const form = screen.layout.children.find(child => child.type === 'Form') || screen.layout;
                form.children.forEach(child => {
                    if (child.type === 'TextHeading') {
                        html += `<h3 class="heading">${child.text}</h3>`;
                    } else if (child.type === 'TextSubheading') {
                        html += `<p class="subheading">${child.text}</p>`;
                    } else if (child.type === 'TextBody') {
                        html += `<p class="body-text">${child.text}</p>`;
                    } else if (child.type === 'TextInput') {
                        html += `
                            <div class="floating-label">
                                <input 
                                    type="${child['input-type']}" 
                                    name="${child.name}" 
                                    id="${child.name}" 
                                    class="input ${this.getInputClass(child.name)} ${this.inputValues[child.name] ? 'active' : ''}" 
                                    value="${this.inputValues[child.name] || ''}"
                                    oninput="this.dispatchEvent(new CustomEvent('inputchange', { detail: { name: '${child.name}', value: this.value, type: this.type } }))"
                                    onfocus="this.dispatchEvent(new CustomEvent('focus', { detail: { name: '${child.name}' } }))"
                                    onblur="this.dispatchEvent(new CustomEvent('blur', { detail: { name: '${child.name}' } }))"
                                />
                                <label for="${child.name}">${child.label}</label>
                            </div>
                        `;
                    } else if (child.type === 'TextArea') {
                        html += `
                            <div class="floating-label">
                                <textarea 
                                    name="${child.name}" 
                                    id="${child.name}" 
                                    class="input ${this.getInputClass(child.name)} ${this.inputValues[child.name] ? 'active' : ''}"
                                    oninput="this.dispatchEvent(new CustomEvent('inputchange', { detail: { name: '${child.name}', value: this.value, type: this.type } }))"
                                    onfocus="this.dispatchEvent(new CustomEvent('focus', { detail: { name: '${child.name}' } }))"
                                    onblur="this.dispatchEvent(new CustomEvent('blur', { detail: { name: '${child.name}' } }))"
                                    rows="4"
                                >${this.inputValues[child.name] || ''}</textarea>
                                <label for="${child.name}">${child.label}</label>
                            </div>
                        `;
                    } else if (child.type === 'RadioButtonsGroup') {
                        html += `
                            <div class="radio-container">
                                <label class="label">${child.label}</label>
                                ${(child['data-source'] || []).map(option => `
                                    <div class="radio-row">
                                        <label class="radio-label">
                                            ${option.title}
                                            <input 
                                                type="radio" 
                                                name="${child.name}" 
                                                value="${option.id}"
                                                ${this.inputValues[child.name] === option.id ? 'checked' : ''}
                                                onchange="this.dispatchEvent(new CustomEvent('inputchange', { detail: { name: '${child.name}', value: this.value, type: this.type } }))"
                                            />
                                        </label>
                                    </div>
                                `).join('')}
                            </div>
                        `;
                    } else if (child.type === 'CheckboxGroup') {
                        html += `
                            <div class="checkbox-container">
                                <label class="label">${child.label}</label>
                                ${(child['data-source'] || []).map(option => `
                                    <label class="checkbox-label">
                                        <input 
                                            type="checkbox" 
                                            name="${child.name}" 
                                            value="${option.id}"
                                            ${this.inputValues[child.name]?.includes(option.id) ? 'checked' : ''}
                                            onchange="this.dispatchEvent(new CustomEvent('inputchange', { detail: { name: '${child.name}', value: this.value, type: this.type } }))"
                                        />
                                        ${option.title}
                                    </label>
                                `).join('')}
                            </div>
                        `;
                    } else if (child.type === 'OptIn') {
                        html += `
                            <div class="checkbox-group">
                                <input 
                                    type="checkbox" 
                                    id="${child.name}" 
                                    name="${child.name}" 
                                    ${this.inputValues[child.name] ? 'checked' : ''}
                                    onchange="this.dispatchEvent(new CustomEvent('inputchange', { detail: { name: '${child.name}', checked: this.checked, type: this.type } }))"
                                />
                                <label for="${child.name}">${child.label}</label>
                                ${child.name === 'tos_optin' ? '<a class="read-more" href="#" onclick="this.dispatchEvent(new CustomEvent(\'navigate\', { detail: { next: \'TERMS_AND_CONDITIONS\' } }))">Read more</a>' : ''}
                            </div>
                        `;
                    } else if (child.type === 'Dropdown') {
                        const hasValue = !!this.inputValues[child.name];
                        html += `
                            <div class="floating-label">
                                <select 
                                    name="${child.name}" 
                                    id="${child.name}" 
                                    class="input ${hasValue ? 'active' : ''} ${this.getInputClass(child.name)}"
                                    onchange="
                                        if (this.value) {
                                            this.classList.add('active');
                                        } else {
                                            this.classList.remove('active');
                                        }
                                        this.dispatchEvent(new CustomEvent('inputchange', { detail: { name: '${child.name}', value: this.value, type: 'select' } }))
                                    "
                                    onfocus="this.classList.add('active')"
                                    onblur="if (!this.value) this.classList.remove('active')"
                                >
                                    <option value="" disabled ${hasValue ? '' : 'selected'}></option>
                                    ${(child['data-source'] || []).map(option => `
                                        <option value="${option.id}" ${this.inputValues[child.name] === option.id ? 'selected' : ''}>${option.title}</option>
                                    `).join('')}
                                </select>
                                <label for="${child.name}">${child.label}</label>
                            </div>
                        `;
                    }
                });

                html += `</div>`;
                html += `</div>`;

                const footer = form.children.find(child => child.type === 'Footer');
                if (footer) {
                    this.contentHeight = '66%';
                    html += `
                        <div class="footer2">
                            <button 
                                class="continue" 
                                data-action='${JSON.stringify(footer["on-click-action"])}'>
                                ${footer.label}
                            </button>
                            <p>Managed by the business. <a href="https://example.com/about" target="_blank">Learn more</a></p>
                        </div>
                    `;
                } else {
                    this.contentHeight = '86%';
                }

                html += `</section>`;

                const mainContainer = this.template.querySelector('.main-container');
                if (mainContainer) {
                    mainContainer.innerHTML = html;

                    // Attach event listener for the close button
                    const closeButton = mainContainer.querySelector('.icon-button[aria-label="Close"]');
                    if (closeButton) {
                        closeButton.addEventListener('click', () => this.handleCloseClick());
                    }

                    // Attach event listeners
                    mainContainer.addEventListener('inputchange', (event) => {
                        const { name, value, checked, type } = event.detail;
                        if (type === 'checkbox') {
                            const currentValues = this.inputValues[name] || [];
                            if (checked) {
                                currentValues.push(value);
                            } else {
                                const index = currentValues.indexOf(value);
                                if (index > -1) currentValues.splice(index, 1);
                            }
                            this.inputValues = { ...this.inputValues, [name]: currentValues };
                        } else {
                            this.inputValues = { ...this.inputValues, [name]: type === 'checkbox' ? checked : value };
                        }
                    });

                    mainContainer.addEventListener('navigate', (event) => {
                        const { next } = event.detail;
                        if (next) {
                            this._currentscreenid = next;
                            this.generatePreview(); // Re-render the preview
                        }
                    });

                    mainContainer.querySelectorAll('button.menu').forEach(button => {
                        button.addEventListener('click', (event) => {
                            try {
                                this.handleMenuClick(event);
                            } catch (e) {
                                console.error('Invalid action JSON:', e);
                            }
                        });
                    });

                    document.querySelectorAll('.floating-label input, .floating-label textarea, .floating-label select').forEach(input => {
                        input.addEventListener('input', () => {
                            if (input.value.trim()) {
                                input.classList.add('active');
                            } else {
                                input.classList.remove('active');
                            }
                        });

                        // Optional: On load
                        if (input.value.trim()) {
                            input.classList.add('active');
                        }
                    });
                    const content = this.template.querySelector('.content');

                    if (content) {
                        content.style.height = `${this.contentHeight}`;
                    }
                }
            }
        }
    }

    handleCloseClick() {
        this.dispatchEvent(new CustomEvent('closepreview', {
            bubbles: true,
            composed: true
        }));
    }

    handleMenuClick(event) {
        event.stopPropagation();
        this.showMenu = !this.showMenu;
        this.generatePreview();
    }

    // Dynamically get input class based on name
    getInputClass(name) {
        return `input ${this.inputFocus[name] || this.inputValues[name] ? 'active' : ''}`;
    }
}