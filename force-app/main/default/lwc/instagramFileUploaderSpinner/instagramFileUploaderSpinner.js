import { LightningElement } from 'lwc';

export default class InstagramFileUploaderSpinner extends LightningElement {
    isLoading = false;        // Track the loading state
    progress = 0;             // Track the progress of the upload
    progressText = 'Ready to upload'; // Initial text
    progressStyle = 'width: 0%'; // Initial progress bar width
    arrowPosition = 0;        // Track the arrow position

    handleFiles(event) {
        // Triggered when a file is selected
        const files = event.target.files;

        if (files.length > 0) {
            this.isLoading = true;       // Show the overlay
            this.progress = 0;           // Reset progress
            this.progressText = 'Uploading...'; // Change text
            this.progressStyle = 'width: 0%';   // Reset progress bar
            this.arrowPosition = 0;       // Reset arrow position

            // Simulate file upload process
            this.simulateFileUpload();
        }
    }

    simulateFileUpload() {
        const interval = setInterval(() => {
            if (this.progress < 100) {
                this.progress += 10; // Increase progress by 10%
                this.progressStyle = `width: ${this.progress}%`; // Update progress bar style
                this.arrowPosition += 2; // Move arrow position toward Instagram icon
            } else {
                this.progressText = 'File uploaded successfully'; // Change text after completion
                clearInterval(interval);  // Stop the progress interval
                setTimeout(() => {
                    this.isLoading = false; // Hide the overlay after a short delay
                }, 500);
            }
        }, 500); // Update every 500ms (simulate upload delay)
    }
}