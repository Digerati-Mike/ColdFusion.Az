/**
 * @description OpenAI API Wrapper
 */
component accessors = true {

    // API endpoint configuration
    property name="openai_host" type="string";
    property name="model" type="string" default="gpt-4o-mini";
    property name="openai_endpoint" type="string" default="";
    property name="prompt" type="string" default="";
    property name="apiKey"       type="string";


    /**
     * Initializes properties and constructs the endpoint.
     */
    function init(any dynamicProperties={}) {
        // Merge dynamicProperties into variables scope
        structAppend(variables, dynamicProperties);


        if( !structKeyExists(arguments.dynamicProperties,"openai_endpoint") ) {
            // Set the endpoint using the openai_host and openai_model
            variables.openai_endpoint = variables.openai_host & "/openai/v1/" & variables.model & "/chat/completions";
        }
            
        return this;
    }






    /**
     * Calls the OpenAI API via cfhttp.
     * @return struct
     */
    function Run(required struct request_body) {
        try {
            cfhttp(method="POST", url=Getopenai_endpoint(), result="local.response") {
                cfhttpparam(type="header", name="Content-Type", value="application/json");
                cfhttpparam(type="header", name="api-key", value=GetApiKey());
                cfhttpparam(type="body", value=serializeJSON(arguments.request_body));
            }
            
            return deserializeJSON(local.response.FileContent);
        } catch(any e) {
            return {
                "success" : false,
                "message" : e.message
            };
        }
    }




    /**
     * Calls the OpenAI API via cfhttp.
     * @return struct
     */
    function send( required string endpoint = GetOpenai_endpoint(), required struct request_body, required string apiKey = GetApiKey() ) {
        try {
            cfhttp(method="POST", url=arguments.endpoint, result="local.response") {
                cfhttpparam(type="header", name="Content-Type", value="application/json");
                cfhttpparam(type="header", name="api-key", value=arguments.apiKey);
                cfhttpparam(type="body", value=serializeJSON(arguments.request_body));
            }
            
            return local.response.FileContent
        } catch(any e) {
            return {
                "success" : false,
                "message" : e.message
            };
        }
    }

    
    function planSpeechAzure(required string userAsk, required any apiResponse, numeric maxSeconds=7) {
     
        // ---- JSON Schema for structured output (SpeechPlan) ----
        var speechPlanSchema = {
            "type"                : "object",
            "additionalProperties": false,
            "properties"          : {
                "intent"     : { "type":"string", "enum":["answer","confirm","error","probe","status"] },
                "speech"     : {
                    "type":"object",
                    "additionalProperties": false,
                    "properties": {
                        "text"        : { "type":"string" },
                        "ssml"        : { "type":"string" },
                        "duration_sec": { "type":"number" }
                    },
                    "required": ["text"]
                },
                "display_text": { "type":"string" },
                "key_facts"   : { "type":"array", "items":{"type":"string"} },
                "followups"   : { "type":"array", "items":{"type":"string"} },
                "confidence"  : { "type":"number" }
            },
            "required": ["intent","speech","display_text"]
        };

        // ---- Messages (system + user) ----
        var systemPrompt = "You are a Speech Planner. Convert API results into a concise spoken response."
            & " Rules: Target " & maxSeconds & " seconds at ~150 wpm. Lead with the answer;"
            & " then 0-2 key facts; then 1 short follow-up. Prefer rounded numbers and plain English."
            & " If error, intent=error with a calm fix suggestion. If ambiguous, intent=probe with one clarifier."
            & " Output STRICTLY in the SpeechPlan JSON schema. No extra keys.";

        var userPayload = {
            "user_ask"   : arguments.userAsk,
            "api_response": arguments.apiResponse,
            "time_now"   : dateTimeFormat(now(), "yyyy-mm-dd'T'HH:nn:ss"),
            "max_seconds": maxSeconds
        };

        var payload = {
            // Azure: deployment is in the URL; you still pass messages as usual.
            "messages"        : [
                { "role":"system", "content": systemPrompt },
                { "role":"user",   "content": serializeJSON(userPayload) }
            ],
            "temperature"     : 0.2,
            "max_tokens"      : 800,
            // Structured Outputs (Azure supports response_format on compatible models)
            "response_format" : {
                "type"       : "json_schema",
                "json_schema": { "name":"SpeechPlan", "schema": speechPlanSchema }
            },
            "model" : getModel()
        };

        return payload;
    }
}
