import { LightningElement } from 'lwc';
import getGeminiResponse from '@salesforce/apex/GeminiChatService.getGeminiResponse';
import getListingFields from '@salesforce/apex/GeminiChatService.getListingFields';
import sendFeedbackEmail from '@salesforce/apex/GeminiChatService.sendFeedbackEmail';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import SUPPORT_EMAILS from '@salesforce/label/c.supportEmail';

export default class ChatBot extends LightningElement {
    userInput = '';
    isLoading = false;
    conversationState = 'WELCOME';
    messages = [];
    propertyCriteria = {};
    showChat = true;
    formSubject = '';
    formDescription = '';
    uploadedImages = [];

    // Default fields to display for properties
    defaultFields = ['MVEX__Address__c', 'MVEX__Listing_Price__c', 'MVEX__Bedrooms__c', 'MVEX__Bathrooms__c', 'MVEX__Property_Type__c', 'MVEX__Listing_Type__c', 'MVEX__Size__c'];

    get formattedMessages() {
        return this.messages.map(message => ({
            ...message,
            className: message.isBot ? (message.isError ? 'message bot error' : 'message bot') : 'message user'
        }));
    }

    connectedCallback() {
        this.initializeChat();
    }

    initializeChat() {
        this.conversationState = 'WELCOME';
        this.messages = [{
            id: 1,
            text: 'Hello! I’m ChatXpert, the support bot for EstateXpert. How can I help you today?',
            isBot: true
        }];
        setTimeout(() => {
            const input = this.template.querySelector('.chat-input-field');
            if (input) input.focus();
        }, 0);
    }

    toggleForm(event) {
        this.showChat = event.target.checked;
        if (!this.showChat) {
            this.formSubject = '';
            this.formDescription = '';
            this.uploadedImages = [];
            this.scrollToBottom();
        }
    }

    handleInputChange(event) {
        this.userInput = event.target.value;
    }

    handleFormInputChange(event) {
        const field = event.target.dataset.field;
        this[field] = event.target.value;
    }

    handleImageChange(event) {
        const files = Array.from(event.target.files);
        const maxTotalSize = 4 * 1024 * 1024; // 4MB in bytes
        const validFormats = ['image/jpeg', 'image/jpg', 'image/png'];
        let totalSize = this.uploadedImages.reduce((sum, img) => sum + img.file.size, 0);

        files.forEach(file => {
            if (!validFormats.includes(file.type)) {
                this.showToast('Error', `${file.name} is not a valid image format (jpg, jpeg, or png only).`, 'error');
                return;
            }
            if (totalSize + file.size > maxTotalSize) {
                this.showToast('Error', `Cannot add ${file.name}. Total image size exceeds 4MB.`, 'error');
                return;
            }
            const reader = new FileReader();
            reader.onload = () => {
                this.uploadedImages = [...this.uploadedImages, {
                    id: Math.random().toString(36).substring(2),
                    url: reader.result,
                    file: file
                }];
                totalSize += file.size;
            };
            reader.readAsDataURL(file);
        });
    }

    removeImage(event) {
        const index = event.target.dataset.index;
        this.uploadedImages = this.uploadedImages.filter((_, i) => i !== parseInt(index));
    }

    async handleSendMessage() {
        const trimmedInput = this.userInput.trim();
        if (trimmedInput === '') return;

        this.messages = [...this.messages, { id: this.messages.length + 1, text: trimmedInput, isBot: false }];
        this.isLoading = true;
        this.scrollToBottom();

        try {
            if (await this.detectPropertyQuery(trimmedInput)) {
                this.conversationState = 'CHATTING';
                await this.handleWelcome(trimmedInput);
            } else {
                await this.handleGeneralQuery(trimmedInput);
            }
        } catch (error) {
            console.error('Error in handleSendMessage:', error);
            this.messages = [...this.messages, {
                id: this.messages.length + 1,
                text: 'Oops, something went wrong. Please try again or use the feedback form to report this issue.',
                isBot: true,
                isError: true
            }];
        } finally {
            this.isLoading = false;
            this.userInput = '';
            this.template.querySelector('.chat-input-field').value = '';
            this.scrollToBottom();
        }
    }

