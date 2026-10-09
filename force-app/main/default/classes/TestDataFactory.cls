@isTest
public class TestDataFactory {
    
    public static Contact createContact(Boolean doInsert) {
        try {
            Contact contact = new Contact(
                FirstName = 'Test',
                LastName = 'User',
                Email = 'test@example.com',
                Phone = '1234567890',
                MVEX__Contact_Type__c = 'Buyer'
            );
            if(doInsert) {
                insert contact;
            }
            return contact;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'TestDataFactory', 'createContact', e.getMessage());
            return null;
        }
    }

    public static MVEX__Property__c createProperty(Boolean doInsert) {
        try {
            MVEX__Property__c property = new MVEX__Property__c(
                Name = 'Dev Test',
                MVEX__Address__c = '123 Salesforce Lane',
                MVEX__Bedrooms__c = 3,
                MVEX__Bathrooms__c = 2
            );
            if(doInsert) {
                insert property;
            }
            return property;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'TestDataFactory', 'createProperty', e.getMessage());
            return null;
        }
    }

    public static MVEX__Listing__c createListing(Boolean doInsert, Id propertyId, Id contactId) {
        try {
            Id rentRecordTypeId = Schema.SObjectType.MVEX__Listing__c.getRecordTypeInfosByDeveloperName().get('Rent').getRecordTypeId();
            
            MVEX__Listing__c listing = new MVEX__Listing__c(
                Name = 'Dev Test',
                MVEX__Property__c = propertyId,
                RecordTypeId = rentRecordTypeId,
                MVEX__Status__c = 'Active',
                MVEX__Listing_Type__c = 'Rent',
                MVEX__Property_Type__c = 'Villa',
                MVEX__Property_Sub_Type__c = 'Residential - Apartment',
                MVEX__Property_Category__c = 'Residential',
                MVEX__Country_Code__c = 'IN',
                MVEX__Street__c = 'Dev Test',
                MVEX__City__c = 'Dev Test',
                MVEX__State__c = 'Dev Test',
                MVEX__Zip_Postal_Code__c = '123456',
                MVEX__Description__c = 'Dev Test',
                MVEX__Listing_Price__c = 1000000,
                MVEX__Bedrooms__c = 3,
                MVEX__Bathrooms__c = 2,
                MVEX__Lot_Size__c = 1000,
                MVEX__Property_OwnerContact__c = contactId,
                MVEX__Listed_Date__c = Date.today(),
                MVEX__Furnished__c = 'Yes',
                MVEX__Property_Status__c = 'Vacant',
                MVEX__Year_Built__c = '2020',
                MVEX__Rent_Frequency__c = 'Monthly',
                MVEX__Listing_Allowed_For_Portals__c = true
            );
            
            if(doInsert) {
                insert listing;
            }
            return listing;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'TestDataFactory', 'createListing', e.getMessage());
            return null;
        }
    }

    public static MVEX__Portal__c createPortal(Boolean doInsert, String name, String generatorType) {
        try {
            MVEX__Portal__c portal = new MVEX__Portal__c(
                Name = name, 
                MVEX__Is_Active__c = true, 
                MVEX__Generator__c = generatorType, 
                MVEX__Field_Mapping__c = '{"Listing_Price__c":"pricing.price","City__c":"location.town_or_city","Broker_s_Listing_ID__c":"listing_reference","Status__c":"life_cycle_status","Property_Type__c":"property_type","Rent_Frequency__c":"pricing.rent_frequency"}',
                MVEX__Portal_Configuration__c = '{"version":"1.2","portalname":"' + name + '","is_test_portal":"true"}'
            );
            
            if(doInsert) {
                insert portal;
            }
            return portal;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'TestDataFactory', 'createPortal', e.getMessage());
            return null;
        }
    }

    public static MVEX__Property_File__c createPropertyFile(Boolean doInsert, Id propertyId) {
        try {
            MVEX__Property_File__c propertyFile = new MVEX__Property_File__c(
                Name = 'Test Image',
                MVEX__Property__c = propertyId,
                MVEX__BaseUrl__c = 'https://example.com/image',
                MVEX__Size__c = 123.45,
                MVEX__IsOnPortalFeed__c = true,
                MVEX__IsOnWebsite__c = true,
                MVEX__IsOnExpose__c = true
            );
            
            if(doInsert) {
                insert propertyFile;
            }
            return propertyFile;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'TestDataFactory', 'createPropertyFile', e.getMessage());
            return null;
        }
    }

    public static MVEX__Portal_Listing_Mapping__c createPortalListingMapping(Boolean doInsert, String portalName) {
        try {
            MVEX__Portal_Listing_Mapping__c mapping = new MVEX__Portal_Listing_Mapping__c(
                Name = 'TestField1', 
                MVEX__Listing_Field_API_Name__c = 'Name', 
                MVEX__Portal_Name__c = portalName, 
                MVEX__Value_Mapping__c = 'Apartment => AP,Penthouse => PH,Villa => VH,Townhouse => TH'
            );
            if(doInsert) {
                insert mapping;
            }
            return mapping;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'TestDataFactory', 'createPortalListingMapping', e.getMessage());
            return null;
        }
    }

    public static MVEX__Checklist__c createChecklist(Boolean doInsert) {
        try {
            MVEX__Checklist__c checklist = new MVEX__Checklist__c(
                Name = 'Test Checklist',
                MVEX__Field_Name__c = 'MVEX__Bedrooms__c',
                MVEX__Object_Name__c = 'MVEX__Listing__c',
                MVEX__Operator__c = 'Not Equals to',
                MVEX__Sequence__c = 1,
                MVEX__Value__c = '4',
                MVEX__Data_Type__c = 'STRING'
            );
            if(doInsert) {
                insert checklist;
            }
            return checklist;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'TestDataFactory', 'createChecklist', e.getMessage());
            return null;
        }
    }

    public static MVEX__PortalListing__c createPortalListing(Boolean doInsert, Id listingId, Id portalId) {
        try {
            MVEX__PortalListing__c portalListing = new MVEX__PortalListing__c(
                MVEX__Listing__c = listingId, 
                MVEX__Portal__c = portalId, 
                MVEX__SystemIsActive__c = true
            );
            if(doInsert) {
                insert portalListing;
            }
            return portalListing;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'TestDataFactory', 'createPortalListing', e.getMessage());
            return null;
        }
    }

    public static MVEX__Lead_Assignment_Setting__c createLeadAssignmentSetting(Boolean doInsert, Id userId) {
        try {
            MVEX__Lead_Assignment_Setting__c setting = new MVEX__Lead_Assignment_Setting__c(
                Name = userId,
                MVEX__Conditions__c = '[{"Lead_Field":"LeadSource","Condition":"equals","Value":"Web","Order":1}]',
                MVEX__Logic_Type__c = 'All',
                MVEX__User_Order__c = 1,
                MVEX__Object_Name__c = 'Contact'
            );
            if(doInsert) {
                insert setting;
            }
            return setting;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'TestDataFactory', 'createLeadAssignmentSetting', e.getMessage());
            return null;
        }
    }

}
