import { createElement } from "lwc";
import QuoteLineModal from "c/quoteLineModal";

function render(line) {
  const element = createElement("c-quote-line-modal", { is: QuoteLineModal });
  if (line) {
    element.line = line;
  }
  document.body.appendChild(element);
  return element;
}

const input = (element, field) =>
  element.shadowRoot.querySelector(`lightning-input[data-field="${field}"]`);
const allValid = (element) =>
  element.shadowRoot.querySelectorAll("lightning-input").forEach((i) => {
    i.reportValidity = jest.fn(() => true);
  });
const change = (target, value) =>
  target.dispatchEvent(new CustomEvent("change", { detail: { value } }));

function spyOnClose(element) {
  const close = jest.fn();
  element.addEventListener("close", (e) => close(e.detail.result));
  return close;
}

describe("c-quote-line-modal", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders a product picker filtered to active products", () => {
    const element = render();
    const picker = element.shadowRoot.querySelector("lightning-record-picker");
    expect(picker.objectApiName).toBe("Product2");
    expect(picker.filter.criteria[0]).toEqual({
      fieldPath: "IsActive",
      operator: "eq",
      value: true
    });
    expect(
      element.shadowRoot.querySelector("lightning-modal-header").label
    ).toBe("c.QuoteManager_LineModalNewTitle");
    expect(input(element, "quantity").value).toBe(1);
    expect(input(element, "discountPercent").disabled).toBe(true);
  });

  it("links price inputs and closes with the result", async () => {
    const element = render({
      id: "l1",
      productId: "p1",
      quantity: 2,
      listPrice: 100,
      negotiatedPrice: 100
    });
    const close = spyOnClose(element);
    expect(
      element.shadowRoot.querySelector("lightning-modal-header").label
    ).toBe("c.QuoteManager_LineModalEditTitle");
    change(input(element, "discountPercent"), "10");
    await Promise.resolve();
    expect(input(element, "negotiatedPrice").value).toBe(90);
    expect(input(element, "totalDiscount").value).toBe(20);
    change(input(element, "totalDiscount"), "40");
    await Promise.resolve();
    expect(input(element, "negotiatedPrice").value).toBe(80);
    expect(input(element, "discountPercent").value).toBe(20);

    allValid(element);
    element.shadowRoot.querySelector(".save-button").click();
    expect(close).toHaveBeenCalledWith({
      id: "l1",
      productId: "p1",
      quantity: 2,
      listPrice: 100,
      negotiatedPrice: 80
    });
  });

  it("requires a product before saving", async () => {
    const element = render();
    const close = spyOnClose(element);
    element.shadowRoot.querySelector(".save-button").click();
    await Promise.resolve();
    expect(close).not.toHaveBeenCalled();
    expect(element.shadowRoot.querySelector(".product-error").textContent).toBe(
      "c.QuoteManager_ProductRequired"
    );

    element.shadowRoot
      .querySelector("lightning-record-picker")
      .dispatchEvent(new CustomEvent("change", { detail: { recordId: "p9" } }));
    change(input(element, "listPrice"), "25");
    await Promise.resolve();
    expect(element.shadowRoot.querySelector(".product-error")).toBeNull();
    allValid(element);
    element.shadowRoot.querySelector(".save-button").click();
    expect(close).toHaveBeenCalledWith({
      id: null,
      productId: "p9",
      quantity: 1,
      listPrice: 25,
      negotiatedPrice: 0
    });
  });

  it("does not save when an input is invalid", () => {
    const element = render({
      id: "l1",
      productId: "p1",
      quantity: 1,
      listPrice: 1,
      negotiatedPrice: 1
    });
    const close = spyOnClose(element);
    input(element, "quantity").reportValidity = jest.fn(() => false);
    element.shadowRoot.querySelector(".save-button").click();
    expect(close).not.toHaveBeenCalled();
  });

  it("closes with no result on cancel", () => {
    const element = render();
    const close = spyOnClose(element);
    element.shadowRoot.querySelector(".cancel-button").click();
    expect(close).toHaveBeenCalledWith(undefined);
  });
});
