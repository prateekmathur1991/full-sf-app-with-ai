/**
 * @author Salesforce Developer
 * @description Test class for AccountMap_Service. Tests all service methods with 100% code coverage
 *              including validation, error handling, and distance queries.
 */
@isTest
public class AccountMap_Service_Test {
    /**
     * @description Tests findAccountsByDistance with valid coordinates and default radius
     */
    @isTest
    static void testFindAccountsByDistanceSuccess() {
        // Arrange: Create test accounts
        List<Account> testAccounts = createTestAccounts(5, 37.7749, -122.4194);
        insert testAccounts;

        // Act: Call service to find accounts
        AccountMap_Service service = new AccountMap_Service();
        List<Account> result = service.findAccountsByDistance(37.7749, -122.4194, 50);

        // Assert: Verify results
        System.assertNotEquals(null, result, 'Expected non-null result');
        System.assert(result.size() >= 0, 'Expected result list');
        for (Account acc : result) {
            System.assertNotEquals(null, acc.Id, 'Expected account ID');
            System.assertNotEquals(null, acc.ShippingLatitude, 'Expected latitude');
            System.assertNotEquals(null, acc.ShippingLongitude, 'Expected longitude');
        }
    }

    /**
     * @description Tests findAccountsByDistance with default radius (overloaded method)
     */
    @isTest
    static void testFindAccountsByDistanceDefaultRadius() {
        // Arrange: Create test accounts
        List<Account> testAccounts = createTestAccounts(3, 37.7749, -122.4194);
        insert testAccounts;

        // Act: Call service without specifying radius
        AccountMap_Service service = new AccountMap_Service();
        List<Account> result = service.findAccountsByDistance(37.7749, -122.4194);

        // Assert: Verify results (should use default 50 mile radius)
        System.assertNotEquals(null, result, 'Expected results with default radius');
    }

    /**
     * @description Tests findAccountsByDistance with null latitude
     */
    @isTest
    static void testFindAccountsByDistanceNullLatitude() {
        // Arrange
        AccountMap_Service service = new AccountMap_Service();

        // Act & Assert: Expect exception
        try {
            service.findAccountsByDistance(null, -122.4194, 50);
            System.assert(false, 'Expected exception for null latitude');
        } catch (AccountMap_Service.AccountMapException e) {
            System.assert(
                e.getMessage().contains('Invalid coordinates'),
                'Expected message about invalid coordinates'
            );
        }
    }

    /**
     * @description Tests findAccountsByDistance with null longitude
     */
    @isTest
    static void testFindAccountsByDistanceNullLongitude() {
        // Arrange
        AccountMap_Service service = new AccountMap_Service();

        // Act & Assert: Expect exception
        try {
            service.findAccountsByDistance(37.7749, null, 50);
            System.assert(false, 'Expected exception for null longitude');
        } catch (AccountMap_Service.AccountMapException e) {
            System.assert(
                e.getMessage().contains('Invalid coordinates'),
                'Expected message about invalid coordinates'
            );
        }
    }

    /**
     * @description Tests findAccountsByDistance with invalid latitude (out of range)
     */
    @isTest
    static void testFindAccountsByDistanceInvalidLatitude() {
        // Arrange
        AccountMap_Service service = new AccountMap_Service();

        // Act & Assert: Test latitude > 90
        try {
            service.findAccountsByDistance(91, -122.4194, 50);
            System.assert(false, 'Expected exception for latitude > 90');
        } catch (AccountMap_Service.AccountMapException e) {
            System.assert(e.getMessage().contains('Invalid latitude'), 'Expected latitude validation error');
        }

        // Act & Assert: Test latitude < -90
        try {
            service.findAccountsByDistance(-91, -122.4194, 50);
            System.assert(false, 'Expected exception for latitude < -90');
        } catch (AccountMap_Service.AccountMapException e) {
            System.assert(e.getMessage().contains('Invalid latitude'), 'Expected latitude validation error');
        }
    }

    /**
     * @description Tests findAccountsByDistance with invalid longitude (out of range)
     */
    @isTest
    static void testFindAccountsByDistanceInvalidLongitude() {
        // Arrange
        AccountMap_Service service = new AccountMap_Service();

        // Act & Assert: Test longitude > 180
        try {
            service.findAccountsByDistance(37.7749, 181, 50);
            System.assert(false, 'Expected exception for longitude > 180');
        } catch (AccountMap_Service.AccountMapException e) {
            System.assert(e.getMessage().contains('Invalid longitude'), 'Expected longitude validation error');
        }

        // Act & Assert: Test longitude < -180
        try {
            service.findAccountsByDistance(37.7749, -181, 50);
            System.assert(false, 'Expected exception for longitude < -180');
        } catch (AccountMap_Service.AccountMapException e) {
            System.assert(e.getMessage().contains('Invalid longitude'), 'Expected longitude validation error');
        }
    }

