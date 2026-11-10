/**
 * @author Salesforce Developer
 * @description Test class for CaseSimilarity_AgentApi_Service. Verifies session start, message send,
 *              session end, and error handling using HttpCalloutMock so no real callouts are made.
 */
@isTest
private class CaseSimilarity_AgentApi_Service_Test {
    @isTest
    static void testStartSessionSuccess() {
        Test.setMock(HttpCalloutMock.class, new CaseSimilarityAgentApiMock('unused'));

        Test.startTest();
        String sessionId = new CaseSimilarity_AgentApi_Service().startSession('0XxTestAgentId');
        Test.stopTest();

        System.assertEquals('mock-session-id-123', sessionId, 'Expected sessionId from mock response');
    }

    @isTest
    static void testSendMessageSuccess() {
        Test.setMock(HttpCalloutMock.class, new CaseSimilarityAgentApiMock('[{"caseNumber":"00001000"}]'));

        Test.startTest();
        String replyText = new CaseSimilarity_AgentApi_Service()
            .sendMessage('mock-session-id-123', 'find similar cases', 1);
        Test.stopTest();

        System.assert(replyText.contains('00001000'), 'Expected the agent reply text to include the mocked payload');
    }

    @isTest
    static void testEndSessionDoesNotThrow() {
        Test.setMock(HttpCalloutMock.class, new CaseSimilarityAgentApiMock('unused'));

        Test.startTest();
        new CaseSimilarity_AgentApi_Service().endSession('mock-session-id-123');
        Test.stopTest();
    }

    @isTest
    static void testErrorResponseThrowsAgentApiException() {
        Test.setMock(HttpCalloutMock.class, new CaseSimilarityAgentApiMock('unused', 500));

        Test.startTest();
        try {
            new CaseSimilarity_AgentApi_Service().startSession('0XxTestAgentId');
            System.assert(false, 'Expected AgentApiException for a non-2xx response');
        } catch (CaseSimilarity_AgentApi_Service.AgentApiException e) {
            System.assert(e.getMessage().contains('500'), 'Expected the status code in the exception message');
        }
        Test.stopTest();
    }
}
