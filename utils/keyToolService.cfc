component displayname="KeyToolService" hint="Manages keystores with default configurations" accessors="true" {

    // Properties
    property name="algorithm" default="RSA" type="string" hint="Algorithm for key generation";
    property name="keySize" default="2048" type="numeric" hint="Size of the key in bits";
    property name="validity" default="365" type="numeric" hint="Key validity in days";
    property name="client_id" default="" type="string" hint="Unique identifier (alias) for the keystore";
    property name="client_secret" default="" type="string" hint="Secret for the keystore";
    property name="keyStorePath" default="C:\\ColdFusion2023\\assets\\keystore\\" type="string" hint="Path to keystore directory";
    property name="audience" default="sample.com" type="string" hint="Audience for the JWT tokens";
    property name="executablePath" default="C:\\ColdFusion2023\\jre\\bin\\keytool.exe" type="string" hint="Path to the keytool executable";
    
    /**
     * Initializes component properties.
     * @param configObject Struct containing configuration overrides.
     * @return KeyToolService The initialized instance.
     */
    public KeyToolService function init(required struct configObject = {}) {
        for (var key in configObject) {
            variables[trim(key)] = configObject[key];
        }

        if (!len(variables.client_id)) {
            setClient_id(createUUID());
        }

        if (!len(variables.client_secret)) {
            variables.client_secret = generateSecret();
        }

        return this;
    }

    /**
     * Generates a client secret.
     * @param length Length of the secret. Default is 64.
     * @param encoding Encoding format (base64 or hex). Default is "base64".
     * @return string Encoded secret.
     */
    public string function generateSecret(required numeric length = 64, string encoding = "base64") {
        var charPool = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@##%^&*()-_=[]{}|;:,.<>?/";
        var rawSecret = "";

        if (length < 1) {
            throw("Length must be a positive integer.");
        }

        for (var i = 1; i <= length; i++) {
            rawSecret &= charPool[randRange(1, len(charPool))];
        }

        switch (encoding) {
            case "base64":
                return toBase64(rawSecret);
            case "hex":
                return binaryEncode(toBinary(rawSecret), "hex");
            default:
                throw("Unsupported encoding type: " & encoding);
        }
    }


    
    
    public any function getKeystoreInfo(required string keystorePath, required string keytoolPath, required string storepass) {
        var output = "";
        var errorOutput = "";
        var args = "-keystore " & keystorePath & " -storepass " & storepass & " -list";
        
        // Execute the keytool command
        cfexecute(
            name = keytoolPath,
            arguments = args,
            timeout = 10,
            variable = "output",
            errorVariable = "errorOutput"
        );
        
        // If there's an error, throw it
        if (len(trim(errorOutput))) {
            throw("Keytool command failed: " & errorOutput);
        }
        
        // Build the initial keystore info structure
        var keystore = {
            KeystoreType     = "",
            KeystoreProvider = "",
            EntryCount       = 0,
            Entries          = []
        };

        // Split the output into an array of trimmed, non-empty lines
        var lines = listToArray(output, chr(10));
        for (var i = 1; i <= arrayLen(lines); i++) {
            lines[i] = trim(lines[i]);

            if( i == 1 ) {

                keystore.KeystoreType = ListRest( lines[i], ':' )
            } else if (i == 2) {
                // Second line contains entry count
                keystore.KeystoreProvider = ListRest( lines[i], ':' )
            } else if (i == 4){
                // Third line contains entry count
                var entryCountMatch = REMatch("([0-9]+)", lines[i])[1]
                keyStore.entryCount = entryCountMatch

            } else if(  i >= 6 ) {
                

                SplitLine = ListToArray(lines[i]);
                
                if( arrayLen(SplitLine) GTE 4) {
                    
                    for (x = 1; x <= ArrayLen(SplitLine); x++) {
                        SplitLine[x] = trim(SplitLine[x]);
                        
                    }

                    CertObject  = {
                        "alias" : SplitLine[1],
                        "expires" : SplitLine[2] & " " & SplitLine[3],
                        "type" : SplitLine[4],
                        "fingerprint" : ListRest( lines[i+1], '):' )
                    }

                    ArrayAppend( keyStore.entries, CertObject, true )
                }

            }
        }

            

        
        
                
        return keystore;
    }


    
    /**
     * Creates a new keystore.
     * @param keyStorePath Path where the keystore will be created.
     * @return struct Keystore details.
     */
    public struct function createKeyStore(required string keyStorePath = getKeyStorePath()) {
        if (!directoryExists(keyStorePath)) {
            directoryCreate(keyStorePath);
        }
        
        var keyStoreFilePath = keyStorePath & getClient_id() & ".jks";
        var jks = {
            alias = getClient_id(),
            keyalg = getAlgorithm(),
            keysize = getKeySize(),
            keystore = keyStoreFilePath,
            storepass = getClient_secret(),
            keypass = getClient_secret(),
            validity = getValidity(),
            // The dname may move to be a nested object in the future so it can be controlled via a json file
            dname = '"CN=#getAudience()#, OU=IT, O=Media3, L=Pembroke, S=MA, C=US"'
        };

        var args = "-genkeypair -alias #jks.alias# -keyalg #jks.keyalg# -keysize #jks.keysize# -keystore #jks.keystore# " &
                   "-storepass #jks.storepass# -keypass #jks.keypass# -validity #jks.validity# -dname #jks.dname#";

        cfexecute(
            name = getExecutablePath(),
            arguments = args,
            variable = "responseVar",
            errorVariable = "errorVar",
            timeout = 5
        );

        return {
            "message" : errorVar,
            "client_id" : getClient_id(),
            "client_secret" : getClient_secret(),
            "keyalg" : getAlgorithm(),
            "keysize" : getKeySize(),
            "expires" : getValidity()
        }
    }

    
    /**
    * Changes the password of an existing keystore.
    * @param keyStorePath Path to the keystore.
    * @param oldPassword Current password of the keystore.
    * @param newPassword New password to set for the keystore.
    * @return struct Updated keystore details.
    */
    public struct function changePassword(
        required string keyStorePath,
        required string oldPassword,
        required string newPassword
    ) {
        // Validate if the keystore file exists
        if (!fileExists(keyStorePath)) {
            throw(
                type="KeyStoreNotFound",
                message="The keystore at the specified path does not exist: #keyStorePath#"
            );
        }

        // Construct arguments to change the keystore password
        var args = "-storepasswd -keystore #keyStorePath# " &
                "-storepass #oldPassword# -newstorepass #newPassword#";

        // Execute the keytool command to change the password
        var errorVar = "";
        var responseVar = "";
        
        cfexecute(
            name = getExecutablePath(),
            arguments = args,
            variable = "responseVar",
            errorVariable = "errorVar",
            timeout = 5
        );

        // Return the updated details
        return {
            "keyStorePath": keyStorePath,
            "newStorePassword": newPassword,
            "response": responseVar,
            "error": errorVar
        };
    }

    /**
     * Adds a new key pair to an existing keystore.
     * @param keyStorePath Path to the existing keystore.
     * @param alias Alias for the new key pair.
     */
    public void function addKeyPair(required string keyStorePath, required string alias) {
        var jks = {
            alias = alias,
            keyalg = getAlgorithm(),
            keysize = getKeySize(),
            keystore = keyStorePath,
            storepass = getClient_secret(),
            keypass = getClient_secret(),
            validity = getValidity(),
            dname = '"CN=#getAudience()#, OU=IT, O=SampleCompany, L=TOWN, S=STATE, C=US"'
        };

        var args = "-genkeypair -alias #jks.alias# -keyalg #jks.keyalg# -keysize #jks.keysize# -keystore #jks.keystore# " &
                   "-storepass #jks.storepass# -keypass #jks.keypass# -validity #jks.validity# -dname #jks.dname#";

        cfexecute(
            name = getExecutablePath(),
            arguments = args,
            variable = "responseVar",
            errorVariable = "errorVar",
            timeout = 5
        );
        
        return {
            "jks" : jks,
            "config" : {
                "client_id" = getClient_id(),
                "client_secret" = getClient_secret()
            },
            "value" : errorVar
        };
    }

    /**
     * Lists all keystores in the specified directory.
     * @param keyStorePath Path to the keystore directory.
     * @return array List of keystores with metadata.
     */
    public array function listKeyStores(required string keyStorePath = variables.keyStorePath) {
        var clients = directoryList(
            path = keyStorePath,
            recurse = false,
            listInfo = "query",
            type = "dir"
        );

        local.returnObject = queryExecute(
            "SELECT DateLastModified AS updated, name, size, directory FROM clients ORDER BY name",
            {},
            { dbType = "query", returnType = "array" }
        ).map((row) => {
            
            row['client_id'] = listFirst(row.name, ".");
            row['updated'] = DateTimeFormat(row.updated, "yyyy-mm-dd'T'HH:mm:ssZ");

            structDelete(row, "name");
            structDelete(row, "directory");
            
            return row;
        });

        return local.returnObject
    }


    /**
     * Deletes an existing keystore.
     * @param keyStorePath Path to the keystore.
     * @return struct Result of the deletion.
     */
    public struct function deleteKeyStore(required string keyStorePath) {
        // Validate if the keystore file exists
        if (!fileExists(keyStorePath)) {
            throw(
                type="KeyStoreNotFound",
                message="The keystore at the specified path does not exist: #keyStorePath#"
            );
        }

        // Delete the keystore file
        fileDelete(keyStorePath);

        // Return the result
        return {
            "keyStorePath": keyStorePath,
            "message": "Keystore successfully deleted."
        };
    }
}
