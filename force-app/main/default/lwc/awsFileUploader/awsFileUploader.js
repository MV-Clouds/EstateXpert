import { LightningElement, track, api } from 'lwc';
import getS3ConfigSettings from "@salesforce/apex/ImageAndMediaController.getS3ConfigSettings";
import AWS_SDK from "@salesforce/resourceUrl/AWSSDK";
import createmediaforlisting from "@salesforce/apex/ImageAndMediaController.createmediaforlisting";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import watermarkjs from "@salesforce/resourceUrl/watermarkjs";
import buffer from 'c/buffer';
import videoThumbnail from '@salesforce/resourceUrl/videothumbnail';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { errorDebugger } from 'c/globalProperties';

export default class AwsFileUploader extends LightningElement {

    @api propertyId;
    @track confData;
    @track s3;
    @track isAwsSdkInitialized = true;
    @track selectedFilesToUpload = [];
    @track imageToShowFiles = [];
    @track showSpinner = true;
    @track fileName = [];
    @track uploadProgress = 0;
    @track fileSize = [];
    @track isFileUploading = false;
    @track data = [];
    @track isWatermark = true;
    @track imageUrlToUpload;
    @track imageTitleToUpload;
    @track selectedUrlType = 'Image';
    @track currentDateTimeWithSeconds = '';
    @track logo;
    @track thumbnail = videoThumbnail;
    @track fileURL = [];
    @track isContentVersionDataIsAvailable = false;
    @track isAWS = true;
    @track uploadStatus = false;
    @track isImageData = false;
    @track isScrolling = false;
    @track isIntegrated = false;

    /**
    * Method Name: options
    * @description: Used to get options.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    get options() {
        return [
            { label: 'Image', value: 'Image' },
            { label: 'Video', value: 'Video' }
        ];
    }

    get checkboxDisabled() {
        return !this.isContentVersionDataIsAvailable;
    }

    /**
    * Method Name: connectedCallback
    * @description: Used to load css and fetch data.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    connectedCallback() {
        try {
            loadStyle(this, MulishFontCss);
            this.getS3ConfigDataAsync();
            this.timeInString();
        } catch (error) {
            errorDebugger('AwsFileUploader', 'connectedCallback', error, 'warn', 'Error while loading css and fetching data');
        }
    }

    /**
    * Method Name: renderedCallback
    * @description: Used to load script and fetch data.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    renderedCallback() {
        try {
            if (this.isAwsSdkInitialized) {
                Promise.all([loadScript(this, AWS_SDK), loadScript(this, watermarkjs)]);
                this.isAwsSdkInitialized = false;
            }

            if (this.isScrolling) {
                const container = this.template.querySelector('.active-tab-content');
                if (container) {
                    container.scrollTop = container.scrollHeight;
                }
                this.isScrolling = false;
            }
        } catch (error) {
            errorDebugger('AwsFileUploader', 'renderedCallback', error, 'warn', 'Error while loading script and fetching data');
        }
    }

    /**
    * Method Name: tabing
    * @description: Used to change the tabs on click.
    * Created Date: 23/12/2024
    * Created By: Karan Singh
    */
    tabing(event) {
        try {
            let actionName = event.currentTarget.dataset.name;
            this.isAWS = actionName == 'AWS' ? true : false;

            const target = event.currentTarget.querySelector('a').getAttribute('data-tab-id');

            this.template.querySelectorAll("a").forEach(tabel => {
                tabel.classList.remove("active-tab");
            });

            this.template.querySelectorAll(".tab").forEach(tabdata => {
                tabdata.classList.remove("active-tab-content");
            });

            this.template.querySelector('[data-tab-id="' + target + '"]').classList.add("active-tab");

            this.template.querySelector('[data-id="' + target + '"]').classList.add("active-tab-content");
        } catch (error) {
            errorDebugger('AwsFileUploader', 'tabing', error, 'warn', 'Error while changing the tabs on click');
        }
    }

    /**
    * Method Name: handleOnSave
    * @description: Used to handle on save.
    * Created Date: 23/12/2024
    * Created By: Karan Singh
    */
    handleOnSave() {
        try {
            this.uploadStatus = true;
            this.showSpinner = true;
            if (this.isAWS) {
                if (this.isIntegrated) {
                    this.handleclick();
                } else {
                    this.showToast('Error', 'Please integrate the AWS first to use this feature.', 'error');
                    this.showSpinner = false;
                }
            } else {
                this.uploadImage();
            }
        } catch (error) {
            errorDebugger('AwsFileUploader', 'handleOnSave', error, 'warn', 'Error while handling on save');
            this.showSpinner = false;
        }
    }


