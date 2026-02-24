@isTest
public class PostInstallScriptTest {

    @isTest
    static void testInstallScript() {
        // 1. Prepare Data
        // Note: Custom Metadata (mdt) is visible to test classes without SeeAllData=true.
        // However, if your org/package has NO metadata records, the loop won't run.
        // Ensure at least one MVEX__recordManagerInquiryConfig__mdt exists in your project.

        PostInstallScript postinstall = new PostInstallScript();

        // 2. Execute Test: Simulate a fresh installation (previousVersion is null)
        Test.startTest();
        // Params: (InstallHandler, version, isUpgrade)
        Test.testInstall(postinstall, null);
        Test.stopTest();

        // 3. Verify results
        // We expect records to be created in the Custom Object MVEX__Configuration_Settings__c
        List<MVEX__Configuration_Settings__c> configs = [SELECT Id, Name FROM MVEX__Configuration_Settings__c];
        
        // We query the metadata to know what the expected count should be
        Integer expectedCount = [SELECT COUNT() FROM MVEX__recordManagerInquiryConfig__mdt];

        System.assertNotEquals(0, configs.size(), 'Records should have been created from metadata.');
        System.assertEquals(expectedCount, configs.size(), 'The number of settings should match the metadata records.');
    }

    @isTest
    static void testUpgradeScript() {
        // This simulates an upgrade (previousVersion is NOT null)
        // Based on your code, if it's an upgrade, createDefaultConfigRecords() should NOT run.
        
        PostInstallScript postinstall = new PostInstallScript();

        Test.startTest();
        // Version 1.0.0 exists, so previousVersion() will not be null
        Test.testInstall(postinstall, new Version(1, 0)); 
        Test.stopTest();
    }
}