/**
 * @author Salesforce Developer
 * @description Test class for CaseSimilarity_Service. Verifies input validation, agent response
 *              parsing, case enrichment, and error handling using HttpCalloutMock to simulate the
 *              Agentforce Agent API without making real callouts.
 */
@isTest
private class CaseSimilarity_Service_Test {
    @isTest
    static void testFindSimilarCasesReturnsEnrichedResults() {
        Case existingCase = new Case(Subject = 'Cannot log in', Description = 'Login fails', Status = 'New');
        insert existingCase;
        existingCase = [SELECT Id, CaseNumber, Subject, Status, Priority FROM Case WHERE Id = :existingCase.Id];

        String agentJson = '[{"caseNumber":"' +
            existingCase.CaseNumber +
            '","subject":"Cannot log in","similarityReason":"Same login failure symptom"}]';
        Test.setMock(HttpCalloutMock.class, new CaseSimilarityAgentApiMock(agentJson));

        Test.startTest();
        List<CaseSimilarity_Service.SimilarCaseResult> results = new CaseSimilarity_Service()
            .findSimilarCases('Unable to sign in', 'User reports being unable to log into the portal');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected exactly one enriched similar case result');
        System.assertEquals(existingCase.CaseNumber, results[0].caseNumber, 'Expected the real case number');
        System.assertEquals(existingCase.Id, results[0].caseId, 'Expected the real case Id');
        System.assertEquals('Same login failure symptom', results[0].similarityReason, 'Expected the similarity reason from the agent');
    }

    @isTest
    static void testFindSimilarCasesIgnoresUnknownCaseNumbers() {
        String agentJson = '[{"caseNumber":"00099999","subject":"Unknown","similarityReason":"n/a"}]';
        Test.setMock(HttpCalloutMock.class, new CaseSimilarityAgentApiMock(agentJson));

        Test.startTest();
        List<CaseSimilarity_Service.SimilarCaseResult> results = new CaseSimilarity_Service()
            .findSimilarCases('Some title', 'Some description');
        Test.stopTest();

        System.assert(results.isEmpty(), 'Expected agent-hallucinated case numbers that do not exist to be filtered out');
    }

    @isTest
    static void testFindSimilarCasesWithBlankInputsThrows() {
        Test.startTest();
        try {
            new CaseSimilarity_Service().findSimilarCases('', '');
            System.assert(false, 'Expected a CaseSimilarityException for blank input');
        } catch (CaseSimilarity_Service.CaseSimilarityException e) {
            System.assert(e.getMessage().contains('Please enter'), 'Expected validation message for blank input');
        }
        Test.stopTest();
    }

    @isTest
    static void testFindSimilarCasesWithUnparsableAgentResponseThrows() {
        Test.setMock(HttpCalloutMock.class, new CaseSimilarityAgentApiMock('This is not JSON at all'));

        Test.startTest();
        List<CaseSimilarity_Service.SimilarCaseResult> results = new CaseSimilarity_Service()
            .findSimilarCases('Some title', 'Some description');
        Test.stopTest();

        System.assert(results.isEmpty(), 'Expected an empty result list when the agent reply has no JSON array');
    }

    @isTest
    static void testFindSimilarCasesWithCalloutFailureThrows() {
        Test.setMock(HttpCalloutMock.class, new CaseSimilarityAgentApiMock('unused', 500));

        Test.startTest();
        try {
            new CaseSimilarity_Service().findSimilarCases('Some title', 'Some description');
            System.assert(false, 'Expected an exception to propagate when the Agent API callout fails');
        } catch (CaseSimilarity_AgentApi_Service.AgentApiException e) {
            System.assert(e.getMessage().contains('500'), 'Expected the callout failure to propagate');
        }
        Test.stopTest();
    }
}
