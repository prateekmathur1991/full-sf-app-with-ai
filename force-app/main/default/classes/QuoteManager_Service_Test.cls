/**
 * @author Salesforce Developer
 * @description Tests for QuoteManager_Service. Runs as the test-running admin, whose profile has
 *              access to the custom objects, except the runAs test for a user without access.
 */
@isTest
private class QuoteManager_Service_Test {
  @TestSetup
  static void setupTestData() {
    QuoteTestDataFactory.assignQuoteManagerPermissionSet();
    QuoteTestDataFactory.createQuotes(2, true);
    QuoteTestDataFactory.createProducts(2, true);
  }

  private static List<Quote__c> getQuotesByName() {
    return [SELECT Id FROM Quote__c ORDER BY Name];
  }

  private static Id getProductId() {
    return [SELECT Id FROM Product2 ORDER BY Name LIMIT 1].Id;
  }

  @isTest
  static void saveLines_NewLines_CalculatesFormulasAndRollups() {
    Id quoteId = getQuotesByName()[0].Id;
    Id productId = getProductId();
    List<QuoteLineInput> inputs = new List<QuoteLineInput>{
      QuoteTestDataFactory.buildInput(null, productId, 2, 100, 80),
      QuoteTestDataFactory.buildInput(null, productId, 1, 100, 120),
      QuoteTestDataFactory.buildInput(null, productId, 3, 0, 10)
    };

    Test.startTest();
    QuoteManager_Service.QuoteDetail detail = new QuoteManager_Service()
      .saveLines(quoteId, inputs);
    Test.stopTest();

    Assert.areEqual(3, detail.lines.size(), 'Three lines should be saved');
    Assert.areEqual(
      40,
      detail.lines[0].Total_Discount__c,
      'Discount line: 200 - 160'
    );
    Assert.areEqual(
      -20,
      detail.lines[1].Total_Discount__c,
      'Markup line should have a negative discount'
    );
    Assert.isTrue(
      detail.lines[1].Discount_Percent__c < 0,
      'Markup line should have a negative percent'
    );
    Assert.areEqual(
      0,
      detail.lines[2].Discount_Percent__c,
      'List price 0 should give 0 percent'
    );
    Assert.areEqual(
      300,
      detail.quote.Total_List_Price__c,
      'Header list total: 200 + 100 + 0'
    );
    Assert.areEqual(
      310,
      detail.quote.Total_Negotiated_Price__c,
      'Header negotiated: 160 + 120 + 30'
    );
    Assert.areEqual(
      -10,
      detail.quote.Total_Discount__c,
      'Header discount: 300 - 310'
    );
    Assert.areEqual(3, detail.quote.Line_Count__c, 'Line count should be 3');
  }

  @isTest
  static void saveLines_ExistingLine_UpdatesValues() {
    Id quoteId = getQuotesByName()[0].Id;
    Id productId = getProductId();
    Quote_Line__c line = QuoteTestDataFactory.buildLine(
      quoteId,
      productId,
      1,
      50,
      50
    );
    insert line;

    Test.startTest();
    QuoteManager_Service.QuoteDetail detail = new QuoteManager_Service()
      .saveLines(
        quoteId,
        new List<QuoteLineInput>{
          QuoteTestDataFactory.buildInput(line.Id, productId, 4, 50, 40)
        }
      );
    Test.stopTest();

    Assert.areEqual(
      1,
      detail.lines.size(),
      'The line should be updated, not duplicated'
    );
    Assert.areEqual(
      160,
      detail.lines[0].Total_Negotiated_Price__c,
      'Line total should be 4 x 40'
    );
    Assert.areEqual(
      200,
      detail.quote.Total_List_Price__c,
      'Header should recalculate to 4 x 50'
    );
  }

  @isTest
  static void saveLines_BulkLines_SavesAll() {
    Id quoteId = getQuotesByName()[0].Id;
    Id productId = getProductId();
    List<QuoteLineInput> inputs = new List<QuoteLineInput>();
    for (Integer i = 0; i < 200; i++) {
      inputs.add(QuoteTestDataFactory.buildInput(null, productId, 1, 10, 9));
    }

    Test.startTest();
    QuoteManager_Service.QuoteDetail detail = new QuoteManager_Service()
      .saveLines(quoteId, inputs);
    Test.stopTest();

    Assert.areEqual(200, detail.lines.size(), 'All 200 lines should be saved');
    Assert.areEqual(
      200,
      detail.quote.Line_Count__c,
      'Line count should be 200'
    );
    Assert.areEqual(
      200,
      detail.quote.Total_Discount__c,
      'Header discount should be 200 x 1'
    );
  }

