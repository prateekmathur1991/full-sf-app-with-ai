import { LightningElement, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import LightningConfirm from "lightning/confirm";
import getQuotes from "@salesforce/apex/QuoteManagerController.getQuotes";
import getQuoteDetail from "@salesforce/apex/QuoteManagerController.getQuoteDetail";
import saveQuoteLines from "@salesforce/apex/QuoteManagerController.saveQuoteLines";
import deleteQuoteLines from "@salesforce/apex/QuoteManagerController.deleteQuoteLines";
import deleteQuote from "@salesforce/apex/QuoteManagerController.deleteQuote";
import QuoteLineModal from "c/quoteLineModal";
import QuoteEditModal from "c/quoteEditModal";
import {
  computeTotals,
  fromLineRecord,
  reduceError,
  toLineInput,
  totalsFromQuote
} from "c/quoteCalculations";
import CARD_TITLE from "@salesforce/label/c.QuoteManager_CardTitle";
import QUOTE_SELECT_LABEL from "@salesforce/label/c.QuoteManager_QuoteSelectLabel";
import QUOTE_SELECT_PLACEHOLDER from "@salesforce/label/c.QuoteManager_QuoteSelectPlaceholder";
import NEW_QUOTE from "@salesforce/label/c.QuoteManager_NewQuote";
import EDIT_QUOTE from "@salesforce/label/c.QuoteManager_EditQuote";
import DELETE_QUOTE from "@salesforce/label/c.QuoteManager_DeleteQuote";
import ADD_LINE from "@salesforce/label/c.QuoteManager_AddLine";
import NO_QUOTES from "@salesforce/label/c.QuoteManager_NoQuotes";
import NO_QUOTE_SELECTED from "@salesforce/label/c.QuoteManager_NoQuoteSelected";
import LOADING from "@salesforce/label/c.QuoteManager_Loading";
import LINES_TITLE from "@salesforce/label/c.QuoteManager_LinesTitle";
import TOAST_SUCCESS from "@salesforce/label/c.QuoteManager_ToastSuccessTitle";
import TOAST_ERROR from "@salesforce/label/c.QuoteManager_ToastErrorTitle";
import LINES_SAVED from "@salesforce/label/c.QuoteManager_LinesSaved";
import LINE_DELETED from "@salesforce/label/c.QuoteManager_LineDeleted";
import QUOTE_DELETED from "@salesforce/label/c.QuoteManager_QuoteDeleted";
import QUOTE_SAVED from "@salesforce/label/c.QuoteManager_QuoteSaved";
import CONFIRM_TITLE from "@salesforce/label/c.QuoteManager_ConfirmDeleteTitle";
import CONFIRM_LINE from "@salesforce/label/c.QuoteManager_ConfirmDeleteLine";
import CONFIRM_QUOTE from "@salesforce/label/c.QuoteManager_ConfirmDeleteQuote";
import UNKNOWN_ERROR from "@salesforce/label/c.QuoteManager_UnknownError";

/**
 * Home/App page container for managing custom quotes and their lines.
 */
export default class QuoteManager extends LightningElement {
  labels = {
    CARD_TITLE,
    QUOTE_SELECT_LABEL,
    QUOTE_SELECT_PLACEHOLDER,
    NEW_QUOTE,
    EDIT_QUOTE,
    DELETE_QUOTE,
    ADD_LINE,
    NO_QUOTES,
    NO_QUOTE_SELECTED,
    LOADING,
    LINES_TITLE
  };

  quotes = [];
  selectedQuoteId;
  quote;
  lines = [];
  draftLines;
  isLoading = false;
  loadError;
  wiredQuotesResult;

  @wire(getQuotes)
  wiredQuotes(result) {
    this.wiredQuotesResult = result;
    if (result.data) {
      this.quotes = result.data;
      this.loadError = undefined;
    } else if (result.error) {
      this.quotes = [];
      this.loadError = reduceError(result.error, UNKNOWN_ERROR);
    }
  }

  get quoteOptions() {
    return this.quotes.map((q) => ({
      label: q.Account__r ? `${q.Name} (${q.Account__r.Name})` : q.Name,
      value: q.Id
    }));
  }

  get hasQuotes() {
    return this.quotes.length > 0;
  }

  get hasSelection() {
    return Boolean(this.selectedQuoteId && this.quote);
  }

  get noSelection() {
    return !this.hasSelection;
  }

  get totals() {
    return this.draftLines
      ? computeTotals(this.draftLines)
      : totalsFromQuote(this.quote);
  }

  async handleQuoteChange(event) {
    this.selectedQuoteId = event.detail.value;
    await this.loadDetail();
  }

  /** Loads the selected quote header and lines. */
  async loadDetail() {
    if (!this.selectedQuoteId) {
      return;
    }
    this.isLoading = true;
    try {
      this.applyDetail(await getQuoteDetail({ quoteId: this.selectedQuoteId }));
    } catch (error) {
      this.showError(error);
    } finally {
      this.isLoading = false;
    }
  }

  applyDetail(detail) {
    this.quote = detail ? detail.quote : undefined;
    this.lines = detail && detail.lines ? detail.lines.map(fromLineRecord) : [];
    this.draftLines = undefined;
  }

  handleDraftsChange(event) {
    this.draftLines = event.detail.lines;
  }

  handleDraftsCancel() {
    this.draftLines = undefined;
  }

  async handleDraftsSave(event) {
    await this.persistLines(event.detail.lines);
  }

  /** Sends lines to Apex, then refreshes the header, lines and quote list. */
  async persistLines(lines) {
    this.isLoading = true;
    try {
      const detail = await saveQuoteLines({
        quoteId: this.selectedQuoteId,
        lines: lines.map(toLineInput)
      });
      this.applyDetail(detail);
      this.showToast(TOAST_SUCCESS, LINES_SAVED, "success");
      await refreshApex(this.wiredQuotesResult);
    } catch (error) {
      this.showError(error);
    } finally {
      this.isLoading = false;
    }
  }

  async handleAddLine() {
    const result = await QuoteLineModal.open({
      size: "small",
      label: ADD_LINE
    });
    if (result) {
      await this.persistLines([result]);
    }
  }

  async handleRowEdit(event) {
    const result = await QuoteLineModal.open({
      size: "small",
      label: ADD_LINE,
      line: event.detail.line
    });
    if (result) {
      await this.persistLines([result]);
    }
  }

  async handleRowDelete(event) {
    if (!(await this.confirmDelete(CONFIRM_LINE))) {
      return;
    }
    this.isLoading = true;
    try {
      const detail = await deleteQuoteLines({
        quoteId: this.selectedQuoteId,
        lineIds: [event.detail.line.id]
      });
      this.applyDetail(detail);
      this.showToast(TOAST_SUCCESS, LINE_DELETED, "success");
      await refreshApex(this.wiredQuotesResult);
    } catch (error) {
      this.showError(error);
    } finally {
      this.isLoading = false;
    }
  }

  async handleNewQuote() {
    await this.openQuoteModal(undefined);
  }

  async handleEditQuote() {
    await this.openQuoteModal(this.selectedQuoteId);
  }

  /** Opens the quote form modal, then reselects and refreshes on save. */
  async openQuoteModal(recordId) {
    const result = await QuoteEditModal.open({
      size: "medium",
      label: recordId ? EDIT_QUOTE : NEW_QUOTE,
      recordId
    });
    if (!result || !result.recordId) {
      return;
    }
    this.showToast(TOAST_SUCCESS, QUOTE_SAVED, "success");
    await refreshApex(this.wiredQuotesResult);
    this.selectedQuoteId = result.recordId;
    await this.loadDetail();
  }

  async handleDeleteQuote() {
    if (!(await this.confirmDelete(CONFIRM_QUOTE))) {
      return;
    }
    this.isLoading = true;
    try {
      await deleteQuote({ quoteId: this.selectedQuoteId });
      this.selectedQuoteId = undefined;
      this.applyDetail(undefined);
      this.showToast(TOAST_SUCCESS, QUOTE_DELETED, "success");
      await refreshApex(this.wiredQuotesResult);
    } catch (error) {
      this.showError(error);
    } finally {
      this.isLoading = false;
    }
  }

  confirmDelete(message) {
    return LightningConfirm.open({
      message,
      label: CONFIRM_TITLE,
      theme: "warning"
    });
  }

  showError(error) {
    this.showToast(TOAST_ERROR, reduceError(error, UNKNOWN_ERROR), "error");
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
