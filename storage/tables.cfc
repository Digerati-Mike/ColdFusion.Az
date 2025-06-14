component accessors="true" {

    property name="Sas" type="string" required="true" hint="sas token for authentication";
    property name="storageAccount" required="true" type="string" hint="sas token for authentication";
    property name="name" type="string" hint="name of the table";
    property name="baseUrl" type="string" hint="baseUrl / hostname of the table";
    property name="xMsVersion" type="string" default="2023-11-03" hint="api version to usse";
    property name="ODataType" type="string" hint="Type of OData to return. Available values: fullmetadata, minimalmetadata, nometadata, none" default="fullmetadata";
    

    function init( required struct dynamicProperties = {} ) {


        variables.Sas = arguments.dynamicProperties.Sas;

        variables.storageAccount = arguments.dynamicProperties.storageAccount;

        variables.ODataType = arguments.dynamicProperties.ODataType ?: "fullmetadata";

        variables.baseUrl = "https://#variables.storageAccount#.table.core.windows.net";

        variables.name = arguments.dynamicProperties.name;

        
        return this;
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
        required string sas = getSas(),
        required string storageAccount = getStorageAccount()
    ){
        try {
            cfhttp(
                url = "#GetBaseUrl()#/#arguments.tableName#()?#getSas()#",
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
