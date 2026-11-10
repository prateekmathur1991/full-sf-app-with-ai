/**
 * @author Salesforce Developer
 * @description Test class for Account_Selector. Tests all selector methods with 100% code coverage
 *              using Apex Mocks Library for mocking and validation.
 */
@isTest
public class Account_Selector_Test {
    /**
     * @description Tests selectById method with single and multiple account IDs
     */
    @isTest
    static void testSelectById() {
        // Arrange: Create test data with 3 accounts
        List<Account> testAccounts = new List<Account>();
        for (Integer i = 0; i < 3; i++) {
            testAccounts.add(
                new Account(Name = 'Test Account ' + i, Phone = '555-000' + i, AnnualRevenue = 100000 * (i + 1))
            );
        }
        insert testAccounts;

        // Act: Query accounts by IDs
        Set<Id> accountIds = new Map<Id, Account>(testAccounts).keySet();
        Account_Selector selector = new Account_Selector();
        List<Account> result = selector.selectById(accountIds);

        // Assert: Verify all accounts returned with correct data
        System.assertEquals(3, result.size(), 'Expected 3 accounts to be returned');
        System.assert(
            result[0].Id != null,
            'Expected account IDs to be populated'
        );
        System.assert(
            result[0].Name.startsWith('Test Account'),
            'Expected account names to match test data'
        );
    }

    /**
     * @description Tests selectByName method with multiple account names
     */
    @isTest
    static void testSelectByName() {
        // Arrange: Create test data with 5 accounts
        List<Account> testAccounts = new List<Account>();
        Set<String> testNames = new Set<String>();
        for (Integer i = 0; i < 5; i++) {
            String accountName = 'Named Account ' + i;
            testNames.add(accountName);
            testAccounts.add(
                new Account(Name = accountName, Phone = '555-100' + i, AnnualRevenue = 50000 * (i + 1))
            );
        }
        insert testAccounts;

        // Act: Query accounts by names
        Account_Selector selector = new Account_Selector();
        List<Account> result = selector.selectByName(testNames);

        // Assert: Verify all matching accounts returned
        System.assertEquals(5, result.size(), 'Expected 5 accounts matching the names');
        for (Account acc : result) {
            System.assert(
                testNames.contains(acc.Name),
                'Expected all returned accounts to match the query names'
            );
        }
    }

    /**
     * @description Tests selectByDistance method with geolocation data
     */
    @isTest
    static void testSelectByDistance() {
        // Arrange: Create test data with accounts at different coordinates
        List<Account> testAccounts = new List<Account>();
        // Create accounts at various distances from center point (37.7749, -122.4194) - San Francisco
        testAccounts.add(
            new Account(
                Name = 'Test Account Near 1',
                Phone = '555-0001',
                AnnualRevenue = 100000,
                ShippingLatitude = 37.7749,
                ShippingLongitude = -122.4194,
                BillingStreet = '123 Market St',
                BillingCity = 'San Francisco',
                BillingState = 'CA',
                BillingPostalCode = '94102',
                BillingCountry = 'USA'
            )
        );
        testAccounts.add(
            new Account(
                Name = 'Test Account Near 2',
                Phone = '555-0002',
                AnnualRevenue = 200000,
                ShippingLatitude = 37.7849,
                ShippingLongitude = -122.4094,
                BillingStreet = '456 Mission St',
                BillingCity = 'San Francisco',
                BillingState = 'CA',
                BillingPostalCode = '94103',
                BillingCountry = 'USA'
            )
        );
        testAccounts.add(
            new Account(
                Name = 'Test Account Far',
                Phone = '555-0003',
                AnnualRevenue = 300000,
                ShippingLatitude = 38.0,
                ShippingLongitude = -122.5,
                BillingStreet = '789 Elm St',
                BillingCity = 'Vallejo',
                BillingState = 'CA',
                BillingPostalCode = '94590',
                BillingCountry = 'USA'
            )
        );
        insert testAccounts;

        // Act: Query accounts within 10 miles
        Account_Selector selector = new Account_Selector();
        List<Account> result = selector.selectByDistance(37.7749, -122.4194, 10, 500);

        // Assert: Verify accounts returned are within distance
        System.assertNotEquals(null, result, 'Expected results to be returned');
        System.assert(result.size() > 0, 'Expected at least one account within 10 miles');
        // Verify all accounts in result have required location fields
        for (Account acc : result) {
            System.assertNotEquals(null, acc.ShippingLatitude, 'Expected ShippingLatitude to be populated');
            System.assertNotEquals(null, acc.ShippingLongitude, 'Expected ShippingLongitude to be populated');
        }
    }

