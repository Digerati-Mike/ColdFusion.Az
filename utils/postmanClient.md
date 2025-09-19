# PostmanClient.cfc Guide

Practical guide for `com/integrations/common/PostmanClient.cfc`: discover REST apps, fetch their schemas, generate Postman collections and environments, convert to OpenAPI, and produce Markdown docs. Includes base URL resolution, CDCI file output, and optional webhook notifications.

## Overview

This utility helps local dev tooling under `/app/dev/*` by:

- Discovering REST applications at a REST root (e.g., `http://127.0.0.1:8500/rest/`)
- Fetching each app's legacy schema shape
- Converting legacy/Swagger-like schema → Postman collection (v2.1)
- Converting legacy schema → OpenAPI 3.x JSON
- Generating a Postman Environment with `baseUrl`
- Rendering a Markdown document from a Postman collection

Key methods:

- `listApps(sourceUrl?, timeout?)`
- `listAppSchemas(sourceUrl?, timeout?)`
- `getAppSchema(appName, sourceUrl?, timeout?)`
- `getAppEndpoints(schema)`
- `SwaggerToPostman(jsonSchema, collectionName?, baseUrl?)`
- `generateEnvironment(envName?, baseUrl?)`
- `SwaggerToOpenAPI(jsonSchema, title?, version?, baseUrl?, openapiVersion?)`
- `postmanToMarkdown(jsonSchema)`

## Quick start

```cfml
// Create an instance
pc = new com.integrations.common.PostmanClient({
	host: "127.0.0.1",      // or FQDN; used to build default base url
	// baseUrl: "https://api.example.com", // optional explicit base url
	// sourceUrl: "http://127.0.0.1:8500/rest/" // optional, otherwise derived
	rootDir: expandPath("/_data/tools"), // where outputs can be saved when cdci=true
	cdci: true,                          // auto-write generated files (best-effort)
	webhook: true,                       // optionally emit webhook events
	webHookUrl: "https://hooks.example.com/my-endpoint"
});
```

## Base URL resolution

The client picks a base URL in this order:

1) The `baseUrl` argument you pass to a method
2) The component property `baseUrl` (if set and not the placeholder `https://api.example.com`)
3) The `host` property: becomes `http://{host}:8500/rest`
4) Fallback: `https://api.example.com`

Tip: When running on a CF dev server, `host: "127.0.0.1"` is often enough. You can also set `sourceUrl` directly to `http://127.0.0.1:8500/rest/`. `getSourceUrl()` always ensures a trailing slash.

## Discover available REST apps

```cfml
apps = pc.listApps();
/** apps => { "value": [ { "name": "defender", "status": "", "message": "" } ] } */

// With explicit root
apps = pc.listApps( sourceUrl = "http://127.0.0.1:8500/rest/" );
```

## Fetch all app schemas at once

```cfml
schemas = pc.listAppSchemas();
/** schemas => { "value": [ { resources: { ... }, host: "127.0.0.1" }, ... ] } */
```

Notes:
- Each schema in `value` is augmented with `host` for downstream usage.
- Default timeout is 10 seconds; adjust with `timeout`.

## Fetch a single app schema

```cfml
schema = pc.getAppSchema( appName = "defender" );
// Returns deserialized JSON schema (struct/array) for that app
```

## Extract endpoint paths from a schema

```cfml
endpoints = pc.getAppEndpoints( schemas.value );
// => [ "/defender/v1/metrics/heartbeat", "/defender/v1/metrics/memory", ... ]
```

## Generate a Postman collection from legacy schema

Input must be a JSON string representing an array of schema objects (e.g., from `listAppSchemas().value`).

```cfml
var schemaJson = serializeJSON( schemas.value );
var collectionJson = pc.SwaggerToPostman(
	jsonSchema = schemaJson,
	collectionName = "Defender API",
	baseUrl = "https://myhost/rest/defender/v1"
);

// If cdci=true and rootDir set, the collection is auto-written as
//   {rootDir}/Defender_API-postman.json  (sanitized name)
```

