@isTest
private class ZooplaIntegrationControllerTest {
    private static final String PORTAL_CONFIGURATION = '{"certificate":"zoopla_certificate","branch_reference":"branch-123","is_test_portal":"true"}';
    private static final String FIELD_MAPPING = '{"MVEX__Broker_s_Listing_ID__c":"listing_reference","MVEX__Listing_Price__c":"pricing.price"}';
    private static Integer callCount = 0;
    private static HttpRequest lastRequest;

    @testSetup
    static void setup() {
        MVEX__Property__c propertyRecord = TestDataFactory.createProperty(true);
        System.assertNotEquals(null, propertyRecord, 'Test property should be created.');

        MVEX__Listing__c listingRecord = TestDataFactory.createListing(true, propertyRecord.Id, null);
        System.assertNotEquals(null, listingRecord, 'Test listing should be created.');

        insert new List<MVEX__Portal__c>{
            createPortal('Zoopla Test', true, PORTAL_CONFIGURATION),
            createPortal('Zoopla Inactive', false, PORTAL_CONFIGURATION),
            createPortal('Zoopla Branch Failure', true, PORTAL_CONFIGURATION)
        };
    }

    private static MVEX__Portal__c createPortal(String name, Boolean active, String configuration) {
        return new MVEX__Portal__c(
            Name = name,
            MVEX__Is_Active__c = active,
            MVEX__Generator__c = 'Zoopla',
            MVEX__Field_Mapping__c = FIELD_MAPPING,
            MVEX__Portal_Configuration__c = configuration
        );
    }

    private static Id getPortalId(String portalName) {
        return [SELECT Id FROM MVEX__Portal__c WHERE Name = :portalName LIMIT 1].Id;
    }

    private static Id getListingId() {
        return [SELECT Id FROM MVEX__Listing__c LIMIT 1].Id;
    }

    private static String getBrokerListingReference() {
        return [SELECT MVEX__Broker_s_Listing_ID__c FROM MVEX__Listing__c LIMIT 1].MVEX__Broker_s_Listing_ID__c;
    }

    @isTest
    static void getListingHandlesMissingPortalAndSuccessfulResponse() {
        ZooplaIntegrationController.ListingResponse missingResponse = ZooplaIntegrationController.zooplaGetListing('invalid-portal-id');
        System.assertEquals('Failed', missingResponse.status);
        System.assertEquals('Portal configuration is missing.', missingResponse.message);

        Id portalId = getPortalId('Zoopla Test');
        String matchingListingReference = getBrokerListingReference();
        Test.setMock(HttpCalloutMock.class, new ZooplaHttpMock(200, '{"listings":[{"listing_reference":"' + matchingListingReference + '","url":"https://zoopla.example/listing"}]}'));

        Test.startTest();
        ZooplaIntegrationController.ListingResponse response = ZooplaIntegrationController.zooplaGetListing(String.valueOf(portalId));
        Test.stopTest();

        System.assertEquals('Success', response.status);
        System.assertEquals(1, response.data.size());
        System.assertEquals(matchingListingReference, response.data[0].get('listing_reference'));
        System.assertEquals('https://zoopla.example/listing', response.data[0].get('url'));
        System.assertEquals('POST', lastRequest.getMethod());
        System.assert(lastRequest.getEndpoint().contains('sandbox/v2/listing/list'));
    }

    @isTest
    static void getListingHandlesZooplaError() {
        Id portalId = getPortalId('Zoopla Test');
        Test.setMock(HttpCalloutMock.class, new ZooplaHttpMock(400, 'Zoopla listing error'));
        Test.startTest();
        ZooplaIntegrationController.ListingResponse errorResponse = ZooplaIntegrationController.zooplaGetListing(String.valueOf(portalId));
        Test.stopTest();
        System.assertEquals('Failed', errorResponse.status);
        System.assertEquals('Zoopla listing error', errorResponse.message);
    }

    @isTest
    static void getListingHandlesInvalidResponse() {
        Id portalId = getPortalId('Zoopla Test');
        Test.setMock(HttpCalloutMock.class, new ZooplaHttpMock(200, 'not-json'));
        Test.startTest();
        ZooplaIntegrationController.ListingResponse invalidResponse = ZooplaIntegrationController.zooplaGetListing(String.valueOf(portalId));
        Test.stopTest();
        System.assertEquals('Failed', invalidResponse.status);
        System.assertNotEquals(null, invalidResponse.message);
    }