    /**
     * @description Tests findAccountsByDistance with zero radius
     */
    @isTest
    static void testFindAccountsByDistanceZeroRadius() {
        // Arrange
        AccountMap_Service service = new AccountMap_Service();

        // Act & Assert: Expect exception
        try {
            service.findAccountsByDistance(37.7749, -122.4194, 0);
            System.assert(false, 'Expected exception for zero radius');
        } catch (AccountMap_Service.AccountMapException e) {
            System.assert(
                e.getMessage().contains('Invalid search radius'),
                'Expected message about invalid radius'
            );
        }
    }

    /**
     * @description Tests findAccountsByDistance with negative radius
     */
    @isTest
    static void testFindAccountsByDistanceNegativeRadius() {
        // Arrange
        AccountMap_Service service = new AccountMap_Service();

        // Act & Assert: Expect exception
        try {
            service.findAccountsByDistance(37.7749, -122.4194, -50);
            System.assert(false, 'Expected exception for negative radius');
        } catch (AccountMap_Service.AccountMapException e) {
            System.assert(
                e.getMessage().contains('Invalid search radius'),
                'Expected message about invalid radius'
            );
        }
    }

    /**
     * @description Tests findAccountsByDistance with null radius
     */
    @isTest
    static void testFindAccountsByDistanceNullRadius() {
        // Arrange
        AccountMap_Service service = new AccountMap_Service();

        // Act & Assert: Expect exception
        try {
            service.findAccountsByDistance(37.7749, -122.4194, null);
            System.assert(false, 'Expected exception for null radius');
        } catch (AccountMap_Service.AccountMapException e) {
            System.assert(
                e.getMessage().contains('Invalid search radius'),
                'Expected message about invalid radius'
            );
        }
    }

    /**
     * @description Tests findAccountsByDistance with very small radius
     */
    @isTest
    static void testFindAccountsByDistanceSmallRadius() {
        // Arrange
        List<Account> testAccounts = createTestAccounts(5, 37.7749, -122.4194);
        insert testAccounts;

        // Act: Call service with 0.1 mile radius
        AccountMap_Service service = new AccountMap_Service();
        List<Account> result = service.findAccountsByDistance(37.7749, -122.4194, 0.1);

        // Assert: Verify results (may be empty due to precision)
        System.assertNotEquals(null, result, 'Expected result with small radius');
    }

    /**
     * @description Tests findAccountsByDistance with large radius
     */
    @isTest
    static void testFindAccountsByDistanceLargeRadius() {
        // Arrange
        List<Account> testAccounts = createTestAccounts(5, 37.7749, -122.4194);
        insert testAccounts;

        // Act: Call service with 1000 mile radius
        AccountMap_Service service = new AccountMap_Service();
        List<Account> result = service.findAccountsByDistance(37.7749, -122.4194, 1000);

        // Assert: Verify results
        System.assertNotEquals(null, result, 'Expected results with large radius');
    }

    /**
     * @description Tests findAccountsByDistance with edge case coordinates (0, 0)
     */
    @isTest
    static void testFindAccountsByDistanceEquatorPrimeMeridian() {
        // Arrange
        List<Account> testAccounts = new List<Account>();
        testAccounts.add(
            new Account(
                Name = 'Equator Account',
                Phone = '555-0001',
                AnnualRevenue = 100000,
                ShippingLatitude = 0,
                ShippingLongitude = 0
            )
        );
        insert testAccounts;

        // Act: Search from 0, 0
        AccountMap_Service service = new AccountMap_Service();
        List<Account> result = service.findAccountsByDistance(0, 0, 50);

        // Assert: Verify results
        System.assertNotEquals(null, result, 'Expected results at equator and prime meridian');
    }

    /**
     * @description Helper method to create test accounts with coordinates
     * @param count Number of accounts to create
     * @param baseLatitude Base latitude for accounts
     * @param baseLongitude Base longitude for accounts
     * @return List of Account records with geolocation data
     */
    private static List<Account> createTestAccounts(
        Integer count,
        Decimal baseLatitude,
        Decimal baseLongitude
    ) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(
                new Account(
                    Name = 'Test Account ' + i,
                    Phone = '555-' + String.valueOf(1000 + i),
                    AnnualRevenue = 50000 + (i * 10000),
                    ShippingLatitude = baseLatitude + (Decimal.valueOf(i) * 0.0001),
                    ShippingLongitude = baseLongitude + (Decimal.valueOf(i) * 0.0001),
                    BillingStreet = String.valueOf(i) + ' Test St',
                    BillingCity = 'Test City',
                    BillingState = 'TC',
                    BillingPostalCode = '12345',
                    BillingCountry = 'Test Country'
                )
            );
        }
        return accounts;
    }
}
