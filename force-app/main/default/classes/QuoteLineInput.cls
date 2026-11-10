/**
 * @author Salesforce Developer
 * @description DTO the quoteManager LWC sends when saving quote lines. It's an explicit whitelist:
 *              the client can only set these five values, never Quote__c or any other field.
 *              A null id means a new line.
 */
public class QuoteLineInput {
  @AuraEnabled
  public Id id { get; set; }
  @AuraEnabled
  public Id productId { get; set; }
  @AuraEnabled
  public Decimal quantity { get; set; }
  @AuraEnabled
  public Decimal listPrice { get; set; }
  @AuraEnabled
  public Decimal negotiatedPrice { get; set; }
}
