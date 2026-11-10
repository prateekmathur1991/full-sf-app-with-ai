import { api } from "lwc";
import LightningModal from "lightning/modal";
import { deriveLine, recalcLine } from "c/quoteCalculations";
import NEW_TITLE from "@salesforce/label/c.QuoteManager_LineModalNewTitle";
import EDIT_TITLE from "@salesforce/label/c.QuoteManager_LineModalEditTitle";
import PRODUCT_LABEL from "@salesforce/label/c.QuoteManager_ProductLabel";
import PRODUCT_PLACEHOLDER from "@salesforce/label/c.QuoteManager_ProductPlaceholder";
import PRODUCT_REQUIRED from "@salesforce/label/c.QuoteManager_ProductRequired";
import QUANTITY from "@salesforce/label/c.QuoteManager_ColQuantity";
import LIST_PRICE from "@salesforce/label/c.QuoteManager_ColListPrice";
import NEGOTIATED_PRICE from "@salesforce/label/c.QuoteManager_ColNegotiatedPrice";
import LINE_DISCOUNT from "@salesforce/label/c.QuoteManager_ColLineDiscount";
import DISCOUNT_PERCENT from "@salesforce/label/c.QuoteManager_DiscountPercent";
import PERCENT_HELP from "@salesforce/label/c.QuoteManager_DiscountPercentHelp";
import SAVE from "@salesforce/label/c.QuoteManager_Save";
import CANCEL from "@salesforce/label/c.QuoteManager_Cancel";

const EMPTY_LINE = {
  id: null,
  productId: null,
  quantity: 1,
  listPrice: 0,
  negotiatedPrice: 0
};

/**
 * Modal for adding or editing a single quote line.
 * Closes with { id, productId, quantity, listPrice, negotiatedPrice } or undefined on cancel.
 */
export default class QuoteLineModal extends LightningModal {
  /** Existing UI line to edit; omit for a new line. */
  @api line;

  labels = {
    PRODUCT_LABEL,
    PRODUCT_PLACEHOLDER,
    QUANTITY,
    LIST_PRICE,
    NEGOTIATED_PRICE,
    LINE_DISCOUNT,
    DISCOUNT_PERCENT,
    PERCENT_HELP,
    SAVE,
    CANCEL
  };
  productFilter = {
    criteria: [{ fieldPath: "IsActive", operator: "eq", value: true }]
  };
  draft = deriveLine(EMPTY_LINE);
  productError = "";

  connectedCallback() {
    this.draft = deriveLine({ ...EMPTY_LINE, ...(this.line || {}) });
  }

  get title() {
    return this.draft.id ? EDIT_TITLE : NEW_TITLE;
  }

  get percentDisabled() {
    return this.draft.listPrice === 0;
  }

  get percentHelp() {
    return this.percentDisabled ? PERCENT_HELP : "";
  }

  handleProductChange(event) {
    this.draft = { ...this.draft, productId: event.detail.recordId || null };
    this.productError = "";
  }

  handleFieldChange(event) {
    const field = event.target.dataset.field;
    this.draft = recalcLine(this.draft, field, event.detail.value);
  }

  handleCancel() {
    this.close();
  }

  handleSave() {
    const inputs = [...this.template.querySelectorAll("lightning-input")];
    const inputsValid = inputs.reduce(
      (ok, input) => input.reportValidity() && ok,
      true
    );
    if (!this.draft.productId) {
      this.productError = PRODUCT_REQUIRED;
    }
    if (!inputsValid || !this.draft.productId) {
      return;
    }
    const { id, productId, quantity, listPrice, negotiatedPrice } = this.draft;
    this.close({ id, productId, quantity, listPrice, negotiatedPrice });
  }
}
