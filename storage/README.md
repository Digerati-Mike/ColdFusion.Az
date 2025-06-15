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
```

# Examples: queue.cfc

```cfscript
  queueStorage = new queue({
        "storageAccount" : "{{storageAccount}}",
        "sas" : "{{sasUri}}",
        "name" : "testqueue"
  });
  
  queueStorage.addMessage( "my text") 
```