    /**
    * Method Name: timeInString
    * @description: Used to get current date and time.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    timeInString() {
        try {
            const currentDateTime = new Date();

            const day = currentDateTime.getDate().toString().padStart(2, '0');
            const month = (currentDateTime.getMonth() + 1).toString().padStart(2, '0'); // Month is zero-indexed, so add 1
            const year = currentDateTime.getFullYear().toString();
            const hours = currentDateTime.getHours().toString().padStart(2, '0');
            const minutes = currentDateTime.getMinutes().toString().padStart(2, '0');
            const seconds = currentDateTime.getSeconds().toString().padStart(2, '0');

            const formattedDateTime = `${day}_${month}_${year}_${hours}:${minutes}:${seconds}`;
            this.currentDateTimeWithSeconds = formattedDateTime;
        } catch (error) {
            errorDebugger('AwsFileUploader', 'timeInString', error, 'warn', 'Error while getting current date and time');
        }
    }

    /**
    * Method Name: storeUrl
    * @description: Used to store url.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    storeUrl(event) {
        try {
            switch (event.target.label) {
                case 'Title':
                    this.imageTitleToUpload = event.target.value;
                    break;
                case 'External Link (URL)':
                    this.imageUrlToUpload = event.target.value;
                    break;
                default:
                    break;
            }
        } catch (error) {
            errorDebugger('AwsFileUploader', 'storeUrl', error, 'warn', 'Error while storing url');
        }
    }

    /**
    * Method Name: getS3ConfigDataAsync
    * @description: Used to get s3 config data.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    getS3ConfigDataAsync() {
        try {
            getS3ConfigSettings()
                .then(result => {
                    this.showSpinner = false;
                    if (result.status) {
                        this.confData = result.awsConfigData;
                        this.isContentVersionDataIsAvailable = result.contentVersionData !== '' ? true : false;
                        this.isWatermark = this.isContentVersionDataIsAvailable;
                        this.logo = result.contentVersionData;
                        this.isIntegrated = result.isIntegrated;
                    } else {
                        this.showToast('Error', result.contentVersionData, 'error');
                    }
                }).catch(error => {
                    this.showSpinner = false;
                    this.showToast('Error', error, 'error');
                    errorDebugger('AwsFileUploader', 'getS3ConfigDataAsync:getS3ConfigSettings', error, 'warn', 'Error while getting s3 config data');
                });
        } catch (error) {
            this.showSpinner = false;
            errorDebugger('AwsFileUploader', 'getS3ConfigDataAsync', error, 'warn', 'Error while getting s3 config data');
        }
    }

    /**
    * Method Name: handleLinkType
    * @description: Used to handle link type.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    handleLinkType(event) {
        this.selectedUrlType = event.target.value;
    }

    /**
    * Method Name: createThumb
    * @description: Used to create thumbnail.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    createThumb(videoUrl) {
        try {
            const regex = /(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})/;
            const match = videoUrl.match(regex);
            return match ? match[1] : null;
        } catch (error) {
            errorDebugger('AwsFileUploader', 'createThumb', error, 'warn', 'Error while creating thumbnail');
        }

        return null; // Return null if no match is found 
    }

    /**
    * Method Name: uploadImage
    * @description: Used to upload image.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    uploadImage() {
        try {
            const urlPattern = new RegExp('^(https?:\\/\\/)?'+ // protocol
                    '((([a-z0-9\\-]+\\.)+[a-z]{2,})|'+ // domain name
                    'localhost|'+ // localhost
                    '\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}|'+ // IP address
                    '\\[?[a-f0-9]*:[a-f0-9:%.]+\\]?)'+ // IPv6
                    '(\\:\\d+)?(\\/[-a-z0-9%_.~+]*)*'+ // port and path
                    '(\\?[;&a-z0-9%_.~+=-]*)?'+ // query string
                    '(\\#[-a-z0-9_]*)?$','i'); // fragment locator
            if (this.imageTitleToUpload?.trim() && this.imageUrlToUpload) {
                if (this.selectedUrlType === 'Image') {
                    if (!this.imageUrlToUpload.match(/\.(png|jpg|jpeg|gif|png|svg)(\?.*)?$/)) {
                        this.showToast('Error', 'Invalid Url kindly check url and type', 'error');
                        this.uploadStatus = false;
                        this.showSpinner = false;
                    } else {
                        let fileContent = [];
                        fileContent.push({
                            externalUrl: this.imageUrlToUpload,
                            name: this.imageTitleToUpload + this.currentDateTimeWithSeconds,
                            isOnExpose: true,
                            isOnPortalFeed: true,
                            isOnWebsite: true
                        })
                        createmediaforlisting({ recordId: this.propertyId, mediaList: fileContent })
                        .then(result => {
                            if (result == 'success') {
                                this.handleDialogueCloseAndRefresh();
                                this.imageTitleToUpload = null;
                                this.showToast('Success', 'Image uploaded successfully.', 'success');
                            } else {
                                this.showToast('Error', result, 'error');
                                this.uploadStatus = false;
                                this.showSpinner = false;
                            }

                        }).catch(error => {
                            this.showToast('Error', JSON.stringify(error.stack), 'error');
                            this.showSpinner = false;
                            this.uploadStatus = false;
                            errorDebugger('AwsFileUploader', 'uploadImage:createmediaforlisting', error, 'warn', 'Error while uploading image');
                        });
                    }
                } else if (this.selectedUrlType === 'Video') {
                    if (urlPattern.test(this.imageUrlToUpload) && !this.imageUrlToUpload.match(/\.(png|jpg|jpeg|gif|png|svg)(\?.*)?$/)) {
                        const videoId = this.createThumb(this.imageUrlToUpload);
                        let fileContent = [];
                        fileContent.push({
                            recordId: this.propertyId,
                            externalUrl: videoId != null ? `https://img.youtube.com/vi/${videoId}/mqdefault.jpg` : this.thumbnail,
                            name: this.imageTitleToUpload + this.currentDateTimeWithSeconds,
                            isOnExpose: true,
                            isOnPortalFeed: true,
                            isOnWebsite: true,
                            externalVideoUrl: this.imageUrlToUpload
                        })
                        createmediaforlisting({ recordId: this.propertyId, mediaList: fileContent })
                            .then(result => {
                                if (result == 'success') {
                                    this.handleDialogueCloseAndRefresh();
                                    this.imageTitleToUpload = null;
                                    this.showToast('Success', 'Video uploaded successfully.', 'success');
                                } else {
                                    this.showSpinner = false;
                                    this.uploadStatus = false;
                                    this.showToast('Error', result, 'error');
                                }
                            })
                            .catch(error => {
                                this.showSpinner = false;
                                this.uploadStatus = false;
                                this.showToast('Error', JSON.stringify(error), 'error');
                                errorDebugger('AwsFileUploader', 'uploadImage:createmediaforlisting', error, 'warn', 'Error while uploading video');
                            });
                    } else {
                        this.showToast('Error', 'Invalid Url kindly check url and type', 'error');
                        this.showSpinner = false;
                        this.uploadStatus = false;
                    }
                } else {
                    this.showToast('Error', 'Image URL and file name are required.', 'error');
                    this.showSpinner = false;
                    this.uploadStatus = false;
                }
            } else {
                this.showToast('Error', 'Please fill all required fields.', 'error');
                this.showSpinner = false;
                this.uploadStatus = false;
            }
        } catch (error) {
            errorDebugger('AwsFileUploader', 'uploadImage', error, 'warn', 'Error while uploading image');
        }
    }

    /**
    * Method Name: initializeAwsSdk
    * @description: Used to initialize aws sdk.
    * @param {object} confData - The configuration data to initialize the AWS SDK.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    initializeAwsSdk(confData) {
        try {
            let AWS = window.AWS;

            AWS.config.update({
                accessKeyId: confData.MVEX__AWS_Access_Key__c,
                secretAccessKey: confData.MVEX__AWS_Secret_Access_Key__c
            });

            AWS.config.region = confData.MVEX__S3_Region_Name__c;

            this.s3 = new AWS.S3({
                apiVersion: "2006-03-01",
                params: {
                    Bucket: confData.MVEX__S3_Bucket_Name__c
                }
            });

        } catch (error) {
            this.showSpinner = false;
            errorDebugger('AwsFileUploader', 'initializeAwsSdk', error, 'warn', 'Error while initializing aws sdk');
        }
    }

    /**
    * Method Name: handleRemove
    * @description: Used to handle remove.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    handleRemove(event) {
        try {
            const fileName = event.currentTarget.dataset.name;
            // Get the index of the file to remove
            const index_of_fileName = this.fileName.indexOf(fileName);
        
            if (index_of_fileName > -1) {
                // Remove the file from the relevant arrays
                this.imageToShowFiles.splice(index_of_fileName, 1);
                this.fileName.splice(index_of_fileName, 1);
                this.selectedFilesToUpload.splice(index_of_fileName, 1);
                this.fileSize.splice(index_of_fileName, 1);
            }
        
            // Reset the file input
            this.template.querySelector('.slds-file-selector__input').value = null;
        
            // If no files left, update the boolean flag
            if (this.imageToShowFiles.length === 0) {
                this.isImageData = false;
            }
        } catch (error) {
            errorDebugger('AwsFileUploader', 'handleRemove', error, 'warn', 'Error while handling remove');
        }
    }
    

    /**
    * Method Name: handleSelectedFiles
    * @description: Used to handle selected files.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    async handleSelectedFiles(event) {
        try {
            const files = event.target.files;
            if (files.length > 0) {
                this.isImageData = true;
                this.largeImagefiles = [];
                let totalSize = 0; // Initialize total size variable

                for (let fileCount = 0; fileCount < files.length; fileCount++) {
                    let file = files[fileCount];
                    const fileSizeInMB = Math.floor((file.size) / 1024); // Size in KB

                    // Check if the individual file size is within 10 MB
                    if (fileSizeInMB <= 10240) {
                        // Check if adding this file exceeds the total size limit of 20 MB
                        if (totalSize + fileSizeInMB <= 20240) {
                            this.selectedFilesToUpload.push(file);
                            this.fileName.push(file.name);
                            this.fileSize.push(fileSizeInMB);
                            totalSize += fileSizeInMB; // Update total size

                            const fileData = {
                                name: file.name,
                                size: file.size,
                                preview: file.type != 'video/mp4' ? URL.createObjectURL(file) : await this.createThumbnail(file)
                            };
                            this.imageToShowFiles.push(fileData);
                        } else {
                            this.showToast('Error', 'Total file size exceeds 20 MB limit.', 'error');
                        }
                    } else {
                        this.largeImagefiles.push(file.name);
                    }
                }

                if (this.largeImagefiles.length > 0) {
                    this.showToast('Error', this.largeImagefiles + ' has size more than 10 MB', 'error');
                }
            }
            this.template.querySelector('.slds-file-selector__input').value = null;

            this.isScrolling = true;
            
        } catch (error) {
            errorDebugger('AwsFileUploader', 'handleSelectedFiles', error, 'warn', 'Error while handling selected files');
        }
    }

    /**
    * Method Name: createThumbnail
    * @description: Used to create thumbnail for video file.
    * @param: file: The file to create thumbnail.
    * Created Date: 23/12/2024
    * Created By: Karan Singh
    * */
    createThumbnail(file) {
        return new Promise((resolve, reject) => {
            try {
                const video = document.createElement('video');
                const canvas = document.createElement('canvas');
                const context = canvas.getContext('2d');
    
                video.src = URL.createObjectURL(file);
                
                video.addEventListener('loadeddata', () => {
                    video.currentTime = 1;
                    
                    video.addEventListener('seeked', () => {
                        canvas.width = video.videoWidth;
                        canvas.height = video.videoHeight;
    
                        context.drawImage(video, 0, 0, canvas.width, canvas.height);
    
                        const thumbnailDataUrl = canvas.toDataURL('image/jpeg');
    
                        resolve(thumbnailDataUrl);
                    });
                });
    
                video.onerror = () => {
                    reject('Error loading video file');
                };

            } catch (error) {
                reject(`Error in createThumbnail -> ${error.stack}`);
            }
        });
    }


