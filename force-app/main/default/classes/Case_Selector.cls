/**
 * @author Salesforce Developer
 * @description Selector class for Case SObject. Keeps all SOQL for Case records used by the Case
 *              Similarity Finder feature in a single place, separated from business logic.
 */
public inherited sharing class Case_Selector {
    /**
     * @description Queries Case records by CaseNumber and returns them keyed by CaseNumber. Used to
     *              verify and enrich case numbers referenced in an Agentforce agent response with
     *              real, access-checked Case data rather than trusting the agent's text output directly.
     * @param caseNumbers Set of CaseNumber values to look up
     * @return Map of CaseNumber to the matching Case record
     */
    public Map<String, Case> selectByCaseNumbers(Set<String> caseNumbers) {
        Map<String, Case> resultsByCaseNumber = new Map<String, Case>();
        if (caseNumbers == null || caseNumbers.isEmpty()) {
            return resultsByCaseNumber;
        }

        for (Case matchedCase : queryCasesByNumbers(caseNumbers)) {
            resultsByCaseNumber.put(matchedCase.CaseNumber, matchedCase);
        }
        return resultsByCaseNumber;
    }

    /**
     * @description Executes the security-enforced SOQL query for Case records by CaseNumber
     * @param caseNumbers Set of CaseNumber values to query
     * @return List of Case records matching the given case numbers
     */
    private List<Case> queryCasesByNumbers(Set<String> caseNumbers) {
        return [
            SELECT Id, CaseNumber, Subject, Status, Priority
            FROM Case
            WHERE CaseNumber IN :caseNumbers
            WITH SECURITY_ENFORCED
            LIMIT 200
        ];
    }
}
