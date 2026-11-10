import { createElement } from "lwc";
import QuoteSummary from "c/quoteSummary";

function render(totals) {
  const element = createElement("c-quote-summary", { is: QuoteSummary });
  element.totals = totals;
  document.body.appendChild(element);
  return element;
}

const tileValue = (element, id) =>
  element.shadowRoot.querySelector(
    `[data-id="${id}"] lightning-formatted-number`
  );

describe("c-quote-summary", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders formatted totals", () => {
    const element = render({
      totalListPrice: 400,
      totalNegotiatedPrice: 340,
      totalDiscount: 60,
      discountPercent: 15,
      lineCount: 3
    });
    expect(tileValue(element, "list").value).toBe(400);
    expect(tileValue(element, "list").formatStyle).toBe("currency");
    expect(tileValue(element, "negotiated").value).toBe(340);
    expect(tileValue(element, "discount").value).toBe(60);
    expect(tileValue(element, "percent").value).toBe(0.15);
    expect(tileValue(element, "percent").formatStyle).toBe("percent");
    expect(tileValue(element, "count").value).toBe(3);
    expect(element.shadowRoot.querySelector("h2").textContent).toBe(
      "c.QuoteManager_SummaryTitle"
    );
  });

  it("shows zeros when totals are missing", () => {
    const element = render(undefined);
    ["list", "negotiated", "discount", "percent", "count"].forEach((id) => {
      expect(tileValue(element, id).value).toBe(0);
    });
  });

  it("shows a negative discount for markups", () => {
    const element = render({
      totalListPrice: 100,
      totalNegotiatedPrice: 120,
      totalDiscount: -20,
      discountPercent: -20
    });
    expect(tileValue(element, "discount").value).toBe(-20);
    expect(tileValue(element, "percent").value).toBe(-0.2);
  });
});
