/**
 * @description Test class for LargeDataTableController
 * Tests pagination, caching, searching, and filtering functionality
 */
@IsTest
private class LargeDataTableControllerTest {

    /**
     * @description Setup test data - creates test accounts
     */
    @TestSetup
    static void setupTestData() {
        List<Account> accounts = new List<Account>();
        
        // Create 1050 test accounts to test pagination (more than 2 pages of 500 records each)
        for (Integer i = 0; i < 1050; i++) {
            accounts.add(new Account(
                Name = 'Test Account ' + i,
                BillingCity = i < 500 ? 'New York' : 'Los Angeles',
                Industry = i < 700 ? 'Technology' : 'Finance'
            ));
        }
        
        insert accounts;
    }

    /**
     * @description Test basic pagination - retrieve first page
     */
    @IsTest
    static void testGetRecordsFirstPage() {
        Test.startTest();
        
        LargeDataTableController.PaginatedResult result = 
            LargeDataTableController.getRecords(
                1,
                'Account',
                'Id, Name, BillingCity'
            );
        
        Test.stopTest();

        // Verify pagination metadata
        Assert.isNotNull(result, 'Result should not be null');
        Assert.equals(1, result.pageNumber, 'Page number should be 1');
        Assert.equals(1050, result.totalRecords, 'Total records should be 1050');
        Assert.equals(3, result.totalPages, 'Total pages should be 3 (1050/500)');
        Assert.isTrue(result.hasNextPage, 'Should have next page');
        Assert.isFalse(result.hasPreviousPage, 'Should not have previous page');
        Assert.equals(500, result.records.size(), 'First page should have 500 records');
    }

    /**
     * @description Test pagination - retrieve middle page
     */
    @IsTest
    static void testGetRecordsMiddlePage() {
        Test.startTest();
        
        LargeDataTableController.PaginatedResult result = 
            LargeDataTableController.getRecords(
                2,
                'Account',
                'Id, Name'
            );
        
        Test.stopTest();

        Assert.equals(2, result.pageNumber, 'Page number should be 2');
        Assert.isTrue(result.hasNextPage, 'Should have next page');
        Assert.isTrue(result.hasPreviousPage, 'Should have previous page');
        Assert.equals(500, result.records.size(), 'Second page should have 500 records');
    }

    /**
     * @description Test pagination - retrieve last page
     */
    @IsTest
    static void testGetRecordsLastPage() {
        Test.startTest();
        
        LargeDataTableController.PaginatedResult result = 
            LargeDataTableController.getRecords(
                3,
                'Account',
                'Id, Name'
            );
        
        Test.stopTest();

        Assert.equals(3, result.pageNumber, 'Page number should be 3');
        Assert.isFalse(result.hasNextPage, 'Should not have next page');
        Assert.isTrue(result.hasPreviousPage, 'Should have previous page');
        Assert.equals(50, result.records.size(), 'Third page should have 50 records');
    }

    /**
     * @description Test pagination with invalid page number (defaults to page 1)
     */
    @IsTest
    static void testGetRecordsInvalidPageNumber() {
        Test.startTest();
        
        LargeDataTableController.PaginatedResult result = 
            LargeDataTableController.getRecords(
                0,
                'Account',
                'Id, Name'
            );
        
        Test.stopTest();

        Assert.equals(1, result.pageNumber, 'Should default to page 1');
    }

    /**
     * @description Test pagination with null page number (defaults to page 1)
     */
    @IsTest
    static void testGetRecordsNullPageNumber() {
        Test.startTest();
        
        LargeDataTableController.PaginatedResult result = 
            LargeDataTableController.getRecords(
                null,
                'Account',
                'Id, Name'
            );
        
        Test.stopTest();

        Assert.equals(1, result.pageNumber, 'Should default to page 1');
    }

    /**
     * @description Test pagination with default object name
     */
    @IsTest
    static void testGetRecordsDefaultObject() {
        Test.startTest();
        
        LargeDataTableController.PaginatedResult result = 
            LargeDataTableController.getRecords(
                1,
                null,
                'Id, Name'
            );
        
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.equals(1, result.pageNumber, 'Page number should be 1');
    }

