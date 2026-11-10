/**
 * @author Salesforce Developer
 * @description Test-only HttpCalloutMock for the Agentforce Agent API used by
 *              CaseSimilarity_AgentApi_Service_Test and CaseSimilarity_Service_Test. Returns canned
 *              JSON responses for the start session, send message, and end session endpoints based
 *              on the request method and endpoint path.
 */
@isTest
public class CaseSimilarityAgentApiMock implements HttpCalloutMock {
    private final String informMessageText;
    private final Integer overrideStatusCode;

    public CaseSimilarityAgentApiMock(String informMessageText) {
        this.informMessageText = informMessageText;
        this.overrideStatusCode = null;
    }

    public CaseSimilarityAgentApiMock(String informMessageText, Integer overrideStatusCode) {
        this.informMessageText = informMessageText;
        this.overrideStatusCode = overrideStatusCode;
    }

    public HttpResponse respond(HttpRequest request) {
        if (overrideStatusCode != null) {
            return buildResponse(overrideStatusCode, '{"error":"simulated failure"}');
        }
        if (request.getMethod() == 'DELETE') {
            return buildResponse(204, '{}');
        }
        if (request.getEndpoint().contains('/messages')) {
            return buildResponse(200, buildMessagesBody());
        }
        return buildResponse(200, '{"sessionId":"mock-session-id-123"}');
    }

    private String buildMessagesBody() {
        Map<String, Object> messageMap = new Map<String, Object>{ 'type' => 'Inform', 'message' => informMessageText };
        Map<String, Object> body = new Map<String, Object>{ 'messages' => new List<Object>{ messageMap } };
        return JSON.serialize(body);
    }

    private HttpResponse buildResponse(Integer statusCode, String body) {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(statusCode);
        response.setBody(body);
        return response;
    }
}
