import { LightningElement, api } from "lwc";
import {
  deriveLine,
  fractionToPercent,
  percentToFraction,
  recalcLine
} from "c/quoteCalculations";
import COL_PRODUCT from "@salesforce/label/c.QuoteManager_ColProduct";
import COL_QUANTITY from "@salesforce/label/c.QuoteManager_ColQuantity";
import COL_LIST from "@salesforce/label/c.QuoteManager_ColListPrice";
import COL_NEGOTIATED from "@salesforce/label/c.QuoteManager_ColNegotiatedPrice";
import COL_TOTAL_LIST from "@salesforce/label/c.QuoteManager_ColLineTotalList";
import COL_TOTAL_NEGOTIATED from "@salesforce/label/c.QuoteManager_ColLineTotalNegotiated";
import COL_DISCOUNT from "@salesforce/label/c.QuoteManager_ColLineDiscount";
import DISCOUNT_PERCENT from "@salesforce/label/c.QuoteManager_DiscountPercent";
import ACTION_EDIT from "@salesforce/label/c.QuoteManager_ActionEdit";
import ACTION_DELETE from "@salesforce/label/c.QuoteManager_ActionDelete";
import LINES_TITLE from "@salesforce/label/c.QuoteManager_LinesTitle";
import NO_LINES from "@salesforce/label/c.QuoteManager_NoLines";

const MONEY = { minimumFractionDigits: 2, maximumFractionDigits: 2 };
const EDITABLE_FIELDS = [
  "quantity",
  "listPrice",
  "negotiatedPrice",
  "totalDiscount",
  "discountPercent"
];

/**
 * Inline-editable datatable of quote lines with linked price recalculation.
 * Events: draftschange { lines }, save { lines }, cancel, rowedit { line }, rowdelete { line }.
 */
export default class QuoteLineTable extends LightningElement {
  labels = { LINES_TITLE, NO_LINES };
  columns = [
    {
      label: COL_PRODUCT,
      fieldName: "productName",
      type: "text",
      wrapText: true
    },
    {
      label: COL_QUANTITY,
      fieldName: "quantity",
      type: "number",
      editable: true
    },
    {
      label: COL_LIST,
      fieldName: "listPrice",
      type: "currency",
      editable: true,
      typeAttributes: MONEY
    },
    {
      label: COL_NEGOTIATED,
      fieldName: "negotiatedPrice",
      type: "currency",
      editable: true,
      typeAttributes: MONEY
    },
    {
      label: COL_DISCOUNT,
      fieldName: "totalDiscount",
      type: "currency",
      editable: true,
      typeAttributes: MONEY
    },
    {
      label: DISCOUNT_PERCENT,
      fieldName: "discountPercentFraction",
      type: "percent",
      editable: true,
      typeAttributes: MONEY
    },
    {
      label: COL_TOTAL_LIST,
      fieldName: "totalListPrice",
      type: "currency",
      typeAttributes: MONEY
    },
    {
      label: COL_TOTAL_NEGOTIATED,
      fieldName: "totalNegotiatedPrice",
      type: "currency",
      typeAttributes: MONEY
    },
    {
      type: "action",
      typeAttributes: {
        rowActions: [
          { label: ACTION_EDIT, name: "edit" },
          { label: ACTION_DELETE, name: "delete" }
        ]
      }
    }
  ];

  _lines = [];
  edited = {};
  draftValues = [];

  /** Saved lines (UI lines from quoteCalculations.fromLineRecord). Setting them clears drafts. */
  @api
  get lines() {
    return this._lines;
  }
  set lines(value) {
    this._lines = Array.isArray(value) ? value : [];
    this.edited = {};
    this.draftValues = [];
  }

  get hasLines() {
    return this._lines.length > 0;
  }

  get currentLines() {
    return this._lines.map((line) => this.edited[line.id] || line);
  }

  get rows() {
    return this.currentLines.map((line) => ({
      ...line,
      discountPercentFraction: percentToFraction(line.discountPercent)
    }));
  }

  /** Clears unsaved edits. */
  @api
  resetDrafts() {
    this.edited = {};
    this.draftValues = [];
  }

  handleCellChange(event) {
    const edited = { ...this.edited };
    event.detail.draftValues.forEach((draft) => {
      const base =
        edited[draft.id] || this._lines.find((l) => l.id === draft.id);
      if (base) {
        edited[draft.id] = this.applyDraft(base, draft);
      }
    });
    this.edited = edited;
    this.draftValues = Object.values(edited).map((line) => this.toDraft(line));
    this.dispatchEvent(
      new CustomEvent("draftschange", { detail: { lines: this.currentLines } })
    );
  }

  applyDraft(base, draft) {
    let line = deriveLine(base);
    Object.keys(draft).forEach((key) => {
      if (key === "discountPercentFraction") {
        line = recalcLine(
          line,
          "discountPercent",
          fractionToPercent(draft[key])
        );
      } else if (EDITABLE_FIELDS.includes(key)) {
        line = recalcLine(line, key, draft[key]);
      }
    });
    return line;
  }

  toDraft(line) {
    return {
      id: line.id,
      quantity: line.quantity,
      listPrice: line.listPrice,
      negotiatedPrice: line.negotiatedPrice,
      totalDiscount: line.totalDiscount,
      discountPercentFraction: percentToFraction(line.discountPercent)
    };
  }

  handleSave() {
    this.dispatchEvent(
      new CustomEvent("save", { detail: { lines: Object.values(this.edited) } })
    );
  }

  handleCancel() {
    this.resetDrafts();
    this.dispatchEvent(new CustomEvent("cancel"));
  }

  handleRowAction(event) {
    const { action, row } = event.detail;
    const line = this.currentLines.find((l) => l.id === row.id);
    const name = action.name === "edit" ? "rowedit" : "rowdelete";
    this.dispatchEvent(new CustomEvent(name, { detail: { line } }));
  }
}
