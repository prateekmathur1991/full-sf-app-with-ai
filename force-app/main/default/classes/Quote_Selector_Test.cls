/**
 * @author Salesforce Developer
 * @description Tests for Quote_Selector
 */
@isTest
private class Quote_Selector_Test {
  @TestSetup
  static void setupTestData() {
    QuoteTestDataFactory.assignQuoteManagerPermissionSet();
    List<Quote__c> quotes = QuoteTestDataFactory.createQuotes(3, true);
    List<Product2> products = QuoteTestDataFactory.createProducts(1, true);
    insert QuoteTestDataFactory.buildLine(
      quotes[0].Id,
      products[0].Id,
      2,
      100,
      80
    );
  }

  @isTest
  static void selectRecent_LimitApplied_ReturnsLimitedRows() {
    Test.startTest();
    List<Quote__c> quotes = new Quote_Selector().selectRecent(2);
    Test.stopTest();

    Assert.areEqual(2, quotes.size(), 'Limit should cap the number of quotes');
  }

  @isTest
  static void selectRecent_MultipleQuotes_OrderedByLastModifiedDesc() {
    Test.startTest();
    List<Quote__c> quotes = new Quote_Selector().selectRecent(10);
    Test.stopTest();

    Assert.areEqual(3, quotes.size(), 'All quotes should be returned');
    for (Integer i = 1; i < quotes.size(); i++) {
      Assert.isTrue(
        quotes[i - 1].LastModifiedDate >= quotes[i].LastModifiedDate,
        'Quotes should be ordered newest first'
      );
    }
  }

  @isTest
  static void selectById_QuoteWithLine_ReturnsRollups() {
    Quote__c seeded = [SELECT Id FROM Quote__c WHERE Line_Count__c = 1 LIMIT 1];

    Test.startTest();
    Quote__c quote = new Quote_Selector().selectById(seeded.Id);
    Test.stopTest();

    Assert.areEqual(
      200,
      quote.Total_List_Price__c,
      'Total list price should roll up 2 x 100'
    );
    Assert.areEqual(
      160,
      quote.Total_Negotiated_Price__c,
      'Total negotiated should roll up 2 x 80'
    );
    Assert.areEqual(
      40,
      quote.Total_Discount__c,
      'Total discount should be 200 - 160'
    );
    Assert.areEqual(1, quote.Line_Count__c, 'Line count should be 1');
  }

  @isTest
  static void selectById_DeletedQuote_ReturnsNull() {
    Quote__c seeded = [SELECT Id FROM Quote__c LIMIT 1];
    delete seeded;

    Test.startTest();
    Quote__c quote = new Quote_Selector().selectById(seeded.Id);
    Test.stopTest();

    Assert.isNull(quote, 'A missing quote should return null');
  }
}
