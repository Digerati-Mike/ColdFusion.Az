component accessors="true" {

    property name="Sas" type="string" required="true" hint="sas token for authentication";
    property name="storageAccount" required="true" type="string" hint="sas token for authentication";
    property name="name" type="string" hint="name of the table";
    property name="baseUrl" type="string" hint="baseUrl / hostname of the table";
    property name="xMsVersion" type="string" default="2023-11-03" hint="api version to usse";
    property name="ODataType" type="string" hint="Type of OData to return. Available values: fullmetadata, minimalmetadata, nometadata, none" default="fullmetadata";
    

    function init( required struct dynamicProperties = {} ) {

        // Loop over dynamicProperties and set each as a variable
        for (var key in arguments.dynamicProperties) {
            variables[key] = arguments.dynamicProperties[key];
        }

        // Set baseUrl at the end
        variables.baseUrl = "https://#variables.storageAccount#.table.core.windows.net";


        variables.ODataType = arguments.dynamicProperties.ODataType ?: "fullmetadata";

        if( !TableExists() ){
            createTable()
        }
        
        return this;
    }

    
    /**
    * @hint Checks if a table exists
    * @returnType boolean
    **/
    public function TableExists(
        required string name = getName(),
        required string sas = getSas(),
        required string storageAccount = getStorageAccount()
    ){
        try {
            cfhttp(
                url = "#GetBaseUrl()#/#arguments.name#()?&#getSas()#",
                method = "GET",
                result = "httpResponse"
            ) {
                cfhttpparam(type="header", name="x-ms-version", value="#GetXmsVersion()#");
                cfhttpparam(type="header", name="Accept", value="application/json;odata=#GetODataType()#");
            }
            // 200 means table exists, 404 means not found
            return httpResponse.statusCode contains "200";
        } catch (any e) {
            // If the error is 404, table does not exist
            if (isDefined("httpResponse.statusCode") && httpResponse.statusCode contains "404") {
                return false;
            }
            // For other errors, rethrow or return false
            return false;
        }
    }



    /**
    * @hint list Tables
    * @returnType struct    
    **/
    public function ListTables(
        required string sas = getSas(),
        required string storageAccount = getStorageAccount()
    ){
        try {
            cfhttp(
                url = "#GetBaseUrl()#/Tables?#getSas()#",
                method = "GET",
                result = "httpResponse"
            ) {
                cfhttpparam(type="header", name="x-ms-version", value="#GetXmsVersion()#");
                cfhttpparam(type="header", name="Accept", value="Application/json;odata=#GetODataType()#");
            }

            return {
                "value" : DeserializeJSON( httpResponse.fileContent ).value
            }
        } catch (any e) {
            return {
                "error" = e.message
            };
        }
    }   

    

    /**
    * @hint List Records in a Table
    * @returnType struct    
    **/
    public function ListRecords(
        required string tableName = getName(),
        string filter,
        required string sas = getSas(),
        required string storageAccount = getStorageAccount()
    ){
        try {
            local.endpoint = "#GetBaseUrl()#/#arguments.tableName#()";
            local.endpoint &= "?" & getSas();
            if ( StructKeyExists( arguments,"filter" ) && len(arguments.filter) GTE 1) {
                local.endpoint &= "&$filter=#arguments.filter#";
            } 

            cfhttp(
                url = local.endpoint,
                method = "GET",
                result = "httpResponse"
            ) {
                cfhttpparam(type="header", name="x-ms-version", value="#GetXmsVersion()#");
                cfhttpparam(type="header", name="Accept", value="Application/json;odata=#GetODataType()#");
            }

            return {
                "value" : DeserializeJSON( httpResponse.fileContent ).value
            }
        } catch (any e) {
            return {
                "error" = e.message
            };
        }
    }   


    /**
    * @hint Delete all records in a Table
    * @returnType struct
    **/
    public function DeleteAllRecords(
        required string tableName = getName(),
        required string sas = getSas(),
        required string storageAccount = getStorageAccount()
    ){
        var deletedCount = 0;
        var errors = [];
        try {
            var recordsResponse = ListRecords(tableName=arguments.tableName, sas=arguments.sas, storageAccount=arguments.storageAccount);
            if (structKeyExists(recordsResponse, "value")) {
                for (var record in recordsResponse.value) {
                    var delResult = DeleteRecord(
                        partitionKey = record.PartitionKey,
                        rowKey = record.RowKey,
                        tableName = arguments.tableName,
                        sas = arguments.sas,
                        storageAccount = arguments.storageAccount
                    );
                    if (structKeyExists(delResult, "error")) {
                        arrayAppend(errors, delResult.error);
                    } else {
                        deletedCount++;
                    }
                }
            } else if (structKeyExists(recordsResponse, "error")) {
                return { "error": recordsResponse.error };
            }
            return {
                "deletedCount": deletedCount,
                "errors": errors
            };
        } catch (any e) {
            return {
                "error": e.message
            };
        }
    }
    /**
    * @hint Insert a Record into a Table
    * @returnType struct
    **/
    public function InsertRecord(
        required struct record,
        required string tableName = getName(),
        required string sas = getSas(),
        required string storageAccount = getStorageAccount()
    ){
        try {

            arguments.record.partitionKey = arguments.record.PartitionKey.toString();
            arguments.record.rowKey = arguments.record.rowKey.toString();
            cfhttp(
                url = "#GetBaseUrl()#/#arguments.tableName#?#getSas()#",
                method = "POST",
                result = "httpResponse"
            ) {
                cfhttpparam(type="header", name="x-ms-version", value="#GetXmsVersion()#");
                cfhttpparam(type="header", name="Accept", value="application/json;odata=#GetODataType()#");
                cfhttpparam(type="header", name="Content-Type", value="application/json;odata=#GetODataType()#");
                cfhttpparam(type="body", value="#serializeJSON(arguments.record)#");
            }

            return {
                "statusCode": httpResponse.statusCode,
                "response": isJSON(httpResponse.fileContent) ? DeserializeJSON(httpResponse.fileContent) : httpResponse.fileContent
            };
        } catch (any e) {
            return {
                "error" = e.message
            };
        }
    }



    /**
    * @hint Create a Table
    * @returnType struct
    **/
    public function CreateTable(
        required string tableName = getName(),
        required string sas = getSas(),
        required string storageAccount = getStorageAccount()
    ){
        try {
            // Azure Table Storage expects a JSON body with TableName property
            local.body = serializeJSON({ "TableName": arguments.tableName });

            cfhttp(
                url = "#GetBaseUrl()#/Tables?#getSas()#",
                method = "POST",
                result = "httpResponse"
            ) {
                cfhttpparam(type="header", name="x-ms-version", value="#GetXmsVersion()#");
                cfhttpparam(type="header", name="Accept", value="application/json;odata=#GetODataType()#");
                cfhttpparam(type="header", name="Content-Type", value="application/json");
                cfhttpparam(type="body", value="#local.body#");
            }

            return {
                "statusCode": httpResponse.statusCode,
                "response": isJSON(httpResponse.fileContent) ? DeserializeJSON(httpResponse.fileContent) : httpResponse.fileContent
            };
        } catch (any e) {
            return {
                "error" = e.message
            };
        }
    }




    /**
    * @hint Get a specific Record from a Table
    * @returnType struct
    **/
    public function GetRecord(
        required string partitionKey,
        required string rowKey,
        required string tableName = getName(),
        required string sas = getSas(),
        required string storageAccount = getStorageAccount()
    ){
        try {
            cfhttp(
                url = "#GetBaseUrl()#/#arguments.tableName#(PartitionKey='#arguments.partitionKey#',RowKey='#arguments.rowKey#')?#getSas()#",
                method = "GET",
                result = "httpResponse"
            ) {
                cfhttpparam(type="header", name="x-ms-version", value="#GetXmsVersion()#");
                cfhttpparam(type="header", name="Accept", value="application/json;odata=#GetODataType()#");
            }

            return {
                "statusCode": httpResponse.statusCode,
                "record": isJSON(httpResponse.fileContent) ? DeserializeJSON(httpResponse.fileContent) : httpResponse.fileContent
            };
        } catch (any e) {
            return {
                "error" = e.message
            };
        }
    }


    /**
    * @hint Delete a Record from a Table
    * @returnType struct
    **/
    public function DeleteRecord(
        required string partitionKey,
        required string rowKey,
        required string tableName = getName(),
        required string sas = getSas(),
        required string storageAccount = getStorageAccount()
    ){
        try {
            cfhttp(
                url = "#GetBaseUrl()#/#arguments.tableName#(PartitionKey='#arguments.partitionKey#',RowKey='#arguments.rowKey#')?#getSas()#",
                method = "DELETE",
                result = "httpResponse"
            ) {
                cfhttpparam(type="header", name="x-ms-version", value="#GetXmsVersion()#");
                cfhttpparam(type="header", name="Accept", value="application/json;odata=#GetODataType()#");
                cfhttpparam(type="header", name="If-Match", value="*");
            }

            return {
                "statusCode": httpResponse.statusCode,
                "response": isJSON(httpResponse.fileContent) ? DeserializeJSON(httpResponse.fileContent) : httpResponse.fileContent
            };
        } catch (any e) {
            return {
                "error" = e.message
            };
        }
    }

    /**
    * @hint Delete a Table
    * @returnType struct
    **/
    public function DeleteTable(
        required string tableName = getName(),
        required string sas = getSas(),
        required string storageAccount = getStorageAccount()
    ){
        try {
            cfhttp(
                url = "#GetBaseUrl()#/Tables('#arguments.tableName#')?#getSas()#",
                method = "DELETE",
                result = "httpResponse"
            ) {
                cfhttpparam(type="header", name="x-ms-version", value="#GetXmsVersion()#");
                cfhttpparam(type="header", name="Accept", value="application/json;odata=#GetODataType()#");
            }

            return {
                "statusCode": httpResponse.statusCode,
                "response": isJSON(httpResponse.fileContent) ? DeserializeJSON(httpResponse.fileContent) : httpResponse.fileContent
            };
        } catch (any e) {
            return {
                "error" = e.message
            };
        }
    }

    /**
    * @hint Update a Record in a Table (Merge)
    * @returnType struct
    **/
    public function UpdateRecord(
        required string partitionKey,
        required string rowKey,
        required struct record,
        required string tableName = getName(),
        required string sas = getSas(),
        required string storageAccount = getStorageAccount()
    ){
        try {
            cfhttp(
                url = "#GetBaseUrl()#/#arguments.tableName#(PartitionKey='#arguments.partitionKey#',RowKey='#arguments.rowKey#')?#getSas()#",
                method = "PUT",
                result = "httpResponse"
            ) {
                cfhttpparam(type="header", name="x-ms-version", value="#GetXmsVersion()#");
                cfhttpparam(type="header", name="Accept", value="application/json;odata=#GetODataType()#");
                cfhttpparam(type="header", name="Content-Type", value="application/json");
                cfhttpparam(type="header", name="If-Match", value="*");
                cfhttpparam(type="body", value="#serializeJSON(arguments.record)#");
            }

            return {
                "statusCode": httpResponse.statusCode,
                "response": isJSON(httpResponse.fileContent) ? DeserializeJSON(httpResponse.fileContent) : httpResponse.fileContent
            };
        } catch (any e) {
            return {
                "error" = e.message
            };
        }
    }

    
}
