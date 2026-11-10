/**
 * @author Salesforce Developer
 * @description Test data factory for the Quote Manager tests
 */
@isTest
public class QuoteTestDataFactory {
  /**
   * @description Assigns the Quote_Manager_User permission set to the running user. The Apex runs in
   *              USER_MODE, and freshly deployed fields carry no FLS for the admin profile, so tests
   *              must run with the same permission set real users get. runAs isolates the setup DML.
   */
  public static void assignQuoteManagerPermissionSet() {
    PermissionSet permSet = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'Quote_Manager_User'
      LIMIT 1
    ];
    Id userId = UserInfo.getUserId();
    Integer existing = [
      SELECT COUNT()
      FROM PermissionSetAssignment
      WHERE AssigneeId = :userId AND PermissionSetId = :permSet.Id
    ];
    if (existing == 0) {
      System.runAs(new User(Id = userId)) {
        insert new PermissionSetAssignment(
          AssigneeId = userId,
          PermissionSetId = permSet.Id
        );
      }
    }
  }

  /**
   * @description Creates active products
   * @param count Number of products
   * @param doInsert Whether to insert them
   * @return The products
   */
  public static List<Product2> createProducts(Integer count, Boolean doInsert) {
    List<Product2> products = new List<Product2>();
    for (Integer i = 0; i < count; i++) {
      products.add(new Product2(Name = 'Test Product ' + i, IsActive = true));
    }
    if (doInsert) {
      insert products;
    }
    return products;
  }

  /**
   * @description Creates draft quotes
   * @param count Number of quotes
   * @param doInsert Whether to insert them
   * @return The quotes
   */
  public static List<Quote__c> createQuotes(Integer count, Boolean doInsert) {
    List<Quote__c> quotes = new List<Quote__c>();
    for (Integer i = 0; i < count; i++) {
      quotes.add(new Quote__c(Name = 'Test Quote ' + i, Status__c = 'Draft'));
    }
    if (doInsert) {
      insert quotes;
    }
    return quotes;
  }

  /**
   * @description Builds an unsaved quote line
   * @param quoteId Parent quote
   * @param productId Product
   * @param quantity Quantity
   * @param listPrice Unit list price
   * @param negotiatedPrice Unit negotiated price
   * @return The line
   */
  public static Quote_Line__c buildLine(
    Id quoteId,
    Id productId,
    Decimal quantity,
    Decimal listPrice,
    Decimal negotiatedPrice
  ) {
    return new Quote_Line__c(
      Quote__c = quoteId,
      Product__c = productId,
      Quantity__c = quantity,
      List_Price__c = listPrice,
      Negotiated_Price__c = negotiatedPrice
    );
  }

  /**
   * @description Builds a line input as the LWC would send it
   * @param lineId Existing line Id, or null for a new line
   * @param productId Product
   * @param quantity Quantity
   * @param listPrice Unit list price
   * @param negotiatedPrice Unit negotiated price
   * @return The input
   */
  public static QuoteLineInput buildInput(
    Id lineId,
    Id productId,
    Decimal quantity,
    Decimal listPrice,
    Decimal negotiatedPrice
  ) {
    QuoteLineInput input = new QuoteLineInput();
    input.id = lineId;
    input.productId = productId;
    input.quantity = quantity;
    input.listPrice = listPrice;
    input.negotiatedPrice = negotiatedPrice;
    return input;
  }

  /**
   * @description Creates a Standard User without the Quote_Manager_User permission set
   * @return The inserted user
   */
  public static User createUserWithoutQuoteAccess() {
    Profile standardProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    String uniqueKey = String.valueOf(Crypto.getRandomInteger())
      .replace('-', '');
    User user = new User(
      Alias = 'qtnoacc',
      Email = 'quote.noaccess' + uniqueKey + '@example.com',
      Username = 'quote.noaccess' + uniqueKey + '@example.com.test',
      LastName = 'NoAccess',
      ProfileId = standardProfile.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
    insert user;
    return user;
  }
}
