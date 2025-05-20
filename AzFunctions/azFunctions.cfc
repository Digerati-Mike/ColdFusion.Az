/**
* @accessors true
*/
component {
    
    // Authenticaion / context properties
    property name="access_token"        type="string" required=true hint="Bearer token for authorization";
    property name="api_version"        type="string" default="2023-01-01" required=true hint="The api-version to use";
    property name="cloudInstance"        type="string" default="management.azure.com" required=true hint="The api-version to use";
    property name="resourceId"        type="string" required=true hint="the full resource id of the az function app";

    function init( required struct dynamicProperties = {} ) {
        variables.access_token = arguments.dynamicProperties.access_token;
        variables.resourceId = arguments.dynamicProperties.resourceId;
        variables.api_version = arguments.dynamicProperties.api_version;
        return this;
    }


    function getFunctionApp( required string resourceId = GetResourceId(), required string api_version = GetApi_Version(), required string access_token = GetAccess_Token() ) {
        
        cfhttp(
            url = "https://#GetCloudInstance()#/#arguments.resourceId#?api-version=#arguments.api_version#",
            method = "GET",
            result = "httpResponse"
        ) {
            cfhttpparam(type="header", name="Authorization", value="Bearer #arguments.access_token#");
        }
        return DeserializeJSON( httpResponse.fileContent );;
    } 

    
    function GetFunctionAppFunctions( required string resourceId = GetResourceId(), required string api_version = GetApi_Version(), required string access_token = GetAccess_Token() ) {
        
        cfhttp(
            url = "https://#GetCloudInstance()#/#arguments.resourceId#/functions?api-version=#arguments.api_version#",
            method = "GET",
            result = "httpResponse"
        ) {
            cfhttpparam(type="header", name="Authorization", value="Bearer #arguments.access_token#");
        }
        return DeserializeJSON( httpResponse.fileContent );;
    } 

    

    function getFunctionAppKeys( required string resourceId = GetResourceId(), required string api_version = GetApi_Version(), required string access_token = GetAccess_Token() ) {
       
        cfhttp(
            url = "https://#GetCloudInstance()#/#arguments.resourceId#/host/default/listKeys?api-version=#arguments.api_version#",
            method = "POST",
            result = "httpResponse"
        ) {
            cfhttpparam(type="header", name="Authorization", value="Bearer #arguments.access_token#");
        }
        return DeserializeJSON( httpResponse.fileContent );
    } 


}