    /**
     * @description Test pagination with default fields
     */
    @IsTest
    static void testGetRecordsDefaultFields() {
        Test.startTest();
        
        LargeDataTableController.PaginatedResult result = 
            LargeDataTableController.getRecords(
                1,
                'Account',
                null
            );
        
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.isTrue(result.records.size() > 0, 'Should have records');
    }

    /**
     * @description Test search with search term
     */
    @IsTest
    static void testSearchRecordsWithSearchTerm() {
        Test.startTest();
        
        LargeDataTableController.SearchCriteria criteria = new LargeDataTableController.SearchCriteria();
        criteria.searchTerm = 'Test Account 1';
        criteria.sortField = 'Name';
        criteria.sortDirection = 'ASC';
        
        LargeDataTableController.PaginatedResult result = 
            LargeDataTableController.searchRecords(
                1,
                'Account',
                'Id, Name',
                criteria
            );
        
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.isTrue(result.totalRecords > 0, 'Should find matching records');
    }

    /**
     * @description Test search with filters
     */
    @IsTest
    static void testSearchRecordsWithFilters() {
        Test.startTest();
        
        LargeDataTableController.SearchCriteria criteria = new LargeDataTableController.SearchCriteria();
        criteria.filters = new Map<String, String>();
        criteria.filters.put('BillingCity', 'New York');
        criteria.sortField = 'Name';
        criteria.sortDirection = 'DESC';
        
        LargeDataTableController.PaginatedResult result = 
            LargeDataTableController.searchRecords(
                1,
                'Account',
                'Id, Name, BillingCity',
                criteria
            );
        
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.isTrue(result.totalRecords > 0, 'Should find records in New York');
        Assert.isTrue(result.records.size() <= 500, 'Should respect pagination limit');
    }

    /**
     * @description Test search with multiple filters
     */
    @IsTest
    static void testSearchRecordsWithMultipleFilters() {
        Test.startTest();
        
        LargeDataTableController.SearchCriteria criteria = new LargeDataTableController.SearchCriteria();
        criteria.filters = new Map<String, String>();
        criteria.filters.put('BillingCity', 'New York');
        criteria.filters.put('Industry', 'Technology');
        
        LargeDataTableController.PaginatedResult result = 
            LargeDataTableController.searchRecords(
                1,
                'Account',
                'Id, Name, BillingCity, Industry',
                criteria
            );
        
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.isTrue(result.totalRecords > 0, 'Should find filtered records');
    }

    /**
     * @description Test search with special characters (SQL injection prevention)
     */
    @IsTest
    static void testSearchRecordsWithSpecialCharacters() {
        Test.startTest();
        
        LargeDataTableController.SearchCriteria criteria = new LargeDataTableController.SearchCriteria();
        criteria.searchTerm = "Test' OR '1'='1";
        
        LargeDataTableController.PaginatedResult result = 
            LargeDataTableController.searchRecords(
                1,
                'Account',
                'Id, Name',
                criteria
            );
        
        Test.stopTest();

        // Should not throw exception and should escape properly
        Assert.isNotNull(result, 'Result should not be null');
    }

    /**
     * @description Test caching behavior
     */
    @IsTest
    static void testCachingBehavior() {
        Test.startTest();
        
        // First call - should query database
        LargeDataTableController.PaginatedResult result1 = 
            LargeDataTableController.getRecords(
                1,
                'Account',
                'Id, Name'
            );
        
        // Second call - should use cache if available
        LargeDataTableController.PaginatedResult result2 = 
            LargeDataTableController.getRecords(
                1,
                'Account',
                'Id, Name'
            );
        
        Test.stopTest();

        Assert.equals(result1.totalRecords, result2.totalRecords, 'Both calls should return same data');
        Assert.equals(result1.records.size(), result2.records.size(), 'Both calls should return same records count');
    }

    /**
     * @description Test sorting with ascending order
     */
    @IsTest
    static void testSearchRecordsWithAscendingSort() {
        Test.startTest();
        
        LargeDataTableController.SearchCriteria criteria = new LargeDataTableController.SearchCriteria();
        criteria.sortField = 'Name';
        criteria.sortDirection = 'ASC';
        
        LargeDataTableController.PaginatedResult result = 
            LargeDataTableController.searchRecords(
                1,
                'Account',
                'Id, Name',
                criteria
            );
        
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.isTrue(result.records.size() > 0, 'Should have records');
    }

