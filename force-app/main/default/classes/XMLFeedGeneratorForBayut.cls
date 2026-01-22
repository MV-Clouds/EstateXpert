/**
 * Class Name : XMLFeedGeneratorForBayut
 * Test Class : XMLFeedPortalTest
 * Created By : Karan Singh
 * Last Modified Date : 05/09/2025
 * Last Modified By : Yash Parekh
 * @description : Used to generate XML Feed for Bayut and Dubizzle portal.
 */
public with sharing class XMLFeedGeneratorForBayut {
    public String recordID;
    public Boolean isForBayut;
    public Boolean isForDubizzle;
    public String xmlstring { get; set; }

    /**
     * @description Constructor to generate XML data using listing records.
     * @return Listing Details in XML format having return type String.
     */
    public XMLFeedGeneratorForBayut() {
        try {
            // Initialize parameters
            if (!Test.isRunningTest()) {
                recordID = ApexPages.currentPage().getParameters().get('Id');
                String isBytParam = ApexPages.currentPage().getParameters()?.get('isByt');
                String isDbzlParam = ApexPages.currentPage().getParameters()?.get('isDbzl');
                isForBayut = isBytParam != null ? Boolean.valueOf(isBytParam) : false;
                isForDubizzle = isDbzlParam != null ? Boolean.valueOf(isDbzlParam) : false;
            } else {
                isForBayut = true;
                isForDubizzle = false;
            }

            // Retrieve portal listings
            Set<Id> listingIds = new Set<Id>();
            List<PortalListing__c> portalListings;
            if (String.isNotBlank(recordID)) {
                portalListings = [SELECT Id, Listing__c FROM PortalListing__c WHERE Portal__c = :recordID AND SystemIsActive__c = TRUE WITH USER_MODE
                                    ORDER BY CreatedDate DESC];
            } else {
                portalListings = new List<PortalListing__c>();
            }

            for (PortalListing__c pl : portalListings) {
                if (pl.Listing__c != null) {
                    listingIds.add(pl.Listing__c);
                }
            }

            if (listingIds.isEmpty()) {
                xmlstring = '<?xml version="1.0" encoding="UTF-8"?><Properties></Properties>';
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
                Id propertyId = (Id) record.get('Property__c');
                if (propertyId != null) {
                    propertyIds.add(propertyId);
                }
            }

            // Query property media
            Map<Id, List<Property_File__c>> propertyMediaMap = new Map<Id, List<Property_File__c>>();
            if (!propertyIds.isEmpty()) {
                for (Property_File__c media : [
                    SELECT BaseUrl__c, ExternalLink__c, Property__c, Tags__c
                    FROM Property_File__c
                    WHERE Property__c IN :propertyIds AND IsOnPortalFeed__c = TRUE
                    WITH USER_MODE
                    ORDER BY Sort_on_Portal_Feed__c ASC NULLS LAST, Name ASC
                ]) {
                    if (!propertyMediaMap.containsKey(media.Property__c)) {
                        propertyMediaMap.put(media.Property__c, new List<Property_File__c>());
                    }
                    propertyMediaMap.get(media.Property__c).add(media);
                }
            }

            // Build XML
            List<String> propertyXmlBlocks = new List<String>();
            for (Map<String, Object> record : modifiedRecords) {
                List<String> currentPropertyParts = new List<String>();
                List<String> featureParts = new List<String>();

                // Process fields
                for (String fieldName : record.keySet()) {
                    if (fieldName == 'MVEX__Property__c' || fieldName == 'LastModifiedDate') continue;
                    Object fieldValue = record.get(fieldName);
                    if (fieldValue == null) continue;

                    String escapedValue = manuallyEscapeXml(String.valueOf(fieldValue));
                    if (fieldName.startsWith('Feature')) {
                        featureParts.add('<Feature>' + escapedValue + '</Feature>');
                    } else {
                        currentPropertyParts.add('<' + fieldName + '>' + escapedValue + '</' + fieldName + '>');
                    }
                }

                if (!featureParts.isEmpty()) {
                    currentPropertyParts.add('<Features>' + String.join(featureParts, '') + '</Features>');
                }

                // Add Last_Updated
                Datetime lastModified = (Datetime) record.get('LastModifiedDate');
                if (lastModified != null) {
                    currentPropertyParts.add('<Last_Updated>' + lastModified.format('yyyy-MM-dd HH:mm:ss') + '</Last_Updated>');
                }

                // Process media
                Id propertyId = (Id) record.get('MVEX__Property__c');
                if (propertyMediaMap.containsKey(propertyId)) {
                    List<String> imageParts = new List<String>();
                    List<String> floorPlanParts = new List<String>();
                    List<String> videoParts = new List<String>();

                    for (Property_File__c media : propertyMediaMap.get(propertyId)) {
                        String imageUrl = String.isNotBlank(media.ExternalLink__c) ? media.ExternalLink__c : media.BaseUrl__c;
                        if (String.isBlank(imageUrl)) continue;

                        String escapedUrl = manuallyEscapeXml(imageUrl);
                        Boolean isSpecialMedia = false;

                        if (String.isNotBlank(media.Tags__c)) {
                            List<String> tags = media.Tags__c.toLowerCase().split(';');
                            if (tags.contains('floorplan')) {
                                floorPlanParts.add('<Floor_Plan>' + escapedUrl + '</Floor_Plan>');
                                isSpecialMedia = true;
                            }
                            if (tags.contains('virtual tour') || tags.contains('360tour')) {
                                videoParts.add('<Video>' + escapedUrl + '</Video>');
                                isSpecialMedia = true;
                            }
                        }
                        if (!isSpecialMedia) {
                            imageParts.add('<Image>' + escapedUrl + '</Image>');
                        }
                    }

                    if (!imageParts.isEmpty()) {
                        currentPropertyParts.add('<Images>' + String.join(imageParts, '') + '</Images>');
                    }
                    if (!floorPlanParts.isEmpty()) {
                        currentPropertyParts.add('<Floor_Plans>' + String.join(floorPlanParts, '') + '</Floor_Plans>');
                    }
                    if (!videoParts.isEmpty()) {
                        currentPropertyParts.add('<Videos>' + String.join(videoParts, '') + '</Videos>');
                    }
                }

                // Add Portals
                List<String> portalParts = new List<String>();
                if (isForBayut) {
                    portalParts.add('<Portal>Bayut</Portal>');
                }
                if (isForDubizzle) {
                    portalParts.add('<Portal>Dubizzle</Portal>');
                }
                if (!portalParts.isEmpty()) {
                    currentPropertyParts.add('<Portals>' + String.join(portalParts, '') + '</Portals>');
                }

                propertyXmlBlocks.add('<Property>' + String.join(currentPropertyParts, '') + '</Property>');
            }

            xmlstring = '<?xml version="1.0" encoding="UTF-8"?><Properties>' + String.join(propertyXmlBlocks, '') + '</Properties>';
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'XMLFeedGenerator Exception: ' + e.getMessage() + ' at line ' + e.getLineNumber());
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
            String picklistValue = (isForBayut && isForDubizzle) || isForBayut ? 'Bayut' : 'Dubizzle';
            Map<String, Map<String, String>> fieldApiNameToLabelMap = new Map<String, Map<String, String>>();
            for (Portal_Listing_Mapping__c mapping : [
                SELECT Name, Listing_Field_API_Name__c, Value_Mapping__c
                FROM Portal_Listing_Mapping__c
                WHERE Portal_Name__c = :picklistValue AND Listing_Field_API_Name__c != NULL
                WITH USER_MODE
            ]) {
                fieldApiNameToLabelMap.put(
                    mapping.Listing_Field_API_Name__c,
                    new Map<String, String>{ 'Label' => mapping.Name, 'ValueMapping' => mapping.Value_Mapping__c }
                );
            }
            return fieldApiNameToLabelMap;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'getFieldNames Exception: ' + e.getMessage());
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
        String query = 'SELECT Id, MVEX__Property__c, LastModifiedDate';
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