    async handleGeneralQuery(input) {
        try {
            const geminiResponse = await getGeminiResponse({ userInput: input });
            if (geminiResponse.includes('I can only assist with questions related to Salesforce or real estate')) {
                this.messages = [...this.messages, {
                    id: this.messages.length + 1,
                    text: geminiResponse,
                    isBot: true,
                    isError: true
                }];
            } else {
                this.messages = [...this.messages, {
                    id: this.messages.length + 1,
                    text: geminiResponse,
                    isBot: true
                }];
            }
        } catch (error) {
            console.error('Gemini API error for general question:', error);
            this.messages = [...this.messages, {
                id: this.messages.length + 1,
                text: `I ran into an issue answering your question. Please try rephrasing or use the feedback form to contact support at ${SUPPORT_EMAILS}.`,
                isBot: true,
                isError: true
            }];
        }
    }

    async handleFormSubmit() {
        if (!this.formSubject || !this.formDescription) {
            this.showToast('Error', 'Please fill out all required fields.', 'error');
            return;
        }

        this.isLoading = true;
        try {
            const imageBase64Array = await Promise.all(
                this.uploadedImages.map(image => this.readFileAsBase64(image.file))
            );
            const result = await sendFeedbackEmail({
                subject: this.formSubject,
                description: this.formDescription,
                images: imageBase64Array
            });
            if (result === 'Success') {
                this.showToast('Success', 'Your feedback has been sent successfully.', 'success');
                this.resetAll();
            } else {
                this.showToast('Error', 'Failed to send feedback. Please try again.', 'error');
            }
        } catch (error) {
            console.error('Error sending feedback:', error);
            this.showToast('Error', 'An error occurred while sending feedback. Please try again.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    resetAll() {
        this.showChat = true;
        this.formSubject = '';
        this.formDescription = '';
        this.uploadedImages = [];
        this.userInput = '';
        this.messages = [];
        this.conversationState = 'WELCOME';
        this.propertyCriteria = {};
        this.initializeChat();
    }

    resetForm() {
        this.formSubject = '';
        this.formDescription = '';
        this.uploadedImages = [];
    }

    async readFileAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve(reader.result.split(',')[1]);
            reader.onerror = error => reject(error);
            reader.readAsDataURL(file);
        });
    }

    async handleWelcome(input) {
        const isPropertyQuery = await this.detectPropertyQuery(input);
        if (isPropertyQuery) {
            this.propertyCriteria = await this.parsePropertyCriteria(input);
            this.conversationState = 'CHATTING';
            this.messages = [...this.messages, {
                id: this.messages.length + 1,
                text: 'Awesome, I’ve got your property request! Let me search for properties matching your criteria...',
                isBot: true
            }];
            await this.handlePropertyQuery('');
        } else {
            await this.handleGeneralQuery(input);
        }
    }

    async detectPropertyQuery(input) {
        const propertySearchKeywords = /(\d+\s*(bedroom|bed|bhk|br)|house|apartment|condo|flat|townhouse|villa|studio|under\s+\$?\d+|budget\s+\$?\d+)/i;
        return propertySearchKeywords.test(input.toLowerCase());
    }

    async parsePropertyCriteria(input) {
        const criteria = {};
        let normalizedInput = input.toLowerCase().trim();

        normalizedInput = normalizedInput
            .replace(/(\d+)(bhk|br|bedroom|bed)/gi, '$1 $2')
            .replace(/\s+/g, ' ')
            .replace(/(\d+)\s*(k)/gi, '$1 $2')
            .replace(/ten/gi, '10')
            .replace(/under|below|less than/gi, 'under');

        const bedroomMatch = normalizedInput.match(/(\d+)\s*(bedroom|bed|bhk|br)s?/i);
        if (bedroomMatch) {
            criteria.bedrooms = parseInt(bedroomMatch[1]);
            normalizedInput = normalizedInput.replace(bedroomMatch[0], '');
        }

        const locationMatch = normalizedInput.match(/(in|near|at)\s+([a-z\s]+?)(?=\s*(with|under|$|\d))/i);
        if (locationMatch) {
            criteria.location = locationMatch[2].trim();
            normalizedInput = normalizedInput.replace(locationMatch[0], '');
        }

        const budgetMatch = normalizedInput.match(/(under|below)\s+\$?(\d{1,}(\.\d{1,2})?)/i);
        if (budgetMatch) {
            criteria.budget = parseFloat(budgetMatch[2]);
            normalizedInput = normalizedInput.replace(budgetMatch[0], '');
        }

        const typeMatch = normalizedInput.match(/(house|apartment|condo|flat|townhouse|villa|studio)/i);
        if (typeMatch) {
            criteria.propertyType = typeMatch[1];
            normalizedInput = normalizedInput.replace(typeMatch[0], '');
        }

        const bathroomMatch = normalizedInput.match(/(\d+)\s*(bathroom|bath|ba)s?/i);
        if (bathroomMatch) {
            criteria.bathrooms = parseInt(bathroomMatch[1]);
            normalizedInput = normalizedInput.replace(bathroomMatch[0], '');
        }

        const amenitiesMatch = normalizedInput.match(/(pool|gym|parking|garden|balcony|terrace)/i);
        if (amenitiesMatch) {
            criteria.amenities = amenitiesMatch[1];
            normalizedInput = normalizedInput.replace(amenitiesMatch[0], '');
        }

        const listingTypeMatch = normalizedInput.match(/(buy|rent|sale)/i);
        if (listingTypeMatch) {
            criteria.listingType = listingTypeMatch[1];
        }

        // Detect specific field requests
        const specificFieldsMatch = normalizedInput.match(/show\s+(?:me\s+)?(?:details\s+of\s+)?([\w\s,]+?)(?=\s*(in|under|$))/i);
        if (specificFieldsMatch) {
            const requestedFields = specificFieldsMatch[1].split(',').map(field => field.trim().replace(/\s+/g, '_') + '__c');
            criteria.specificFields = requestedFields.filter(field => field !== '__c');
        }

        if (Object.keys(criteria).length === 0) {
            try {
                const geminiResponse = await getGeminiResponse({
                    userInput: `Parse the following property query into JSON with fields for bedrooms, location, budget, propertyType, bathrooms, amenities, listingType, and specificFields: "${input}"`
                });
                const parsed = JSON.parse(geminiResponse);
                Object.assign(criteria, parsed);
            } catch (error) {
                console.error('Gemini API fallback failed:', error);
            }
        }

        return criteria;
    }

    async handlePropertyQuery(input) {
        if (input) {
            this.propertyCriteria = await this.parsePropertyCriteria(input);
        }

        const fieldSchema = await getListingFields();
        if (fieldSchema.error) {
            this.messages = [...this.messages, {
                id: this.messages.length + 1,
                text: fieldSchema.error,
                isBot: true,
                isError: true
            }];
            return;
        }

        const query = await this.generateSOQLQuery(fieldSchema);
        const properties = await getGeminiResponse({ userInput: query });

        if (properties && properties.startsWith('Error:')) {
            this.messages = [...this.messages, {
                id: this.messages.length + 1,
                text: `I ran into an issue while searching: ${properties}. Please try again or use the feedback form to contact support.`,
                isBot: true,
                isError: true
            }];
            return;
        }

        const parsedProperties = JSON.parse(properties);
        if (parsedProperties.length === 0) {
            this.messages = [...this.messages, {
                id: this.messages.length + 1,
                text: 'I couldn’t find any properties matching your criteria. Would you like to try different requirements, like adjusting the budget or location? Alternatively, you can use the feedback form to contact support.',
                isBot: true
            }];
        } else {
            this.messages = [...this.messages, {
                id: this.messages.length + 1,
                text: `Great news! I found ${parsedProperties.length} properties that match your criteria:`,
                isBot: true
            }];

            // Determine which fields to display
            const fieldsToDisplay = this.propertyCriteria.specificFields && this.propertyCriteria.specificFields.length > 0
                ? this.propertyCriteria.specificFields
                : this.defaultFields;

            parsedProperties.forEach((prop, index) => {
                let propDetails = [`Property ${index + 1}:`];
                fieldsToDisplay.forEach(field => {
                    if (prop[field] != null) {
                        const fieldInfo = fieldSchema.find(f => f.name === field);
                        const fieldLabel = fieldInfo ? fieldInfo.label : field.replace('_c', '').replace('_', ' ');
                        propDetails.push(`  ${fieldLabel}: ${prop[field]}`);
                    }
                });
                this.messages = [...this.messages, {
                    id: this.messages.length + 1,
                    text: propDetails.join('\n'),
                    isBot: true
                }];
            });
            this.messages = [...this.messages, {
                id: this.messages.length + 1,
                text: 'Interested in any of these? Let me know if you want more details (e.g., say "show me amenities, square footage" for specific fields) or if you’d like to tweak your search (e.g., different budget, more bedrooms, or another city).',
                isBot: true
            }];
        }
    }

    async generateSOQLQuery(fieldSchema) {
        let conditions = [];
        if (this.propertyCriteria.location) {
            conditions.push(`MVEX__City__c LIKE '%${String.escapeSingleQuotes(this.propertyCriteria.location)}%' OR MVEX__Address__c LIKE '%${String.escapeSingleQuotes(this.propertyCriteria.location)}%'`);
        }
        if (this.propertyCriteria.budget) {
            conditions.push(`MVEX__Price__c <= ${this.propertyCriteria.budget}`);
        }
        if (this.propertyCriteria.bedrooms) {
            conditions.push(`MVEX__Bedrooms__c = ${this.propertyCriteria.bedrooms}`);
        }
        if (this.propertyCriteria.bathrooms) {
            conditions.push(`MVEX__Bathrooms__c = ${this.propertyCriteria.bathrooms}`);
        }
        if (this.propertyCriteria.propertyType) {
            conditions.push(`MVEX__Property_Type__c = '${String.escapeSingleQuotes(this.propertyCriteria.propertyType)}'`);
        }
        if (this.propertyCriteria.amenities) {
            conditions.push(`MVEX__Amenities__c LIKE '%${String.escapeSingleQuotes(this.propertyCriteria.amenities)}%'`);
        }
        if (this.propertyCriteria.listingType) {
            const listingType = this.propertyCriteria.listingType.toLowerCase() === 'buy' || this.propertyCriteria.listingType.toLowerCase() === 'sale' ? 'Sale' : 'Rent';
            conditions.push(`MVEX__Listing_Type__c = '${String.escapeSingleQuotes(listingType)}'`);
        }

        // Use specific fields if requested, otherwise use default fields
        const fieldsToQuery = this.propertyCriteria.specificFields && this.propertyCriteria.specificFields.length > 0
            ? this.propertyCriteria.specificFields
            : this.defaultFields;
        const fields = fieldsToQuery
            .filter(f => fieldSchema.some(fs => fs.name === f))
            .join(', ');
        let query = `SELECT ${fields} FROM MVEX__Listing__c`;
        if (conditions.length > 0) {
            query += ' WHERE ' + conditions.join(' AND ');
        }
        query += ' LIMIT 10';
        return query;
    }

    handleKeyPress(event) {
        if (event.key === 'Enter' && !this.isLoading) {
            this.handleSendMessage();
        }
    }

    scrollToBottom() {
        setTimeout(() => {
            const chatBody = this.template.querySelector('.chat-body');
            if (chatBody) {
                chatBody.scrollTop = chatBody.scrollHeight;
            }
        }, 0);
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(evt);
    }
}