# graphClient.cfc

A ColdFusion component for authenticating and interacting with the Microsoft Graph API. This utility simplifies making API requests to Microsoft Graph, handling authentication, headers, and flexible request options.

## Features
- Easily send requests to any Microsoft Graph API endpoint
- Supports all HTTP methods (GET, POST, PATCH, DELETE, etc.)
- Handles authentication via Bearer token
- Flexible options for headers, query parameters, and request body
- Automatic JSON serialization/deserialization

## Usage

### Initialization
```
// Create a new instance with your access token
var graphclient = new com.graphClient({
    "access_token": "YOUR_ACCESS_TOKEN"
});
```

### Sending Requests
```
// Send a GET request to /me endpoint
var response = graphclient.send("/me");

// Send a POST request with JSON body
var payload = { displayName = "New List" };
var response = graphclient.send("/me/todo/lists", {
    method: "POST",
    body: serializeJSON(payload)
});

// Send a PATCH request
var payload = { displayName = "Updated Name" };
var response = graphclient.send("/me/todo/lists/LIST_ID", {
    method: "PATCH",
    body: serializeJSON(payload)
});

// Send a DELETE request
var response = graphclient.send("/me/todo/lists/LIST_ID", {
    method: "DELETE"
});
```

### Options
- `uri` (string): The Graph API endpoint (relative or absolute URL)
- `options` (struct):
    - `method`: HTTP method (default: GET)
    - `headers`: Struct of additional headers
    - `body`: Request body (string or struct)
    - `json`: Boolean, serialize body as JSON (default: false)
    - `query`: Struct of query parameters
    - `timeout`: Request timeout in seconds (default: 60)

## Example: Get To Do Lists
```
var lists = graphclient.send("/me/todo/lists");
```

## Example: Create a Task
```
var payload = { title = "My Task" };
var resp = graphclient.send("/me/todo/lists/LIST_ID/tasks", {
    method: "POST",
    body: serializeJSON(payload)
});
```

## Return Value
Returns a struct with the parsed JSON response (if possible), or the raw HTTP result struct.

## Author
Michael Hayes - Media3 Technologies, LLC

---
For more details on the Microsoft Graph API, see: https://docs.microsoft.com/en-us/graph/api/overview
