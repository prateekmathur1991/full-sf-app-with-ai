import { createElement } from "lwc";
import QuoteManager from "c/quoteManager";
import LightningConfirm from "lightning/confirm";
import QuoteLineModal from "c/quoteLineModal";
import QuoteEditModal from "c/quoteEditModal";
import { refreshApex } from "@salesforce/apex";
import getQuotes from "@salesforce/apex/QuoteManagerController.getQuotes";
import getQuoteDetail from "@salesforce/apex/QuoteManagerController.getQuoteDetail";
import saveQuoteLines from "@salesforce/apex/QuoteManagerController.saveQuoteLines";
import deleteQuoteLines from "@salesforce/apex/QuoteManagerController.deleteQuoteLines";
import deleteQuote from "@salesforce/apex/QuoteManagerController.deleteQuote";

jest.mock(
  "@salesforce/apex/QuoteManagerController.getQuotes",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/QuoteManagerController.getQuoteDetail",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/QuoteManagerController.saveQuoteLines",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/QuoteManagerController.deleteQuoteLines",
  () => ({ default: jest.fn() }),
  {
    virtual: true
  }
);
jest.mock(
  "@salesforce/apex/QuoteManagerController.deleteQuote",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex",
  () => ({ refreshApex: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);

const QUOTES = [
  { Id: "q1", Name: "Q-1", Status__c: "Draft", Account__r: { Name: "Acme" } },
  { Id: "q2", Name: "Q-2", Status__c: "Draft" }
];
const LINE = {
  Id: "l1",
  Name: "QL-00001",
  Product__c: "p1",
  Product__r: { Name: "Widget" },
  Quantity__c: 2,
  List_Price__c: 100,
  Negotiated_Price__c: 80
};
const QUOTE = {
  Id: "q1",
  Name: "Q-1",
  Total_List_Price__c: 200,
  Total_Negotiated_Price__c: 160,
  Total_Discount__c: 40,
  Discount_Percent__c: 20,
  Line_Count__c: 1
};
const DETAIL = { quote: QUOTE, lines: [LINE] };

// eslint-disable-next-line @lwc/lwc/no-async-operation
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));
const $ = (element, selector) => element.shadowRoot.querySelector(selector);

async function renderWithSelection() {
  const element = createElement("c-quote-manager", { is: QuoteManager });
  document.body.appendChild(element);
  getQuotes.emit(QUOTES);
  await flush();
  getQuoteDetail.mockResolvedValue(DETAIL);
  $(element, ".quote-picker").dispatchEvent(
    new CustomEvent("change", { detail: { value: "q1" } })
  );
  await flush();
  return element;
}

function captureToasts(element) {
  const toasts = jest.fn();
  element.addEventListener("lightning__showtoast", (e) => toasts(e.detail));
  return toasts;
}