    /**
    * Method Name: handleclick
    * @description: Used to handle click.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    async handleclick() {
        try {
            if (this.isContentVersionDataIsAvailable === false && this.isWatermark === true) {
                this.showSpinner = false;
                this.uploadStatus = false;
                this.showToast('Error', 'Please uncheck the "Upload Image With Watermark" checkbox or upload a watermark image from the Control Center.', 'error');
                return;
            }

            if (this.selectedFilesToUpload.length == 0) {
                this.showSpinner = false;
                this.uploadStatus = false;
                this.showToast('Error', 'Please select a file to upload.', 'error');
                return;
            }

            if (this.propertyId != undefined) {
                await this.uploadToAWS(this.selectedFilesToUpload);

                let contents = [];
                for (let file = 0; file < this.selectedFilesToUpload.length; file++) {
                    contents.push({
                        recordId: this.propertyId,
                        externalUrl: this.selectedFilesToUpload[file].type != 'video/mp4' ? this.fileURL[file] : this.thumbnail,
                        externalVideoUrl: this.fileURL[file],
                        name: this.renameFileName(this.fileName[file]),
                        size: this.fileSize[file],
                        type: this.selectedFilesToUpload[file].type,
                        isOnExpose: true,
                        isOnPortalFeed: true,
                        isOnWebsite: true
                    });
                }
                createmediaforlisting({ recordId: this.propertyId, mediaList: contents })
                    .then(result => {
                        this.showSpinner = false;
                        if (result == 'success') {
                            this.handleDialogueCloseAndRefresh();
                        } else {
                            this.showToast('Error', result, 'error');
                        }
                    }).catch(error => {
                        this.showSpinner = false;
                        this.uploadStatus = false;
                        this.showToast('Error', error, 'error');
                        errorDebugger('AwsFileUploader', 'handleclick:createmediaforlisting', error, 'warn', 'Error while uploading image');
                    });
            } else {
                this.showSpinner = false;
                this.uploadStatus = false;
                this.showToast('Error', 'Property not added.', 'error');
            }
        } catch (error) {
            this.showSpinner = false;
            this.uploadStatus = false;
            this.showToast('Error', JSON.stringify(error.stack), 'error');
            errorDebugger('AwsFileUploader', 'handleclick', error, 'warn', 'Error while handling click');
        }
    }

    /**
    * Method Name: uploadToAWS
    * @description: Used to upload to aws.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    async uploadToAWS() {
        try {
            this.initializeAwsSdk(this.confData);
            const uploadPromises = this.selectedFilesToUpload.map(async (file, index) => {
                this.showSpinner = true;
                let objKey = this.renameFileName(this.fileName[index]);

                let params = {
                    Key: objKey,
                    ContentType: this.isWatermark && file.type !== 'video/mp4' ? 'image/jpeg' : file.type,
                    Body: this.isWatermark && file.type !== 'video/mp4' ? await this.compressAndWatermarkImage(file) : file,
                    ACL: "public-read"
                };

                let upload = this.s3.upload(params);
                this.showSpinner = false;
                this.isImageData = false;
                this.isFileUploading = true;
                upload.on('httpUploadProgress', (progress) => {
                    this.uploadProgress = Math.round((progress.loaded / progress.total) * 100);
                });

                return await upload.promise();
            });

            // Wait for all uploads to complete
            const results = await Promise.all(uploadPromises);
            this.isFileUploading = false;
            this.uploadProgress = 0;
            results.forEach((result) => {
                if (result) {
                    let bucketName = this.confData.MVEX__S3_Bucket_Name__c;
                    let objKey = result.Key;
                    this.fileURL.push(`https://${bucketName}.s3.amazonaws.com/${objKey}`);
                }
            });

        } catch (error) {
            this.showSpinner = false;
            this.uploadStatus = false;
            errorDebugger('AwsFileUploader', 'uploadToAWS', error, 'warn', 'Error while uploading to aws');
        }
    }

    /**
    * Method Name: compressAndWatermarkImage
    * @description: Used to compress and watermark image.
    * @param {object} file - The file to compress and watermark.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    async compressAndWatermarkImage(file) {
        try {
            let outImage = await this.imageWithWatermark(file);
            const base64String = outImage.replace(/^data:image\/\w+;base64,/, '');
            const Buffer = buffer.Buffer;
            const buff = new Buffer(base64String, 'base64');
            const compressedImageBuffer = await this.compressJPEG(buff, 80); // Adjust quality as needed
            return compressedImageBuffer;
        } catch (error) {
            errorDebugger('AwsFileUploader', 'compressAndWatermarkImage', error, 'warn', 'Error while compressing and watermarking image');
        }
    }

    /**
    * Method Name: imageWithWatermark
    * @description: Used to get image with watermark.
    * @param {object} image - The image to get image with watermark.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    async imageWithWatermark(image) {
        try {
            let file = image;
            let logoImg = 'data:image/png;base64,' + this.logo;
            const fileUrl = URL.createObjectURL(file);
            // Load the file image
            const fileImage = await new Promise((resolve, reject) => {
                let img = new Image();
                img.onload = () => resolve(img);
                img.onerror = reject;
                img.src = fileUrl;
            });
            // Load the watermark image
            const watermarkImage = await new Promise((resolve, reject) => {
                let img = new Image();
                img.onload = () => resolve(img);
                img.onerror = reject;
                img.src = logoImg;
            });

            const watermarkScale = 0.5; // 50% of the file image's size

            // Calculate the dimensions of the watermark
            const newWidth = fileImage.width * watermarkScale;
            const newHeight = fileImage.height * watermarkScale;
            // Resize the watermark image
            const resizedWatermarkImage = this.resizeImage(watermarkImage, newWidth, newHeight);

            // Add the resized watermark image to the main image
            const watermark = window?.globalThis?.watermark;
            const watermarkedImage = await watermark([file, resizedWatermarkImage])
                .image(watermark.image.center(0.5));

            URL.revokeObjectURL(fileUrl);
            return watermarkedImage.src;
        } catch (error) {
            this.showToast('Error', 'Something went wrong while adding watermark.', 'error');
            errorDebugger('AwsFileUploader', 'imageWithWatermark', error, 'warn', 'Error while getting image with watermark');
        }
    }

    /**
    * Method Name: resizeImage
    * @description: Used to resize image.
    * @param {object} image - The image to resize.
    * @param {number} newWidth - The new width of the image.
    * @param {number} newHeight - The new height of the image.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    resizeImage(image, newWidth, newHeight) {
        try {
            const canvas = document.createElement('canvas');
            canvas.width = newWidth;
            canvas.height = newHeight;
            const ctx = canvas.getContext('2d');
            ctx.drawImage(image, 0, 0, newWidth, newHeight);
            return canvas.toDataURL(); // Returns the resized image as a data URL
        } catch (error) {
            errorDebugger('AwsFileUploader', 'resizeImage', error, 'warn', 'Error while resizing image');
        }
    }

    /**
    * Method Name: compressJPEG
    * @description: Used to compress jpeg.
    * @param {object} imageBuffer - The image buffer to compress.
    * @param {number} quality - The quality of the compression.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    async compressJPEG(imageBuffer, quality) {
        return new Promise((resolve, reject) => {
            try {
                const dataURL = 'data:image/jpeg;base64,' + imageBuffer.toString('base64');

                const img = new Image();

                img.onload = () => {
                    const canvas = document.createElement('canvas');
                    const ctx = canvas.getContext('2d');
                    canvas.width = img.width;
                    canvas.height = img.height;
                    ctx.drawImage(img, 0, 0);
                    const compressedDataURL = canvas.toDataURL('image/jpeg', quality / 100);
                    const Buffer = buffer.Buffer;
                    const compressedImageBuffer = new Buffer(compressedDataURL.split(',')[1], 'base64');
                    resolve(compressedImageBuffer);
                };
                img.src = dataURL;
                img.onerror = (error) => {
                    reject(error);
                };
            } catch (error) {
                errorDebugger('AwsFileUploader', 'compressJPEG', error, 'warn', 'Error while compressing jpeg');
            }
        });
    }

    /**
    * Method Name: allowDrop
    * @description: Used to allow drop.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    allowDrop(event) {
        try {
            event.preventDefault();
        } catch (error) {
            errorDebugger('AwsFileUploader', 'allowDrop', error, 'warn', 'Error while allowing drop');
        }
    }

    /**
    * Method Name: handleDrop
    * @description: Used to handle drop.
    * @param {object} event - The event to handle drop.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    async handleDrop(event) {
        event.preventDefault();
        try {
            const files = event.dataTransfer.files;
            this.isImageData = true;
            this.largeImageFiles = [];
            let invalidFileTypes = [];
            let totalSize = 0;

            for (let i = 0; i < files.length; i++) {
                let file = files[i];
                if (file.type === 'image/png' || file.type === 'image/jpg' || file.type === 'image/jpeg' || file.type === 'video/mp4') {
                    const fileSize = Math.floor(file.size / 1024);
                    // Check if the individual file size is within 10 MB
                    if (fileSize <= 10240) {
                        // Check if adding this file exceeds the total size limit of 20 MB
                        if (totalSize + fileSize <= 20240) {
                            this.selectedFilesToUpload.push(file);
                            this.fileName.push(file.name);
                            this.fileSize.push(fileSize);
                            totalSize += fileSize;

                            const fileData = {
                                Id: Date.now() + '-' + file,
                                name: file.name,
                                size: file.size,
                                preview: file.type != 'video/mp4' ? URL.createObjectURL(file) : await this.createThumbnail(file)
                            };
                            this.imageToShowFiles.push(fileData);
                        } else {
                            this.showToast('Error', 'Total file size exceeds 20 MB limit.', 'error');
                        }
                    } else {
                        this.largeImagefiles.push(file.name);
                    }
                } else {
                    invalidFileTypes.push(file.name);
                }
            }

            this.isScrolling = true;

            if (invalidFileTypes.length > 0) {
                this.showToast('Error', 'Invalid file types: ' + invalidFileTypes.join(', '), 'error');
            }

            if (this.largeImageFiles.length > 0) {
                this.showToast('Error', 'File(s) too large: ' + this.largeImageFiles.join(', '), 'error');
            }
        } catch (error) {
            errorDebugger('AwsFileUploader', 'handleDrop', error, 'warn', 'Error while handling drop');
        }
    }

    /**
    * Method Name: handleDialogueClose
    * @description: Used to handle dialogue close.
    * Created Date: 23/12/2024
    * Created By: Karan Singh
    */
    handleDialogueClose() {
        try {
            this.dispatchEvent(new CustomEvent('close'));
        } catch (error) {
            errorDebugger('AwsFileUploader', 'handleDialogueClose', error, 'warn', 'Error while handling dialogue close');
        }
    }