    @isTest
    static void syncListingHandlesMissingPortalAndSuccessfulUpdate() {
        Id listingId = getListingId();
        ZooplaIntegrationController.getListingRecordForSync(String.valueOf(listingId), null);

        Test.setMock(HttpCalloutMock.class, new ZooplaHttpMock(200, '{"listing_reference":"created"}'));
        Test.startTest();
        ZooplaIntegrationController.getListingRecordForSync(String.valueOf(listingId), String.valueOf(getPortalId('Zoopla Test')));
        Test.stopTest();

        System.assertEquals(1, [SELECT count() FROM MVEX__PortalListing__c WHERE MVEX__Listing__c = :listingId]);
    }

    @isTest
    static void createAndUpdateListingPersistsSuccess() {
        Id portalId = getPortalId('Zoopla Test');
        Id listingId = getListingId();

        Test.setMock(HttpCalloutMock.class, new ZooplaHttpMock(200, '{"result":"updated"}'));
        Test.startTest();
        ZooplaIntegrationController.zooplaCreateAndUpdateListing('{"listing_reference":"zoopla-reference-123"}', String.valueOf(portalId), String.valueOf(listingId), true, 'zoopla_certificate');
        Test.stopTest();

        System.assertEquals(1, [SELECT count() FROM MVEX__PortalListing__c WHERE MVEX__Listing__c = :listingId]);
    }

    @isTest
    static void createAndUpdateListingHandlesFailure() {
        Id portalId = getPortalId('Zoopla Test');
        Id listingId = getListingId();
        Test.setMock(HttpCalloutMock.class, new ZooplaHttpMock(400, 'update rejected'));
        Test.startTest();
        ZooplaIntegrationController.zooplaCreateAndUpdateListing('{}', String.valueOf(portalId), String.valueOf(listingId), false, 'zoopla_certificate');
        Test.stopTest();
        System.assertEquals(0, [SELECT count() FROM MVEX__PortalListing__c WHERE MVEX__Listing__c = :listingId]);
        System.assert(lastRequest.getEndpoint().contains('live/v2/listing/update'));
    }

    @isTest
    static void deleteListingsPostsListingReferenceAndSkipsInactivePortal() {
        Id portalId = getPortalId('Zoopla Test');
        Id listingId = getListingId();
        Map<String, Map<String, String>> listingData = new Map<String, Map<String, String>>{
            String.valueOf(listingId) => new Map<String, String>{ 'portalId' => String.valueOf(portalId) }
        };
        Test.setMock(HttpCalloutMock.class, new ZooplaHttpMock(200, '{}'));

        Test.startTest();
        ZooplaIntegrationController.zooplaDeleteListings(JSON.serialize(listingData));
        Test.stopTest();

        System.assertEquals(1, callCount);
        System.assert(lastRequest.getEndpoint().contains('sandbox/v2/listing/delete'));
        System.assert(lastRequest.getBody().contains(getBrokerListingReference()));
    }

    @isTest
    static void deleteListingsSkipsInactivePortal() {
        Id listingId = getListingId();
        Map<String, Map<String, String>> listingData = new Map<String, Map<String, String>>{
            String.valueOf(listingId) => new Map<String, String>{
                'portalId' => String.valueOf(getPortalId('Zoopla Inactive'))
            }
        };
        Test.setMock(HttpCalloutMock.class, new ZooplaHttpMock(200, '{}'));
        Test.startTest();
        ZooplaIntegrationController.zooplaDeleteListings(JSON.serialize(listingData));
        Test.stopTest();
        System.assertEquals(0, callCount);
    }

    @isTest
    static void createAndUpdateBranchUpdatesPortalOnSuccess() {
        Id portalId = getPortalId('Zoopla Test');
        Map<String, Object> wrapper = new Map<String, Object>{
            'branch_reference' => 'branch-123',
            'branch_name' => 'Test Branch',
            'street_name' => 'Main Street',
            'town_or_city' => 'Test City',
            'postal_code' => '123456',
            'country_code' => 'GB',
            'is_test_portal' => 'true'
        };
        Test.setMock(HttpCalloutMock.class, new ZooplaHttpMock(200, '{"branch":"updated"}'));

        Test.startTest();
        ZooplaIntegrationController.zooplaCreateAndUpdateBranch(JSON.serialize(wrapper), String.valueOf(portalId));
        Test.stopTest();

        MVEX__Portal__c updatedPortal = [SELECT MVEX__Response__c FROM MVEX__Portal__c WHERE Id = :portalId];
        System.assertEquals('{"branch":"updated"}', updatedPortal.MVEX__Response__c);
        System.assert(lastRequest.getEndpoint().contains('sandbox/v2/branch/update'));
    }

