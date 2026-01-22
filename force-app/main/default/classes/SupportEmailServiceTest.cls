@IsTest
public class SupportEmailServiceTest {

    @IsTest
    static void testHandleInboundEmail_WithAttachments() {
        // Arrange: Create a simulated inbound email
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();
        
        email.fromAddress = 'test@example.com';
        email.subject = 'Test Support Case';
        
        // Simulating email body with From and Email fields
        email.plainTextBody = 'From : John Doe\nEmail : johndoe@example.com\nThis is a test support case email body.';

        // Simulating binary attachments
        Messaging.InboundEmail.BinaryAttachment binaryAttachment = new Messaging.InboundEmail.BinaryAttachment();
        binaryAttachment.fileName = 'TestAttachment.pdf';
        binaryAttachment.body = Blob.valueOf('Test file content');
        binaryAttachment.mimeTypeSubType = 'application/pdf';
        email.binaryAttachments = new Messaging.InboundEmail.BinaryAttachment[] { binaryAttachment };

        // Act: Call the handleInboundEmail method
        Test.startTest();
        SupportEmailService service = new SupportEmailService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, envelope);
        Test.stopTest();

        // Assert: Validate that the Support Case was created
        List<Support_Case__c> cases = [SELECT Id, Name__c, Email__c, Subject__c, Description__c FROM Support_Case__c];
        System.assertEquals(1, cases.size(), 'A Support Case should be created');
        Support_Case__c createdCase = cases[0];
        System.assertEquals('John Doe', createdCase.Name__c, 'The Name should be extracted from the email body');
        System.assertEquals('johndoe@example.com', createdCase.Email__c, 'The Email should be extracted from the email body');
        System.assertEquals('Test Support Case', createdCase.Subject__c, 'The Subject should match the email subject');
        System.assertEquals('This is a test support case email body.', createdCase.Description__c, 'The body should match the email content');

        // Assert: Validate that the attachment was created as a ContentVersion
        List<ContentVersion> contentVersions = [SELECT Id, Title, PathOnClient FROM ContentVersion];
        System.assertEquals(1, contentVersions.size(), 'One attachment should be stored as ContentVersion');
        ContentVersion createdContent = contentVersions[0];
        System.assertEquals('TestAttachment.pdf.pdf', createdContent.Title, 'The attachment file name should match');

