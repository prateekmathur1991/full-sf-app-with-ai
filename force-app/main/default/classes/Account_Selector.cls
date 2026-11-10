/**
 * @author Salesforce Developer
 * @description Selector class for Account SObject. Provides methods for querying Account records
 *              including a distance-based query to find accounts within a specified radius of a coordinate.
 *              Plain Apex implementation (no third-party query framework) that keeps all SOQL for
 *              Account records in a single place, separated from business logic and controllers.
 */
public inherited sharing class Account_Selector {
    /**
     * @description Returns the list of Account fields that should be selected in all queries
     * @return List of Account fields for standard queries
     */
    public List<Schema.SObjectField> getSObjectFieldList() {
        return new List<Schema.SObjectField>{
            Account.Id,
            Account.Name,
            Account.Phone,
            Account.AnnualRevenue,
            Account.ShippingLatitude,
            Account.ShippingLongitude,
            Account.BillingStreet,
            Account.BillingCity,
            Account.BillingState,
            Account.BillingPostalCode,
            Account.BillingCountry
        };
    }

    /**
     * @description Returns the SObjectType for this Selector (Account)
     * @return Account.SObjectType
     */
    public Schema.SObjectType getSObjectType() {
        return Account.SObjectType;
    }

    /**
     * @description Queries accounts by their IDs
     * @param accountIds Set of Account IDs to query
     * @return List of Accounts with the specified IDs
     */
    public List<Account> selectById(Set<Id> accountIds) {
        return [
            SELECT
                Id,
                Name,
                Phone,
                AnnualRevenue,
                ShippingLatitude,
                ShippingLongitude,
                BillingStreet,
                BillingCity,
                BillingState,
                BillingPostalCode,
                BillingCountry
            FROM Account
            WHERE Id IN :accountIds
        ];
    }

    /**
     * @description Queries accounts by Name field
     * @param accountNames Set of Account names to query
     * @return List of Accounts matching the specified names
     */
    public List<Account> selectByName(Set<String> accountNames) {
        return [
            SELECT
                Id,
                Name,
                Phone,
                AnnualRevenue,
                ShippingLatitude,
                ShippingLongitude,
                BillingStreet,
                BillingCity,
                BillingState,
                BillingPostalCode,
                BillingCountry
            FROM Account
            WHERE Name IN :accountNames
        ];
    }

    /**
     * @description Finds accounts within a specified distance from a coordinate
     * @param latitude The latitude coordinate of the center point
     * @param longitude The longitude coordinate of the center point
     * @param distanceMiles The distance in miles from the center point
     * @param limitRecords Maximum number of records to return (default 500 per requirements)
     * @return List of Accounts within the specified distance, sorted by distance
     */
    public List<Account> selectByDistance(
        Decimal latitude,
        Decimal longitude,
        Decimal distanceMiles,
        Integer limitRecords
    ) {
        String query =
            'SELECT ' +
            getFieldsCSV() +
            ', DISTANCE(ShippingAddress, GEOLOCATION(' +
            latitude +
            ',' +
            longitude +
            '), \'mi\') dist ' +
            'FROM Account ' +
            'WHERE DISTANCE(ShippingAddress, GEOLOCATION(' +
            latitude +
            ',' +
            longitude +
            '), \'mi\') < ' +
            distanceMiles +
            ' ORDER BY dist ASC ' +
            'LIMIT ' +
            limitRecords;

        return Database.query(query);
    }

    /**
     * @description Helper method to get field names as CSV string
     * @return Comma-separated list of field API names
     */
    private String getFieldsCSV() {
        return String.join(
            new List<String>{
                'Id',
                'Name',
                'Phone',
                'AnnualRevenue',
                'ShippingLatitude',
                'ShippingLongitude',
                'BillingStreet',
                'BillingCity',
                'BillingState',
                'BillingPostalCode',
                'BillingCountry'
            },
            ','
        );
    }
}
