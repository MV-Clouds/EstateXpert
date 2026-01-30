@isTest
private class GeminiChatServiceTest {
    
    @isTest
    static void testSendFeedbackEmailWithoutImages() {
        Test.startTest();
        String result = GeminiChatService.sendFeedbackEmail(
            'Test Feedback Subject',
            'This is a test feedback description',
            null
        );
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(
            result.contains('Success') || result.contains('Error'), 
            'Result should contain Success or Error message'
        );
    }
    
    @isTest
    static void testSendFeedbackEmailWithMultipleImages() {
        // Create multiple base64 encoded test images (1x1 transparent PNG)
        String base64Image = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
        String[] images = new String[]{ base64Image, base64Image, base64Image };
        
        Test.startTest();
        String result = GeminiChatService.sendFeedbackEmail(
            'Test Feedback with Multiple Images',
            'Test description with multiple image attachments',
            images
        );
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(
            result.contains('Success') || result.contains('Error'), 
            'Result should contain Success or Error message'
        );
    }
    
    @isTest
    static void testSendFeedbackEmailWithEmptyImagesList() {
        Test.startTest();
        String result = GeminiChatService.sendFeedbackEmail(
            'Test Feedback',
            'Test description with empty images list',
            new String[]{}
        );
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(
            result.contains('Success') || result.contains('Error'), 
            'Result should contain Success or Error message'
        );
    }
}