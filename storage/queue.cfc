component accessors="true" {

    property name="Sas" type="string" required="true" hint="sas token for authentication";
    property name="storageAccount" required="true" type="string" hint="sas token for authentication";
    property name="name" type="string" hint="name of the queue";
    property name="baseUrl" type="string" hint="baseUrl / hostname of the queue";
    property name="xMsVersion" type="string" default="2023-11-03" hint="name of the queue";
    property name="encodeMessage" type="boolean" default="true" hint="base64 encodes the message before placing into the queue";
    

    // USE WITH CAUTION WITH LARGE MESSAGES
    property name="decodeMessage" type="boolean" default="true" hint="Automatically decodes the message if it is base64 encoded.";



    function init( required struct dynamicProperties = {} ) {


        variables.Sas = arguments.dynamicProperties.Sas;
        variables.storageAccount = arguments.dynamicProperties.storageAccount;

        variables.baseUrl = "https://#variables.storageAccount#.queue.core.windows.net";

        variables.name = arguments.dynamicProperties.name;

        if( !testAuth() ){
            throw( type="Auth Error", message="Could not validate connection to storage account", detail="Please check your connection string and try again." );
        }
        
        return this;
    }
    
    
    /** 
    * @hint Converts an XML string to a JSON object
    * @returnType any
    **/
    public function xmlToJson( required string xmlString ){

        try {
            JSONText = CreateObject("java", "org.json.XML").ToJsonObject(xmlString);
            return DeserializeJSON(JSONText);
        } catch (any e) {
            return {
                "error" = e.message
            };
        }
    }


    /**
    * @hint Checks if a queue exists
    * @returnType boolean
    **/
    public function QueueExists(
        required string name = getName(),
        required string sas = getSas(),
        required string storageAccount = getStorageAccount()
    ){
        try {
            cfhttp(
                url = "https://#variables.storageAccount#.queue.core.windows.net/#arguments.name#?comp=metadata&#getSas()#",
                method = "GET",
                result = "httpResponse"
            ) {
                cfhttpparam(type="header", name="x-ms-version", value="#GetXmsVersion()#");
            }
            // 200 means queue exists, 404 means not found
            return httpResponse.statusCode contains "200";
        } catch (any e) {
            // If the error is 404, queue does not exist
            if (isDefined("httpResponse.statusCode") && httpResponse.statusCode contains "404") {
                return false;
            }
            // For other errors, rethrow or return false
            return false;
        }
    }

    /**
    * @hint list queues
    * @returnType struct    
    **/
    public function ListQueues(
        required string sas = getSas(),
        required string storageAccount = getStorageAccount()
    ){
        try {
            cfhttp(
                url = "https://#variables.storageAccount#.queue.core.windows.net/?comp=list&#getSas()#",
                method = "GET",
                result = "httpResponse"
            ) {
                cfhttpparam(type="header", name="x-ms-version", value="#GetXmsVersion()#");
            }


            local.queueObject = xmlToJson(httpResponse.fileContent);

            if( !IsArray( local.queueObject.enumerationResults.queues.queue ) ){
                local.queueObject.enumerationResults.queues.queue = [ local.queueObject.enumerationResults.queues.queue ];
            }

            return {
                "value" : local.queueObject.enumerationResults.queues.queue
            }
        } catch (any e) {
            return {
                "error" = e.message,
                "statusCode" = httpResponse.statusCode,
                "response" = httpResponse.fileContent
            };
        }
    }   


    /**
    * @hint Get Queue MetaData
    * @returnType struct    
    **/
    public function GetQueueMetaData(
        required string name = getName(),
        required string sas = getSas(),
        required string storageAccount = getStorageAccount()
    ){
        try {
            cfhttp(
                url = "https://#variables.storageAccount#.queue.core.windows.net/#arguments.name#?comp=metadata&#getSas()#",
                method = "GET",
                result = "httpResponse"
            ) {
                cfhttpparam(type="header", name="x-ms-version", value="#GetXmsVersion()#");
            }


            headerKeys = StructKeyArray(httpResponse.Responseheader);        

            for (i = 1; i <= ArrayLen(headerKeys); i++) {
                
                if( headerKeys[i] contains "x-ms-meta-" ){
                    local.key = ReplaceNoCase(headerKeys[i], "x-ms-meta-", "");
                    local.value = httpResponse.Responseheader[headerKeys[i]];
                    local.metaData[local.key] = local.value;
                }
            }

            return local.metaData
        } catch (any e) {
            return {
                "error" = e.message,
                "statusCode" = httpResponse.statusCode,
                "response" = httpResponse.fileContent
            };
        }
    }



    /**
    * @hint Set Queue MetaData
    * @returnType struct    
    **/
    public function SetQueueMetaData(
        required struct metadata = {
            "key" : "value"
        },
        required string name = getName(),
        required string sas = getSas(),
        required string storageAccount = getStorageAccount()
    ){
        try {
            cfhttp(
                url = "https://#variables.storageAccount#.queue.core.windows.net/#arguments.name#?comp=metadata&#getSas()#",
                method = "PUT",
                result = "httpResponse"
            ) {
                cfhttpparam(type="header", name="x-ms-version", value="#GetXmsVersion()#");
                for( key in structKeyList(arguments.metadata) ){
                    cfhttpparam(type="header", name="x-ms-meta-#key#", value="#arguments.metadata[key]#");
                }
            }
            
            return httpResponse
        } catch (any e) {
            return {
                "error" = e.message,
                "statusCode" = httpResponse.statusCode,
                "response" = httpResponse.fileContent
            };
        }
    }   
    
    /**
    * @hint Adds a new queue
    * @returnType struct    
    **/
    public function AddQueue(
        required string name = getName(),
        required string sas = getSas(),
        required string storageAccount = getStorageAccount()
    ){
        try {
            cfhttp(
                url = "https://#variables.storageAccount#.queue.core.windows.net/#arguments.name#?#getSas()#",
                method = "PUT",
                result = "httpResponse"
            ) {
                cfhttpparam(type="header", name="x-ms-version", value="#GetXmsVersion()#")
            }


            return {
                "success" : (httpResponse.statusCode contains "204") ? true : false
            }



        } catch (any e) {
            return {
                "error" = e.message,
                "statusCode" = httpResponse.statusCode,
                "response" = httpResponse.fileContent
            };
        }
    }   


    /**
    * @hint Adds a message to the specified queue
    * @returnType struct
    **/
    public function AddMessage(
        required string messageText,
        required numeric messageTTL = 60,
        required numeric visibilitytimeout = 0,
        required string name = getName(),
        required string sas = getSas(),
        required string storageAccount = getStorageAccount()
    ){
        if (getEncodeMessage()) {
            var xmlPayload = '<QueueMessage><MessageText>' & toBase64(arguments.messageText) & '</MessageText></QueueMessage>';
     
        } else {
            var xmlPayload = '<QueueMessage><MessageText>' & arguments.messageText & '</MessageText></QueueMessage>';
        }

        
        try {
            cfhttp(
                url = "https://#variables.storageAccount#.queue.core.windows.net/#arguments.name#/messages?messagettl=#arguments.messagettl#&visibilitytimeout=#arguments.visibilitytimeout#&#getSas()#",
                method = "POST",
                result = "httpResponse"
            ) {
                cfhttpparam(type="header", name="x-ms-version", value="#GetXmsVersion()#");
                cfhttpparam(type="header", name="Content-Type", value="application/xml");
                cfhttpparam(type="body", value=xmlPayload);
            }

            local.message = xmlToJson(httpResponse.fileContent);

            return {
                "messageId" : local.message.QueueMessagesList.QueueMessage.MessageId,
                "PopReceipt" : local.message.QueueMessagesList.QueueMessage.PopReceipt,
                "ExpirationTime" : local.message.QueueMessagesList.QueueMessage.ExpirationTime,
                "serverTimeStamp" : now(),
                "TimeNextVisible" : local.message.QueueMessagesList.QueueMessage.TimeNextVisible,
                "InsertionTime" : local.message.QueueMessagesList.QueueMessage.InsertionTime,
                "messageText" : arguments.messageText

            }
        } catch (any e) {
            return {
                "error" = e.message,
                "statusCode" = isDefined("httpResponse.statusCode") ? httpResponse.statusCode : "",
                "response" = isDefined("httpResponse.fileContent") ? httpResponse.fileContent : ""
            };
        }
    }

    
    /**
    * @hint Verifies the SAS token and storage account credentials by attempting to list queues
    * @returnType boolean
    **/
    public function TestAuth(){

        try {
            cfhttp(
                url = "https://#variables.storageAccount#.queue.core.windows.net/?comp=list&#getSas()#",
                method = "GET",
                result = "httpResponse"
            ) {
                cfhttpparam(type="header", name="x-ms-version", value="#GetXmsVersion()#");
            }

            if( httpResponse.statusCode contains 200 ){
                return true;
            } else {
                return false;
            }
        } catch (any e) {
            return false;
        }
    }



    /**
    * @hint List (peek) messages in a queue
    * @returnType struct
    **/
    public function ListMessages(
        required string name = getName(),
        required string sas = getSas(),
        required string storageAccount = getStorageAccount(),
        numeric numOfMessages = 1
    ){
        try {
            cfhttp(
                url = "https://#variables.storageAccount#.queue.core.windows.net/#arguments.name#/messages?peekonly=true&numofmessages=#arguments.numOfMessages#&#getSas()#",
                method = "GET",
                result = "httpResponse"
            ) {
                cfhttpparam(type="header", name="x-ms-version", value="#GetXmsVersion()#");
            }
            local.messages = xmlToJson(httpResponse.fileContent);
            

            if( !structKeyExists(local.messages.QueueMessagesList, "queuemessage") ){
                return {
                    "success": false,
                    "message": "No messages found in the queue",
                    "value": []
                };
            } 
            if( !IsArray( local.messages.QueueMessagesList.queueMessage ) ){
                local.messages.QueueMessagesList.queueMessage = [ local.messages.QueueMessagesList.queueMessage ];
            }
            if( getDecodeMessage() ){
                for (i = 1; i <= ArrayLen(local.messages.QueueMessagesList.queueMessage); i++) {
                   local.messages.QueueMessagesList.queueMessage[i].MessageText = ToString(ToBinary((local.messages.QueueMessagesList.queueMessage[i].MessageText)));
                }
            }

            return {
                "success": true,
                "value": local.messages.QueueMessagesList.queueMessage
            };
        } catch (any e) {
            return {
                "error" = e.message,
                "statusCode" = isDefined("httpResponse.statusCode") ? httpResponse.statusCode : "",
                "response" = isDefined("httpResponse.fileContent") ? httpResponse.fileContent : ""
            };
        }
    }
    
    /**
    * @hint Clear all messages from a queue
    * @returnType struct
    **/
    public function ClearMessages(
        required string name = getName(),
        required string sas = getSas(),
        required string storageAccount = getStorageAccount()
    ){
        try {
            cfhttp(
                url = "https://#variables.storageAccount#.queue.core.windows.net/#arguments.name#/messages?#getSas()#",
                method = "DELETE",
                result = "httpResponse"
            ) {
                cfhttpparam(type="header", name="x-ms-version", value="#GetXmsVersion()#");
            }
            return {
                "success": (httpResponse.statusCode contains "204") ? true : false,
                "statusCode": httpResponse.statusCode
            };
        } catch (any e) {
            return {
                "error" = e.message,
                "statusCode" = isDefined("httpResponse.statusCode") ? httpResponse.statusCode : "",
                "response" = isDefined("httpResponse.fileContent") ? httpResponse.fileContent : ""
            };
        }
    }
    
    /**
    * @hint Get a specific message by messageId and popReceipt
    * @returnType struct
    **/
    public function getMessage(
        required string name = getName(),
        required string messageId,
        required string sas = getSas(),
        required string storageAccount = getStorageAccount()
    ){
        try {
            local.messages = ListMessages( arguments.name )


            for (i = 1; i <= ArrayLen(local.messages.value); i++) {
                if( local.messages.value[i].MessageId == arguments.messageId ) {
                    local.message = local.messages.value[i];
                    break;
                }
            }

            return {
                "success": false,
                "message": "message not found"
            };
        } catch (any e) {
            return {
                "error" = e.message,
                "statusCode" = isDefined("httpResponse.statusCode") ? httpResponse.statusCode : "",
                "response" = isDefined("httpResponse.fileContent") ? httpResponse.fileContent : ""
            };
        }
    }
    
    /**
    * @hint Delete a specific message by messageId and popReceipt
    * @returnType struct
    **/
    public function DeleteMessage(
        required string name = getName(),
        required string messageId,
        required string popReceipt,
        required string sas = getSas(),
        required string storageAccount = getStorageAccount()
    ){
        try {
            cfhttp(
                url = "https://#variables.storageAccount#.queue.core.windows.net/#arguments.name#/messages/#arguments.messageId#?popreceipt=#ENcodeForUrl( arguments.popReceipt )#&#getSas()#",
                method = "DELETE",
                result = "httpResponse"
            ) {
                cfhttpparam(type="header", name="x-ms-version", value="#GetXmsVersion()#");
            }
            return {
                "success": (httpResponse.statusCode contains "204") ? true : false,
                "statusCode": httpResponse.statusCode
            };
        } catch (any e) {
            return {
                "error" = e.message,
                "httpResponse" = httpResponse
            };
        }
    }


}
