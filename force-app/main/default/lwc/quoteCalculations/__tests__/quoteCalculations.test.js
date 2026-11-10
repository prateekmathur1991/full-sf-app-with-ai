import {
  computeTotals,
  deriveLine,
  discountPercent,
  fractionToPercent,
  fromLineRecord,
  percentToFraction,
  recalcLine,
  reduceError,
  round2,
  toLineInput,
  toNumber,
  totalsFromQuote
} from "c/quoteCalculations";

const base = () =>
  deriveLine({
    id: "a",
    productId: "p",
    quantity: 2,
    listPrice: 100,
    negotiatedPrice: 80
  });

describe("c-quote-calculations", () => {
  it("derives totals, discount and percent", () => {
    const line = base();
    expect(line.totalListPrice).toBe(200);
    expect(line.totalNegotiatedPrice).toBe(160);
    expect(line.totalDiscount).toBe(40);
    expect(line.discountPercent).toBe(20);
  });

  it("stores an edited negotiated price directly", () => {
    const line = recalcLine(base(), "negotiatedPrice", 90);
    expect(line.negotiatedPrice).toBe(90);
    expect(line.totalDiscount).toBe(20);
    expect(line.discountPercent).toBe(10);
  });

  it("converts a line discount to a unit negotiated price", () => {
    const line = recalcLine(base(), "totalDiscount", 50);
    expect(line.negotiatedPrice).toBe(75);
    expect(line.totalDiscount).toBe(50);
    expect(line.discountPercent).toBe(25);
  });

  it("converts a discount percent to a unit negotiated price", () => {
    const line = recalcLine(base(), "discountPercent", 15);
    expect(line.negotiatedPrice).toBe(85);
    expect(line.totalDiscount).toBe(30);
  });

  it("keeps the unit negotiated price when quantity changes", () => {
    const line = recalcLine(base(), "quantity", 5);
    expect(line.negotiatedPrice).toBe(80);
    expect(line.totalListPrice).toBe(500);
    expect(line.totalDiscount).toBe(100);
    expect(line.discountPercent).toBe(20);
  });

  it("keeps the unit negotiated price when list price changes", () => {
    const line = recalcLine(base(), "listPrice", 160);
    expect(line.negotiatedPrice).toBe(80);
    expect(line.discountPercent).toBe(50);
  });

  it("returns 0 percent and ignores percent edits when list price is 0", () => {
    const zero = recalcLine(base(), "listPrice", 0);
    expect(zero.discountPercent).toBe(0);
    const edited = recalcLine(zero, "discountPercent", 30);
    expect(edited.negotiatedPrice).toBe(80);
    expect(edited.discountPercent).toBe(0);
  });

  it("ignores a line discount edit when quantity is 0", () => {
    const zeroQty = recalcLine(base(), "quantity", 0);
    expect(recalcLine(zeroQty, "totalDiscount", 10).negotiatedPrice).toBe(80);
  });

  it("allows markups with a negative discount", () => {
    const line = recalcLine(base(), "negotiatedPrice", 120);
    expect(line.totalDiscount).toBe(-40);
    expect(line.discountPercent).toBe(-20);
    expect(recalcLine(base(), "discountPercent", -10).negotiatedPrice).toBe(
      110
    );
  });

  it("rounds to 2 decimals", () => {
    expect(round2(1.005)).toBe(1.01);
    expect(round2(-1.005)).toBe(-1.01);
    expect(round2(undefined)).toBe(0);
    const line = deriveLine({
      quantity: 3,
      listPrice: 9.99,
      negotiatedPrice: 3.333
    });
    expect(line.negotiatedPrice).toBe(3.33);
    expect(line.totalNegotiatedPrice).toBe(9.99);
    expect(
      recalcLine(
        deriveLine({ quantity: 3, listPrice: 10, negotiatedPrice: 10 }),
        "totalDiscount",
        10
      ).negotiatedPrice
    ).toBe(6.67);
  });

  it("computes header totals", () => {
    const lines = [base(), recalcLine(base(), "negotiatedPrice", 120)];
    expect(computeTotals(lines)).toEqual({
      totalListPrice: 400,
      totalNegotiatedPrice: 400,
      totalDiscount: 0,
      discountPercent: 0,
      lineCount: 2
    });
    expect(computeTotals(undefined).lineCount).toBe(0);
    expect(computeTotals([base()]).discountPercent).toBe(20);
  });

  it("converts percent and fractions", () => {
    expect(percentToFraction(15)).toBe(0.15);
    expect(fractionToPercent(0.155)).toBe(15.5);
    expect(discountPercent(0, 10)).toBe(0);
    expect(toNumber("abc")).toBe(0);
    expect(toNumber("")).toBe(0);
  });

  it("maps records and inputs", () => {
    const line = fromLineRecord({
      Id: "l1",
      Name: "QL-1",
      Product__c: "p1",
      Product__r: { Name: "Widget" },
      Quantity__c: 1,
      List_Price__c: 10,
      Negotiated_Price__c: 8
    });
    expect(line.productName).toBe("Widget");
    expect(fromLineRecord({ Id: "x" }).productName).toBe("");
    expect(toLineInput(line)).toEqual({
      id: "l1",
      productId: "p1",
      quantity: 1,
      listPrice: 10,
      negotiatedPrice: 8
    });
    expect(toLineInput({ productId: "p" }).id).toBeNull();
    expect(
      totalsFromQuote({
        Total_List_Price__c: 5,
        Discount_Percent__c: 15,
        Line_Count__c: 2
      })
    ).toEqual({
      totalListPrice: 5,
      totalNegotiatedPrice: 0,
      totalDiscount: 0,
      discountPercent: 15,
      lineCount: 2
    });
    expect(totalsFromQuote(undefined).lineCount).toBe(0);
  });

  it("reduces errors to a message", () => {
    expect(reduceError({ body: { message: "Boom" } }, "x")).toBe("Boom");
    expect(
      reduceError({ body: [{ message: "A" }, { message: "B" }] }, "x")
    ).toBe("A, B");
    expect(reduceError(new Error("JS"), "x")).toBe("JS");
    expect(reduceError(undefined, "fallback")).toBe("fallback");
  });
});
