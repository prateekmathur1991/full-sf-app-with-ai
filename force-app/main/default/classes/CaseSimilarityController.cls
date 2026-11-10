/**
 * @author Salesforce Developer
 * @description Apex controller for the Case Similarity Finder Lightning Web Component. Contains NO
 *              business logic - all case similarity logic (input sanitization, Agentforce agent
 *              invocation, response parsing) is delegated to CaseSimilarity_Service.
 */
public with sharing class CaseSimilarityController {
    /**
     * @description Finds existing cases similar to the given candidate case title/description by
     *              invoking the Agentforce agent configured for this org
     * @param caseTitle The candidate case title entered by the user
     * @param caseDescription The candidate case description entered by the user
     * @return List of similar case results to display in the LWC
     */
    @AuraEnabled(cacheable=false)
    public static List<CaseSimilarity_Service.SimilarCaseResult> findSimilarCases(
        String caseTitle,
        String caseDescription
    ) {
        try {
            return new CaseSimilarity_Service().findSimilarCases(caseTitle, caseDescription);
        } catch (CaseSimilarity_Service.CaseSimilarityException e) {
            throw wrapAsAuraException(e.getMessage());
        } catch (Exception e) {
            throw wrapAsAuraException('An unexpected error occurred while finding similar cases: ' + e.getMessage());
        }
    }

    /**
     * @description Builds an AuraHandledException with the message set explicitly, since
     *              AuraHandledException.getMessage() returns null on the client unless setMessage()
     *              is called even though a message was passed to the constructor
     * @param message The error message to surface to the LWC
     * @return An AuraHandledException ready to throw
     */
    private static AuraHandledException wrapAsAuraException(String message) {
        AuraHandledException auraException = new AuraHandledException(message);
        auraException.setMessage(message);
        return auraException;
    }
}
