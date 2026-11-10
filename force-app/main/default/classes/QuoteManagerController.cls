/**
 * @author Salesforce Developer
 * @description Apex controller for the quoteManager LWC. Contains NO business logic; everything is
 *              delegated to QuoteManager_Service. Errors reach the client as AuraHandledException
 *              with the message set explicitly.
 */
public with sharing class QuoteManagerController {
  /**
   * @description Returns the most recently modified quotes
   * @return Recent quotes, newest first
   */
  @AuraEnabled(cacheable=true)
  public static List<Quote__c> getQuotes() {
    try {
      return new QuoteManager_Service().getQuotes();
    } catch (Exception e) {
      throw toAuraException(e);
    }
  }

  /**
   * @description Returns a quote header and its lines
   * @param quoteId Id of the quote
   * @return The quote detail
   */
  @AuraEnabled
  public static QuoteManager_Service.QuoteDetail getQuoteDetail(Id quoteId) {
    try {
      return new QuoteManager_Service().getQuoteDetail(quoteId);
    } catch (Exception e) {
      throw toAuraException(e);
    }
  }

  /**
   * @description Inserts and updates lines on a quote
   * @param quoteId Id of the quote
   * @param lines Line values; a null id means a new line
   * @return The refreshed quote detail
   */
  @AuraEnabled
  public static QuoteManager_Service.QuoteDetail saveQuoteLines(
    Id quoteId,
    List<QuoteLineInput> lines
  ) {
    try {
      return new QuoteManager_Service().saveLines(quoteId, lines);
    } catch (Exception e) {
      throw toAuraException(e);
    }
  }

  /**
   * @description Deletes lines from a quote
   * @param quoteId Id of the quote
   * @param lineIds Ids of the lines to delete
   * @return The refreshed quote detail
   */
  @AuraEnabled
  public static QuoteManager_Service.QuoteDetail deleteQuoteLines(
    Id quoteId,
    List<Id> lineIds
  ) {
    try {
      return new QuoteManager_Service().deleteLines(quoteId, lineIds);
    } catch (Exception e) {
      throw toAuraException(e);
    }
  }

  /**
   * @description Deletes a quote and, through the master-detail cascade, its lines
   * @param quoteId Id of the quote
   */
  @AuraEnabled
  public static void deleteQuote(Id quoteId) {
    try {
      new QuoteManager_Service().deleteQuote(quoteId);
    } catch (Exception e) {
      throw toAuraException(e);
    }
  }

  /**
   * @description Converts an exception into a client-safe message. Business errors pass through,
   *              DML errors surface the first validation message, anything else is prefixed.
   * @param e The caught exception
   * @return An AuraHandledException ready to throw
   */
  private static AuraHandledException toAuraException(Exception e) {
    if (e instanceof QuoteManager_Service.QuoteManagerException) {
      return wrapAsAuraException(e.getMessage());
    }
    if (e instanceof DmlException) {
      return wrapAsAuraException(((DmlException) e).getDmlMessage(0));
    }
    return wrapAsAuraException(
      'An unexpected error occurred while managing quotes: ' + e.getMessage()
    );
  }

  /**
   * @description Builds an AuraHandledException with the message set explicitly, since
   *              AuraHandledException.getMessage() returns null on the client unless setMessage()
   *              is called even though a message was passed to the constructor
   * @param message The error message to surface to the LWC
   * @return An AuraHandledException ready to throw
   */
  private static AuraHandledException wrapAsAuraException(String message) {
    AuraHandledException auraException = new AuraHandledException(message);
    auraException.setMessage(message);
    return auraException;
  }
}
