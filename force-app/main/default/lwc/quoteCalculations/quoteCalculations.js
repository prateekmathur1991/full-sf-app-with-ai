/**
 * Pure pricing helpers shared by the Quote Manager components.
 * Percent values are in "percent units" (15 means 15%), matching the
 * values returned by Apex for Discount_Percent__c.
 */

/**
 * Converts a value to a finite number, defaulting to 0.
 * @param {*} value raw value
 * @returns {number} finite number
 */
export function toNumber(value) {
  const num = Number(value);
  return value === null ||
    value === undefined ||
    value === "" ||
    !Number.isFinite(num)
    ? 0
    : num;
}

/**
 * Rounds to 2 decimal places, avoiding binary float drift (1.005 -> 1.01).
 * @param {number} value value to round
 * @returns {number} rounded value
 */
export function round2(value) {
  const num = toNumber(value);
  return Math.round((num + Math.sign(num) * Number.EPSILON) * 100) / 100;
}

/**
 * Discount percent in percent units, 0 when the list amount is 0.
 * @param {number} listAmount list amount
 * @param {number} negotiatedAmount negotiated amount
 * @returns {number} percent rounded to 2 decimals
 */
export function discountPercent(listAmount, negotiatedAmount) {
  const list = toNumber(listAmount);
  return list === 0
    ? 0
    : round2(((list - toNumber(negotiatedAmount)) / list) * 100);
}

/**
 * Converts percent units (15) to a fraction (0.15) for lightning-datatable.
 * @param {number} percent percent units
 * @returns {number} fraction
 */
export function percentToFraction(percent) {
  return toNumber(percent) / 100;
}

/**
 * Converts a fraction (0.15) to percent units (15).
 * @param {number} fraction fraction
 * @returns {number} percent units rounded to 2 decimals
 */
export function fractionToPercent(fraction) {
  return round2(toNumber(fraction) * 100);
}

/**
 * Builds a full line (with derived totals) from quantity and unit prices.
 * @param {object} line line with quantity, listPrice and negotiatedPrice
 * @returns {object} new line with totalListPrice, totalNegotiatedPrice, totalDiscount, discountPercent
 */
export function deriveLine(line) {
  const quantity = toNumber(line.quantity);
  const listPrice = round2(line.listPrice);
  const negotiatedPrice = round2(line.negotiatedPrice);
  const totalListPrice = round2(quantity * listPrice);
  const totalNegotiatedPrice = round2(quantity * negotiatedPrice);
  return {
    ...line,
    quantity,
    listPrice,
    negotiatedPrice,
    totalListPrice,
    totalNegotiatedPrice,
    totalDiscount: round2(totalListPrice - totalNegotiatedPrice),
    discountPercent: discountPercent(listPrice, negotiatedPrice)
  };
}

/**
 * Works out the unit negotiated price implied by an edit.
 * @param {object} line current line
 * @param {string} field edited field
 * @param {number} value edited value
 * @returns {number} unit negotiated price
 */
function negotiatedPriceFor(line, field, value) {
  const listPrice = toNumber(line.listPrice);
  const quantity = toNumber(line.quantity);
  if (field === "negotiatedPrice") {
    return value;
  }
  if (field === "totalDiscount") {
    return quantity === 0
      ? toNumber(line.negotiatedPrice)
      : listPrice - value / quantity;
  }
  if (field === "discountPercent") {
    return listPrice === 0
      ? toNumber(line.negotiatedPrice)
      : listPrice * (1 - value / 100);
  }
  return toNumber(line.negotiatedPrice);
}

/**
 * Applies one edited field to a line and recalculates the linked values.
 * Negotiated price, line discount and discount % are linked; quantity and
 * list price changes keep the unit negotiated price. Discount % edits are
 * ignored when list price is 0.
 * @param {object} line current line
 * @param {string} editedField quantity | listPrice | negotiatedPrice | totalDiscount | discountPercent
 * @param {*} value new value
 * @returns {object} new recalculated line
 */
export function recalcLine(line, editedField, value) {
  const num = toNumber(value);
  const next = { ...line };
  if (editedField === "quantity" || editedField === "listPrice") {
    next[editedField] = num;
  } else {
    next.negotiatedPrice = negotiatedPriceFor(line, editedField, num);
  }
  return deriveLine(next);
}

/**
 * Aggregates header totals from lines.
 * @param {object[]} lines derived lines
 * @returns {object} totalListPrice, totalNegotiatedPrice, totalDiscount, discountPercent, lineCount
 */
export function computeTotals(lines) {
  const list = Array.isArray(lines) ? lines : [];
  const totalListPrice = round2(
    list.reduce((sum, l) => sum + toNumber(l.totalListPrice), 0)
  );
  const totalNegotiatedPrice = round2(
    list.reduce((sum, l) => sum + toNumber(l.totalNegotiatedPrice), 0)
  );
  return {
    totalListPrice,
    totalNegotiatedPrice,
    totalDiscount: round2(totalListPrice - totalNegotiatedPrice),
    discountPercent: discountPercent(totalListPrice, totalNegotiatedPrice),
    lineCount: list.length
  };
}

/**
 * Maps a Quote_Line__c record from Apex to a UI line.
 * @param {object} record Quote_Line__c record
 * @returns {object} derived UI line
 */
export function fromLineRecord(record) {
  return deriveLine({
    id: record.Id,
    name: record.Name,
    productId: record.Product__c,
    productName: record.Product__r ? record.Product__r.Name : "",
    quantity: record.Quantity__c,
    listPrice: record.List_Price__c,
    negotiatedPrice: record.Negotiated_Price__c
  });
}

/**
 * Maps a Quote__c record's roll-ups to header totals.
 * @param {object} record Quote__c record
 * @returns {object} totals
 */
export function totalsFromQuote(record) {
  const q = record || {};
  return {
    totalListPrice: toNumber(q.Total_List_Price__c),
    totalNegotiatedPrice: toNumber(q.Total_Negotiated_Price__c),
    totalDiscount: toNumber(q.Total_Discount__c),
    discountPercent: toNumber(q.Discount_Percent__c),
    lineCount: toNumber(q.Line_Count__c)
  };
}

/**
 * Maps a UI line to the QuoteLineInput DTO sent to Apex.
 * @param {object} line UI line
 * @returns {object} { id, productId, quantity, listPrice, negotiatedPrice }
 */
export function toLineInput(line) {
  return {
    id: line.id || null,
    productId: line.productId,
    quantity: toNumber(line.quantity),
    listPrice: round2(line.listPrice),
    negotiatedPrice: round2(line.negotiatedPrice)
  };
}

/**
 * Extracts a readable message from an Apex/LDS error.
 * @param {*} error error object
 * @param {string} fallback fallback message
 * @returns {string} message
 */
export function reduceError(error, fallback) {
  if (error && error.body) {
    if (Array.isArray(error.body)) {
      return error.body.map((e) => e.message).join(", ") || fallback;
    }
    if (error.body.message) {
      return error.body.message;
    }
  }
  return (error && error.message) || fallback;
}
