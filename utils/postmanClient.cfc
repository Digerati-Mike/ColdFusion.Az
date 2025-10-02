component accessors="true" name="postmanClient" {

    // Properties with generated getters/setters via accessors
    property name="jsonSchema" type="string" hint="JSON schema input (optional if using method arguments)";
    property name="collectionName" type="string" hint="Default Postman collection name";
    property name="baseUrl" type="string" hint="Default base URL for requests";
    property name="host" type="string"  default="127.0.0.1" hint="IP or FQDN used to derive baseUrl when not provided";
    property name="sourceUrl" type="string" hint="REST root URL (used by listApps); derived from host by default";
    property name="rootDir" type="string" hint="Directory path for generated outputs (if used)";
    property name="cdci" type="boolean" default="false" hint="Toggle to automatically write generated schemas to the output directory";
    // ADDED: webhook configuration
    property name="webHookUrl" type="string" hint="endpoint to send the event to once completed. Trigger on SwaggerToPostan, GenerateEnvironment, SwaggerToPoenApi, PostanRequestToMarkdown, or postmanToMarkdown";
    property name="webhook" type="boolean" default="false" hint="Enable/disable webhook triggering after operations";

    this.name = "Postman Client";

    // Pseudo-constructor: initialize defaults without changing existing method behavior
    variables.jsonSchema = "";
    variables.collectionName = "Converted API Collection";
    variables.baseUrl = "https://api.example.com";
    variables.host = "";
    variables.sourceUrl = "";
    variables.rootDir = "";
    // ADDED defaults for webhook props
    variables.webHookUrl = "";
    variables.webhook = false;

    // ------------------------------
    // Lifecycle
    // ------------------------------
    /**
    * @hint Initialize Component Properties
    */
    function init( any dynamicProperties = {} ){
        for ( var key in dynamicProperties ) {
            if ( structKeyExists( variables, key ) ) {
                variables[ key ] = dynamicProperties[ key ];
            } else if ( isCustomFunction( "set" & key ) ) {
                invoke( this, "set" & key, [ dynamicProperties[ key ] ] );
            }
        }
        return this;
    }

    /**
     * Generate Postman collection JSON from input schema
     * @param jsonSchema JSON string representing the outdated API schema
     * @param collectionName Desired name for the Postman collection
     * @param baseUrl Base URL to use for environment variable substitution
     * @return string (JSON)
     */
    public string function SwaggerToPostman(
        required any jsonSchema,
        string collectionName = "Converted API Collection",
        string baseUrl = ""
    ) {

        if( !IsSimpleValue( arguments.jsonSchema ) ){
            arguments.jsonSchema = serializeJSON( arguments.jsonSchema );
        }
        
        var inputSchemas = deserializeJSON(arguments.jsonSchema);

        // Resolve effective base URL from argument, component property, or host fallback
        var effectiveBaseUrl = resolveBaseUrl(arguments.baseUrl);

        // Merge all resources from all schema objects
        var apiSchema = {};
        for (var schemaObj in inputSchemas) {
            if (structKeyExists(schemaObj, "resources")) {
                for (var key in schemaObj.resources) {
                    apiSchema[key] = schemaObj.resources[key];
                }
            }
        }

        // Initialize the Postman collection structure
        var collection = {};
        collection["info"] = {
            "name": arguments.collectionName,
            "_postman_id": createUUID(),
            "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
        };

        // Collection-level variable for baseUrl
        collection["variables"] = [
            {
                "key": "baseUrl",
                "value": effectiveBaseUrl,
                "type": "string"
            }
        ];

        collection["item"] = [];

        // Loop through each resource category
        for (var categoryName in apiSchema) {
            var categoryData = apiSchema[categoryName];

            if (structKeyExists(categoryData, "apis")) {
                var folderItem = {
                    "name": categoryName,
                    "item": []
                };

                for (var apiEntry in categoryData.apis) {
                    var endpointPath = apiEntry.path;

                    for (var operationDetail in apiEntry.operations) {
                        var method = operationDetail.method;
                        var fullUrl = "{{baseUrl}}" & endpointPath;

                        var requestItem = {};
                        // Use nickname if available, otherwise fallback to path
                        var requestName = structKeyExists(operationDetail, "nickname") && len(trim(operationDetail.nickname))
                            ? operationDetail.nickname
                            : endpointPath;
                        requestItem["name"] = ucase(trim(method)) & " " & requestName;
                        requestItem["request"] = {
                            "method": ucase(trim(method)),
                            "url": fullUrl
                        };

                        if (structKeyExists(operationDetail, "description")) {
                            requestItem["request"]['description'] = operationDetail["description"];
                        } else if (structKeyExists(operationDetail, "summary")) {
                            requestItem["request"]['description']  = operationDetail["summary"];
                        }

                        requestItem["response"] = [];

                        arrayAppend(folderItem.item, requestItem);
                    }
                }

                arrayAppend(collection.item, folderItem);
            }
        }

        collection.info['description']  = postmanToMarkdown(serializeJSON(collection));

        var outputJson = serializeJSON(collection);

        // Automatically write file if CDCI flag is set
        if (getCDCI()) {
            var outDir = getrootDir();
            if (len(trim(outDir))) {
                try {
                    if (!directoryExists(outDir)) directoryCreate(outDir);
                    var baseName = reReplace(arguments.collectionName, "[^A-Za-z0-9_-]+", "_", "all");
                    if (!len(baseName)) baseName = "collection";
                    var fileName = baseName & "-postman.json";
                    var sep = reFind("[\\/]$", outDir) ? "" : ( find("\\", outDir) ? "\\" : "/" );
                    var filePath = outDir & sep & fileName;
                    fileWrite(filePath, outputJson);
                } catch (any e) {
                    // Ignore write failures to avoid breaking main flow
                }
            }
        }

        // ADDED: webhook trigger
        triggerWebhook(
            "SwaggerToPostman",
            {
                "collectionName": arguments.collectionName,
                "baseUrl": effectiveBaseUrl,
                "folders": arrayLen(collection.item),
                "size": len(outputJson)
            }
        );

        return outputJson;
    }

    /**
     * Generate Postman environment JSON with baseUrl variable
     * @param envName Name for the Postman environment
     * @param baseUrl Base URL value for the environment variable
     * @return string (JSON)
     */
    public string function generateEnvironment(
        string envName = "API Environment",
        string baseUrl = ""
    ) {
        var effectiveBaseUrl = resolveBaseUrl(arguments.baseUrl);
        var envJson = serializeJSON({
            "name": arguments.envName,
            "values": [
                { "key": "baseUrl", "value": effectiveBaseUrl, "enabled": true }
            ],
            "_postman_variable_scope": "environment",
            "_postman_exported_at": dateTimeFormat(now(), "yyyy-MM-dd'T'HH:mm:ss'Z'"),
            "_postman_exported_using": "ColdFusion Postman Converter"
        });

        // ADDED: webhook trigger
        triggerWebhook(
            "generateEnvironment",
            { "envName": arguments.envName, "baseUrl": effectiveBaseUrl, "size": len(envJson) }
        );

        return envJson;
    }

    /**
     * Convert legacy/Swagger-like schema JSON to an OpenAPI (v3) document
     * @param jsonSchema JSON string representing the outdated API schema
     * @param title OpenAPI info.title
     * @param version OpenAPI info.version
     * @param baseUrl Server URL for the OpenAPI servers array
     * @param openapiVersion OpenAPI spec version (default 3.0.3)
     * @return string (JSON OpenAPI document)
     */
    public string function SwaggerToOpenAPI(
        required string jsonSchema,
        string title = "Converted API",
        string version = "1.0.0",
        string baseUrl = "",
        string openapiVersion = "3.0.3"
    ) {
        var inputSchemas = deserializeJSON(arguments.jsonSchema);

        // Resolve effective base URL from argument, component property, or host fallback
        var effectiveBaseUrl = resolveBaseUrl(arguments.baseUrl);

        // Merge all resources from all schema objects
        var apiSchema = {};
        for (var schemaObj in inputSchemas) {
            if (structKeyExists(schemaObj, "resources")) {
                for (var key in schemaObj.resources) {
                    apiSchema[key] = schemaObj.resources[key];
                }
            }
        }

        var openapi = {
            "openapi": openapiVersion,
            "info": {
                "title": arguments.title,
                "version": arguments.version,
                "description": "Generated from legacy schema"
            },
            "servers": [ { "url": effectiveBaseUrl } ],
            "paths": {},
            "components": { "schemas": {} }
        };

        // Build paths and operations
        for (var categoryName in apiSchema) {
            var categoryData = apiSchema[categoryName];
            if (!structKeyExists(categoryData, "apis")) continue;

            for (var apiEntry in categoryData.apis) {
                var endpointPath = apiEntry.path;
                if (!structKeyExists(openapi.paths, endpointPath)) openapi.paths[endpointPath] = {};

                for (var operationDetail in apiEntry.operations) {
                    var method = lcase(trim(operationDetail.method));
                    var op = {};

                    // tags
                    op["tags"] = [ categoryName ];

                    // summary/description
                    if (structKeyExists(operationDetail, "summary")) op["summary"] = operationDetail.summary;
                    if (structKeyExists(operationDetail, "description")) op["description"] = operationDetail.description;

                    // operationId
                    var rawOperationId = (structKeyExists(operationDetail, "nickname") && len(trim(operationDetail.nickname)))
                        ? operationDetail.nickname
                        : (ucase(method) & " " & endpointPath);
                    op["operationId"] = sanitizeOperationId(rawOperationId);

                    // parameters & requestBody
                    op["parameters"] = [];
                    if (structKeyExists(operationDetail, "parameters") && isArray(operationDetail.parameters)) {
                        var hasBody = false;
                        var bodySchema = {};
                        var bodyRequired = false;

                        for (var p in operationDetail.parameters) {
                            var paramType = structKeyExists(p, "paramType") ? lcase(p.paramType) : "query";
                            var pName = structKeyExists(p, "name") ? p.name : "param";
                            var pDesc = structKeyExists(p, "description") ? p.description : "";
                            var pRequired = (structKeyExists(p, "required") && (p.required EQ true OR p.required EQ 1 OR lcase(toString(p.required)) EQ "true"));

                            if (paramType EQ "body") {
                                hasBody = true;
                                bodyRequired = pRequired;
                                // If explicit schema present, use it; else infer minimal from type
                                if (structKeyExists(p, "schema") && isStruct(p.schema)) {
                                    bodySchema = p.schema;
                                } else {
                                    bodySchema = legacyTypeToSchema(p);
                                    // If the body is represented as a set of fields, build an object
                                    if (!structKeyExists(bodySchema, "type") OR bodySchema.type NEQ "object") {
                                        bodySchema = { "type": "object", "properties": { } };
                                        // Use the parameter itself as a property when name available
                                        bodySchema.properties[pName] = legacyTypeToSchema(p);
                                    }
                                }
                            } else {
                                var paramOut = {
                                    "name": pName,
                                    "in": paramType,
                                    "required": pRequired,
                                    "description": pDesc,
                                    "schema": legacyTypeToSchema(p)
                                };
                                arrayAppend(op.parameters, paramOut);
                            }
                        }

                        if (hasBody) {
                            op["requestBody"] = {
                                "required": bodyRequired,
                                "content": {
                                    "application/json": { "schema": bodySchema }
                                }
                            };
                        }
                    }

                    // responses
                    op["responses"] = {};
                    var addedResponse = false;
                    if (structKeyExists(operationDetail, "responseMessages") && isArray(operationDetail.responseMessages)) {
                        for (var r in operationDetail.responseMessages) {
                            var code = structKeyExists(r, "code") ? toString(r.code) : "default";
                            var msg = structKeyExists(r, "message") ? r.message : ("Response " & code);
                            op.responses[code] = { "description": msg, "content": { "application/json": { } } };
                            addedResponse = true;
                        }
                    }
                    if (!addedResponse) {
                        // Minimal default response
                        op.responses["200"] = { "description": "Success" };
                    }

                    // mark deprecated if provided
                    if (structKeyExists(operationDetail, "deprecated") && (operationDetail.deprecated EQ true OR lcase(toString(operationDetail.deprecated)) EQ "true")) {
                        op["deprecated"] = true;
                    }

                    openapi.paths[endpointPath][method] = op;
                }
            }
        }

        var outputJson = serializeJSON(openapi);

        // Automatically write file if CDCI flag is set
        if (getCDCI()) {
            var outDir = getrootDir();
            if (len(trim(outDir))) {
                try {
                    if (!directoryExists(outDir)) directoryCreate(outDir);
                    var baseName = reReplace(arguments.title, "[^A-Za-z0-9_-]+", "_", "all");
                    if (!len(baseName)) baseName = "openapi";
                    var fileName = baseName & "-openapi.json";
                    var sep = reFind("[\\/]$", outDir) ? "" : ( find("\\", outDir) ? "\\" : "/" );
                    var filePath = outDir & sep & fileName;
                    fileWrite(filePath, outputJson);
                } catch (any e) {
                    // Ignore write failures to avoid breaking main flow
                }
            }
        }

        // ADDED: webhook trigger
        triggerWebhook(
            "SwaggerToOpenAPI",
            {
                "title": arguments.title,
                "version": arguments.version,
                "baseUrl": effectiveBaseUrl,
                "paths": structCount(openapi.paths),
                "size": len(outputJson)
            }
        );

        return outputJson;
    }

    /**
     * Helper function to convert a Postman request item to Markdown
     * @param req Postman request struct
     * @return string (Markdown)
     */
    private string function postmanRequestToMarkdown(struct req) {
        var md = "## " & req.name & chr(10);

        if (structKeyExists(req, "request")) {
            var method = req.request.method;
            var url = req.request.url;
            var desc = structKeyExists(req.request, "description") ? req.request.description : "";

            md &= "**Method:** `" & method & "`  " & chr(10);
            md &= "**URL:** `" & (isSimpleValue(url) ? url : serializeJSON(url)) & "`" & chr(10);

            if (len(trim(desc))) {
                md &= chr(10) & desc & chr(10);
            }
        }
        md &= chr(10);

        // ADDED: webhook trigger per request
        try {
            var eventUrl = structKeyExists(req, "request") ? (isSimpleValue(req.request.url) ? req.request.url : serializeJSON(req.request.url)) : "";
            var eventMethod = structKeyExists(req, "request") ? toString(req.request.method) : "";
            triggerWebhook(
                "postmanRequestToMarkdown",
                { "name": req.name, "method": eventMethod, "url": eventUrl, "size": len(md) }
            );
        } catch (any _ignore) {}

        return md;
    }

    /**
     * Generate a Markdown document from a Postman collection JSON string
     * @param postmanCollectionJson JSON string of the Postman collection (v2.1)
     * @return string (Markdown)
     */
    public string function postmanToMarkdown(
        required string jsonSchema = GetJsonSchema()
    ) {
        var collection = deserializeJSON(arguments.jsonSchema);
        var md = "";

        // Collection title
        if (structKeyExists(collection, "info") && structKeyExists(collection.info, "name")) {
            md &= "## " & collection.info.name & chr(10) & chr(10);
        }

        // Collection description (if any)
        if (structKeyExists(collection.info, "description")) {
            md &= collection.info.description & chr(10) & chr(10);
        }

        // Loop through folders/items
        if (structKeyExists(collection, "item")) {
            for (var folder in collection.item) {
                // If folder has sub-items, treat as folder
                if (structKeyExists(folder, "item")) {
                    md &= "## " & folder.name & chr(10) & chr(10);
                    for (var req in folder.item) {
                        md &= postmanRequestToMarkdown(req);
                    }
                } else {
                    // Single request at root
                    md &= postmanRequestToMarkdown(folder);
                }
            }
        }

        // ADDED: webhook trigger for final markdown
        try {
            var collName = (structKeyExists(collection, "info") && structKeyExists(collection.info, "name")) ? collection.info.name : "";
            triggerWebhook(
                "postmanToMarkdown",
                { "collectionName": collName, "size": len(md) }
            );
        } catch (any _ignore) {}

        return md;
    }

    /**
     * Resolve the effective base URL using (in order):
     * 1) Provided argument baseUrl (if non-empty)
     * 2) Component baseUrl property (if set and not the placeholder)
     * 3) Component host property -> http://{host}:8500/rest
     * 4) Fallback to component baseUrl (placeholder default)
     */
    private string function resolveBaseUrl(string baseUrl = "") {
        var placeholder = "https://api.example.com";
        var argUrl = trim(toString(baseUrl));
        if (len(argUrl)) return argUrl;

        var compBase = trim(toString(variables.baseUrl));
        if (len(compBase) && lcase(compBase) NEQ lcase(placeholder)) return compBase;

        var h = trim(toString(variables.host));
        if (len(h)) {
            // Assume host is IP or FQDN; build default REST root
            // If a scheme is included, use as-is; otherwise default to http and port 8500/rest
            if (reFindNoCase("^[a-z][a-z0-9+\.-]*://", h)) {
                return h;
            } else {
                return "http://" & h & ":8500/rest";
            }
        }

    return len(compBase) ? compBase : placeholder;
    }

    /**
     * Map legacy parameter/type definitions to a minimal OpenAPI schema object
     */
    private struct function legacyTypeToSchema(required struct paramDef) {
        var schema = {};
        var t = structKeyExists(arguments.paramDef, "type") ? lcase(arguments.paramDef.type) : "string";

        switch (t) {
            case "int":
            case "integer":
                schema.type = "integer";
                break;
            case "long":
                schema.type = "integer";
                schema.format = "int64";
                break;
            case "float":
                schema.type = "number";
                schema.format = "float";
                break;
            case "double":
                schema.type = "number";
                schema.format = "double";
                break;
            case "bool":
            case "boolean":
                schema.type = "boolean";
                break;
            case "array":
                schema.type = "array";
                if (structKeyExists(arguments.paramDef, "items")) {
                    schema.items = legacyTypeToSchema(arguments.paramDef.items);
                } else {
                    schema.items = { "type": "string" };
                }
                break;
            case "object":
                schema.type = "object";
                if (structKeyExists(arguments.paramDef, "properties") && isStruct(arguments.paramDef.properties)) {
                    schema.properties = {};
                    for (var pName in arguments.paramDef.properties) {
                        schema.properties[pName] = legacyTypeToSchema(arguments.paramDef.properties[pName]);
                    }
                }
                break;
            default:
                schema.type = "string";
        }

        return schema;
    }

    /**
     * Sanitize a string to a valid OpenAPI operationId
     */
    private string function sanitizeOperationId(required string rawId) {
        var id = reReplace(arguments.rawId, "[^A-Za-z0-9_]+", "_", "all");
        id = reReplace(id, "^_+|_+$", "", "all");
        if (!len(id)) id = "op_" & left(hash(createUUID()), 8);
        return id;
    }
    
    /**
    * Fetch the REST root and list available app/service names.
    * Example sourceUrl: "http://127.0.0.1:8500/rest/" which returns
    *   [ { "name":"defender", "status":"", "message":"" } ]
    * @param sourceUrl Root REST URL that returns an array of objects with a name property.
    * @param timeout   Optional request timeout in seconds (default 10).
    * @return struct    Struct of string names (e.g., ["defender"]).
    */
    public struct function listApps(string sourceUrl = "", numeric timeout = 10) {

        var names = [];
        var endpoint = len(trim(arguments.sourceUrl)) ? arguments.sourceUrl : getSourceUrl();

        cfhttp( url=endpoint, method="GET", timeout=timeout, result="apiResponse" ) {
            cfhttpparam( type="header", name="Accept", value="application/json" );
            cfhttpparam( type="header", name="User-Agent", value="#this.name#" );
        }

        return {
            "value" : deserializeJSON(apiResponse.fileContent)
        };
    }

    /**
    * Fetch the REST root and list available app/service names.
    * Example sourceUrl: "http://127.0.0.1:8500/rest/" which returns
    *   [ { "name":"defender", "status":"", "message":"" } ]
    * @param sourceUrl Root REST URL that returns an array of objects with a name property.
    * @param timeout   Optional request timeout in seconds (default 10).
    * @return struct    Struct of string names (e.g., ["defender"]).
    */
    public struct function listAppSchemas(string sourceUrl = "", numeric timeout = 10) {

        var names = [];
        var endpoint = len(trim(arguments.sourceUrl)) ? arguments.sourceUrl : getSourceUrl();

        local.appCollection = listApps( sourceUrl = endpoint, timeout = arguments.timeout );

        appNames = local.appCollection.value.map( (app)=>{
            return app.name;
        } )

        cfhttp( url=endpoint & "?apps=" & arrayToList(appNames), method="GET", timeout=timeout, result="apiResponse" ) {
            cfhttpparam( type="header", name="Accept", value="application/json" );
            cfhttpparam( type="header", name="User-Agent", value="#this.name#" );
        }

        local.schemaCollection = deserializeJSON(apiResponse.fileContent);

        for (i = 1; i <= ArrayLen(local.schemaCollection); i++) {
            local.schemaCollection[i]['host'] = getHost()
        }
            

        return {
            "value" : local.schemaCollection
        };
    }


    
    /**
    * Extract unique endpoint paths from a schema JSON (array or struct).
    * @param Schema The decoded schema JSON (array or struct)
    * @return array Array of unique endpoint paths (strings), order preserved
    */
    public array function getAppEndpoints(required any Schema) {
        var endpoints = [];
        var seen = structNew();

        if (isArray(arguments.Schema)) {
            for (item in arguments.Schema) {
                if (isStruct(item) and structKeyExists(item, "resources") and isStruct(item.resources)) {
                    for (resName in item.resources) {
                        var resource = item.resources[resName];
                        if (isStruct(resource) and structKeyExists(resource, "apis") and isArray(resource.apis)) {
                            for (api in resource.apis) {
                                if (isStruct(api) and structKeyExists(api, "path")) {
                                    var p = api.path;
                                    if (!structKeyExists(seen, p)) {
                                        arrayAppend(endpoints, p);
                                        seen[p] = true;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return endpoints;
    }

    /**
    * Fetch the schema JSON for a specific app/service.
    * Example: getAppSchema("defender") will GET http://host:8500/rest/defender/schema
    * @param appName   Name of the app/service (required)
    * @param sourceUrl Optional REST root URL (defaults to getSourceUrl())
    * @param timeout   Optional request timeout in seconds (default 10)
    * @return any   Decoded schema JSON as struct
    */
    public any function getAppSchema(
        required string appName,
        string sourceUrl = "",
        numeric timeout = 10
    ) {
        var rootUrl = len(trim(arguments.sourceUrl)) ? arguments.sourceUrl : getSourceUrl();

        var endpoint = rootUrl & "/?apps=#arguments.appName#";

        cfhttp( url=endpoint, method="GET", timeout=timeout, result="schemaResponse" ) {
            cfhttpparam( type="header", name="Accept", value="application/json" );
            cfhttpparam( type="header", name="User-Agent", value="#this.name#" );
        }

        return deserializeJSON(schemaResponse.fileContent)
    }



    /**
     * Getter override for sourceUrl to provide a sensible default derived from host/baseUrl.
     * Ensures a trailing slash for REST root (e.g., http://127.0.0.1:8500/rest/).
     */
    public string function getSourceUrl() {
        var su = trim(toString(variables.sourceUrl));
        if (len(su)) return ensureTrailingSlash(su);

        // Derive from host via resolveBaseUrl (which yields .../rest)
        var base = resolveBaseUrl("");
        return ensureTrailingSlash(base);
    }

    /** Ensure a single trailing slash */
    private string function ensureTrailingSlash(required string url) {
        var u = toString(arguments.url);
        if (right(u,1) NEQ "/") u &= "/";
        return u;
    }



    /**
     * Internal helper: If webhook is enabled and URL set, POST a JSON payload
     * Best-effort: swallow errors and keep primary flow unaffected.
     */
    private void function triggerWebhook(required string eventName, struct payload = {}) {
        try {
            // Check toggle first
            var on = ( getWebhook() EQ true OR lcase(toString(getWebhook())) EQ "true" );
            if (!on) return;

            var url = trim(toString(getWebHookUrl()));
            if (!len(url)) return;

            var body = duplicate(arguments.payload);
            body["event"] = arguments.eventName;
            body["component"] = this.name;
            body["timestamp"] = dateTimeFormat(now(), "yyyy-MM-dd'T'HH:mm:ss'Z'");

            var jsonBody = serializeJSON(body);

            cfhttp( url=url, method="POST", timeout=5, result="whResponse" ) {
                cfhttpparam( type="header", name="Content-Type", value="application/json" );
                cfhttpparam( type="body", value=jsonBody );
            }
        } catch (any e) {
            // Intentionally ignore webhook failures
        }
    }

}
