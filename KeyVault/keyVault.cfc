/**
* @hint Manage and interact with the Azure Key Vault api
* @description this will be used to authenticate and interace with the Azure Key Vault rest api and retrieve api secrets and credentials
*/
component accessors=true  {
    
	property 
		name="auth"
		type="string"
		setter=true
		hint="JWT  / Bearer token obtained from the internal metadata service, or an entra app registration with access to the key vault.";
	
    
	property 
		name="imsEndpoint"
		type="string"
		setter=true
        default="http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net/"
		hint="Endpoint of the internal metadata service";
	
	property 
		name="api-version"
		type="string"
		setter=true
        default="7.4"
		hint="Default api version to use";
	
    
	property 
		name="endpoint"
		type="string"
		setter=true
        default="https://{{vaultName}}.vault.azure.net/"
		hint='Endpoint to send the api requests to';
	

	property 
		name="vaultName"
		type="string"
        required="true"
		setter=true
		hint='Name of the key vault';
	

    
    
    /**
    * @hint Initialize Component Properties
    * @returnType any
    */
    function init( any dynamicProperties = {} ){


		// Set Initialized Properties
		for (var key in dynamicProperties) {
            variables[ Trim( key ) ] = dynamicProperties[ key ];
        }
        
        if( !structKeyExists(variables, "auth") || StructKeyExists( Variables, "auth" ) && !IsStruct( variables.auth )){
            variables.auth = auth()
        }

        variables.endpoint = ReplaceNoCase( variables.endpoint, '{{vaultName}}', variables.vaultName, "all" )

		return this;
	};
    
    
    /**
    * @hint Gets the Access Token for API requests
    * @description Gets the Access Token for API requests
    * @returnType struct
    */
    private function Auth(){
        
        try {
            var local.endpoint = getImsEndpoint();
            cfhttp(
                url = local.endpoint,
                method = "GET",
                result = "local.httpResult"
            ) {
                cfhttpparam(type="header", name="Metadata", value="true");
            }
            if (local.httpResult.statusCode contains 200 ) {
                authRequest = deserializeJSON(local.httpResult.fileContent);
            } else {
                authRequest = {
                    "error": "HTTP error " & local.httpResult.statusCode,
                    "response": local.httpResult.fileContent
                };
            }
            
        } catch(any e){

            return {
                "error" : e.message
            }
        }

        return  authRequest 
    }


    /**
    * @hint Get all secrets
    * @description Gets the secrets from key vault.
    * @returnType struct
    */
    function getSecrets(
        numeric pageSize = 10,
        string filter_string
    ) {
        var local.endpoint = variables.endpoint & "/secrets/?api-version=" & variables['api-version'];
        var local.secretsCollection = [];
        var local.apiRequest = {};
        var local.secretCount = 10;

        local.loopCount = 0
        do {
            local.loopCOunt ++ 
            local.secretCount++;

            // Make the API request using cfhttp
            local.apiRequest = {};
            cfhttp(
                url = local.endpoint,
                method = "GET",
                result = "local.httpResult"
            ) {
                cfhttpparam(type="header", name="authorization", value="Bearer " & GetAuth().access_token);
            }
            if (local.httpResult.statusCode contains 200 ) {
                local.apiRequest = deserializeJSON(local.httpResult.fileContent);
            } else {
                local.apiRequest = {
                    "error": "HTTP error " & local.httpResult.statusCode,
                    "response": local.httpResult.fileContent
                };
            }

            // Append the current page of secrets to the collection
            if ( IsStruct( local.apiRequest ) && StructKeyExists(local.apiRequest, "value")) {
                ArrayAppend(local.secretsCollection, local.apiRequest.value, true);
            }

            // Update the endpoint to the nextLink, if it exists
            local.endpoint = StructKeyExists( local.apiRequest, "nextLink") ? local.apiRequest.nextLink : "";


        } while ( StructKeyExists( local.apiRequest, "nextLink" ) &&  Len(local.apiRequest.nextLInk) > 1 && local.loopCount <= pageSize );


        if( structKeyExists(arguments,"filter_string") ){
            
            local.newSecretsCollection = [];
            for (i = 1; i <= ArrayLen(local.secretsCollection); i++) {
                secretName = ListLast( local.secretsCollection[i].id,'/' );
                filterLength = Len(arguments.filter_string);
                if( left( secretName, filterLength ) == arguments.filter_string ){
                    ArrayAppend(local.newSecretsCollection, local.secretsCollection[i], true);
                }
            }

            local.secretsCollection = local.newSecretsCollection;
        }

        return {
            "value": local.secretsCollection
        };
    }

    

    /**
    * @hint Get a secret
    * @description Gets a secret from key vault. This does not display the value, rather the id of the secret for obtaining versions.
    * @returnType struct
    */
    function getSecret(
        required string secretName
    ){
        
        var local.endpoint = variables.endpoint & "/secrets/" & secretName & "?api-version=" & variables['api-version']
        
        var local.currentSecret = {};
        cfhttp(
            url = local.endpoint,
            method = "GET",
            result = "local.httpResult"
        ) {
            cfhttpparam(type="header", name="authorization", value="Bearer " & GetAuth().access_token);
        }
        if (local.httpResult.statusCode contains 200) {
            local.currentSecret = deserializeJSON(local.httpResult.fileContent);
        } else {
            local.currentSecret = {
            "error": "HTTP error " & local.httpResult.statusCode,
            "response": local.httpResult.fileContent
            };
        }

        if( !structKeyExists(local.currentSecret, "id") ){
            return local.currentSecret
        }

        endpoint = currentSecret.id & "?api-version=" & variables['api-version'];
        
        var local.secretDetail = {};
        cfhttp(
            url = endpoint,
            method = "GET",
            result = "local.httpResult"
        ) {
            cfhttpparam(type="header", name="authorization", value="Bearer " & GetAuth().access_token);
        }
        if (local.httpResult.statusCode contains 200) {
            local.secretDetail = deserializeJSON(local.httpResult.fileContent);
        } else {
            local.secretDetail = {
            "error": "HTTP error " & local.httpResult.statusCode,
            "response": local.httpResult.fileContent
            };
        }
        return local.secretDetail;
        
    };
    

    /**
    * @hint Get Versions of a secret
    * @description Gets the versions for a specific secret
    * @returnType struct
    */
    function getSecretVersions(
        required string secretName
    ){
        
        var local.endpoint = variables.endpoint & "/secrets/" & secretName & "/versions?api-version=" & variables['api-version']
        var local.httpResult = {};
        cfhttp(
            url = local.endpoint,
            method = "GET",
            result = "local.httpResult"
        ) {
            cfhttpparam(type="header", name="authorization", value="Bearer " & GetAuth().access_token);
        }
        if (local.httpResult.statusCode contains 200) {
            return deserializeJSON(local.httpResult.fileContent);
        } else {
            return {
            "error": "HTTP error " & local.httpResult.statusCode,
            "response": local.httpResult.fileContent
            };
        }
    };
    
    

    /**
    * @hint Add a secret
    * @description Adds a secret to the key vault
    * @returnType struct
    */
    function addSecret( 
        required string secretName,
        required string secretValue,
        struct tags = {}
     ){
        
        var local.endpoint = variables['endpoint'] & "/secrets/" & arguments.secretName & "?api-version=" & variables['api-version']


        secretObject = {
            "value": arguments.secretValue
        }

        StructAppend( SecretObject, {
            "tags" : arguments.tags
        }, true )

        var local.httpResult = {};
        cfhttp(
            url = local.endpoint,
            method = "PUT",
            result = "local.httpResult"
        ) {
            cfhttpparam(type="header", name="Authorization", value="Bearer " & GetAuth().access_token);
            cfhttpparam(type="header", name="Content-Type", value="application/json");
            cfhttpparam(type="body", value=serializeJSON(secretObject));
        }

        if (local.httpResult.statusCode contains 200 or local.httpResult.statusCode contains 201) {
            return deserializeJSON(local.httpResult.fileContent);
        } else {
            return {
            "error": "HTTP error " & local.httpResult.statusCode,
            "response": local.httpResult.fileContent
            };
        }
    }

    

    /**
    * @hint Delete secret
    * @description Deletes a secret from the key vault
    */
    function deleteSecret( 
        required string secretName
    ){
        var local.endpoint = variables['endpoint'] & "/secrets/" & arguments.secretName & "?api-version=" & variables['api-version']
        // First, delete the secret
        cfhttp(
            url = local.endpoint,
            method = "DELETE",
            result = "local.deleteResult"
        ) {
            cfhttpparam(type="header", name="Authorization", value="Bearer " & GetAuth().access_token);
        }

        sleep(15000);

        // Then, delete the deleted secret (purge)
        var purgeEndpoint = variables['endpoint'] & "/deletedsecrets/" & arguments.secretName & "?api-version=" & variables['api-version'];

        cfhttp(
            url = purgeEndpoint,
            method = "DELETE",
            result = "local.purgeResult"
        ) {
            cfhttpparam(type="header", name="Authorization", value="Bearer " & GetAuth().access_token);
        }

        return {
            deleteResult = local.deleteResult,
            purgeResult = local.purgeResult
        };
    }
    
    function dateTimeToEpoch(dateTime) {
        if (!isDate(dateTime)) {
            throw "Invalid dateTime format.";
        }
        return dateDiff("s", createDateTime(1970, 1, 1, 0, 0, 0), dateTime);
    }

    
    function epochToDateTime(epoch) {
        if (!isNumeric(epoch)) {
            throw "Invalid epoch time format.";
        }
        return dateAdd("s", epoch, createDateTime(1970, 1, 1, 0, 0, 0));
    }

}