        // Assert: Validate that the ContentDocumentLink is correctly linked to the Support Case
        List<ContentDocumentLink> contentLinks = [SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId = :createdCase.Id];
        System.assertEquals(1, contentLinks.size(), 'The ContentVersion should be linked to the Support Case');
    }

    @IsTest
    static void testHandleInboundEmail_WithoutAttachments() {
        // Arrange: Create a simulated inbound email without attachments
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();
        
        email.fromAddress = 'test2@example.com';
        email.subject = 'Test Support Case Without Attachments';
        
        // Simulating email body with From and Email fields
        email.plainTextBody = 'From : Jane Smith\nEmail : janesmith@example.com\nThis is a test email without attachments.';

        // No binary attachments
        email.binaryAttachments = null;

        // Act: Call the handleInboundEmail method
        Test.startTest();
        SupportEmailService service = new SupportEmailService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, envelope);
        Test.stopTest();

        // Assert: Validate that the Support Case was created
        List<Support_Case__c> cases = [SELECT Id, Name__c, Email__c, Subject__c, Description__c FROM Support_Case__c];
        System.assertEquals(1, cases.size(), 'A Support Case should be created');
        Support_Case__c createdCase = cases[0];
        System.assertEquals('Jane Smith', createdCase.Name__c, 'The Name should be extracted from the email body');
        System.assertEquals('janesmith@example.com', createdCase.Email__c, 'The Email should be extracted from the email body');
        System.assertEquals('Test Support Case Without Attachments', createdCase.Subject__c, 'The Subject should match the email subject');
        System.assertEquals('This is a test email without attachments.', createdCase.Description__c, 'The body should match the email content');

        // Assert: Validate that no ContentVersion was created since there were no attachments
        List<ContentVersion> contentVersions = [SELECT Id FROM ContentVersion];
        System.assertEquals(0, contentVersions.size(), 'No ContentVersion should be created without attachments');
    }

    @IsTest
    static void testParseEmail() {
        // Arrange: Email body to test parsing
        String emailBody = 'From : Test User\nEmail : testuser@example.com\nThis is a test email body.';
        
        // Act: Call the parseEmail method
        SupportEmailService.ParsedEmailWrapper parsedEmail = SupportEmailService.parseEmail(emailBody);
        
        // Assert: Validate the parsed data
        System.assertEquals('Test User', parsedEmail.fromName, 'The Name should be extracted correctly');
        System.assertEquals('testuser@example.com', parsedEmail.emailAddress, 'The Email should be extracted correctly');
        System.assertEquals('This is a test email body.', parsedEmail.body, 'The body content should be extracted correctly');
    }

    @IsTest
    static void testNewSupportCaseCreation() {
        // Arrange
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();

        email.fromAddress = 'newcase@example.com';
        email.subject = 'New Support Request';
        email.plainTextBody = 'From : Jane Doe\nEmail : janedoe@example.com\nPriority : High\nThis is a test email for a new case.';

        // Act
        Test.startTest();
        SupportEmailService service = new SupportEmailService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, envelope);
        Test.stopTest();

        // Assert
        List<Support_Case__c> cases = [SELECT Id, Name__c, Email__c, Priority__c FROM Support_Case__c];
        System.assertEquals(1, cases.size(), 'A new Support Case should be created.');
        System.assertEquals('Jane Doe', cases[0].Name__c, 'Name should match parsed email.');
        System.assertEquals('janedoe@example.com', cases[0].Email__c, 'Email should match parsed email.');
    }

    // Test for existing case (non-replied email)
    @IsTest
    static void testExistingCaseNonRepliedEmail() {
        // Arrange
        Support_Case__c existingCase = new Support_Case__c(
            Name__c = 'John Smith',
            Email__c = 'johnsmith@example.com',
            Subject__c = 'Existing Case Subject',
            Description__c = 'Existing case description.',
            Priority__c = 'Medium'
        );
        insert existingCase;

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();
        email.fromAddress = 'followup@example.com';
        email.subject = 'Update - Ticket ID ' + existingCase.Id;
        email.plainTextBody = 'Adding more details to the existing case.';

        // Act
        Test.startTest();
        SupportEmailService service = new SupportEmailService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, envelope);
        Test.stopTest();

        // Assert
        List<ContentVersion> contentVersions = [SELECT Id FROM ContentVersion WHERE FirstPublishLocationId = :existingCase.Id];
        System.assertEquals(0, contentVersions.size(), 'No attachments should be created for non-replied emails without attachments.');
    }

    // Test for existing case (replied email)
    @IsTest
    static void testExistingCaseRepliedEmail() {
        // Arrange
        Support_Case__c existingCase = new Support_Case__c(
            Name__c = 'Alice Brown',
            Email__c = 'alicebrown@example.com',
            Subject__c = 'Replied Case Subject',
            Description__c = 'Case description.',
            Priority__c = 'Low'
        );
        insert existingCase;

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();
        email.fromAddress = 'reply@example.com';
        email.subject = 'Re: Update - Ticket ID ' + existingCase.Id;
        email.plainTextBody = 'This is a reply to the case.';

        // Act
        Test.startTest();
        SupportEmailService service = new SupportEmailService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, envelope);
        Test.stopTest();

        List<Support_Case__c> supportData = [SELECT Id FROM Support_Case__c LIMIT 1];
        System.AssertNotEquals(0, supportData.size(), 'At least one supportData should be created.');
    }
}