    /**
    * Method Name: handleDialogueCloseAndRefresh
    * @description: Used to handle dialogue close and refresh.
    * Created Date: 23/12/2024
    * Created By: Karan Singh
    */
    handleDialogueCloseAndRefresh() {
        try {
            this.showSpinner = false;
            this.dispatchEvent(new CustomEvent('closeandrefresh'));
        } catch (error) {
            errorDebugger('AwsFileUploader', 'handleDialogueCloseAndRefresh', error, 'warn', 'Error while handling dialogue close and refresh');
        }
    }

    /**
    * Method Name: showToast
    * @description: Used to show toast message.
    * @param: title - title of toast message.
    * @param: mesaage - message to show in toast message.
    * @param: variant- type of toast message.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    showToast(title, message, variant) {
        try {
            if (typeof window !== 'undefined') {
                const event = new ShowToastEvent({
                    title: title,
                    message: message,
                    variant: variant,
                });
    
                this.dispatchEvent(event);
            }
        } catch (error) {
            errorDebugger('AwsFileUploader', 'showToast', error, 'warn', 'Error while showing toast message');
        }
    }

    /**
    * Method Name: renameFileName
    * @description: Used to rename file name.
    * @param {string} filename - The filename to rename.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    renameFileName(filename) {
        try {
            let originalFileName = filename;
            let extensionIndex = originalFileName.lastIndexOf('.');
            let baseFileName = originalFileName.substring(0, extensionIndex);
            let extension = originalFileName.substring(extensionIndex + 1);

            const time = this.currentDateTimeWithSeconds;
            let watermarkPart = this.isWatermark ? '_watermark' : '';
            let objKey = `${baseFileName}_${time}${watermarkPart}.${extension}`
                .replace(/\s+/g, "_")
                .toLowerCase();
            return objKey;
        } catch (error) {
            errorDebugger('AwsFileUploader', 'renameFileName', error, 'warn', 'Error while renaming file name');
        }
    }

    /**
    * Method Name: watermarkValue
    * @description: Used to get watermark value.
    * @param {object} event - The event to get watermark value.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    watermarkValue(event) {
        try {
            this.isWatermark = event.target.checked;
        } catch (error) {
            errorDebugger('AwsFileUploader', 'watermarkValue', error, 'warn', 'Error while getting watermark value');
        }
    }
}