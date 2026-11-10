/**
 * @author Salesforce Developer
 * @description Business logic for the Quote Manager. All SOQL lives in Quote_Selector and
 *              Quote_Line_Selector, and all DML runs in AccessLevel.USER_MODE so CRUD and FLS are
 *              enforced for the running user.
 *
 *              Input sanitization: every input is an Id or a Decimal, and every query uses bind
 *              variables, so String.escapeSingleQuotes and escapeHtml4 have nothing to sanitize.
 *              Id parameters are type-checked by the platform during deserialization.
 */
public with sharing class QuoteManager_Service {
  private static final Integer RECENT_QUOTE_LIMIT = 50;

  /**
   * @description Thrown for business-rule violations (missing input, foreign line Ids, missing quote)
   */
  public class QuoteManagerException extends Exception {
  }

  /**
   * @description A quote header with its lines, returned to the LWC
   */
  public class QuoteDetail {
    @AuraEnabled
    public Quote__c quote;
    @AuraEnabled
    public List<Quote_Line__c> lines;
  }

  /**
   * @description Returns the 50 most recently modified quotes
   * @return Recent quotes, newest first
   */
  public List<Quote__c> getQuotes() {
    return new Quote_Selector().selectRecent(RECENT_QUOTE_LIMIT);
  }

  /**
   * @description Returns a quote header (with roll-ups) and its lines
   * @param quoteId Id of the quote
   * @return The quote detail
   * @throws QuoteManagerException when quoteId is null or the quote isn't found
   */
  public QuoteDetail getQuoteDetail(Id quoteId) {
    requireQuoteId(quoteId);
    Quote__c quote = new Quote_Selector().selectById(quoteId);
    if (quote == null) {
      throw new QuoteManagerException(
        'The quote was not found or you do not have access to it.'
      );
    }
    QuoteDetail detail = new QuoteDetail();
    detail.quote = quote;
    detail.lines = new Quote_Line_Selector().selectByQuoteId(quoteId);
    return detail;
  }

  /**
   * @description Inserts new lines and updates existing ones on a quote
   * @param quoteId Id of the quote the lines belong to
   * @param lines Line values from the LWC; a null id means a new line
   * @return The refreshed quote detail with recalculated roll-ups
   * @throws QuoteManagerException when input is missing or a line belongs to another quote
   * @throws DmlException when a validation rule or required field blocks the save
   */
  public QuoteDetail saveLines(Id quoteId, List<QuoteLineInput> lines) {
    requireQuoteId(quoteId);
    if (lines == null || lines.isEmpty()) {
      throw new QuoteManagerException(
        'Provide at least one quote line to save.'
      );
    }
    verifyLinesBelongToQuote(quoteId, collectExistingIds(lines));
    List<Quote_Line__c> records = new List<Quote_Line__c>();
    for (QuoteLineInput input : lines) {
      records.add(toRecord(quoteId, input));
    }
    Database.upsert(records, true, AccessLevel.USER_MODE);
    return getQuoteDetail(quoteId);
  }

  /**
   * @description Deletes lines from a quote
   * @param quoteId Id of the quote the lines belong to
   * @param lineIds Ids of the lines to delete
   * @return The refreshed quote detail with recalculated roll-ups
   * @throws QuoteManagerException when input is missing or a line belongs to another quote
   */
  public QuoteDetail deleteLines(Id quoteId, List<Id> lineIds) {
    requireQuoteId(quoteId);
    if (lineIds == null || lineIds.isEmpty()) {
      throw new QuoteManagerException(
        'Provide at least one quote line to delete.'
      );
    }
    List<Quote_Line__c> records = verifyLinesBelongToQuote(
      quoteId,
      new Set<Id>(lineIds)
    );
    Database.delete(records, true, AccessLevel.USER_MODE);
    return getQuoteDetail(quoteId);
  }

  /**
   * @description Deletes a quote; its lines are removed by the master-detail cascade
   * @param quoteId Id of the quote to delete
   * @throws QuoteManagerException when quoteId is null
   */
  public void deleteQuote(Id quoteId) {
    requireQuoteId(quoteId);
    Database.delete(new Quote__c(Id = quoteId), true, AccessLevel.USER_MODE);
  }

  /**
   * @description Throws when the quote Id is missing
   * @param quoteId The quote Id to check
   */
  private void requireQuoteId(Id quoteId) {
    if (quoteId == null) {
      throw new QuoteManagerException('A quote Id is required.');
    }
  }

  /**
   * @description Collects the Ids of lines that already exist (non-null id)
   * @param lines The line inputs
   * @return Set of existing line Ids
   */
  private Set<Id> collectExistingIds(List<QuoteLineInput> lines) {
    Set<Id> lineIds = new Set<Id>();
    for (QuoteLineInput input : lines) {
      if (input?.id != null) {
        lineIds.add(input.id);
      }
    }
    return lineIds;
  }

  /**
   * @description Confirms every line Id exists, is accessible, and belongs to the quote
   * @param quoteId The quote the lines must belong to
   * @param lineIds The line Ids to check
   * @return The matching line records
   * @throws QuoteManagerException when any Id is missing or belongs to another quote
   */
  private List<Quote_Line__c> verifyLinesBelongToQuote(
    Id quoteId,
    Set<Id> lineIds
  ) {
    if (lineIds.isEmpty()) {
      return new List<Quote_Line__c>();
    }
    List<Quote_Line__c> records = new Quote_Line_Selector()
      .selectByIds(lineIds);
    Boolean allOwned = records.size() == lineIds.size();
    for (Quote_Line__c line : records) {
      allOwned = allOwned && line.Quote__c == quoteId;
    }
    if (!allOwned) {
      throw new QuoteManagerException(
        'One or more quote lines do not belong to this quote.'
      );
    }
    return records;
  }

  /**
   * @description Maps a line input to a Quote_Line__c. Quote__c is only set on new lines,
   *              because the master-detail field can't be reparented on update.
   * @param quoteId The parent quote Id
   * @param input The line input
   * @return The record to upsert
   * @throws QuoteManagerException when the input is null
   */
  private Quote_Line__c toRecord(Id quoteId, QuoteLineInput input) {
    if (input == null) {
      throw new QuoteManagerException('A quote line in the request was empty.');
    }
    Quote_Line__c record = new Quote_Line__c(Id = input.id);
    if (input.id == null) {
      record.Quote__c = quoteId;
    }
    record.Product__c = input.productId;
    record.Quantity__c = input.quantity;
    record.List_Price__c = input.listPrice;
    record.Negotiated_Price__c = input.negotiatedPrice;
    return record;
  }
}
