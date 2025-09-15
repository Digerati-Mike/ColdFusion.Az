
component accessors="true" {

    // Properties
    property name="CloudAlias" type="string" required="true" hint="Storage account alias configured in CF Admin";
    property name="CloudAliasConfig" type="string" required="true" hint="Storage account config profile in CF Admin";
    property name="storageAccount" type="string" required="true" hint="Storage account name";
    property name="storageEndpoint" type="string" required="true" hint="Storage endpoint URL";
    property name="container" type="string" required="false" hint="Container to use, defaults to 'mycontainer'";
    property name="cloudService" type="string" required="false" hint="Cloud service object";

    // Default property values
    this.defaultProperties = { "container": "mycontainer" };

    /**
     * Initializes the blob object with dynamic properties.
     * @param dynamicProperties Struct of properties to override defaults
     */
    function init(required struct dynamicProperties = {}) {
        // Set default properties
        for (var key in this.defaultProperties) {
            variables[key] = this.defaultProperties[key];
        }
        // Override with dynamic properties
        for (var key in arguments.dynamicProperties) {
            variables[key] = arguments.dynamicProperties[key];
        }
        // Set storage endpoint URL
        variables.storageEndpoint = "https://#variables.storageAccount#.blob.core.windows.net";
        // Get cloud service object
        variables.cloudService = getCloudService(GetCloudAlias(), GetCloudAliasConfig());
        return this;
    }

    /**
     * Generates a SAS URI for a blob in the specified container.
     * @param container Name of the container
     * @param blobName Name of the blob
     * @return struct with SAS URI or error
     */
    public function GenerateSas(
        required string container = "docs",
        required string blobName = "example.pdf",
        required numeric timeSpan = 1,
        required array permissions = ["READ"]
    ) {
        try {
            var local = {};
            // Get container object from cloud service
            local.rootObject = variables.cloudService.container(arguments.container, true);


            local.sasConfig = {
                "blobName": arguments.blobName,
                "policy": {
                    "permissions": arguments.permissions,
                    "sharedAccessExpiryTime": DateTimeFormat(DateAdd('d', arguments.timeSpan, now())),
                    "sharedAccessStartTime": DateTimeFormat(now(), 'mm/dd/yyyy')
                }
            }


            // Generate SAS for the blob
            local.SasUri = local.rootObject.generateSas(local.sasConfig);


            local.connectionString = GetStorageEndpoint() &  '/' &  arguments.container & "/" & arguments.blobName & "?" & local.SasUri.sas


            return {
                "value" : local.sasConfig,
                "endpoint": GetStorageEndpoint() &  '/' &  arguments.container & "/" & arguments.blobName & "?" & local.SasUri.sas,
                "token" : local.sasUri.sas
            }
        } catch (any e) {
            return { "error": e };
        }
    }

}
