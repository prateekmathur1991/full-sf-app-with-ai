import { createElement } from "lwc";
import QuoteEditModal from "c/quoteEditModal";

function render(recordId) {
  const element = createElement("c-quote-edit-modal", { is: QuoteEditModal });
  if (recordId) {
    element.recordId = recordId;
  }
  document.body.appendChild(element);
  return element;
}

const form = (element) =>
  element.shadowRoot.querySelector("lightning-record-edit-form");

function spyOnClose(element) {
  const close = jest.fn();
  element.addEventListener("close", (e) => close(e.detail.result));
  return close;
}

describe("c-quote-edit-modal", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders the Quote__c fields for a new quote", () => {
    const element = render();
    expect(form(element).objectApiName).toBe("Quote__c");
    expect(form(element).recordId).toBeUndefined();
    const fields = [
      ...element.shadowRoot.querySelectorAll("lightning-input-field")
    ].map((f) => f.fieldName);
    expect(fields).toEqual([
      "Name",
      "Account__c",
      "Opportunity__c",
      "Status__c",
      "Expiration_Date__c"
    ]);
    expect(
      element.shadowRoot.querySelector("lightning-modal-header").label
    ).toBe("c.QuoteManager_QuoteModalNewTitle");
  });

  it("submits the form and closes with the record id on success", async () => {
    const element = render("a00000000000001");
    const close = spyOnClose(element);
    expect(
      element.shadowRoot.querySelector("lightning-modal-header").label
    ).toBe("c.QuoteManager_QuoteModalEditTitle");
    form(element).submit = jest.fn();
    element.shadowRoot.querySelector(".save-button").click();
    expect(form(element).submit).toHaveBeenCalled();
    form(element).dispatchEvent(
      new CustomEvent("success", { detail: { id: "a00000000000001" } })
    );
    expect(close).toHaveBeenCalledWith({ recordId: "a00000000000001" });
  });

  it("shows the error and stays open on failure", async () => {
    const element = render();
    const close = spyOnClose(element);
    form(element).dispatchEvent(
      new CustomEvent("error", { detail: { message: "Name is required" } })
    );
    await Promise.resolve();
    expect(element.shadowRoot.querySelector(".error-message").textContent).toBe(
      "Name is required"
    );
    expect(close).not.toHaveBeenCalled();
  });

  it("closes with no result on cancel", () => {
    const element = render();
    const close = spyOnClose(element);
    element.shadowRoot.querySelector(".cancel-button").click();
    expect(close).toHaveBeenCalledWith(undefined);
  });
});