describe("c-quote-manager", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("shows the empty state when there are no quotes", async () => {
    const element = createElement("c-quote-manager", { is: QuoteManager });
    document.body.appendChild(element);
    getQuotes.emit([]);
    await flush();
    expect($(element, ".no-quotes").textContent).toBe(
      "c.QuoteManager_NoQuotes"
    );
    expect($(element, ".quote-picker")).toBeNull();
  });

  it("shows an error when quotes fail to load", async () => {
    const element = createElement("c-quote-manager", { is: QuoteManager });
    document.body.appendChild(element);
    getQuotes.error({ message: "No access" });
    await flush();
    expect($(element, ".load-error").textContent).toBe("No access");
  });

  it("loads quotes into the picker and asks for a selection", async () => {
    const element = createElement("c-quote-manager", { is: QuoteManager });
    document.body.appendChild(element);
    getQuotes.emit(QUOTES);
    await flush();
    expect($(element, ".quote-picker").options).toEqual([
      { label: "Q-1 (Acme)", value: "q1" },
      { label: "Q-2", value: "q2" }
    ]);
    expect($(element, ".no-selection")).not.toBeNull();
    expect($(element, "c-quote-summary")).toBeNull();
  });

  it("loads the selected quote detail into the summary and table", async () => {
    const element = await renderWithSelection();
    expect(getQuoteDetail).toHaveBeenCalledWith({ quoteId: "q1" });
    expect($(element, "c-quote-summary").totals).toEqual(
      expect.objectContaining({
        totalListPrice: 200,
        discountPercent: 20,
        lineCount: 1
      })
    );
    const lines = $(element, "c-quote-line-table").lines;
    expect(lines[0]).toEqual(
      expect.objectContaining({
        id: "l1",
        productName: "Widget",
        negotiatedPrice: 80
      })
    );
  });

  it("updates the header live from drafts and reverts on cancel", async () => {
    const element = await renderWithSelection();
    const table = $(element, "c-quote-line-table");
    const draft = {
      ...table.lines[0],
      negotiatedPrice: 50,
      totalListPrice: 200,
      totalNegotiatedPrice: 100
    };
    table.dispatchEvent(
      new CustomEvent("draftschange", { detail: { lines: [draft] } })
    );
    await flush();
    expect($(element, "c-quote-summary").totals.totalNegotiatedPrice).toBe(100);
    expect($(element, "c-quote-summary").totals.discountPercent).toBe(50);
    table.dispatchEvent(new CustomEvent("cancel"));
    await flush();
    expect($(element, "c-quote-summary").totals.totalNegotiatedPrice).toBe(160);
  });

  it("saves drafts with recalculated values and refreshes", async () => {
    const element = await renderWithSelection();
    const toasts = captureToasts(element);
    saveQuoteLines.mockResolvedValue({
      quote: { ...QUOTE, Total_Negotiated_Price__c: 150 },
      lines: [LINE]
    });
    const edited = {
      ...$(element, "c-quote-line-table").lines[0],
      negotiatedPrice: 75
    };
    $(element, "c-quote-line-table").dispatchEvent(
      new CustomEvent("save", { detail: { lines: [edited] } })
    );
    await flush();
    expect(saveQuoteLines).toHaveBeenCalledWith({
      quoteId: "q1",
      lines: [
        {
          id: "l1",
          productId: "p1",
          quantity: 2,
          listPrice: 100,
          negotiatedPrice: 75
        }
      ]
    });
    expect(refreshApex).toHaveBeenCalled();
    expect($(element, "c-quote-summary").totals.totalNegotiatedPrice).toBe(150);
    expect(toasts).toHaveBeenCalledWith(
      expect.objectContaining({ variant: "success" })
    );
  });

  it("shows an error toast when save fails", async () => {
    const element = await renderWithSelection();
    const toasts = captureToasts(element);
    saveQuoteLines.mockRejectedValue({
      body: { message: "Quantity must be greater than 0" }
    });
    $(element, "c-quote-line-table").dispatchEvent(
      new CustomEvent("save", {
        detail: { lines: [{ id: "l1", productId: "p1", quantity: 0 }] }
      })
    );
    await flush();
    expect(toasts).toHaveBeenCalledWith(
      expect.objectContaining({
        variant: "error",
        message: "Quantity must be greater than 0"
      })
    );
  });

  it("adds a line through the modal", async () => {
    const element = await renderWithSelection();
    const result = {
      id: null,
      productId: "p2",
      quantity: 1,
      listPrice: 10,
      negotiatedPrice: 9
    };
    jest.spyOn(QuoteLineModal, "open").mockResolvedValue(result);
    saveQuoteLines.mockResolvedValue(DETAIL);
    $(element, ".add-line").click();
    await flush();
    expect(saveQuoteLines).toHaveBeenCalledWith({
      quoteId: "q1",
      lines: [result]
    });
  });

  it("edits a line through the modal and skips save on cancel", async () => {
    const element = await renderWithSelection();
    const open = jest
      .spyOn(QuoteLineModal, "open")
      .mockResolvedValue(undefined);
    const line = $(element, "c-quote-line-table").lines[0];
    $(element, "c-quote-line-table").dispatchEvent(
      new CustomEvent("rowedit", { detail: { line } })
    );
    await flush();
    expect(open).toHaveBeenCalledWith(expect.objectContaining({ line }));
    expect(saveQuoteLines).not.toHaveBeenCalled();
  });

  it("deletes a line after confirmation", async () => {
    const element = await renderWithSelection();
    LightningConfirm.open = jest.fn().mockResolvedValue(true);
    deleteQuoteLines.mockResolvedValue({ quote: QUOTE, lines: [] });
    $(element, "c-quote-line-table").dispatchEvent(
      new CustomEvent("rowdelete", { detail: { line: { id: "l1" } } })
    );
    await flush();
    expect(LightningConfirm.open).toHaveBeenCalled();
    expect(deleteQuoteLines).toHaveBeenCalledWith({
      quoteId: "q1",
      lineIds: ["l1"]
    });
    expect($(element, "c-quote-line-table").lines).toEqual([]);
  });

  it("does not delete when the confirmation is declined", async () => {
    const element = await renderWithSelection();
    LightningConfirm.open = jest.fn().mockResolvedValue(false);
    $(element, ".delete-quote").click();
    await flush();
    expect(deleteQuote).not.toHaveBeenCalled();
  });

  it("deletes the quote after confirmation", async () => {
    const element = await renderWithSelection();
    LightningConfirm.open = jest.fn().mockResolvedValue(true);
    deleteQuote.mockResolvedValue(undefined);
    $(element, ".delete-quote").click();
    await flush();
    expect(deleteQuote).toHaveBeenCalledWith({ quoteId: "q1" });
    expect(refreshApex).toHaveBeenCalled();
    expect($(element, "c-quote-summary")).toBeNull();
  });

  it("creates a quote through the modal and selects it", async () => {
    const element = createElement("c-quote-manager", { is: QuoteManager });
    document.body.appendChild(element);
    getQuotes.emit(QUOTES);
    await flush();
    jest.spyOn(QuoteEditModal, "open").mockResolvedValue({ recordId: "q2" });
    getQuoteDetail.mockResolvedValue({
      quote: { Id: "q2", Name: "Q-2" },
      lines: []
    });
    $(element, ".new-quote").click();
    await flush();
    expect(QuoteEditModal.open).toHaveBeenCalledWith(
      expect.objectContaining({ recordId: undefined })
    );
    expect(refreshApex).toHaveBeenCalled();
    expect(getQuoteDetail).toHaveBeenCalledWith({ quoteId: "q2" });
    expect($(element, ".quote-picker").value).toBe("q2");
  });

  it("opens the edit modal for the selected quote", async () => {
    const element = await renderWithSelection();
    jest.spyOn(QuoteEditModal, "open").mockResolvedValue(undefined);
    $(element, ".edit-quote").click();
    await flush();
    expect(QuoteEditModal.open).toHaveBeenCalledWith(
      expect.objectContaining({ recordId: "q1" })
    );
  });
});
