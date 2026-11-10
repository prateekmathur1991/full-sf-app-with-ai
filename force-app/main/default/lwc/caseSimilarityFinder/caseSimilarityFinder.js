/**
 * @author Salesforce Developer
 * @description Lightning Web Component that lets a user type a case title and description and calls
 *              CaseSimilarityController (backed by an Agentforce agent via the Agent API) to find
 *              similar existing cases. Designed to be placed on a Lightning App Page.
 */
import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import findSimilarCases from '@salesforce/apex/CaseSimilarityController.findSimilarCases';

import labelCardTitle from '@salesforce/label/c.CaseSimilarityFinder_CardTitle';
import labelCaseTitle from '@salesforce/label/c.CaseSimilarityFinder_CaseTitleLabel';
import labelCaseDescription from '@salesforce/label/c.CaseSimilarityFinder_CaseDescriptionLabel';
import labelSearchButton from '@salesforce/label/c.CaseSimilarityFinder_SearchButtonLabel';
import labelLoading from '@salesforce/label/c.CaseSimilarityFinder_LoadingLabel';
import labelNoResults from '@salesforce/label/c.CaseSimilarityFinder_NoResultsMessage';
import labelStatus from '@salesforce/label/c.CaseSimilarityFinder_StatusLabel';
import labelPriority from '@salesforce/label/c.CaseSimilarityFinder_PriorityLabel';
import labelErrorToastTitle from '@salesforce/label/c.CaseSimilarityFinder_ErrorToastTitle';

export default class CaseSimilarityFinder extends LightningElement {
    @api cardTitle = labelCardTitle;

    labelCaseTitle = labelCaseTitle;
    labelCaseDescription = labelCaseDescription;
    labelSearchButton = labelSearchButton;
    labelLoading = labelLoading;
    labelNoResults = labelNoResults;
    labelStatus = labelStatus;
    labelPriority = labelPriority;

    @api caseTitle = '';
    @api caseDescription = '';
    @api similarCases = [];
    @api isLoading = false;
    @api hasSearched = false;

    handleTitleChange(event) {
        this.caseTitle = event.target.value;
    }

    handleDescriptionChange(event) {
        this.caseDescription = event.target.value;
    }

    get isSearchDisabled() {
        return this.isLoading || (!this.caseTitle && !this.caseDescription);
    }

    get hasResults() {
        return this.similarCases && this.similarCases.length > 0;
    }

    handleFindSimilarCases() {
        this.isLoading = true;
        this.hasSearched = false;

        findSimilarCases({ caseTitle: this.caseTitle, caseDescription: this.caseDescription })
            .then((result) => this.handleSearchSuccess(result))
            .catch((error) => this.handleSearchError(error))
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleSearchSuccess(result) {
        this.similarCases = result || [];
        this.hasSearched = true;
    }

    handleSearchError(error) {
        this.similarCases = [];
        this.hasSearched = true;
        this.dispatchEvent(
            new ShowToastEvent({
                title: labelErrorToastTitle,
                message: this.extractErrorMessage(error),
                variant: 'error'
            })
        );
    }

    extractErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return 'An unknown error occurred.';
    }
}