    @isTest
    static void createAndUpdateBranchDeletesPortalOnFailure() {
        Id portalId = getPortalId('Zoopla Branch Failure');
        Map<String, Object> wrapper = new Map<String, Object>{
            'branch_reference' => 'branch-456',
            'branch_name' => 'Failed Branch',
            'is_test_portal' => 'false'
        };
        Test.setMock(HttpCalloutMock.class, new ZooplaHttpMock(400, 'branch rejected'));

        Test.startTest();
        ZooplaIntegrationController.zooplaCreateAndUpdateBranch(JSON.serialize(wrapper), String.valueOf(portalId));
        Test.stopTest();

        System.assertEquals(0, [SELECT count() FROM MVEX__Portal__c WHERE Id = :portalId]);
        System.assert(lastRequest.getEndpoint().contains('live/v2/branch/update'));
    }

    @isTest
    static void updatePortalListingRecordPublishesFailureWithoutInsert() {
        Id listingId = getListingId();
        Integer countBefore = [SELECT count() FROM MVEX__PortalListing__c WHERE MVEX__Listing__c = :listingId];

        Test.startTest();
        ZooplaIntegrationController.updatePortalListingRecord(String.valueOf(listingId), String.valueOf(getPortalId('Zoopla Test')), 'update rejected', 'Failed');
        Test.stopTest();

        System.assertEquals(countBefore, [SELECT count() FROM MVEX__PortalListing__c WHERE MVEX__Listing__c = :listingId]);
    }

    @isTest
    static void createInputDataBuildsMappedNestedJsonAndMediaContent() {
        insert new List<MVEX__Portal_Listing_Mapping__c>{
            new MVEX__Portal_Listing_Mapping__c(
                Name = 'pricing.price',
                MVEX__Portal_Name__c = 'Zoopla',
                MVEX__Data_Type__c = 'Integer'
            ),
            new MVEX__Portal_Listing_Mapping__c(
                Name = 'life_cycle_status',
                MVEX__Portal_Name__c = 'Zoopla',
                MVEX__Data_Type__c = 'String',
                MVEX__Value_Mapping__c = 'Active => available'
            ),
            new MVEX__Portal_Listing_Mapping__c(
                Name = 'accessibility',
                MVEX__Portal_Name__c = 'Zoopla'
            )
        };
        List<MVEX__Property_File__c> media = new List<MVEX__Property_File__c>{
            new MVEX__Property_File__c(
                Name = 'External Tour',
                MVEX__BaseUrl__c = 'https://example.com/base.jpg',
                MVEX__ExternalLink__c = 'https://example.com/external.jpg',
                MVEX__Tags__c = '360tour'
            ),
            new MVEX__Property_File__c(
                Name = 'Floorplan',
                MVEX__BaseUrl__c = 'https://example.com/floorplan.jpg',
                MVEX__Tags__c = 'Floorplan'
            ),
            new MVEX__Property_File__c(
                Name = 'Photo',
                MVEX__BaseUrl__c = 'https://example.com/photo.jpg',
                MVEX__Tags__c = 'Photo'
            )
        };

        String jsonBody = ZooplaJSONController.createInputData(
            new Map<String, Object>{
                'pricing.price' => '250000',
                'life_cycle_status' => 'Active',
                'accessibility' => 'wheelchair_access'
            },
            media
        );
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
        Map<String, Object> pricing = (Map<String, Object>) body.get('pricing');
        List<Object> accessibility = (List<Object>) body.get('accessibility');
        List<Object> content = (List<Object>) body.get('content');

        System.assertEquals(250000, pricing.get('price'));
        System.assertEquals('available', body.get('life_cycle_status'));
        System.assertEquals('wheelchair_access', accessibility[0]);
        System.assertEquals(3, content.size());
        System.assertEquals('https://example.com/external.jpg', ((Map<String, Object>) content[0]).get('url'));
        System.assertEquals('virtual_tour', ((Map<String, Object>) content[0]).get('type'));
        System.assertEquals('floor_plan', ((Map<String, Object>) content[1]).get('type'));
        System.assertEquals('image', ((Map<String, Object>) content[2]).get('type'));
    }

