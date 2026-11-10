/**
 * @author Salesforce Developer
 * @description Handles the raw HTTP callouts to the Salesforce Agentforce Agent API (session start,
 *              synchronous message send, and session end) using the Agentforce_Agent_API Named
 *              Credential. This class contains no case similarity business logic - it only knows how
 *              to talk to the Agent API and hand back the agent's raw reply text.
 * @see https://developer.salesforce.com/docs/ai/agentforce/guide/agent-api-get-started.html
 * @see https://developer.salesforce.com/docs/ai/agentforce/guide/agent-api-examples.html
 */
public with sharing class CaseSimilarity_AgentApi_Service {
    private static final String NAMED_CREDENTIAL = 'callout:Agentforce_Agent_API';
    private static final String AGENT_API_BASE = '/einstein/ai-agent/v1';
    private static final Integer CALLOUT_TIMEOUT_MS = 60000;

    /**
     * @description Custom exception thrown when the Agent API returns an error or an unexpected payload
     */
    public class AgentApiException extends Exception {
    }

    /**
     * @description Starts a new Agent API session for the given agent
     * @param agentId The Agentforce Agent ID (BotDefinition Id)
     * @return The sessionId to use for subsequent message calls
     */
    public String startSession(String agentId) {
        String endpoint = NAMED_CREDENTIAL + AGENT_API_BASE + '/agents/' + agentId + '/sessions';
        HttpResponse response = sendRequest(endpoint, 'POST', JSON.serialize(buildStartSessionBody()));
        return extractSessionId(response);
    }

    /**
     * @description Sends a synchronous text message to an active Agent API session
     * @param sessionId The session ID returned by startSession
     * @param messageText The text to send to the agent
     * @param sequenceId A monotonically increasing sequence number for this session
     * @return The concatenated text of all "Inform" messages returned by the agent
     */
    public String sendMessage(String sessionId, String messageText, Integer sequenceId) {
        String endpoint = NAMED_CREDENTIAL + AGENT_API_BASE + '/sessions/' + sessionId + '/messages';
        Map<String, Object> body = buildMessageBody(messageText, sequenceId);
        HttpResponse response = sendRequest(endpoint, 'POST', JSON.serialize(body));
        return extractAgentReplyText(response);
    }

    /**
     * @description Ends an active Agent API session
     * @param sessionId The session ID to end
     */
    public void endSession(String sessionId) {
        String endpoint = NAMED_CREDENTIAL + AGENT_API_BASE + '/sessions/' + sessionId;
        sendRequest(endpoint, 'DELETE', null);
    }

    private Map<String, Object> buildStartSessionBody() {
        return new Map<String, Object>{
            'externalSessionKey' => Uuid.randomUUID().toString(),
            'instanceConfig' => new Map<String, Object>{ 'endpoint' => URL.getOrgDomainUrl().toExternalForm() },
            'streamingCapabilities' => new Map<String, Object>{ 'chunkTypes' => new List<String>{ 'Text' } },
            'bypassUser' => true
        };
    }

    private Map<String, Object> buildMessageBody(String messageText, Integer sequenceId) {
        return new Map<String, Object>{
            'message' => new Map<String, Object>{
                'sequenceId' => sequenceId,
                'type' => 'Text',
                'text' => messageText
            }
        };
    }

    private HttpResponse sendRequest(String endpoint, String method, String body) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod(method);
        request.setHeader('Content-Type', 'application/json');
        request.setTimeout(CALLOUT_TIMEOUT_MS);
        if (body != null) {
            request.setBody(body);
        }
        HttpResponse response = new Http().send(request);
        validateResponse(response);
        return response;
    }

    private void validateResponse(HttpResponse response) {
        Integer statusCode = response.getStatusCode();
        if (statusCode < 200 || statusCode >= 300) {
            throw new AgentApiException('Agent API call failed with status ' + statusCode + ': ' + response.getBody());
        }
    }

    private String extractSessionId(HttpResponse response) {
        Map<String, Object> responseMap = parseResponseBody(response);
        Object sessionId = responseMap.get('sessionId');
        if (sessionId == null) {
            throw new AgentApiException('Agent API response did not include a sessionId.');
        }
        return String.valueOf(sessionId);
    }

    private String extractAgentReplyText(HttpResponse response) {
        Map<String, Object> responseMap = parseResponseBody(response);
        List<Object> messages = (List<Object>) responseMap.get('messages');
        return concatenateInformMessages(messages);
    }

    private Map<String, Object> parseResponseBody(HttpResponse response) {
        try {
            return (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        } catch (Exception e) {
            throw new AgentApiException('Unable to parse Agent API response: ' + e.getMessage());
        }
    }

    private String concatenateInformMessages(List<Object> messages) {
        List<String> texts = new List<String>();
        if (messages != null) {
            for (Object item : messages) {
                addInformMessageText((Map<String, Object>) item, texts);
            }
        }
        return String.join(texts, '\n');
    }

    private void addInformMessageText(Map<String, Object> messageMap, List<String> texts) {
        Object messageText = messageMap.get('message');
        if (messageText != null) {
            texts.add(String.valueOf(messageText));
        }
    }
}