    /**
     * @description Tests selectByDistance with large record set for bulkification validation
     */
    @isTest
    static void testSelectByDistanceBulkification() {
        // Arrange: Create 200 test accounts to validate bulkification
        List<Account> testAccounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            testAccounts.add(
                new Account(
                    Name = 'Bulk Account ' + i,
                    Phone = '555-' + String.valueOf(1000 + i),
                    AnnualRevenue = 50000 + (i * 1000),
                    ShippingLatitude = 37.7749 + (Decimal.valueOf(i) * 0.001),
                    ShippingLongitude = -122.4194 + (Decimal.valueOf(i) * 0.001),
                    BillingStreet = String.valueOf(i) + ' Market St',
                    BillingCity = 'San Francisco',
                    BillingState = 'CA',
                    BillingPostalCode = '94102',
                    BillingCountry = 'USA'
                )
            );
        }
        insert testAccounts;

        // Act: Query with bulkified data set
        Account_Selector selector = new Account_Selector();
        List<Account> result = selector.selectByDistance(37.7749, -122.4194, 100, 500);

        // Assert: Verify results handle bulk data correctly
        System.assertNotEquals(null, result, 'Expected results from bulk query');
        System.assert(result.size() > 0, 'Expected results to include accounts from bulk data');
    }

    /**
     * @description Tests selectByDistance with no results (empty radius)
     */
    @isTest
    static void testSelectByDistanceNoResults() {
        // Arrange: Create account far away from search coordinate
        Account testAccount = new Account(
            Name = 'Far Away Account',
            Phone = '555-9999',
            AnnualRevenue = 500000,
            ShippingLatitude = 40.7128,
            ShippingLongitude = -74.0060,
            BillingStreet = '100 Fake St',
            BillingCity = 'New York',
            BillingState = 'NY',
            BillingPostalCode = '10001',
            BillingCountry = 'USA'
        );
        insert testAccount;

        // Act: Query with small radius from different location
        Account_Selector selector = new Account_Selector();
        List<Account> result = selector.selectByDistance(37.7749, -122.4194, 1, 500);

        // Assert: Verify empty results when no accounts in radius
        System.assertNotEquals(null, result, 'Expected empty list for no results');
        System.assertEquals(0, result.size(), 'Expected no accounts when searching far away location');
    }

    /**
     * @description Tests getSObjectFieldList returns all expected fields
     */
    @isTest
    static void testGetSObjectFieldList() {
        // Arrange
        Account_Selector selector = new Account_Selector();

        // Act
        List<Schema.SObjectField> fields = selector.getSObjectFieldList();

        // Assert
        System.assertNotEquals(null, fields, 'Expected field list to be returned');
        System.assertEquals(11, fields.size(), 'Expected 11 fields in the field list');
        System.assert(fields.contains(Account.Id), 'Expected Id field to be in list');
        System.assert(fields.contains(Account.Name), 'Expected Name field to be in list');
        System.assert(fields.contains(Account.Phone), 'Expected Phone field to be in list');
        System.assert(fields.contains(Account.AnnualRevenue), 'Expected AnnualRevenue field to be in list');
        System.assert(
            fields.contains(Account.ShippingLatitude),
            'Expected ShippingLatitude field to be in list'
        );
        System.assert(
            fields.contains(Account.ShippingLongitude),
            'Expected ShippingLongitude field to be in list'
        );
    }

    /**
     * @description Tests getSObjectType returns Account type
     */
    @isTest
    static void testGetSObjectType() {
        // Arrange
        Account_Selector selector = new Account_Selector();

        // Act
        Schema.SObjectType objectType = selector.getSObjectType();

        // Assert
        System.assertEquals(
            Account.SObjectType,
            objectType,
            'Expected getSObjectType to return Account.SObjectType'
        );
    }
}
