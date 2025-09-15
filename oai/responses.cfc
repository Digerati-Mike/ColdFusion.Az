/**
 * @description OpenAI API Wrapper
 */
component accessors = true {

    // API endpoint configuration
    property name="model" type="string" default="gpt-4o-mini";
    property name="endpoint" type="string" default="";
    property name="input" type="string" default="";
    property name="apiKey"       type="string";
    property name="payload"       type="struct";
    property name="tools"      type="array" default="";
    property name="tool_choice"      type="string" default="auto";
    property name="id"     type="string" default="";
    property name="response"     type="struct" default="";
    property name="previous_response_id"     type="string" default="";


    this.defaultPayload =  {
        "model": "gpt-4.1",
        "input": "Total vms?"
    }

    this.defaultTools = []

    /**
     * Initializes properties and constructs the endpoint.
     */
    function init(any dynamicProperties={}) {
        // Merge dynamicProperties into variables scope
        structAppend(variables, dynamicProperties);

        if( !structKeyExists(dynamicProperties, "payload") ){

            variables.payload = this.defaultPayload
        }
        if( !structKeyExists(dynamicProperties, "tools") ) {
            variables.tools = this.defaultTools
        }

        return this;
    }

    /**
    * Builds the payload for the API request.
    * @return struct
    */
    function buildPayload(){


        variables.payload = {
            "model": getModel(),
            "tools": getTools(),
            "input": getInput(),
            "tool_choice": getTool_choice()
        }

        
        return getPayload()
    }
    

    /**
     * Calls the OpenAI API via cfhttp.
     * @return struct
     */
    function run( required string endpoint = Getendpoint(), required struct payload = getPayload(), required string apiKey = GetApiKey() ) {
        try {
            cfhttp(method="POST", url=arguments.endpoint, result="local.response") {
                cfhttpparam(type="header", name="Content-Type", value="application/json");
                cfhttpparam(type="header", name="api-key", value=arguments.apiKey);
                cfhttpparam(type="body", value=serializeJSON(arguments.payload));
            }


            local.responseObject = DeserializeJSON(local.response.fileContent);

            variables.id = local.responseObject.id;

       
            

            return local.responseObject;
        } catch(any e) {
            return {
                "success" : false,
                "message" : e,
                "local.response" : local.response
            };
        }
    }



    /**
    * Calls the OpenAI API via cfhttp.
    * @return struct
    */
    function getResponse( required string id = getId() ) {
        try {
            cfhttp(method="get", url=variables.endpoint & "/" & arguments.id, result="local.response") {
                cfhttpparam(type="header", name="Content-Type", value="application/json");
                cfhttpparam(type="header", name="api-key", value=getApiKey());
            }


            local.responseObject = DeserializeJSON(local.response.fileContent);

            variables.id = local.responseObject.id;
            variables.response = local.responseObject;


            return local.responseObject;
        } catch(any e) {
            return {
                "success" : false,
                "message" : e.message
            };
        }
    }



    
}
