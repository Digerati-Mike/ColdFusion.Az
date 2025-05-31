component accessors="true" {

    property name="Sas" type="string" required="true" hint="sas token for authentication";
    property name="storageAccount" required="true" type="string" hint="sas token for authentication";
    property name="name" type="string" hint="name of the queue";
    property name="baseUrl" type="string" hint="baseUrl / hostname of the queue";
    

    function init( required struct dynamicProperties = {} ) {


        variables.Sas = arguments.dynamicProperties.Sas;
        variables.storageAccount = arguments.dynamicProperties.storageAccount;

        variables.baseUrl = "https://#variables.storageAccount#.table.core.windows.net";

        variables.name = arguments.dynamicProperties.name;

        
        return this;
    }
    

}
