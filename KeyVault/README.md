
# keyvault.cfc — Azure Key Vault helper (CFML)

This component wraps Azure Key Vault REST operations. It supports Azure Managed Identity (default) or a pre-supplied bearer token.

- File: `keyvault.cfc`
- Defaults: `api-version=7.4`, endpoint `https://{vaultName}.vault.azure.net/`

## Setup

Instantiate with at least `vaultName`. If you omit `auth`, the component will attempt to get a token from Azure IMDS (Managed Identity).

```cfml
// Using Managed Identity (on an Azure VM/AppService with MI enabled)
kv = new keyvault({
    vaultName: "my-keyvault"
});

// Using a pre-obtained bearer token (e.g., client credentials)
kv = new keyvault({
    vaultName: "my-keyvault",
    auth: { access_token: myAccessToken } // string token
});

// Optional overrides
kv = new keyvault({
    vaultName: "my-keyvault",
    "api-version": "7.4",
    imsEndpoint: "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net/",
    endpoint: "https://{{vaultName}}.vault.azure.net/" // {{vaultName}} gets replaced automatically
});
```

Notes
- `auth` must be a struct with `access_token` when supplied manually.
- `fetch()` must be available in your CFML engine (Adobe CF 2023+ or compatible runtime providing `fetch`).

## API reference with examples

### getSecrets()
List all secrets (names/ids; values are not included in the list response).

```cfml
result = kv.getSecrets();
// result = { value: [ { id: ".../secrets/secretA", attributes: {...} }, ... ] }
writeDump(result);
```

### getSecret(secretName)
Get a single secret (returns the latest version by id if present). Response is the Key Vault secret bundle; access the value via `result.value`.

```cfml
secret = kv.getSecret("db-password");
if (isStruct(secret) && structKeyExists(secret, "value")) {
    pw = secret.value;
}
writeDump(secret);
```

### getSecretVersions(secretName)
List versions (metadata) for a secret.

```cfml
versions = kv.getSecretVersions("db-password");
// { value: [ { id: ".../secrets/db-password/{versionId}", attributes: {...} }, ... ] }
writeDump(versions);
```

### addSecret(secretName, secretValue, secretAttributes={})
Create or update a secret. You can pass optional fields per the Key Vault API (`attributes`, `tags`, `contentType`). If you want to set expiry (`exp`) or not-before (`nbf`), use the provided epoch helpers.

```cfml
// Example: add a secret with tags and 30‑day expiry
expEpoch = kv.dateTimeToEpoch( dateAdd("d", 30, now()) );
response = kv.addSecret(
    secretName = "db-password",
    secretValue = "S3cr3t!",
    secretAttributes = {
        attributes: { enabled: true, exp: expEpoch },
        tags: { env: "prod", owner: "platform" },
        contentType: "text/plain"
    }
);
writeDump(response);
```

### deleteSecret(secretName)
Deletes a secret and then purges it after a short wait. WARNING: This is a permanent delete once purged.

```cfml
result = kv.deleteSecret("db-password");
// The function waits ~15 seconds, then calls the purge endpoint.
writeDump(result);
```

### dateTimeToEpoch(dateTime)
Convert a CFML date/time to Unix epoch seconds.

```cfml
epoch = kv.dateTimeToEpoch( now() );
```

### epochToDateTime(epoch)
Convert Unix epoch seconds to a CFML date/time.

```cfml
dt = kv.epochToDateTime( 1735689600 ); // example epoch
```

## Error handling
- Auth: If Managed Identity is not available or `fetch` fails, `Auth()` returns `{ error: "..." }`.
- Most methods return the JSON response from the REST API as a struct. Check for HTTP error payloads (e.g., `structKeyExists(resp, "error")`).

```cfml
resp = kv.getSecret("missing-secret");
if (isStruct(resp) && structKeyExists(resp, "error")) {
  // Handle error message/code from Key Vault
  writeDump(resp.error);
}
```

## Behavior notes
- Pagination: `getSecrets()` follows `nextLink` automatically and merges pages.
- `getSecret()` first queries the latest secret, then follows the `id` to fetch by specific version when available.
- `deleteSecret()` performs soft delete then attempts purge (hard delete) after a 15s sleep.

## Minimum requirements
- CFML engine with `fetch()` and JSON serialization (`serializeJSON`) support.
- Running in Azure with Managed Identity for default token flow, or provide your own bearer token via `auth.access_token`.
