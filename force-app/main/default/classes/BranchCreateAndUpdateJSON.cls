/**
* Class Name : BranchCreateAndUpdateJSON
* Test Class : PortalMappingControllerTest
* Created By : Karan Singh
* Last Modified Date : 30/06/2024
* Last Modified By : Karan Singh
* @description : Used to create the JSON for branch creation and update.
*/
public with sharing class BranchCreateAndUpdateJSON {

    /**
    * Class Name : BranchInfo
    * @description : Used to store the branch info data.
    */
    public class BranchInfo {
        public String branch_reference;
        public String branch_name;
        public Location location;
        public String telephone;
        public String email;
        public String website;
    }

    /**
    * Class Name : Location
    * @description : Used to store the location data.
    */
    public class Location {
        public String street_name;
        public String locality;
        public String town_or_city;
        public String county;
        public String postal_code;
        public String country_code;
        public Coordinates coordinates;
        public PAFAddress paf_address;
        public String paf_udprn;
    }

    /**
    * Class Name : Coordinates
    * @description : Used to store the coordinates data.
    */
    public class Coordinates {
        public Decimal latitude;
        public Decimal longitude;
    }

    /**
    * Class Name : PAFAddress
    * @description : Used to store the PAF address data.
    */
    public class PAFAddress {
        public String address_key;
        public String organisation_key;
        public String postcode_type;
    }

    /**
    * Class Name : isNullOrEmpty
    * @description : Used to check if the value is null or empty.
    */
    private static Boolean isNullOrEmpty(Object value) {
        if (value == null) return true;
        if (value instanceof String && ((String)value).trim() == '') return true;
        return false;
    }

    /**
    * Class Name : removeNullValues
    * @description : Used to remove the null values from the map.
    */
    private static void removeNullValues(Map<String, Object> mapping) {
        List<String> keysToRemove = new List<String>();
        for (String key : mapping.keySet()) {
            Object value = mapping.get(key);
            if (isNullOrEmpty(value)) {
                keysToRemove.add(key);
            } else if (value instanceof Map<String, Object>) {
                removeNullValues((Map<String, Object>)value);
                if (((Map<String, Object>)value).isEmpty()) {
                    keysToRemove.add(key);
                }
            }
        }
        for (String key : keysToRemove) {
            mapping.remove(key);
        }
    }

    /**
    * Method Name : buildJSON
    * @param branchReference to stored the branch reference
    * @param branchname to stored the branch name
    * @param streetname to stored the street name
    * @param localitytext to stored the locality text
    * @param townorcity to stored the town or city
    * @param countytext to stored the county text
    * @param postalcode to stored the postal code
    * @param countrycode to stored the country code
    * @return String that contains the JSON data.
    * @description : Used to build the JSON data for branch creation and update.
    */
    public static String buildJSON(
        String branchReference,
        String branchname,
        String streetname,
        String localitytext,
        String townorcity,
        String countytext,
        String postalcode,
        String countrycode,
        String latitudedec,
        String longitudedec,
        String addresskey,
        String organisationkey,
        String pafudprn,
        String postcodetype,
        String telephonetext,
        String email,
        String websitetext
    ) {
        try {
            Map<String, Object> branchInfo = new Map<String, Object>();
            branchInfo.put('branch_reference', branchReference);
            branchInfo.put('branch_name', branchname);

            Map<String, Object> location = new Map<String, Object>();
            location.put('street_name', streetname);
            location.put('locality', localitytext);
            location.put('town_or_city', townorcity);
            location.put('county', countytext);
            location.put('postal_code', postalcode);
            location.put('country_code', countrycode);

            Map<String, Object> coordinates = new Map<String, Object>();
            if (!isNullOrEmpty(latitudedec)) {
                coordinates.put('latitude', Decimal.valueOf(latitudedec));
            }
            if (!isNullOrEmpty(longitudedec)) {
                coordinates.put('longitude', Decimal.valueOf(longitudedec));
            }
            if (!coordinates.isEmpty()) {
                location.put('coordinates', coordinates);
            }

            Map<String, Object> paf_address = new Map<String, Object>();
            paf_address.put('address_key', addresskey);
            paf_address.put('organisation_key', organisationkey);
            paf_address.put('postcode_type', postcodetype);
            if (!paf_address.isEmpty()) {
                location.put('paf_address', paf_address);
            }

            location.put('paf_udprn', pafudprn);
            if (!location.isEmpty()) {
                branchInfo.put('location', location);
            }

            branchInfo.put('telephone', telephonetext);
            branchInfo.put('email', email);
            branchInfo.put('website', websitetext);

            removeNullValues(branchInfo);

            String requestBody = JSON.serialize(branchInfo);
            
            return requestBody;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'BranchCreateAndUpdateJSON', 'buildJSON', 'Error while building the JSON data for branch creation and update.');
            return e.getMessage();
        }
    }
}