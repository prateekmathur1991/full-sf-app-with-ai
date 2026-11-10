/**
 * @author Salesforce Developer
 * @description Selector holding all SOQL for Quote__c. Uses inherited sharing so the caller's
 *              sharing context applies, and WITH USER_MODE so CRUD and FLS are enforced.
 */
public inherited sharing class Quote_Selector {
  /**
   * @description Returns the most recently modified quotes, header fields and roll-ups included
   * @param limitSize Maximum number of quotes to return
   * @return Quotes ordered by LastModifiedDate descending (empty list when none)
   */
  public List<Quote__c> selectRecent(Integer limitSize) {
    return [
      SELECT
        Id,
        Name,
        Status__c,
        Account__c,
        Account__r.Name,
        Expiration_Date__c,
        Total_List_Price__c,
        Total_Negotiated_Price__c,
        Total_Discount__c,
        Discount_Percent__c,
        Line_Count__c,
        LastModifiedDate
      FROM Quote__c
      WITH USER_MODE
      ORDER BY LastModifiedDate DESC
      LIMIT :limitSize
    ];
  }

  /**
   * @description Returns a single quote with its header fields and roll-ups
   * @param quoteId Id of the quote to fetch
   * @return The matching quote, or null when it doesn't exist or isn't accessible
   */
  public Quote__c selectById(Id quoteId) {
    List<Quote__c> quotes = [
      SELECT
        Id,
        Name,
        Status__c,
        Account__c,
        Account__r.Name,
        Expiration_Date__c,
        Total_List_Price__c,
        Total_Negotiated_Price__c,
        Total_Discount__c,
        Discount_Percent__c,
        Line_Count__c,
        LastModifiedDate
      FROM Quote__c
      WHERE Id = :quoteId
      WITH USER_MODE
      LIMIT 1
    ];
    return quotes.isEmpty() ? null : quotes[0];
  }
}
