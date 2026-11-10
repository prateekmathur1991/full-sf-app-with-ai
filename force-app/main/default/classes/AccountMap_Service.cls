/**
 * @author Salesforce Developer
 * @description Service class for Account Map features. Handles business logic for finding accounts
 *              within a specified distance from a geographic coordinate. This class provides a
 *              single point of entry for account distance-based searches used by the Account Map LWC.
 *              All methods are limited to 25 lines and follow single responsibility principle.
 */
public with sharing class AccountMap_Service {
    private static final Decimal DEFAULT_SEARCH_RADIUS = 50;
    private static final Integer DEFAULT_RESULT_LIMIT = 500;
    private static final String INVALID_COORDINATES_ERROR = 'Invalid coordinates: latitude and longitude are required';
    private static final String INVALID_RADIUS_ERROR = 'Invalid search radius: must be greater than 0';

    /**
     * @description Finds Account records within a specified distance from a coordinate
     * @param latitude The latitude coordinate of the search center
     * @param longitude The longitude coordinate of the search center
     * @param distanceMiles The distance in miles to search (default: 50)
     * @return List of Account records within the specified distance
     * @throws AccountMapException if coordinates are invalid or search fails
     */
    public List<Account> findAccountsByDistance(Decimal latitude, Decimal longitude, Decimal distanceMiles) {
        validateCoordinates(latitude, longitude);
        validateRadius(distanceMiles);

        try {
            return executeDistanceQuery(latitude, longitude, distanceMiles);
        } catch (Exception e) {
            throw new AccountMapException('Error executing distance query: ' + e.getMessage());
        }
    }

    /**
     * @description Finds Account records within the default search radius (50 miles)
     * @param latitude The latitude coordinate of the search center
     * @param longitude The longitude coordinate of the search center
     * @return List of Account records within 50 miles
     * @throws AccountMapException if coordinates are invalid or search fails
     */
    public List<Account> findAccountsByDistance(Decimal latitude, Decimal longitude) {
        return findAccountsByDistance(latitude, longitude, DEFAULT_SEARCH_RADIUS);
    }

    /**
     * @description Validates that latitude and longitude are not null and within valid ranges
     * @param latitude The latitude to validate
     * @param longitude The longitude to validate
     * @throws AccountMapException if coordinates are invalid
     */
    private void validateCoordinates(Decimal latitude, Decimal longitude) {
        if (latitude == null || longitude == null) {
            throw new AccountMapException(INVALID_COORDINATES_ERROR);
        }

        if (latitude < -90 || latitude > 90) {
            throw new AccountMapException('Invalid latitude: must be between -90 and 90');
        }

        if (longitude < -180 || longitude > 180) {
            throw new AccountMapException('Invalid longitude: must be between -180 and 180');
        }
    }

    /**
     * @description Validates that the search radius is positive
     * @param radius The radius in miles to validate
     * @throws AccountMapException if radius is invalid
     */
    private void validateRadius(Decimal radius) {
        if (radius == null || radius <= 0) {
            throw new AccountMapException(INVALID_RADIUS_ERROR);
        }
    }

    /**
     * @description Executes the distance query using the Account Selector
     * @param latitude The latitude coordinate
     * @param longitude The longitude coordinate
     * @param distanceMiles The distance in miles
     * @return List of Account records from the selector
     */
    private List<Account> executeDistanceQuery(Decimal latitude, Decimal longitude, Decimal distanceMiles) {
        Account_Selector selector = new Account_Selector();
        return selector.selectByDistance(latitude, longitude, distanceMiles, DEFAULT_RESULT_LIMIT);
    }

    /**
     * @description Custom exception for Account Map Service errors
     */
    public class AccountMapException extends Exception {
    }
}