    @isTest
    static void processValueBuildsNestedAndArrayMaps() {
        Map<String, Object> result = new Map<String, Object>();
        ZooplaJSONController.processValue(result, 'location.town_or_city', 'London');
        ZooplaJSONController.processValue(result, 'feature_list.bills_included', 'water');
        ZooplaJSONController.processValue(result, 'feature_list.bills_included', 'electricity');
        ZooplaJSONController.processValue(result, 'accessibility', 'step_free');
        ZooplaJSONController.processValue(result, 'simple_field', 'simple value');

        Map<String, Object> location = (Map<String, Object>) result.get('location');
        List<Object> featureList = (List<Object>) result.get('feature_list');
        Map<String, Object> firstFeature = (Map<String, Object>) featureList[0];
        List<Object> billsIncluded = (List<Object>) firstFeature.get('bills_included');
        List<Object> accessibility = (List<Object>) result.get('accessibility');

        System.assertEquals('London', location.get('town_or_city'));
        System.assertEquals(1, featureList.size());
        System.assertEquals(2, billsIncluded.size());
        System.assertEquals('water', billsIncluded[0]);
        System.assertEquals('electricity', billsIncluded[1]);
        System.assertEquals('step_free', accessibility[0]);
        System.assertEquals('simple value', result.get('simple_field'));

        ZooplaJSONController.processValue(null, 'ignored', 'value');
        System.assert(ZooplaJSONController.createInputData(new Map<String, Object>(), null).startsWith('{"status":"fail"'));
    }

    @isTest
    static void valueConversionHandlesSupportedTypesAndFailures() {
        System.assertEquals(null, ZooplaJSONController.conditionallyChangeValue('Integer', null, null));
        System.assertEquals(12, ZooplaJSONController.conditionallyChangeValue('Integer', '12', null));
        System.assertEquals(12, ZooplaJSONController.conditionallyChangeValue('Integer', Decimal.valueOf('12.9'), null));
        System.assertEquals(true, ZooplaJSONController.conditionallyChangeValue('Boolean', 'true', null));
        System.assertEquals(false, ZooplaJSONController.conditionallyChangeValue('Boolean', false, null));
        System.assertEquals('available', ZooplaJSONController.conditionallyChangeValue('String', 'Active', 'Active => available'));
        System.assertEquals('available', ZooplaJSONController.conditionallyChangeValue(null, 'Active', 'Active => available'));
        System.assertEquals(12, ZooplaJSONController.conditionallyChangeValue('Integer', 12, null));
        System.assertEquals(Datetime.valueOfGmt('2024-01-02 03:04:05').format('yyyy-MM-dd\'T\'HH:mm:ss'), ZooplaJSONController.conditionallyChangeValue('Datetime', '2024-01-02 03:04:05', null));
        System.assertEquals(Datetime.newInstance(2024, 1, 2, 3, 4, 5).format('yyyy-MM-dd\'T\'HH:mm:ss'), ZooplaJSONController.conditionallyChangeValue('Datetime', Datetime.newInstance(2024, 1, 2, 3, 4, 5), null));
        String formattedDate = (String) ZooplaJSONController.conditionallyChangeValue('Date', Date.newInstance(2024, 1, 2), null);
        String formattedDateTime = (String) ZooplaJSONController.conditionallyChangeValue('Date', Datetime.newInstance(2024, 1, 2, 3, 4, 5), null);
        System.assertEquals(10, formattedDate.length());
        System.assert(formattedDate.startsWith('2024-01-'));
        System.assertEquals(10, formattedDateTime.length());
        System.assert(formattedDateTime.startsWith('2024-01-'));
        System.assertEquals('not-an-integer', ZooplaJSONController.conditionallyChangeValue('Integer', 'not-an-integer', null));
        for (String arrayField : new List<String>{
            'accessibility',
            'bills_included',
            'broadband_supply',
            'building_safety_issues',
            'buyer_incentives',
            'commercial_use_classes',
            'connected_utilities',
            'construction_materials',
            'detailed_description',
            'electricity_supply',
            'feature_list',
            'floor_levels',
            'heating_source',
            'outside_space',
            'parking',
            'sewerage_supply',
            'water_supply',
            'sources_of_flooding'
        }) {
            System.assertEquals(true, ZooplaJSONController.isArrayField(arrayField));
        }
        System.assertEquals(false, ZooplaJSONController.isArrayField('town_or_city'));
        System.assertEquals('virtual_tour', ZooplaJSONController.urlType('360tour'));
        System.assertEquals('virtual_tour', ZooplaJSONController.urlType('Virtual Tour'));
        System.assertEquals('floor_plan', ZooplaJSONController.urlType('Floorplan'));
        System.assertEquals('image', ZooplaJSONController.urlType(null));
    }

    private class ZooplaHttpMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;
        ZooplaHttpMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest request) {
            ZooplaIntegrationControllerTest.callCount++;
            ZooplaIntegrationControllerTest.lastRequest = request;
            HttpResponse response = new HttpResponse();
            response.setStatusCode(statusCode);
            response.setBody(responseBody);
            return response;
        }
    }
}
