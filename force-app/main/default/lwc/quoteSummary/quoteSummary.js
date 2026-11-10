import { LightningElement, api } from "lwc";
import { percentToFraction, toNumber } from "c/quoteCalculations";
import SUMMARY_TITLE from "@salesforce/label/c.QuoteManager_SummaryTitle";
import TOTAL_LIST from "@salesforce/label/c.QuoteManager_TotalListPrice";
import TOTAL_NEGOTIATED from "@salesforce/label/c.QuoteManager_TotalNegotiatedPrice";
import TOTAL_DISCOUNT from "@salesforce/label/c.QuoteManager_TotalDiscount";
import DISCOUNT_PERCENT from "@salesforce/label/c.QuoteManager_DiscountPercent";
import LINE_COUNT from "@salesforce/label/c.QuoteManager_LineCount";

/**
 * Header tiles showing quote aggregates. Read-only; totals come from the parent.
 */
export default class QuoteSummary extends LightningElement {
  /** Totals object from quoteCalculations.computeTotals or totalsFromQuote. */
  @api totals;

  labels = { SUMMARY_TITLE, LINE_COUNT };

  get tiles() {
    const t = this.totals || {};
    return [
      {
        key: "list",
        label: TOTAL_LIST,
        value: toNumber(t.totalListPrice),
        isCurrency: true
      },
      {
        key: "negotiated",
        label: TOTAL_NEGOTIATED,
        value: toNumber(t.totalNegotiatedPrice),
        isCurrency: true
      },
      {
        key: "discount",
        label: TOTAL_DISCOUNT,
        value: toNumber(t.totalDiscount),
        isCurrency: true
      },
      {
        key: "percent",
        label: DISCOUNT_PERCENT,
        value: percentToFraction(t.discountPercent),
        isCurrency: false
      }
    ];
  }

  get lineCount() {
    return toNumber((this.totals || {}).lineCount);
  }
}
