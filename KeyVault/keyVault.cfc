/**
* @hint Azure Key Vault Wrapper
* @Author Michael Hayes - Media3 Technologies, LLC.
* @description Azure Key Vault Wrapper. Uses the internal metadata service to obtain a JWT token for authentication or replace the logic inside of the Auth() function to use an Entra app registration. 
*/
component accessors="true" {

    property name="auth"        type="string" hint="JWT / Bearer token obtained from the internal metadata service, or an entra app registration with access to the key vault.";
    property name="api-version" type="string" default="7.4" hint="Default api version to use";
    property name="endpoint"    type="string" default="https://{{vaultName}}.vault.azure.net/" hint="Endpoint to send the api requests to";
    property name="vaultName"   type="string" required="true" hint="Name of the key vault";
    
    
    /**
    * @hint Initialize Component Properties
    * @returnType any
    */
    function init( any dynamicProperties = {} ){

        StructAppend( variables, dynamicProperties, true );
        
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
            var local.endpoint = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net/"
            cfhttp(
                url = local.endpoint,
                method = "GET",
                result = "local.httpResult"
            ) {
                cfhttpparam(type="header", name="Metadata", value="true");
            }
            return deserializeJSON(local.httpResult.fileContent)
            
        } catch(any e){
            return {
                "error" : e.message
            }
        }
    }
    



    /**
    * @hint Get secrets by tag
    * @description Gets all secrets from key vault that have a specific tag key and (optionally) value.
    * @returnType struct
    */
    function getSecretsByTag(
        required string tagKey,
        string tagValue = ""
    ) {
        var local.endpoint = variables.endpoint & "/secrets/?api-version=" & variables['api-version'];
        var local.secretsCollection = [];
        var local.apiRequest = {};

        // Fetch all secrets (paged)
        do {
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

            if ( IsStruct(local.apiRequest) && StructKeyExists(local.apiRequest, "value")) {
                ArrayAppend(local.secretsCollection, local.apiRequest.value, true);
            }

            local.endpoint = StructKeyExists(local.apiRequest, "nextLink") ? local.apiRequest.nextLink : "";

        } while ( StructKeyExists(local.apiRequest, "nextLink") && Len(local.apiRequest.nextLink) > 1 );

        // Filter by tag
        var local.filteredSecrets = [];
        for (var i = 1; i <= ArrayLen(local.secretsCollection); i++) {
            var secret = local.secretsCollection[i];
            // Get full secret details (to access tags)
            var secretDetail = {};
            try {
                cfhttp(
                    url = secret.id & "?api-version=" & variables['api-version'],
                    method = "GET",
                    result = "local.detailResult"
                ) {
                    cfhttpparam(type="header", name="authorization", value="Bearer " & GetAuth().access_token);
                }
                if (local.detailResult.statusCode contains 200) {
                    secretDetail = deserializeJSON(local.detailResult.fileContent);
                }
            } catch (any e) {
                continue;
            }
            if (
                StructKeyExists(secretDetail, "tags") &&
                StructKeyExists(secretDetail.tags, arguments.tagKey) &&
                (Len(arguments.tagValue) EQ 0 OR secretDetail.tags[arguments.tagKey] EQ arguments.tagValue)
            ) {
                ArrayAppend(local.filteredSecrets, secretDetail, true);
            }
        }

        return {
            "value": local.filteredSecrets
        };
    }

    
    /**
    * @hint Get all secrets
    * @description Gets the secrets from key vault.
    * @returnType struct
    */
    function getSecrets(
        string filter_string
    ) {
        var local.endpoint = variables.endpoint & "/secrets/?api-version=" & variables['api-version'];
        var local.secretsCollection = [];
        var local.apiRequest = {};
        var local.secretCount = 0;


        do {
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


        } while ( StructKeyExists( local.apiRequest, "nextLink" ) &&  Len(local.apiRequest.nextLInk) > 1 );


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
        
        var local = {};
        local.endpoint = variables['endpoint'] & "/secrets/" & arguments.secretName & "?api-version=" & variables['api-version'];

        // Build a local secret object to avoid accidental component-scope reuse
        local.secretObject = { "value": arguments.secretValue }

        StructAppend( local.secretObject, {
            "tags" : arguments.tags
        }, true );

        local.httpResult = {};
        cfhttp(
            url = local.endpoint,
            method = "PUT",
            result = "local.httpResult"
        ) {
            cfhttpparam(type="header", name="Authorization", value="Bearer " & GetAuth().access_token);
            cfhttpparam(type="header", name="Content-Type", value="application/json");
            cfhttpparam(type="body", value='{ "value": "#arguments.secretValue#" }');
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
    * @hint Purge deleted secret
    * @description Permanently deletes a deleted secret from the key vault
    * @returnType struct
    */
    function purgeSecret(
        required string secretName
    ) {
        var purgeEndpoint = variables['endpoint'] & "/deletedsecrets/" & arguments.secretName & "?api-version=" & variables['api-version'];
        var local = {};
        cfhttp(
            url = purgeEndpoint,
            method = "DELETE",
            result = "local.purgeResult"
        ) {
            cfhttpparam(type="header", name="Authorization", value="Bearer " & GetAuth().access_token);
        }
        return local.purgeResult;
    }



    /**
    * @hint Delete secret
    * @description Deletes a secret from the key vault, optionally purges it
    * @returnType struct
    */
    function deleteSecret(
        required string secretName,
        boolean purge = true
    ) {
        var local = {};
        local.endpoint = variables['endpoint'] & "/secrets/" & arguments.secretName & "?api-version=" & variables['api-version'];
        // First, delete the secret
        cfhttp(
            url = local.endpoint,
            method = "DELETE",
            result = "local.deleteResult"
        ) {
            cfhttpparam(type="header", name="Authorization", value="Bearer " & GetAuth().access_token);
        }

        // Optionally purge the deleted secret
        if (arguments.purge) {
            sleep(15000);
            local.purgeResult = purgeSecret(arguments.secretName);
        } else {
            local.purgeResult = {};
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