  @isTest
  static void saveLines_LineFromOtherQuote_Throws() {
    List<Quote__c> quotes = getQuotesByName();
    Quote_Line__c foreignLine = QuoteTestDataFactory.buildLine(
      quotes[1].Id,
      getProductId(),
      1,
      10,
      10
    );
    insert foreignLine;
    List<QuoteLineInput> inputs = new List<QuoteLineInput>{
      QuoteTestDataFactory.buildInput(
        foreignLine.Id,
        foreignLine.Product__c,
        5,
        10,
        10
      )
    };

    Test.startTest();
    try {
      new QuoteManager_Service().saveLines(quotes[0].Id, inputs);
      Assert.fail('Expected QuoteManagerException for a foreign line Id');
    } catch (QuoteManager_Service.QuoteManagerException e) {
      Assert.isTrue(
        e.getMessage().contains('do not belong'),
        'Message should explain ownership'
      );
    }
    Test.stopTest();

    Assert.areEqual(
      1,
      [SELECT Quantity__c FROM Quote_Line__c WHERE Id = :foreignLine.Id]
      .Quantity__c,
      'Foreign line must be unchanged'
    );
  }

  @isTest
  static void saveLines_ZeroQuantity_BlockedByValidation() {
    assertSaveBlocked(
      QuoteTestDataFactory.buildInput(null, getProductId(), 0, 10, 10)
    );
  }

  @isTest
  static void saveLines_NegativeListPrice_BlockedByValidation() {
    assertSaveBlocked(
      QuoteTestDataFactory.buildInput(null, getProductId(), 1, -1, 10)
    );
  }

  @isTest
  static void saveLines_NegativeNegotiatedPrice_BlockedByValidation() {
    assertSaveBlocked(
      QuoteTestDataFactory.buildInput(null, getProductId(), 1, 10, -1)
    );
  }

