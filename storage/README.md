## Notes:

Authorization: Only has ability for sas uri currently. Please be careful not to expose this sas uri in log ingestion / apache / iis logs or ColdFusion-Out.log and http.log




# Examples: tables.cfc

```cfscript
  tableStorage = new Tables({
      "storageAccount" : "{{storageAccount}}",
      "sas" : "{{sasUri}}",
      "name" : "testtable"
  });
  
 
  tableStorage.InsertRecord({
      "id" : 1,
      "PartitionKey": createUUID(),  
      "RowKey": CreateUUID()
  } )

  // Get queue messages (max returned in a single response is 32)
  GetMessagesWithOData =  tableStorage.ListRecords( filter = "(id eq '1')", 32 )



  // Get All Messages
  GetMessage =  tableStorage.ListAllRecords( )

  // Delete the processed record from the table
  DeleteRecord = tableStorage.DeleteRecord( GetMessagesWithOData.value[1].PartitionKey, GetMessagesWithOData.value[1].RowKey );
  
```

# Examples: queue.cfc

```cfscript
  queueStorage = new queue({
        "storageAccount" : "{{storageAccount}}",
        "sas" : "{{sasUri}}",
        "name" : "testqueue"
  });
  
  addMessage = queueStorage.addMessage( "my text")

  
  queueStorage.deleteMessage( addMessage.messageId, addMessage.popReceipt );
```
