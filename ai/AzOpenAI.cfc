/**
 * @description OpenAI API Wrapper
 */
component accessors = true {

    // API endpoint configuration
    property name="openai_host" type="string";
    property name="openai_model" type="string" default="gpt-35-turbo";
    property name="openai_endpoint" type="string" default="";
    property name="apiKey"       type="string";
    property name="temperature"  type="numeric" default=0.7;
    property name="TopP"         type="numeric" default=0.95;
    property name="maxTokens"    type="numeric" default="800";

    /**
     * Initializes properties and constructs the endpoint.
     */
    function init(any dynamicProperties={}) {
        // Merge dynamicProperties into variables scope
        structAppend(variables, dynamicProperties);

        // Set the endpoint using the openai_host and openai_model
        variables.openai_endpoint = variables.openai_host & 
            "/openai/deployments/" & variables.openai_model & "/chat/completions?api-version=2024-02-15-preview";
            
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
            
            local.parsedResponse = deserializeJSON(local.response.FileContent);
            return {
                "success" : true,
                "value"   : local.parsedResponse.choices[1].message.tool_calls[1].function.arguments,
                "full"    : local.parsedResponse
            };
        } catch(any e) {
            return {
                "success" : false,
                "message" : e.message
            };
        }
    }
}