  private static void assertSaveBlocked(QuoteLineInput input) {
    Id quoteId = getQuotesByName()[0].Id;
    Test.startTest();
    try {
      new QuoteManager_Service()
        .saveLines(quoteId, new List<QuoteLineInput>{ input });
      Assert.fail('Expected DmlException from a validation rule');
    } catch (DmlException e) {
      Assert.areEqual(
        StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION,
        e.getDmlType(0),
        'A validation rule should block the save'
      );
    }
    Test.stopTest();
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Quote_Line__c],
      'No line should be saved'
    );
  }

  @isTest
  static void saveLines_NullQuoteId_Throws() {
    assertServiceError(
      'quote Id is required',
      null,
      new List<QuoteLineInput>{ new QuoteLineInput() }
    );
  }

  @isTest
  static void saveLines_EmptyList_Throws() {
    assertServiceError(
      'at least one quote line to save',
      getQuotesByName()[0].Id,
      new List<QuoteLineInput>()
    );
  }

  @isTest
  static void saveLines_NullLineInList_Throws() {
    assertServiceError(
      'was empty',
      getQuotesByName()[0].Id,
      new List<QuoteLineInput>{ null }
    );
  }

  private static void assertServiceError(
    String expectedFragment,
    Id quoteId,
    List<QuoteLineInput> inputs
  ) {
    Test.startTest();
    try {
      new QuoteManager_Service().saveLines(quoteId, inputs);
      Assert.fail('Expected QuoteManagerException');
    } catch (QuoteManager_Service.QuoteManagerException e) {
      Assert.isTrue(
        e.getMessage().contains(expectedFragment),
        'Unexpected message: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @isTest
  static void deleteLines_OwnedLine_RecalculatesHeader() {
    Id quoteId = getQuotesByName()[0].Id;
    Id productId = getProductId();
    Quote_Line__c keep = QuoteTestDataFactory.buildLine(
      quoteId,
      productId,
      1,
      100,
      90
    );
    Quote_Line__c remove = QuoteTestDataFactory.buildLine(
      quoteId,
      productId,
      1,
      50,
      50
    );
    insert new List<Quote_Line__c>{ keep, remove };

    Test.startTest();
    QuoteManager_Service.QuoteDetail detail = new QuoteManager_Service()
      .deleteLines(quoteId, new List<Id>{ remove.Id });
    Test.stopTest();

    Assert.areEqual(1, detail.lines.size(), 'One line should remain');
    Assert.areEqual(
      100,
      detail.quote.Total_List_Price__c,
      'Header list total should drop to 100'
    );
    Assert.areEqual(
      10,
      detail.quote.Total_Discount__c,
      'Header discount should be 100 - 90'
    );
  }

  @isTest
  static void deleteLines_LineFromOtherQuote_Throws() {
    List<Quote__c> quotes = getQuotesByName();
    Quote_Line__c foreignLine = QuoteTestDataFactory.buildLine(
      quotes[1].Id,
      getProductId(),
      1,
      10,
      10
    );
    insert foreignLine;

    Test.startTest();
    try {
      new QuoteManager_Service()
        .deleteLines(quotes[0].Id, new List<Id>{ foreignLine.Id });
      Assert.fail('Expected QuoteManagerException for a foreign line Id');
    } catch (QuoteManager_Service.QuoteManagerException e) {
      Assert.isTrue(
        e.getMessage().contains('do not belong'),
        'Message should explain ownership'
      );
    }
    Test.stopTest();

    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Quote_Line__c],
      'Foreign line must not be deleted'
    );
  }

  @isTest
  static void deleteLines_EmptyList_Throws() {
    Test.startTest();
    try {
      new QuoteManager_Service()
        .deleteLines(getQuotesByName()[0].Id, new List<Id>());
      Assert.fail('Expected QuoteManagerException');
    } catch (QuoteManager_Service.QuoteManagerException e) {
      Assert.isTrue(
        e.getMessage().contains('to delete'),
        'Message should mention delete'
      );
    }
    Test.stopTest();
  }

  @isTest
  static void deleteQuote_WithLines_CascadesToLines() {
    Id quoteId = getQuotesByName()[0].Id;
    insert QuoteTestDataFactory.buildLine(quoteId, getProductId(), 1, 10, 10);

    Test.startTest();
    new QuoteManager_Service().deleteQuote(quoteId);
    Test.stopTest();

    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Quote__c WHERE Id = :quoteId],
      'Quote should be deleted'
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Quote_Line__c],
      'Lines should cascade delete'
    );
  }

  @isTest
  static void deleteQuote_NullId_Throws() {
    Test.startTest();
    try {
      new QuoteManager_Service().deleteQuote(null);
      Assert.fail('Expected QuoteManagerException');
    } catch (QuoteManager_Service.QuoteManagerException e) {
      Assert.isTrue(
        e.getMessage().contains('quote Id is required'),
        'Message should require an Id'
      );
    }
    Test.stopTest();
  }

  @isTest
  static void getQuotes_SeededQuotes_ReturnsAll() {
    Test.startTest();
    List<Quote__c> quotes = new QuoteManager_Service().getQuotes();
    Test.stopTest();

    Assert.areEqual(2, quotes.size(), 'Both seeded quotes should be returned');
  }

  @isTest
  static void getQuoteDetail_DeletedQuote_Throws() {
    Quote__c quote = getQuotesByName()[0];
    delete quote;

    Test.startTest();
    try {
      new QuoteManager_Service().getQuoteDetail(quote.Id);
      Assert.fail('Expected QuoteManagerException');
    } catch (QuoteManager_Service.QuoteManagerException e) {
      Assert.isTrue(
        e.getMessage().contains('not found'),
        'Message should say not found'
      );
    }
    Test.stopTest();
  }

  @isTest
  static void getQuotes_UserWithoutPermissionSet_FailsUnderUserMode() {
    User noAccessUser = QuoteTestDataFactory.createUserWithoutQuoteAccess();
    Boolean failed = false;

    Test.startTest();
    System.runAs(noAccessUser) {
      try {
        new QuoteManager_Service().getQuotes();
      } catch (QueryException e) {
        failed = true;
      }
    }
    Test.stopTest();

    Assert.isTrue(
      failed,
      'USER_MODE should block a user without Quote__c access'
    );
  }
}
