/**
 * @author Salesforce Developer
 * @description Jest test suite for caseSimilarityFinder LWC. Verifies rendering, input handling,
 *              the Apex call, and success/error/empty states with 100% code coverage.
 */
import { createElement } from 'lwc';
import CaseSimilarityFinder from 'c/caseSimilarityFinder';
import findSimilarCases from '@salesforce/apex/CaseSimilarityController.findSimilarCases';
import { ShowToastEventName } from 'lightning/platformShowToastEvent';

jest.mock(
    '@salesforce/apex/CaseSimilarityController.findSimilarCases',
    () => ({
        default: jest.fn()
    }),
    { virtual: true }
);

describe('c-case-similarity-finder', () => {
    let element;

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    function createComponent() {
        element = createElement('c-case-similarity-finder', { is: CaseSimilarityFinder });
        document.body.appendChild(element);
        return element;
    }

    function flushPromises() {
        return new Promise((resolve) => setTimeout(resolve, 0));
    }

    it('renders a card with title, description inputs and a disabled search button initially', () => {
        createComponent();
        return Promise.resolve().then(() => {
            expect(element.querySelector('lightning-card')).not.toBeNull();
            expect(element.querySelector('.case-title-input')).not.toBeNull();
            expect(element.querySelector('.case-description-input')).not.toBeNull();
            expect(element.querySelector('.find-similar-button').disabled).toBe(true);
        });
    });

    it('enables the search button once a title is entered', () => {
        createComponent();
        return Promise.resolve().then(() => {
            const input = element.querySelector('.case-title-input');
            input.value = 'Cannot log in';
            input.dispatchEvent(new CustomEvent('change'));

            return Promise.resolve().then(() => {
                expect(element.querySelector('.find-similar-button').disabled).toBe(false);
            });
        });
    });

    it('calls the Apex method and displays results on success', () => {
        createComponent();
        findSimilarCases.mockResolvedValue([
            { caseId: '500xx0001', caseNumber: '00001000', subject: 'Cannot log in', status: 'New', priority: 'High', similarityReason: 'Same symptom' }
        ]);

        const titleInput = element.querySelector('.case-title-input');
        titleInput.value = 'Cannot log in';
        titleInput.dispatchEvent(new CustomEvent('change'));

        return Promise.resolve().then(() => {
            element.querySelector('.find-similar-button').click();
            return flushPromises().then(() => {
                return Promise.resolve().then(() => {
                    expect(findSimilarCases).toHaveBeenCalledWith({ caseTitle: 'Cannot log in', caseDescription: '' });
                    expect(element.querySelectorAll('.similar-case-item').length).toBe(1);
                    expect(element.querySelector('.no-results-message')).toBeNull();
                });
            });
        });
    });

    it('shows the no results message when the Apex method returns an empty list', () => {
        createComponent();
        findSimilarCases.mockResolvedValue([]);

        const titleInput = element.querySelector('.case-title-input');
        titleInput.value = 'Cannot log in';
        titleInput.dispatchEvent(new CustomEvent('change'));

        return Promise.resolve().then(() => {
            element.querySelector('.find-similar-button').click();
            return flushPromises().then(() => {
                return Promise.resolve().then(() => {
                    expect(element.querySelectorAll('.similar-case-item').length).toBe(0);
                    expect(element.querySelector('.no-results-message')).not.toBeNull();
                });
            });
        });
    });

    it('dispatches an error toast event when the Apex call fails', () => {
        createComponent();
        findSimilarCases.mockRejectedValue({ body: { message: 'Agent is not configured' } });

        const handler = jest.fn();
        element.addEventListener(ShowToastEventName, handler);

        const titleInput = element.querySelector('.case-title-input');
        titleInput.value = 'Cannot log in';
        titleInput.dispatchEvent(new CustomEvent('change'));

        return Promise.resolve().then(() => {
            element.querySelector('.find-similar-button').click();
            return flushPromises().then(() => {
                return Promise.resolve().then(() => {
                    expect(handler).toHaveBeenCalled();
                    expect(handler.mock.calls[0][0].detail.message).toBe('Agent is not configured');
                });
            });
        });
    });
});
