/**
 * @description Controller for LWC that displays large datasets (100,000+ records).
 *              Implements pagination, caching, and optimization patterns to work
 *              within Salesforce governor limits.
 * 
 * Design considerations:
 * 1. SOQL limit: Max 50,000 records per query - uses pagination
 * 2. Heap size: Max 6MB per transaction - limits records returned per call
 * 3. Query timeout: 5 seconds - optimized queries with WHERE clauses
 * 4. Governor limits: CPU time and callouts - efficient data retrieval
 */
public with sharing class LargeDataTableController {

    // Constants for pagination and performance optimization
    private static final Integer RECORDS_PER_PAGE = 500;
    private static final Integer MAX_CACHED_PAGES = 10;
    private static final String CACHE_PREFIX = 'LargeDataTable_';
    private static final String ACCOUNT_OBJECT = 'Account';

    /**
     * @description Wrapper class to return paginated data to LWC
     */
    public class PaginatedResult {
        @AuraEnabled
        public List<Map<String, Object>> records { get; set; }
        @AuraEnabled
        public Integer pageNumber { get; set; }
        @AuraEnabled
        public Integer totalRecords { get; set; }
        @AuraEnabled
        public Integer totalPages { get; set; }
        @AuraEnabled
        public Boolean hasNextPage { get; set; }
        @AuraEnabled
        public Boolean hasPreviousPage { get; set; }
    }

    /**
     * @description Wrapper class for search/filter criteria
     */
    public class SearchCriteria {
        @AuraEnabled
        public String searchTerm { get; set; }
        @AuraEnabled
        public String sortField { get; set; }
        @AuraEnabled
        public String sortDirection { get; set; }
        @AuraEnabled
        public Map<String, String> filters { get; set; }
    }

    /**
     * @description Fetches paginated records for the data table
     * @param pageNumber The page number to retrieve (1-based)
     * @param objectName The Salesforce object to query
     * @param fields Comma-separated list of field names to retrieve
     * @return PaginatedResult containing records and pagination metadata
     */
    @AuraEnabled(cacheable=true)
    public static PaginatedResult getRecords(
        Integer pageNumber,
        String objectName,
        String fields
    ) {
        try {
            // Validate inputs
            pageNumber = pageNumber != null && pageNumber > 0 ? pageNumber : 1;
            objectName = String.isNotBlank(objectName) ? objectName : ACCOUNT_OBJECT;
            fields = String.isNotBlank(fields) ? fields : 'Id, Name';

            // Check cache first
            PaginatedResult cachedResult = getCachedResult(objectName, pageNumber, fields, null);
            if (cachedResult != null) {
                return cachedResult;
            }

            PaginatedResult result = new PaginatedResult();
            
            // Get total record count
            Integer totalRecords = getTotalRecordCount(objectName, null);
            Integer totalPages = (Integer)Math.ceil((Decimal)totalRecords / RECORDS_PER_PAGE);

            result.totalRecords = totalRecords;
            result.totalPages = totalPages;
            result.pageNumber = pageNumber;
            result.hasNextPage = pageNumber < totalPages;
            result.hasPreviousPage = pageNumber > 1;

            // Calculate offset
            Integer offset = (pageNumber - 1) * RECORDS_PER_PAGE;

            // Build query
            String query = buildQuery(objectName, fields, null, offset);

            // Execute query
            List<SObject> records = Database.query(query);
            result.records = convertSObjectsToMaps(records, fields);

            // Cache the result
            cacheResult(objectName, pageNumber, fields, null, result);

            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving records: ' + e.getMessage());
        }
    }

    /**
     * @description Fetches paginated records with search and filter criteria
     * @param pageNumber The page number to retrieve (1-based)
     * @param objectName The Salesforce object to query
     * @param fields Comma-separated list of field names to retrieve
     * @param searchCriteria Contains search term, filters, and sorting options
     * @return PaginatedResult containing records and pagination metadata
     */
    @AuraEnabled
    public static PaginatedResult searchRecords(
        Integer pageNumber,
        String objectName,
        String fields,
        SearchCriteria searchCriteria
    ) {
        try {
            pageNumber = pageNumber != null && pageNumber > 0 ? pageNumber : 1;
            objectName = String.isNotBlank(objectName) ? objectName : ACCOUNT_OBJECT;
            fields = String.isNotBlank(fields) ? fields : 'Id, Name';

            // Create cache key from search criteria
            String cacheKey = JSON.serialize(searchCriteria);

            // Check cache
            PaginatedResult cachedResult = getCachedResult(objectName, pageNumber, fields, cacheKey);
            if (cachedResult != null) {
                return cachedResult;
            }

            PaginatedResult result = new PaginatedResult();

            // Get total record count with filters
            Integer totalRecords = getTotalRecordCount(objectName, searchCriteria);
            Integer totalPages = (Integer)Math.ceil((Decimal)totalRecords / RECORDS_PER_PAGE);

            result.totalRecords = totalRecords;
            result.totalPages = totalPages;
            result.pageNumber = pageNumber;
            result.hasNextPage = pageNumber < totalPages;
            result.hasPreviousPage = pageNumber > 1;

            Integer offset = (pageNumber - 1) * RECORDS_PER_PAGE;

            String query = buildQuery(objectName, fields, searchCriteria, offset);
            List<SObject> records = Database.query(query);
            result.records = convertSObjectsToMaps(records, fields);

            cacheResult(objectName, pageNumber, fields, cacheKey, result);

            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error searching records: ' + e.getMessage());
        }
    }

    /**
     * @description Gets the total count of records in the object
     * @param objectName The Salesforce object name
     * @param searchCriteria Optional search/filter criteria
     * @return Total record count
     */
    private static Integer getTotalRecordCount(String objectName, SearchCriteria searchCriteria) {
        try {
            String countQuery = 'SELECT COUNT() FROM ' + objectName;
            countQuery = addWhereClause(countQuery, searchCriteria);
            return Database.countQuery(countQuery);
        } catch (Exception e) {
            // Return 0 if count fails
            return 0;
        }
    }

    /**
     * @description Builds SOQL query with pagination, filters, and sorting
     * @param objectName The Salesforce object name
     * @param fields Comma-separated field list
     * @param searchCriteria Search/filter criteria
     * @param offset Record offset for pagination
     * @return SOQL query string
     */
    private static String buildQuery(
        String objectName,
        String fields,
        SearchCriteria searchCriteria,
        Integer offset
    ) {
        String query = 'SELECT ' + fields + ' FROM ' + objectName;
        query = addWhereClause(query, searchCriteria);

        // Add sorting
        if (searchCriteria != null && String.isNotBlank(searchCriteria.sortField)) {
            String sortDir = String.isNotBlank(searchCriteria.sortDirection) 
                ? searchCriteria.sortDirection 
                : 'ASC';
            query += ' ORDER BY ' + searchCriteria.sortField + ' ' + sortDir;
        }

        // Add pagination
        query += ' LIMIT ' + RECORDS_PER_PAGE + ' OFFSET ' + offset;

        return query;
    }

    /**
     * @description Adds WHERE clause to query based on search criteria
     * @param query The base query
     * @param searchCriteria Search criteria with search term and filters
     * @return Query with WHERE clause appended
     */
    private static String addWhereClause(String query, SearchCriteria searchCriteria) {
        if (searchCriteria == null) {
            return query;
        }

        List<String> conditions = new List<String>();

        // Add search term condition
        if (String.isNotBlank(searchCriteria.searchTerm)) {
            String searchTerm = '%' + String.escapeSingleQuotes(searchCriteria.searchTerm) + '%';
            conditions.add('Name LIKE \'' + searchTerm + '\'');
        }

        // Add filter conditions
        if (searchCriteria.filters != null && !searchCriteria.filters.isEmpty()) {
            for (String filterKey : searchCriteria.filters.keySet()) {
                String filterValue = String.escapeSingleQuotes(searchCriteria.filters.get(filterKey));
                conditions.add(filterKey + ' = \'' + filterValue + '\'');
            }
        }

        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }

        return query;
    }

    /**
     * @description Converts SObject records to Map<String, Object> for JSON serialization
     * @param records List of SObjects
     * @param fieldList Comma-separated field names
     * @return List of Maps containing field data
     */
    private static List<Map<String, Object>> convertSObjectsToMaps(
        List<SObject> records,
        String fieldList
    ) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        List<String> fields = fieldList.split(',');

        for (SObject record : records) {
            Map<String, Object> recordMap = new Map<String, Object>();
            for (String field : fields) {
                String fieldName = field.trim();
                recordMap.put(fieldName, record.get(fieldName));
            }
            result.add(recordMap);
        }

        return result;
    }

    /**
     * @description Retrieves cached result if available
     * @param objectName The object name
     * @param pageNumber Page number
     * @param fields Field list
     * @param cacheKey Optional cache key for search criteria
     * @return Cached PaginatedResult or null
     */
    private static PaginatedResult getCachedResult(
        String objectName,
        Integer pageNumber,
        String fields,
        String cacheKey
    ) {
        try {
            String key = generateCacheKey(objectName, pageNumber, fields, cacheKey);
            Cache.OrgPartition orgPartition = Cache.Org.getPartition('default');
            return (PaginatedResult)orgPartition.get(key);
        } catch (Exception e) {
            // Cache miss or error - return null
            return null;
        }
    }

    /**
     * @description Caches the paginated result
     * @param objectName The object name
     * @param pageNumber Page number
     * @param fields Field list
     * @param cacheKey Optional cache key for search criteria
     * @param result The result to cache
     */
    private static void cacheResult(
        String objectName,
        Integer pageNumber,
        String fields,
        String cacheKey,
        PaginatedResult result
    ) {
        try {
            String key = generateCacheKey(objectName, pageNumber, fields, cacheKey);
            Cache.OrgPartition orgPartition = Cache.Org.getPartition('default');
            // Cache for 1 hour (3600 seconds)
            orgPartition.put(key, result, 3600);
        } catch (Exception e) {
            // Caching is optional - log but don't fail
            System.debug('Cache write failed: ' + e.getMessage());
        }
    }

    /**
     * @description Generates cache key for storing/retrieving cached results
     * @param objectName The object name
     * @param pageNumber Page number
     * @param fields Field list
     * @param cacheKey Optional cache key for search criteria
     * @return Cache key string
     */
    private static String generateCacheKey(
        String objectName,
        Integer pageNumber,
        String fields,
        String cacheKey
    ) {
        String baseKey = CACHE_PREFIX + objectName + '_Page' + pageNumber + '_Fields' + fields.hashCode();
        if (String.isNotBlank(cacheKey)) {
            baseKey += '_' + cacheKey.hashCode();
        }
        return baseKey;
    }
}
