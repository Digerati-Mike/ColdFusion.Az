/**
* @author       Michael Hayes - Media3 Technologies, LLC
* @hint         Authenticate and interact with the Microsoft Graph API
* @description  This will be used to simplify API requests to the Microsoft Graph API
*/
component accessors="true"{
    
    property name="baseUrl" default="https://graph.microsoft.com";
    property name="uri" default="me";
    property name="apiVersion" default="v1.0";
    property name="access_token" default="";

     
    /**
    * @hint Initialize Component Properties
    * @returnType any
    */
    function init( any dynamicProperties = {} ){


		// Set Initialized Properties
		for (var key in dynamicProperties) {
            variables[ Trim( key ) ] = dynamicProperties[ key ];
        }
        

		return this;
	};
    

    /**
    * Send an API request with flexible options (fetch-style)
    * @param uri      The endpoint URI (string)
    * @param options  Struct with method, headers, body, etc. (optional)
    * @return         Struct with status, headers, and body
    */
    function send( string uri = "", struct options = {} ) {
        // Resolve endpoint: use provided uri or default property
        var endpoint = len(arguments.uri) ? arguments.uri : variables.uri;

        // Build full URL from properties unless an absolute URL is passed
        var isAbsolute = reFindNoCase("^https?://", endpoint) GT 0;
        var base   = reReplace( variables.baseUrl, "/+$", "" );
        var ver    = reReplace( variables.apiVersion, "^/+|/+$", "" );
        var path   = reReplace( endpoint, "^/+", "" );
        var fullUrl = isAbsolute ? endpoint : base & "/" & ver & "/" & path;

        // Optional query params: options.query = { key: value }
        var queryParams = structKeyExists(options, "query") ? options.query : structNew();
        if ( structCount(queryParams) ) {
            var parts = [];
            for (var qk in queryParams) {
                arrayAppend( parts, urlEncodedFormat(qk) & "=" & urlEncodedFormat( queryParams[qk] & "" ) );
            }
            fullUrl &= ( find("?", fullUrl) ? "&" : "?" ) & arrayToList(parts, "&");
        }

        // HTTP options
        var method  = uCase( structKeyExists(options, "method") ? options.method : "GET" );
        var headers = structKeyExists(options, "headers") ? duplicate(options.headers) : structNew();
        var body    = structKeyExists(options, "body") ? options.body : "";
        var asJson  = structKeyExists(options, "json") ? options.json : false;
        var timeout = structKeyExists(options, "timeout") ? int(options.timeout) : 60;

        // Default headers
        if ( !structKeyExists(headers, "Authorization") && len(variables.access_token) ) {
            headers["Authorization"] = "Bearer " & variables.access_token;
        }
        if ( !structKeyExists(headers, "Accept") ) headers["Accept"] = "application/json";
        if ( asJson && !structKeyExists(headers, "Content-Type") ) headers["Content-Type"] = "application/json";

       
        headers["Content-Type"] = "application/json";

        // Make request
        var httpResult = {};
        cfhttp( url=fullUrl, method=method, result="httpResult", charset="utf-8", timeout=timeout ) {
            for (var headerName in headers) {
                cfhttpparam( type="header", name=headerName, value=headers[ headerName ] );
            }
            if ( len(body) ) {
            var payload = ( asJson && !isSimpleValue(body) ? serializeJSON(body) : body );
                cfhttpparam( type="body", value=payload );
            }
        }

        // Try to parse JSON body, return both raw and parsed
        var rawBody = httpResult.fileContent;
        var parsedBody = rawBody;
        try { parsedBody = deserializeJSON(rawBody); } catch(any e) {}

        if( isJSON( httpResult.fileContent ) ){
            return DeserializeJSON( httpResult.fileContent );
        }

        return httpResult 
    }



}
