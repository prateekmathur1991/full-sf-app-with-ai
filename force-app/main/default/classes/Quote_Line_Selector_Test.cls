/**
 * @author Salesforce Developer
 * @description Tests for Quote_Line_Selector
 */
@isTest
private class Quote_Line_Selector_Test {
  @TestSetup
  static void setupTestData() {
    QuoteTestDataFactory.assignQuoteManagerPermissionSet();
    List<Quote__c> quotes = QuoteTestDataFactory.createQuotes(2, true);
    List<Product2> products = QuoteTestDataFactory.createProducts(1, true);
    insert new List<Quote_Line__c>{
      QuoteTestDataFactory.buildLine(quotes[0].Id, products[0].Id, 1, 10, 10),
      QuoteTestDataFactory.buildLine(quotes[0].Id, products[0].Id, 2, 20, 15),
      QuoteTestDataFactory.buildLine(quotes[1].Id, products[0].Id, 3, 30, 30)
    };
  }

  @isTest
  static void selectByQuoteId_TwoQuotes_ReturnsOnlyThatQuotesLines() {
    Quote__c quote = [SELECT Id FROM Quote__c WHERE Line_Count__c = 2 LIMIT 1];

    Test.startTest();
    List<Quote_Line__c> lines = new Quote_Line_Selector()
      .selectByQuoteId(quote.Id);
    Test.stopTest();

    Assert.areEqual(
      2,
      lines.size(),
      'Only the lines of the requested quote should be returned'
    );
    for (Quote_Line__c line : lines) {
      Assert.areEqual(
        quote.Id,
        line.Quote__c,
        'Line should belong to the requested quote'
      );
      Assert.areEqual(
        'Test Product 0',
        line.Product__r.Name,
        'Product name should be included'
      );
    }
    Assert.isTrue(
      lines[0].Name < lines[1].Name,
      'Lines should be ordered by Name'
    );
  }

  @isTest
  static void selectByIds_ExistingIds_ReturnsLinesWithQuote() {
    Map<Id, Quote_Line__c> expected = new Map<Id, Quote_Line__c>(
      [SELECT Id, Quote__c FROM Quote_Line__c]
    );

    Test.startTest();
    List<Quote_Line__c> lines = new Quote_Line_Selector()
      .selectByIds(expected.keySet());
    Test.stopTest();

    Assert.areEqual(3, lines.size(), 'All requested lines should be returned');
    for (Quote_Line__c line : lines) {
      Assert.areEqual(
        expected.get(line.Id).Quote__c,
        line.Quote__c,
        'Quote__c should be populated'
      );
    }
  }
}
