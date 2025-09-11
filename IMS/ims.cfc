/**
* @author       Michael Hayes - Media3 Technologies, LLC
* @hint         Authenticate to the Azure Internal Metadata Service (IMDS)
* @description  this will be used to authenticate to various services using the internal metadata service (IMDS) available to azure hosted services
*/
component accessors="true" {
    
    property name="api-version" type="string" setter=true default="2019-08-01" hint="API Version to use when running requests against the internal metadata service.";
    property name="resource" type="string" setter=true default="https://vault.azure.net/" hint="Resource / API to obtain a JWT token for.";
    property name="imsEndpoint" type="string" setter=true hint="Endpoint of the internal metadata service.";


    /**
    * @hint Initialize Component Properties
    * @returnType any
    */
    function init( any dynamicProperties = {} ){

        // Set Initialized Properties securely
        for (var key in dynamicProperties) {
            variables[ Trim( key ) ] =  dynamicProperties[ key ] 
        }

        // Set the IMS Query String with the concantenated values
        Variables.ImsQueryString = "api-version=" & Variables['api-version'] & "&resource=" & Variables['resource']

        // Construct the final imsEndpoint url
        variables.imsEndpoint = "http://169.254.169.254/metadata/identity/oauth2/token?" & variables.imsQueryString
        

        return this
    };

    
    /**
    * @hint Get access_token
    * @returnType struct
    **/
    public function Auth(){
        
        // Make the HTTP request using cfhttp
        cfhttp(
            url = variables.imsEndpoint,
            method = "GET",
            result = "httpResult"
        ) {
            cfhttpparam(
                type = "header",
                name = "Metadata",
                value = "true"
            );
        }

        // Initialize response variable
        Variables.response = {};

        // Check if the request was successful
        if (structKeyExists(httpResult, "fileContent") && IsJSON(httpResult.fileContent)) {
            Variables.response = DeserializeJSON(httpResult.fileContent);

            if (structKeyExists(Variables.response, "expires_in")) {
                variables['response']['expires_time'] = dateAdd("s", Variables.response.expires_in, now());
            }
        } else {
            // Optionally, handle errors or non-JSON responses
            Variables.response = {
                error = "Request failed or response was not JSON",
                statusCode = httpResult.statusCode ?: "",
                responseHeader = httpResult.responseHeader ?: ""
            };
        }

        return Variables.response;
    }
}
