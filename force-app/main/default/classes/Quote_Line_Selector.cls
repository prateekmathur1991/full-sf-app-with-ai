/**
 * @author Salesforce Developer
 * @description Selector holding all SOQL for Quote_Line__c. Uses inherited sharing so the caller's
 *              sharing context applies, and WITH USER_MODE so CRUD and FLS are enforced.
 */
public inherited sharing class Quote_Line_Selector {
  private static final Integer MAX_LINES = 500;

  /**
   * @description Returns the lines of a quote, including the product name and line formulas
   * @param quoteId Id of the parent quote
   * @return Up to 500 lines ordered by Name (the autonumber), empty list when none
   */
  public List<Quote_Line__c> selectByQuoteId(Id quoteId) {
    return [
      SELECT
        Id,
        Name,
        Quote__c,
        Product__c,
        Product__r.Name,
        Quantity__c,
        List_Price__c,
        Negotiated_Price__c,
        Total_List_Price__c,
        Total_Negotiated_Price__c,
        Total_Discount__c,
        Discount_Percent__c
      FROM Quote_Line__c
      WHERE Quote__c = :quoteId
      WITH USER_MODE
      ORDER BY Name
      LIMIT :MAX_LINES
    ];
  }

  /**
   * @description Returns lines by Id with their parent quote, used for ownership checks
   * @param lineIds Ids of the lines to fetch
   * @return The accessible lines among the given Ids
   */
  public List<Quote_Line__c> selectByIds(Set<Id> lineIds) {
    return [
      SELECT Id, Quote__c
      FROM Quote_Line__c
      WHERE Id IN :lineIds
      WITH USER_MODE
    ];
  }
}