    /**
     * @description Test sorting with descending order
     */
    @IsTest
    static void testSearchRecordsWithDescendingSort() {
        Test.startTest();
        
        LargeDataTableController.SearchCriteria criteria = new LargeDataTableController.SearchCriteria();
        criteria.sortField = 'CreatedDate';
        criteria.sortDirection = 'DESC';
        
        LargeDataTableController.PaginatedResult result = 
            LargeDataTableController.searchRecords(
                1,
                'Account',
                'Id, Name, CreatedDate',
                criteria
            );
        
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
    }

    /**
     * @description Test pagination calculation
     */
    @IsTest
    static void testPaginationCalculation() {
        Test.startTest();
        
        LargeDataTableController.PaginatedResult result = 
            LargeDataTableController.getRecords(
                1,
                'Account',
                'Id, Name'
            );
        
        Test.stopTest();

        // 1050 records / 500 per page = 3 pages (rounding up)
        Integer expectedPages = (Integer)Math.ceil(1050.0 / 500);
        Assert.equals(expectedPages, result.totalPages, 'Total pages calculation should be correct');
    }

    /**
     * @description Test field mapping in converted records
     */
    @IsTest
    static void testFieldMappingInRecords() {
        Test.startTest();
        
        LargeDataTableController.PaginatedResult result = 
            LargeDataTableController.getRecords(
                1,
                'Account',
                'Id, Name, BillingCity'
            );
        
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.isTrue(result.records.size() > 0, 'Should have records');
        
        // Verify that records contain the requested fields
        Map<String, Object> firstRecord = result.records.get(0);
        Assert.isNotNull(firstRecord.get('Id'), 'Record should have Id field');
        Assert.isNotNull(firstRecord.get('Name'), 'Record should have Name field');
        Assert.isTrue(firstRecord.containsKey('BillingCity'), 'Record should have BillingCity field');
    }

    /**
     * @description Test with null search criteria
     */
    @IsTest
    static void testSearchRecordsWithNullCriteria() {
        Test.startTest();
        
        LargeDataTableController.PaginatedResult result = 
            LargeDataTableController.searchRecords(
                1,
                'Account',
                'Id, Name',
                null
            );
        
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.equals(1050, result.totalRecords, 'Should return all records when criteria is null');
    }

    /**
     * @description Test search with empty search term
     */
    @IsTest
    static void testSearchRecordsWithEmptySearchTerm() {
        Test.startTest();
        
        LargeDataTableController.SearchCriteria criteria = new LargeDataTableController.SearchCriteria();
        criteria.searchTerm = '';
        
        LargeDataTableController.PaginatedResult result = 
            LargeDataTableController.searchRecords(
                1,
                'Account',
                'Id, Name',
                criteria
            );
        
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.equals(1050, result.totalRecords, 'Should return all records with empty search term');
    }

    /**
     * @description Test edge case - very high page number
     */
    @IsTest
    static void testGetRecordsVeryHighPageNumber() {
        Test.startTest();
        
        LargeDataTableController.PaginatedResult result = 
            LargeDataTableController.getRecords(
                999,
                'Account',
                'Id, Name'
            );
        
        Test.stopTest();

        Assert.equals(999, result.pageNumber, 'Page number should be 999');
        Assert.isFalse(result.hasNextPage, 'Should not have next page');
        Assert.equals(0, result.records.size(), 'Should return 0 records for out-of-range page');
    }

    /**
     * @description Test handling of records with null fields
     */
    @IsTest
    static void testRecordsWithNullFields() {
        // Create an account with minimal data
        Account testAccount = new Account(Name = 'Minimal Account');
        insert testAccount;

        Test.startTest();
        
        LargeDataTableController.PaginatedResult result = 
            LargeDataTableController.getRecords(
                1,
                'Account',
                'Id, Name, BillingCity, Industry'
            );
        
        Test.stopTest();

        Assert.isTrue(result.records.size() > 0, 'Should have records');
        // Verify that null fields are handled
        for (Map<String, Object> record : result.records) {
            Assert.isNotNull(record.get('Id'), 'Id should always be present');
        }
    }
}
