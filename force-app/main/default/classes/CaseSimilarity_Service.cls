/**
 * @author Salesforce Developer
 * @description Service class containing all business logic for the Case Similarity Finder feature.
 *              Sanitizes user-entered case title/description, calls the Agentforce agent configured
 *              in Agentforce_Agent_Config__mdt via CaseSimilarity_AgentApi_Service, interprets the
 *              agent's JSON reply, and enriches it with real, access-checked Case records so the UI
 *              never renders unverified data returned directly by the agent.
 */
public with sharing class CaseSimilarity_Service {
    private static final Integer MAX_RESULTS = 10;
    private static final Integer MAX_INPUT_LENGTH = 2000;
    private static final String CONFIG_NAME = 'Case_Similarity_Agent';

    /**
     * @description Custom exception for Case Similarity Service errors
     */
    public class CaseSimilarityException extends Exception {
    }

    /**
     * @description Finds cases similar to a candidate case title/description using the configured
     *              Agentforce agent
     * @param caseTitle The candidate case title/subject entered by the user
     * @param caseDescription The candidate case description entered by the user
     * @return List of SimilarCaseResult wrappers for display in the LWC
     * @throws CaseSimilarityException if input is invalid or the agent/callout is not configured
     */
    public List<SimilarCaseResult> findSimilarCases(String caseTitle, String caseDescription) {
        String sanitizedTitle = sanitizeInput(caseTitle);
        String sanitizedDescription = sanitizeInput(caseDescription);
        validateInputs(sanitizedTitle, sanitizedDescription);

        String agentReplyText = callAgent(sanitizedTitle, sanitizedDescription);
        List<Object> parsedCases = parseAgentResponse(agentReplyText);
        return buildResults(parsedCases);
    }

    private void validateInputs(String title, String description) {
        if (String.isBlank(title) && String.isBlank(description)) {
            throw new CaseSimilarityException('Please enter a case title or description to search for similar cases.');
        }
    }

    /**
     * @description Sanitizes free-text user input by escaping HTML and single quotes and truncating
     *              to a safe length before it is sent to the agent
     * @param rawValue The raw value entered by the user
     * @return The sanitized value, or an empty string if blank
     */
    private String sanitizeInput(String rawValue) {
        if (String.isBlank(rawValue)) {
            return '';
        }
        String escaped = String.escapeSingleQuotes(rawValue.escapeHtml4());
        return escaped.abbreviate(MAX_INPUT_LENGTH);
    }

    private String callAgent(String title, String description) {
        Agentforce_Agent_Config__mdt config = getAgentConfig();
        CaseSimilarity_AgentApi_Service agentApi = new CaseSimilarity_AgentApi_Service();
        String sessionId = agentApi.startSession(config.Agent_Id__c);
        try {
            return agentApi.sendMessage(sessionId, buildPrompt(title, description), 1);
        } finally {
            endSessionSafely(agentApi, sessionId);
        }
    }

    private void endSessionSafely(CaseSimilarity_AgentApi_Service agentApi, String sessionId) {
        try {
            agentApi.endSession(sessionId);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Unable to end Agentforce session cleanly: ' + e.getMessage());
        }
    }

    private Agentforce_Agent_Config__mdt getAgentConfig() {
        Agentforce_Agent_Config__mdt config = Agentforce_Agent_Config__mdt.getInstance(CONFIG_NAME);
        if (config == null || String.isBlank(config.Agent_Id__c)) {
            throw new CaseSimilarityException('The Agentforce agent has not been configured yet. Contact your administrator.');
        }
        return config;
    }

    private String buildPrompt(String title, String description) {
        return 'Find up to ' +
            MAX_RESULTS +
            ' existing support cases that are most similar to a new case with Title: "' +
            title +
            '" and Description: "' +
            description +
            '". Respond with ONLY a JSON array (no other text, no markdown) where each element has ' +
            'exactly these keys: caseNumber, subject, similarityReason.';
    }

    private List<Object> parseAgentResponse(String replyText) {
        String jsonArray = extractJsonArray(replyText);
        if (String.isBlank(jsonArray)) {
            return new List<Object>();
        }
        try {
            return (List<Object>) JSON.deserializeUntyped(jsonArray);
        } catch (Exception e) {
            throw new CaseSimilarityException('Unable to interpret the response from the Agentforce agent.');
        }
    }

    private String extractJsonArray(String text) {
        if (String.isBlank(text)) {
            return null;
        }
        Integer startIndex = text.indexOf('[');
        Integer endIndex = text.lastIndexOf(']');
        if (startIndex < 0 || endIndex < 0 || endIndex < startIndex) {
            return null;
        }
        return text.substring(startIndex, endIndex + 1);
    }

    private List<SimilarCaseResult> buildResults(List<Object> parsedCases) {
        Set<String> caseNumbers = collectCaseNumbers(parsedCases);
        Map<String, Case> caseByNumber = new Case_Selector().selectByCaseNumbers(caseNumbers);
        return mapToResults(parsedCases, caseByNumber);
    }

    private Set<String> collectCaseNumbers(List<Object> parsedCases) {
        Set<String> caseNumbers = new Set<String>();
        for (Object item : parsedCases) {
            addCaseNumber((Map<String, Object>) item, caseNumbers);
        }
        return caseNumbers;
    }

    private void addCaseNumber(Map<String, Object> caseMap, Set<String> caseNumbers) {
        Object caseNumber = caseMap.get('caseNumber');
        if (caseNumber != null) {
            caseNumbers.add(String.valueOf(caseNumber));
        }
    }

    private List<SimilarCaseResult> mapToResults(List<Object> parsedCases, Map<String, Case> caseByNumber) {
        List<SimilarCaseResult> results = new List<SimilarCaseResult>();
        for (Object item : parsedCases) {
            SimilarCaseResult result = buildSingleResult((Map<String, Object>) item, caseByNumber);
            if (result != null) {
                results.add(result);
            }
        }
        return results;
    }

    private SimilarCaseResult buildSingleResult(Map<String, Object> caseMap, Map<String, Case> caseByNumber) {
        Object rawCaseNumber = caseMap.get('caseNumber');
        if (rawCaseNumber == null) {
            return null;
        }
        Case matchedCase = caseByNumber.get(String.valueOf(rawCaseNumber));
        if (matchedCase == null) {
            return null;
        }
        return new SimilarCaseResult(matchedCase, String.valueOf(caseMap.get('similarityReason')));
    }

    /**
     * @description Wrapper returned to the LWC representing a single similar case match
     */
    public class SimilarCaseResult {
        @AuraEnabled
        public Id caseId;
        @AuraEnabled
        public String caseNumber;
        @AuraEnabled
        public String subject;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String priority;
        @AuraEnabled
        public String similarityReason;

        public SimilarCaseResult(Case matchedCase, String reason) {
            this.caseId = matchedCase.Id;
            this.caseNumber = matchedCase.CaseNumber;
            this.subject = matchedCase.Subject;
            this.status = matchedCase.Status;
            this.priority = matchedCase.Priority;
            this.similarityReason = reason;
        }
    }
}
