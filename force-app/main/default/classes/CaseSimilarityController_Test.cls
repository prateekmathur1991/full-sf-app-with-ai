/**
 * @author Salesforce Developer
 * @description Test class for CaseSimilarityController. Verifies the controller delegates correctly
 *              to CaseSimilarity_Service and translates exceptions into AuraHandledException with a
 *              usable message.
 */
@isTest
private class CaseSimilarityController_Test {
    @isTest
    static void testFindSimilarCasesReturnsResultsFromService() {
        Case existingCase = new Case(Subject = 'Cannot log in', Status = 'New');
        insert existingCase;
        existingCase = [SELECT CaseNumber FROM Case WHERE Id = :existingCase.Id];

        String agentJson = '[{"caseNumber":"' + existingCase.CaseNumber + '","subject":"Cannot log in","similarityReason":"Matches"}]';
        Test.setMock(HttpCalloutMock.class, new CaseSimilarityAgentApiMock(agentJson));

        Test.startTest();
        List<CaseSimilarity_Service.SimilarCaseResult> results = CaseSimilarityController.findSimilarCases(
            'Cannot sign in',
            'User cannot sign in to the app'
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected the controller to return the service results');
    }

    @isTest
    static void testFindSimilarCasesWithBlankInputThrowsAuraHandledException() {
        Test.startTest();
        try {
            CaseSimilarityController.findSimilarCases('', '');
            System.assert(false, 'Expected an AuraHandledException for blank input');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Please enter'), 'Expected the validation message to be surfaced');
        }
        Test.stopTest();
    }

    @isTest
    static void testFindSimilarCasesWithCalloutFailureThrowsAuraHandledException() {
        Test.setMock(HttpCalloutMock.class, new CaseSimilarityAgentApiMock('unused', 500));

        Test.startTest();
        try {
            CaseSimilarityController.findSimilarCases('Some title', 'Some description');
            System.assert(false, 'Expected an AuraHandledException when the underlying callout fails');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('unexpected error'), 'Expected a generic unexpected error message');
        }
        Test.stopTest();
    }
}
