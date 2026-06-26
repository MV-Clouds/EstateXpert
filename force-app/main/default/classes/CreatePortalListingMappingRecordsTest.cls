@isTest
public class CreatePortalListingMappingRecordsTest {

    @isTest
    static void testCreatePortalRecords() {

        Test.startTest();
        String result = CreatePortalListingMappingRecords.createPortalRecords('Zoopla');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');

    }

    @isTest
    static void testCreatePortalRecords1() {

        Test.startTest();
        String result = CreatePortalListingMappingRecords.createPortalRecords('Propertyfinder');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');

    }

    @isTest
    static void testCreatePortalRecords2() {

        Test.startTest();
        String result = CreatePortalListingMappingRecords.createPortalRecords('Bayut');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');

    }

    @isTest
    static void testCreatePortalRecords3() {

        Test.startTest();
        String result = CreatePortalListingMappingRecords.createPortalRecords('Rightmove');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');

    }

    @isTest
    static void testCreatePortalRecords4() {

        Test.startTest();
        String result = CreatePortalListingMappingRecords.createPortalRecords('Rightmove Overseas');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');

    }

    @isTest
    static void testCreatePortalRecords5() {

        Test.startTest();
        String result = CreatePortalListingMappingRecords.createPortalRecords('Dubizzle');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');

    }

}