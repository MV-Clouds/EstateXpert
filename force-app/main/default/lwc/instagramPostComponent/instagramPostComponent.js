import { LightningElement, track } from 'lwc';
// import createInstagramPost from '@salesforce/apex/InstagramPostController.createInstagramPost';

export default class InstagramPostComponent extends LightningElement {
    @track images = [];
    @track videos = [];
    @track caption = '';

    handleImageUpload(event) {
        const files = event.target.files;
        for (let i = 0; i < files.length; i++) {
            const file = files[i];
            const reader = new FileReader();
            reader.onloadend = () => {
                this.images.push({
                    name: file.name,
                    data: reader.result
                });
            };
            reader.readAsDataURL(file);
        }
    }

    handleVideoUpload(event) {
        const files = event.target.files;
        for (let i = 0; i < files.length; i++) {
            const file = files[i];
            const reader = new FileReader();
            reader.onloadend = () => {
                this.videos.push({
                    name: file.name,
                    data: reader.result
                });
            };
            reader.readAsDataURL(file);
        }
    }

    handleCaptionChange(event) {
        this.caption = event.target.value;
    }

    handleImageRemove() {
        // this.images.splice(index, 1);
    }

    handleSubmit() {
        const postData = {
            images: this.images,
            videos: this.videos,
            caption: this.caption
        };

        // createInstagramPost({ postData })
        //     .then(result => {
        //         // Handle success
        //         console.log('Instagram post created successfully', result);
        //         // Reset form or display success message
        //     })
        //     .catch(error => {
        //         // Handle error
        //         console.error('Error creating Instagram post', error);
        //         // Display error message
        //     });
    }
}