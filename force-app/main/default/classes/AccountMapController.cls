/**
 * @author Salesforce Developer
 * @description Apex controller for the Account Map Lightning Web Component. Provides methods to search
 *              for accounts within a specified distance from a geographic coordinate.
 *              This controller contains NO business logic - all business operations are delegated to
 *              the AccountMap_Service class. Input is sanitized for security.
 */
public with sharing class AccountMapController {
    /**
     * @description Searches for Account records within a specified distance from a geographic coordinate.
     *              Input is sanitized to prevent SOQL injection and HTML injection.
     * @param latitude The latitude coordinate of the search center
     * @param longitude The longitude coordinate of the search center
     * @param distanceMiles The distance in miles to search (default: 50 if null)
     * @return Wrapper object containing search results or error message
     */
    @AuraEnabled(Cacheable=false)
    public static AccountSearchResult searchAccountsByCoordinates(
        Decimal latitude,
        Decimal longitude,
        Decimal distanceMiles
    ) {
        try {
            // Use provided distance or default to 50 miles
            Decimal searchDistance = distanceMiles != null ? distanceMiles : 50;

            // Delegate business logic to service
            AccountMap_Service service = new AccountMap_Service();
            List<Account> accounts = service.findAccountsByDistance(latitude, longitude, searchDistance);

            return new AccountSearchResult(accounts, null);
        } catch (AccountMap_Service.AccountMapException e) {
            return new AccountSearchResult(new List<Account>(), e.getMessage());
        } catch (Exception e) {
            return new AccountSearchResult(
                new List<Account>(),
                'An unexpected error occurred: ' + e.getMessage()
            );
        }
    }

    /**
     * @description Wrapper class for returning search results and error messages from controller methods
     */
    public class AccountSearchResult {
        /**
         * @description List of Account records found within the search distance
         */
        @AuraEnabled
        public List<Account> accounts;

        /**
         * @description Error message if search failed, null if successful
         */
        @AuraEnabled
        public String errorMessage;

        /**
         * @description Constructor
         * @param accountsList List of Account records found
         * @param errorMsg Error message if any error occurred
         */
        public AccountSearchResult(List<Account> accountsList, String errorMsg) {
            this.accounts = accountsList != null ? accountsList : new List<Account>();
            this.errorMessage = errorMsg;
        }
    }
}
