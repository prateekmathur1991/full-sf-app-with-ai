/**
 * @author Salesforce Developer
 * @description Tests for QuoteManagerController: delegation and error wrapping
 */
@isTest
private class QuoteManagerController_Test {
  @TestSetup
  static void setupTestData() {
    QuoteTestDataFactory.assignQuoteManagerPermissionSet();
    QuoteTestDataFactory.createQuotes(1, true);
    QuoteTestDataFactory.createProducts(1, true);
  }

  private static Id getQuoteId() {
    return [SELECT Id FROM Quote__c LIMIT 1].Id;
  }

  private static Id getProductId() {
    return [SELECT Id FROM Product2 LIMIT 1].Id;
  }

  @isTest
  static void fullLifecycle_ValidInput_Delegates() {
    Id quoteId = getQuoteId();
    List<QuoteLineInput> inputs = new List<QuoteLineInput>{
      QuoteTestDataFactory.buildInput(null, getProductId(), 2, 10, 8)
    };

    Test.startTest();
    Assert.areEqual(
      1,
      QuoteManagerController.getQuotes().size(),
      'getQuotes should delegate'
    );
    QuoteManager_Service.QuoteDetail saved = QuoteManagerController.saveQuoteLines(
      quoteId,
      inputs
    );
    QuoteManager_Service.QuoteDetail loaded = QuoteManagerController.getQuoteDetail(
      quoteId
    );
    QuoteManager_Service.QuoteDetail afterDelete = QuoteManagerController.deleteQuoteLines(
      quoteId,
      new List<Id>{ saved.lines[0].Id }
    );
    QuoteManagerController.deleteQuote(quoteId);
    Test.stopTest();

    Assert.areEqual(
      1,
      saved.lines.size(),
      'saveQuoteLines should return the saved line'
    );
    Assert.areEqual(
      4,
      loaded.quote.Total_Discount__c,
      'getQuoteDetail should return roll-ups'
    );
    Assert.areEqual(
      0,
      afterDelete.lines.size(),
      'deleteQuoteLines should remove the line'
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Quote__c],
      'deleteQuote should delete the quote'
    );
  }

  @isTest
  static void getQuoteDetail_NullId_ThrowsAuraWithServiceMessage() {
    Test.startTest();
    try {
      QuoteManagerController.getQuoteDetail(null);
      Assert.fail('Expected AuraHandledException');
    } catch (AuraHandledException e) {
      Assert.areEqual(
        'A quote Id is required.',
        e.getMessage(),
        'Service message should pass through'
      );
    }
    Test.stopTest();
  }

  @isTest
  static void saveQuoteLines_InvalidQuantity_ThrowsAuraWithValidationMessage() {
    List<QuoteLineInput> inputs = new List<QuoteLineInput>{
      QuoteTestDataFactory.buildInput(null, getProductId(), 0, 10, 10)
    };

    Test.startTest();
    try {
      QuoteManagerController.saveQuoteLines(getQuoteId(), inputs);
      Assert.fail('Expected AuraHandledException');
    } catch (AuraHandledException e) {
      Assert.isFalse(
        String.isBlank(e.getMessage()),
        'Validation message should be surfaced'
      );
      Assert.isFalse(
        e.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'),
        'Message should be readable'
      );
    }
    Test.stopTest();
  }

  @isTest
  static void deleteQuoteLines_EmptyList_ThrowsAura() {
    Test.startTest();
    try {
      QuoteManagerController.deleteQuoteLines(getQuoteId(), new List<Id>());
      Assert.fail('Expected AuraHandledException');
    } catch (AuraHandledException e) {
      Assert.isTrue(
        e.getMessage().contains('to delete'),
        'Service message should pass through'
      );
    }
    Test.stopTest();
  }

  @isTest
  static void deleteQuote_NullId_ThrowsAura() {
    Test.startTest();
    try {
      QuoteManagerController.deleteQuote(null);
      Assert.fail('Expected AuraHandledException');
    } catch (AuraHandledException e) {
      Assert.isTrue(
        e.getMessage().contains('required'),
        'Service message should pass through'
      );
    }
    Test.stopTest();
  }

  @isTest
  static void getQuotes_UserWithoutAccess_ThrowsAuraUnexpected() {
    User noAccessUser = QuoteTestDataFactory.createUserWithoutQuoteAccess();
    String message;

    Test.startTest();
    System.runAs(noAccessUser) {
      try {
        QuoteManagerController.getQuotes();
      } catch (AuraHandledException e) {
        message = e.getMessage();
      }
    }
    Test.stopTest();

    Assert.isTrue(
      message.startsWith('An unexpected error occurred'),
      'Generic errors should be prefixed'
    );
  }
}
