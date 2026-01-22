/**
 * @description       Class to generate XML feed for Property Finder portal.
 * @author            Karan Singh
 * @lastModifiedBy    Yash Parekh
 * @lastModifiedDate  05/09/2025
 * @testClass         XMLFeedPortalTest
 */
public with sharing class XMLFeedGeneratorForPF {
    public String recordID;
    public String xmlstring { get; set; }

    /**
     * @description Constructor to generate XML data using listing records.
     */
    public XMLFeedGeneratorForPF() {
        try {
            // Initialize recordID
            if (!Test.isRunningTest()) {
                recordID = ApexPages.currentPage().getParameters().get('Id');
            }

            // Retrieve portal listings
            Set<Id> listingIds = new Set<Id>();
            List<PortalListing__c> portalListings;
            if (!Test.isRunningTest()) {
                portalListings = [SELECT Id, Listing__c, Portal__r.LastModifiedDate FROM PortalListing__c WHERE Portal__c = :recordID AND SystemIsActive__c = TRUE
                                    WITH USER_MODE];
            } else {
                portalListings = [SELECT Id, Listing__c FROM PortalListing__c WITH USER_MODE LIMIT 10];
            }

            for (PortalListing__c pl : portalListings) {
                if (pl.Listing__c != null) {
                    listingIds.add(pl.Listing__c);
                }
            }

            if (listingIds.isEmpty()) {
                xmlstring = '<?xml version="1.0" encoding="UTF-8"?><list last_update="" listing_count="0"></list>';
                return;
            }

            // Get field mappings
            Map<String, Map<String, String>> fieldApiNameToLabelMap = getFieldNames();
            List<String> fieldNames = new List<String>();
            for (String fieldName : fieldApiNameToLabelMap.keySet()) {
                fieldNames.add(fieldName);
            }

            // Query listings
            String query = generateDynamicQuery(fieldNames, listingIds);
            List<SObject> records = Database.query(query);

            // Process field mappings
            List<Map<String, Object>> modifiedRecords = replaceFieldApiNamesWithMapping(records, fieldApiNameToLabelMap);

            // Collect property IDs for media
            Set<Id> propertyIds = new Set<Id>();
            for (Map<String, Object> record : modifiedRecords) {
                Id propertyId = (Id) record.get('MVEX__Property__c');
                if (propertyId != null) {
                    propertyIds.add(propertyId);
                }
            }

            // Query property media
            Map<Id, List<Property_File__c>> propertyMediaMap = new Map<Id, List<Property_File__c>>();
            if (!propertyIds.isEmpty()) {
                for (Property_File__c media : [SELECT BaseUrl__c, ExternalLink__c, Property__c, Tags__c, LastModifiedDate FROM Property_File__c
                                                WHERE Property__c IN :propertyIds AND IsOnPortalFeed__c = TRUE WITH USER_MODE
                                                ORDER BY Sort_on_Portal_Feed__c ASC NULLS LAST, Name ASC]) 
                {
                    if (!propertyMediaMap.containsKey(media.Property__c)) {
                        propertyMediaMap.put(media.Property__c, new List<Property_File__c>());
                    }
                    propertyMediaMap.get(media.Property__c).add(media);
                }
            }

            // Build XML
            String lastUpdate = portalListings.isEmpty() 
                ? '' 
                : portalListings[0].Portal__r.LastModifiedDate?.format('yyyy-MM-dd HH:mm:ss') ?? '';
            List<String> propertyXmlBlocks = new List<String>();
            for (Map<String, Object> record : modifiedRecords) {
                List<String> currentPropertyParts = new List<String>();
                List<String> agentParts = new List<String>();
                List<String> amenityParts = new List<String>();
                String listingType = (String) record.get('listing_type');
                String rentFrequency = (String) record.get('rent_frequency');

                // Process fields
                for (String fieldName : record.keySet()) {
                    if (fieldName == 'Property__c' || fieldName == 'LastModifiedDate') continue;
                    Object fieldValue = record.get(fieldName);
                    if (fieldValue == null) continue;

                    String escapedValue = manuallyEscapeXml(String.valueOf(fieldValue));
                    if (fieldName.startsWith('amenity')) {
                        amenityParts.add('<amenity>' + escapedValue + '</amenity>');
                    } else if (isAgentField(fieldName)) {
                        agentParts.add('<' + fieldName + '>' + escapedValue + '</' + fieldName + '>');
                    } else if (fieldName == 'price' && listingType == 'Rent' && rentFrequency != null) {
                        String lowerRentFrequency = rentFrequency.toLowerCase();
                        currentPropertyParts.add(
                            '<price><' + lowerRentFrequency + '>' + escapedValue + '</' + lowerRentFrequency + '></price>'
                        );
                    } else {
                        currentPropertyParts.add('<' + fieldName + '>' + escapedValue + '</' + fieldName + '>');
                    }
                }

                if (!amenityParts.isEmpty()) {
                    currentPropertyParts.add('<amenities>' + String.join(amenityParts, '') + '</amenities>');
                }

                if (!agentParts.isEmpty()) {
                    currentPropertyParts.add('<agent>' + String.join(agentParts, '') + '</agent>');
                }

                // Add last_update attribute
                String lastModified = record.get('LastModifiedDate') != null
                    ? ((Datetime) record.get('LastModifiedDate')).format('yyyy-MM-dd HH:mm:ss')
                    : '';

                // Process media
                Id propertyId = (Id) record.get('MVEX__Property__c');
                if (propertyMediaMap.containsKey(propertyId)) {
                    List<String> photoParts = new List<String>();
                    List<String> floorPlanParts = new List<String>();
                    List<String> videoTourParts = new List<String>();
                    List<String> view360Parts = new List<String>();

                    for (Property_File__c media : propertyMediaMap.get(propertyId)) {
                        String imageUrl = String.isNotBlank(media.ExternalLink__c) ? media.ExternalLink__c : media.BaseUrl__c;
                        if (String.isBlank(imageUrl)) continue;

                        String escapedUrl = manuallyEscapeXml(imageUrl);
                        Boolean isSpecialMedia = false;

                        if (String.isNotBlank(media.Tags__c)) {
                            List<String> tags = media.Tags__c.toLowerCase().split(';');
                            if (tags.contains('floorplan')) {
                                floorPlanParts.add('<url>' + escapedUrl + '</url>');
                                isSpecialMedia = true;
                            }
                            if (tags.contains('virtual tour')) {
                                videoTourParts.add('<![CDATA[' + imageUrl + ']]>');
                                isSpecialMedia = true;
                            }
                            if (tags.contains('360tour')) {
                                view360Parts.add('<![CDATA[' + imageUrl + ']]>');
                                isSpecialMedia = true;
                            }
                        }
                        if (!isSpecialMedia) {
                            String mediaLastModified = media.LastModifiedDate?.format('yyyy-MM-dd HH:mm:ss') ?? '';
                            photoParts.add(
                                '<url last_update="' + mediaLastModified + '" watermark="yes">' + escapedUrl + '</url>'
                            );
                        }
                    }

                    if (!photoParts.isEmpty()) {
                        currentPropertyParts.add('<photo>' + String.join(photoParts, '') + '</photo>');
                    }
                    if (!floorPlanParts.isEmpty()) {
                        currentPropertyParts.add('<floor_plan>' + String.join(floorPlanParts, '') + '</floor_plan>');
                    }
                    if (!videoTourParts.isEmpty()) {
                        currentPropertyParts.add('<video_tour_url>' + String.join(videoTourParts, '') + '</video_tour_url>');
                    }
                    if (!view360Parts.isEmpty()) {
                        currentPropertyParts.add('<view360>' + String.join(view360Parts, '') + '</view360>');
                    }
                }

                String propertyAttributes = ' last_update="' + manuallyEscapeXml(lastModified) + '"';
                propertyXmlBlocks.add(
                    '<property' + propertyAttributes + '>' + String.join(currentPropertyParts, '') + '</property>'
                );
            }

            String listAttributes = ' last_update="' + manuallyEscapeXml(lastUpdate) + '" listing_count="' + records.size() + '"';
            xmlstring = '<?xml version="1.0" encoding="UTF-8"?><list' + listAttributes + '>' + String.join(propertyXmlBlocks, '') + '</list>';

        } catch (Exception e) {
            System.debug('XMLFeedGeneratorForPF Exception: ' + e.getMessage() + ' at line ' + e.getLineNumber());
            String errorMessage = manuallyEscapeXml(e.getMessage());
            if (String.isBlank(errorMessage)) {
                errorMessage = 'An unknown error occurred.';
            }
            xmlstring = '<?xml version="1.0" encoding="UTF-8"?><Failed><Error>' + errorMessage + '</Error><Line>' + e.getLineNumber() + '</Line></Failed>';
        }
    }

    /**
     * @description Retrieves field mappings for listings and portal listing fields.
     * @return Map of field API names to their label and value mapping.
     */
    private Map<String, Map<String, String>> getFieldNames() {
        try {
            Map<String, Map<String, String>> fieldApiNameToLabelMap = new Map<String, Map<String, String>>();
            for (Portal_Listing_Mapping__c mapping : [
                SELECT Name, Listing_Field_API_Name__c, Value_Mapping__c
                FROM Portal_Listing_Mapping__c
                WHERE Portal_Name__c = 'Propertyfinder XML' AND Listing_Field_API_Name__c != NULL
                WITH USER_MODE
            ]) {
                fieldApiNameToLabelMap.put(
                    mapping.Listing_Field_API_Name__c,
                    new Map<String, String>{ 'Label' => mapping.Name, 'ValueMapping' => mapping.Value_Mapping__c }
                );
            }
            return fieldApiNameToLabelMap;
        } catch (Exception e) {
            System.debug('getFieldNames Exception: ' + e.getMessage());
            return new Map<String, Map<String, String>>();
        }
    }

    /**
     * @description Generates a dynamic SOQL query string for listing fields.
     * @param fieldNames List of field API names to include in the query.
     * @param listingIds Set of listing IDs to filter.
     * @return The generated SOQL query string.
     */
    private String generateDynamicQuery(List<String> fieldNames, Set<Id> listingIds) {
        String query = 'SELECT Id, MVEX__Property__c, LastModifiedDate, MVEX__Listing_Type__c, MVEX__Rent_Frequency__c';
        for (String fieldName : fieldNames) {
            query += ', ' + String.escapeSingleQuotes(fieldName);
        }
        query += ' FROM MVEX__Listing__c WHERE Id IN :listingIds';
        return query;
    }

    /**
     * @description Replaces field API names with portal field labels in records, excluding unmapped fields.
     * @param records List of SObject records to process.
     * @param fieldApiNameToLabelMap Mapping of field API names to labels.
     * @return List of maps with only mapped field names and values.
     */
    private List<Map<String, Object>> replaceFieldApiNamesWithMapping(
        List<SObject> records,
        Map<String, Map<String, String>> fieldApiNameToLabelMap
    ) {
        List<Map<String, Object>> modifiedRecords = new List<Map<String, Object>>();
        for (SObject record : records) {
            Map<String, Object> modifiedRecordMap = new Map<String, Object>();
            // Always include MVEX__Property__c and LastModifiedDate for processing
            modifiedRecordMap.put('MVEX__Property__c', record.get('MVEX__Property__c'));
            modifiedRecordMap.put('LastModifiedDate', record.get('LastModifiedDate'));
            // Include listing_type and rent_frequency for price handling
            modifiedRecordMap.put('listing_type', record.get('MVEX__Listing_Type__c'));
            modifiedRecordMap.put('rent_frequency', record.get('MVEX__Rent_Frequency__c'));

            // Process only fields that have mappings
            for (String fieldApiName : fieldApiNameToLabelMap.keySet()) {
                if (record.get(fieldApiName) == null) continue;
                String mappedLabel = fieldApiNameToLabelMap.get(fieldApiName).get('Label');
                String valueMapping = fieldApiNameToLabelMap.get(fieldApiName).get('ValueMapping');
                Object fieldValue = record.get(fieldApiName);

                if (String.isNotBlank(valueMapping)) {
                    fieldValue = applyValueMapping(fieldValue, valueMapping);
                }

                modifiedRecordMap.put(mappedLabel, fieldValue);
            }
            modifiedRecords.add(modifiedRecordMap);
        }
        return modifiedRecords;
    }

    /**
     * @description Applies value mapping to a field value.
     * @param fieldValue The original field value.
     * @param valueMapping The mapping string defining value replacements.
     * @return The mapped field value.
     */
    private Object applyValueMapping(Object fieldValue, String valueMapping) {
        if (fieldValue == null || String.isBlank(valueMapping)) {
            return fieldValue;
        }

        Map<String, String> valueMap = new Map<String, String>();
        valueMapping = valueMapping.replaceAll('\\r\\n|\\r|\\n', '');
        for (String mapping : valueMapping.split(',')) {
            List<String> keyValue = mapping.split('=>');
            if (keyValue.size() == 2) {
                valueMap.put(keyValue[0].trim(), keyValue[1].trim());
            }
        }

        List<String> values = String.valueOf(fieldValue).split(';');
        List<String> mappedValues = new List<String>();
        for (String value : values) {
            mappedValues.add(valueMap.containsKey(value.trim()) ? valueMap.get(value.trim()) : value.trim());
        }
        return String.join(mappedValues, ',');
    }

    /**
     * @description Checks if a field is an agent-related field.
     * @param fieldName The name of the field to check.
     * @return Boolean indicating if the field is an agent field.
     */
    private Boolean isAgentField(String fieldName) {
        return fieldName == 'id' || fieldName == 'name' || fieldName == 'email' || fieldName == 'phone';
    }

    /**
     * @description Manually escapes special XML characters.
     * @param textToEscape The string to escape.
     * @return The escaped string.
     */
    private String manuallyEscapeXml(String textToEscape) {
        if (String.isBlank(textToEscape)) {
            return '';
        }
        return textToEscape.replace('&', '&amp;')
                          .replace('<', '&lt;')
                          .replace('>', '&gt;')
                          .replace('"', '&quot;')
                          .replace('\'', '&apos;');
    }
}