import { api } from "lwc";
import LightningModal from "lightning/modal";
import { reduceError } from "c/quoteCalculations";
import NEW_TITLE from "@salesforce/label/c.QuoteManager_QuoteModalNewTitle";
import EDIT_TITLE from "@salesforce/label/c.QuoteManager_QuoteModalEditTitle";
import SAVE from "@salesforce/label/c.QuoteManager_Save";
import CANCEL from "@salesforce/label/c.QuoteManager_Cancel";
import UNKNOWN_ERROR from "@salesforce/label/c.QuoteManager_UnknownError";

/**
 * Modal wrapping lightning-record-edit-form for creating or editing a Quote__c.
 * Closes with { recordId } on success or undefined on cancel.
 */
export default class QuoteEditModal extends LightningModal {
  /** Quote__c Id to edit; omit to create. */
  @api recordId;

  labels = { SAVE, CANCEL };
  fields = [
    "Name",
    "Account__c",
    "Opportunity__c",
    "Status__c",
    "Expiration_Date__c"
  ];
  errorMessage = "";
  isSaving = false;

  get title() {
    return this.recordId ? EDIT_TITLE : NEW_TITLE;
  }

  handleSave() {
    this.errorMessage = "";
    this.isSaving = true;
    this.template.querySelector("lightning-record-edit-form").submit();
  }

  handleSuccess(event) {
    this.isSaving = false;
    this.close({ recordId: event.detail.id });
  }

  handleError(event) {
    this.isSaving = false;
    this.errorMessage =
      (event.detail && event.detail.message) ||
      reduceError(event.detail, UNKNOWN_ERROR);
  }

  handleCancel() {
    this.close();
  }
}
