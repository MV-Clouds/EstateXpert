@isTest
public class CreatePortalListingMappingRecordsTest {

    @isTest
    static void testCreatePortalRecords() {

        Test.startTest();
        String result = CreatePortalListingMappingRecords.createPortalRecords('Zoopla', false);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');

    }

    @isTest
    static void testCreatePortalRecords1() {

        Test.startTest();
        String result = CreatePortalListingMappingRecords.createPortalRecords('Propertyfinder', false);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');

    }

    @isTest
    static void testCreatePortalRecords2() {

        Test.startTest();
        String result = CreatePortalListingMappingRecords.createPortalRecords('Bayut', false);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');

    }

    @isTest
    static void testCreatePortalRecords3() {

        Test.startTest();
        String result = CreatePortalListingMappingRecords.createPortalRecords('Rightmove', false);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');

    }

    @isTest
    static void testCreatePortalRecords4() {

        Test.startTest();
        String result = CreatePortalListingMappingRecords.createPortalRecords('Rightmove Overseas', false);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');

    }

    @isTest
    static void testCreatePortalRecords5() {

        Test.startTest();
        String result = CreatePortalListingMappingRecords.createPortalRecords('Dubizzle', false);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');

    }

}