component accessors="true" {

  
	property name="access_token" type="string" setter=true hint="JWT / Bearer token or oms access token";
	property name="workspaceId" type="string" setter=true hint="The ID of the log analytics / oms workspace to use";
	property name="baseUrl" type="string" setter=true hint="The ID of the log analytics / oms workspace to use" default="https://api.loganalytics.azure.com/v1/workspaces";
	
    
    /**
    * @hint Initialize Component Properties
    * @returnType any
    */
    function init( any dynamicProperties = {} ){

        // Set Initialized Properties securely
        for (var key in dynamicProperties) {
            if ( isSafeHtml(dynamicProperties[key] ) && IsSafeHtml( key )) {
                variables[ Trim( key ) ] = getSafeHtml( dynamicProperties[ GetSafeHtml( key ) ] );
            }
        }
        
        return this;
    };


    /**
    * @hint Execute Query
    * @returnType any
    **/
    public function ExecuteKQL(
        required string kustoQuery
    ){
        
        // Set the endpoint
        local.endpoint = GetBaseUrl() & "/" & GetWorkspaceId() & "/query"

        cfhttp(
            url = local.endpoint,
            method = "POST",
            timeout = 30
        ) {

            cfhttpparam( 
                type = "header",
                name = "content-type",
                value = "application/json"
             )
             
            cfhttpparam( 
                type = "header",
                name = "Authorization",
                value = "Bearer " & GetAccess_token()
             )
             
            cfhttpparam(
                type = "body",
                value = serializeJson({
                    "query" : GetSafeHtml( arguments.kustoQuery )
                })
            );
        }


        return deserializeJson(cfhttp.fileContent);
    }

}