Collection structure highlights:
- Sets a collection-level variable `baseUrl` you can reference as `{{baseUrl}}`
- Folders match top-level resource categories
- Each request uses the operation method and nickname or path as the name

## Generate a Postman environment

```cfml
envJson = pc.generateEnvironment(
	envName = "Local",
	baseUrl = "http://127.0.0.1:8500/rest/defender/v1"
);
```

Result is a Postman environment JSON with `baseUrl` variable. Import both the collection and environment into Postman.

## Convert legacy schema to OpenAPI 3

```cfml
openapiJson = pc.SwaggerToOpenAPI(
	jsonSchema = schemaJson,
	title = "Defender API",
	version = "1.0.0",
	baseUrl = "https://myhost/rest/defender/v1",
	openapiVersion = "3.0.3"
);

// If cdci=true and rootDir set, auto-written as
//   {rootDir}/Defender_API-openapi.json
```

Notes:
- Parameters with `paramType` other than `body` become OpenAPI parameters in the right `in` location (query/path/header)
- A single `body` parameter is mapped to `requestBody` with `application/json`
- Types like integer, number, boolean, array, object are inferred by `legacyTypeToSchema`
- Responses are copied from `responseMessages` if present; otherwise a default 200 is added
- `operationId` is sanitized by `sanitizeOperationId`

## Produce Markdown docs from a Postman collection

```cfml
// Given the Postman collection JSON string (collectionJson)
var md = pc.postmanToMarkdown( jsonSchema = collectionJson );
```

Output includes collection, folder, and per-request sections with method and URL.

## End-to-end example (all-in-one)

```cfml
pc = new com.integrations.common.PostmanClient({
	host: "127.0.0.1",
	rootDir: expandPath("/_data/tools"),
	cdci: true,
	webhook: false
});

// 1) Discover and fetch schemas
var allSchemas = pc.listAppSchemas();
var schemaJson = serializeJSON(allSchemas.value);

// 2) Collection + Environment
var collectionJson = pc.SwaggerToPostman(
	jsonSchema = schemaJson,
	collectionName = "Local Defender API"
);
var envJson = pc.generateEnvironment(
	envName = "Local",
	baseUrl = pc.getSourceUrl() & "defender/v1"
);

// 3) OpenAPI
var openapiJson = pc.SwaggerToOpenAPI(
	jsonSchema = schemaJson,
	title = "Local Defender API",
	version = "1.0.0",
	baseUrl = pc.getSourceUrl() & "defender/v1"
);

// 4) Markdown from collection
var md = pc.postmanToMarkdown( jsonSchema = collectionJson );
```

If `cdci=true` and `rootDir` is set, steps 2 and 3 auto-save files into that directory.

## Webhook notifications (optional)

If `webhook=true` and `webHookUrl` is set, the client will POST a small JSON payload for these events:

- `SwaggerToPostman`
- `generateEnvironment`
- `SwaggerToOpenAPI`
- `postmanRequestToMarkdown` (per request item)
- `postmanToMarkdown` (final document)

Payload includes fields like `event`, `component`, `timestamp`, and operation-specific metadata (e.g., collection size, path count). Webhook failures are swallowed.

## Error handling and timeouts

- Discovery and schema fetch use `cfhttp` with default timeout of 10 seconds (configurable)
- Webhook failures are swallowed (do not break primary flow)
- CDCI file writes are best-effort and quietly ignored on failure

## Tips

- Prefer `getSourceUrl()` to construct URLs consistently; it ensures a trailing slash
- When building `baseUrl` for Postman/OpenAPI, target the logical REST base like `https://host/rest/defender/v1`
- Use `getAppEndpoints(schemas.value)` to quickly list unique endpoint paths across all resources
- Preserve JSON key casing across your own integrations to match codebase conventions
