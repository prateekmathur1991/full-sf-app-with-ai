import { createElement } from "lwc";
import QuoteLineTable from "c/quoteLineTable";
import { deriveLine } from "c/quoteCalculations";

const LINES = [
  deriveLine({
    id: "l1",
    productId: "p1",
    productName: "Widget",
    quantity: 2,
    listPrice: 100,
    negotiatedPrice: 80
  }),
  deriveLine({
    id: "l2",
    productId: "p2",
    productName: "Gadget",
    quantity: 1,
    listPrice: 50,
    negotiatedPrice: 50
  })
];

function render(lines = LINES) {
  const element = createElement("c-quote-line-table", { is: QuoteLineTable });
  element.lines = lines;
  document.body.appendChild(element);
  return element;
}

const table = (element) =>
  element.shadowRoot.querySelector("lightning-datatable");

describe("c-quote-line-table", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders editable price columns and read-only product and totals", () => {
    const element = render();
    const columns = table(element).columns;
    const editable = columns.filter((c) => c.editable).map((c) => c.fieldName);
    expect(editable).toEqual([
      "quantity",
      "listPrice",
      "negotiatedPrice",
      "totalDiscount",
      "discountPercentFraction"
    ]);
    expect(
      columns.find((c) => c.fieldName === "productName").editable
    ).toBeUndefined();
    expect(
      columns.find((c) => c.fieldName === "discountPercentFraction").type
    ).toBe("percent");
    expect(table(element).data[0].discountPercentFraction).toBe(0.2);
    expect(table(element).keyField).toBe("id");
  });

  it("shows the empty state with no lines", () => {
    const element = render([]);
    expect(table(element)).toBeNull();
    expect(element.shadowRoot.querySelector(".empty-lines").textContent).toBe(
      "c.QuoteManager_NoLines"
    );
  });

  it("recalculates a line on cell change and dispatches draftschange", async () => {
    const element = render();
    const handler = jest.fn();
    element.addEventListener("draftschange", handler);
    table(element).dispatchEvent(
      new CustomEvent("cellchange", {
        detail: { draftValues: [{ id: "l1", discountPercentFraction: 0.25 }] }
      })
    );
    await Promise.resolve();
    const lines = handler.mock.calls[0][0].detail.lines;
    expect(lines[0].negotiatedPrice).toBe(75);
    expect(lines[0].totalDiscount).toBe(50);
    expect(lines[1]).toEqual(LINES[1]);
    const draft = table(element).draftValues[0];
    expect(draft).toEqual(
      expect.objectContaining({
        id: "l1",
        negotiatedPrice: 75,
        totalDiscount: 50
      })
    );
  });

  it("applies successive edits and sends edited lines on save", async () => {
    const element = render();
    const save = jest.fn();
    element.addEventListener("save", save);
    table(element).dispatchEvent(
      new CustomEvent("cellchange", {
        detail: { draftValues: [{ id: "l2", quantity: 4 }] }
      })
    );
    table(element).dispatchEvent(
      new CustomEvent("cellchange", {
        detail: { draftValues: [{ id: "l2", totalDiscount: 40 }] }
      })
    );
    table(element).dispatchEvent(
      new CustomEvent("save", { detail: { draftValues: [] } })
    );
    const lines = save.mock.calls[0][0].detail.lines;
    expect(lines).toHaveLength(1);
    expect(lines[0]).toEqual(
      expect.objectContaining({ id: "l2", quantity: 4, negotiatedPrice: 40 })
    );
  });

  it("clears drafts on cancel and when new lines arrive", async () => {
    const element = render();
    const cancel = jest.fn();
    element.addEventListener("cancel", cancel);
    table(element).dispatchEvent(
      new CustomEvent("cellchange", {
        detail: { draftValues: [{ id: "l1", negotiatedPrice: 90 }] }
      })
    );
    await Promise.resolve();
    expect(table(element).draftValues).toHaveLength(1);
    table(element).dispatchEvent(new CustomEvent("cancel"));
    await Promise.resolve();
    expect(cancel).toHaveBeenCalled();
    expect(table(element).draftValues).toHaveLength(0);

    table(element).dispatchEvent(
      new CustomEvent("cellchange", {
        detail: { draftValues: [{ id: "l1", negotiatedPrice: 90 }] }
      })
    );
    element.lines = [...LINES];
    await Promise.resolve();
    expect(table(element).draftValues).toHaveLength(0);
  });

  it("dispatches rowedit and rowdelete for row actions", () => {
    const element = render();
    const edit = jest.fn();
    const del = jest.fn();
    element.addEventListener("rowedit", edit);
    element.addEventListener("rowdelete", del);
    table(element).dispatchEvent(
      new CustomEvent("rowaction", {
        detail: { action: { name: "edit" }, row: { id: "l1" } }
      })
    );
    table(element).dispatchEvent(
      new CustomEvent("rowaction", {
        detail: { action: { name: "delete" }, row: { id: "l2" } }
      })
    );
    expect(edit.mock.calls[0][0].detail.line.id).toBe("l1");
    expect(del.mock.calls[0][0].detail.line.id).toBe("l2");
  });
});
